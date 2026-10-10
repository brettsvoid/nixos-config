# NVIDIA driver baseline for every host with an NVIDIA GPU. Laptops whose
# Intel iGPU drives the panel also import nvidia-prime.
#
# Hosts must set `hardware.nvidia.open`: nixpkgs refuses to evaluate without
# it on drivers >= 560. The open modules need Turing (RTX 20 / GTX 16) or
# newer.
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

      # Stop the driver wiping its whole shader cache, ~/.cache/nvidia/GLCache
      # (shared by every GL and Vulkan app), when it passes the size limit,
      # 1 GB by default. DXVK games fill that fast, and each wipe means
      # stuttering recompiles. Session-wide, because any app can trigger the
      # wipe. The cache then grows unbounded; deleting it is safe.
      environment.sessionVariables.__GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
    };
}
