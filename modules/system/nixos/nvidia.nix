# NVIDIA driver baseline, shared by every host with an NVIDIA GPU — desktops
# and laptops alike.
#
# Hosts must set `hardware.nvidia.open` themselves: nixpkgs refuses to evaluate
# without an explicit choice on drivers >= 560. The open kernel modules need
# Turing or newer (RTX 20 / GTX 16 series onwards).
#
# Laptops where an Intel iGPU drives the internal panel also import
# nvidia-prime.
_: {
  flake.modules.nixos.nvidia =
    { config, ... }:
    {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement.enable = true;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
}
