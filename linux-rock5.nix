{ pkgs, lib, buildPackages, fetchFromGitHub, perl, buildLinux, nixosTests, ... } @ args:
let k = pkgs.linuxManualConfig (rec {
  inherit (pkgs) stdenv;
  inherit lib;

  version = "5.10.66";
  modDirVersion = "5.10.66";
  extraMeta.branch = "5.10"; 

  src = fetchFromGitHub {
      owner = "radxa";
      repo = "kernel";
      rev = "7917720a4d4dc4f1e37feaa16698773ce8f2d230";
      sha256 = "10dk235zz4fqmgp9k8m58mzm6a0kckv3a88dd2rp7z03hqm17dbm";
  };
  
  configfile = ./rockchip_linux_defconfig;

  # i wasted like 2 days on this option
  # time to be 'controversial'
  allowImportFromDerivation = true;

  kernelPatches = [{
    name = "fix-out-of-tree";
    patch = ./fix-rkwifi-out-of-tree.patch;
  }];

  extraMeta.platforms = [ "aarch64-linux" ];
  extraMakeFlags = [];
} // (args.argsOverride or {})); in k
