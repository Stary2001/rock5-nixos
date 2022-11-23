# To build, use:
# nix-build nixos -I nixos-config=nixos/modules/installer/sd-card/sd-image-aarch64.nix -A config.system.build.sdImage
{ config, lib, pkgs, ... }:
let
  linux_rock5 = pkgs.callPackage ./linux-rock5.nix { stdenv = pkgs.gcc10Stdenv; };
  custom_uboot = pkgs.callPackage ./uboot-rock5.nix {};
  uboot_rock5 = custom_uboot.ubootRadxaRock5;
  pkgs_for = pkgs.linuxPackagesFor linux_rock5; in
{
  imports = [
    <nixpkgs/nixos/modules/profiles/base.nix>
    <nixpkgs/nixos/modules/installer/sd-card/sd-image.nix>
  ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
 
  # This is supposed to work. It doesn't. Why?
  # boot.initrd.includeDefaultModules = false;

  # This works instead.
  boot.initrd.availableKernelModules = lib.mkForce [ ];

  boot.consoleLogLevel = lib.mkDefault 7;

  boot.kernelPackages = pkgs.recurseIntoAttrs ( pkgs_for.extend ( lib.const (super: 
  {
    kernel = super.kernel.overrideDerivation(drv: {nativeBuildInputs = (drv.nativeBuildInputs or []) ++ [pkgs.ubootTools]; }); 
  })) );

  # The serial ports listed here are:
  # - ttyS0: for Tegra (Jetson TX1)
  # - ttyAMA0: for QEMU's -machine virt
  boot.kernelParams = ["console=ttyS0,115200n8" "console=ttyAMA0,115200n8" "console=tty0"];

  sdImage = {
    populateFirmwareCommands = "";
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
    postBuildCommands = ''
        dd if=${uboot_rock5}/idbloader.img of=$img bs=512 seek=64 conv=notrunc
	dd if=${uboot_rock5}/u-boot.itb of=$img bs=512 seek=16384 conv=notrunc
    '';
  };

    # Allow the user to log in as root without a password.
    users.users.root.initialHashedPassword = "";
}
