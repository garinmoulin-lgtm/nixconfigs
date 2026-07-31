{ pkgs, ... }:
let
  cachyKernel = pkgs.linuxPackages_cachyos-lto.cachyOverride {
    cachyVars = pkgs.linuxPackages_cachyos-lto.kernel.cachyConfig.cachyVars // {
      "_processor_opt" = "ZEN4";
    };
  };
in
{
  boot.kernelPackages = pkgs.linuxKernel.packagesFor (cachyKernel.kernel.overrideAttrs (old: {
    KCFLAGS = (old.KCFLAGS or "") + " -march=native -mtune=native";
    structuredExtraConfig = with pkgs.lib.kernel; {
      DEBUG_INFO_BTF = yes;
      DEBUG_INFO_BTF_MODULES = no;
    };
  }));
}
