{ stdenv
, lib
, bc
, bison
, dtc
, fetchFromGitHub
, fetchpatch
, fetchurl
, flex
, gnutls
, libuuid
, meson-tools
, ncurses
, openssl
, python2
, swig
, which
, buildPackages
}:

let
  defaultVersion = "2022.10";
  defaultSrc = fetchurl {
    url = "ftp://ftp.denx.de/pub/u-boot/u-boot-${defaultVersion}.tar.bz2";
    hash = "sha256-ULRIKlBbwoG6hHDDmaPCbhReKbI1ALw1xQ3r1/pGvfg=";
  };
  buildUBoot = lib.makeOverridable ({
    version ? null
  , src ? null
  , filesToInstall
  , installDir ? "$out"
  , defconfig
  , extraConfig ? ""
  , extraPatches ? []
  , extraMakeFlags ? []
  , extraMeta ? {}
  , ... } @ args: stdenv.mkDerivation ({
    pname = "uboot-${defconfig}";

    version = if src == null then defaultVersion else version;

    src = if src == null then defaultSrc else src;

    patches = [
      ./0001-configs-rpi-allow-for-bigger-kernels.patch

      # Make U-Boot forward some important settings from the firmware-provided FDT. Fixes booting on BCM2711C0 boards.
      # See also: https://github.com/NixOS/nixpkgs/issues/135828
      # Source: https://patchwork.ozlabs.org/project/uboot/patch/20210822143656.289891-1-sjoerd@collabora.com/
      ./0001-rpi-Copy-properties-from-firmware-dtb-to-the-loaded-.patch
    ] ++ extraPatches;

    postPatch = ''
      patchShebangs tools
      patchShebangs arch/arm/mach-rockchip
    '';

    nativeBuildInputs = [
      ncurses # tools/kwboot
      bc
      bison
      dtc
      flex
      openssl
      python2 # Fucking rockchip
      (buildPackages.python3.withPackages (p: [
        p.libfdt
        p.setuptools # for pkg_resources
      ]))
      swig
      which # for scripts/dtc-version.sh
    ];
    depsBuildBuild = [ buildPackages.stdenv.cc ];

    buildInputs = [
      ncurses # tools/kwboot
      libuuid # tools/mkeficapsule
      gnutls # tools/mkeficapsule
    ];

    hardeningDisable = [ "all" ];

    enableParallelBuilding = true;

    makeFlags = [
      "DTC=dtc"
      "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
    ] ++ extraMakeFlags;

    passAsFile = [ "extraConfig" ];

    configurePhase = ''
      runHook preConfigure

      make ${defconfig}

      cat $extraConfigPath >> .config

      runHook postConfigure
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p ${installDir}
      cp ${lib.concatStringsSep " " filesToInstall} ${installDir}

      mkdir -p "$out/nix-support"
      ${lib.concatMapStrings (file: ''
        echo "file binary-dist ${installDir}/${builtins.baseNameOf file}" >> "$out/nix-support/hydra-build-products"
      '') filesToInstall}

      runHook postInstall
    '';

    dontStrip = true;

    meta = with lib; {
      homepage = "http://www.denx.de/wiki/U-Boot/";
      description = "Boot loader for embedded systems";
      license = licenses.gpl2;
      maintainers = with maintainers; [ bartsch dezgeg samueldr lopsided98 ];
    } // extraMeta;
  } // removeAttrs args [ "extraMeta" ]));
in {
  inherit buildUBoot;

  ubootTools = buildUBoot {
    defconfig = "tools-only_defconfig";
    installDir = "$out/bin";
    hardeningDisable = [];
    dontStrip = false;
    extraMeta.platforms = lib.platforms.linux;
    extraMakeFlags = [ "HOST_TOOLS_ALL=y" "CROSS_BUILD_TOOLS=1" "NO_SDL=1" "tools" ];
    filesToInstall = [
      "tools/dumpimage"
      "tools/fdtgrep"
      "tools/kwboot"
      "tools/mkenvimage"
      "tools/mkimage"
    ];
  };

  ubootRadxaRock5 = let
    rkbin = fetchFromGitHub {
      owner = "radxa";
      repo = "rkbin";
      rev = "9840e87723eef7c41235b89af8c049c1bcd3d133";
      sha256 = "033qwim94wswj9584qa8qssrgw1w4cgca89hqlbfhfb8savl9qv1";
    };
  in buildUBoot {
    src = fetchFromGitHub {
      owner = "radxa";
      repo = "u-boot";
      rev = "49da44e116d1f68f0ce187d551a7b5b9d1571768";
      sha256 = "1f9qnjgdfn39w3gawgmh2pany0lybg5pyra72wx5sf28lqckhipv";
    };
    version = "2017.09";

    BL31 = "${rkbin}/bin/rk35/rk3588_bl31_v1.28.elf";
    extraMakeFlags = [ "all" "spl/u-boot-spl.bin" "u-boot.dtb" "u-boot.itb" ];
    defconfig = "rock-5b-rk3588_defconfig";
    extraMeta = {
      platforms = [ "aarch64-linux" ];
      license = lib.licenses.unfreeRedistributableFirmware;
    };

    extraPatches = [ ./uboot-reenable-console.patch ];

    filesToInstall = [ "u-boot.itb" "idbloader.img" ];
    postBuild = ''
      ./tools/mkimage -n rk3588 -T rksd -d ${rkbin}/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.08.bin:spl/u-boot-spl.bin idbloader.img
    '';
  };
}
