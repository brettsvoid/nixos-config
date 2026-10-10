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

      # The driver wipes its whole shader cache (~/.cache/nvidia/GLCache,
      # shared by every GL and Vulkan app) once it passes the size limit,
      # 1 GB by default. DXVK games fill that fast (Nolvus alone: 626 MB),
      # and every wipe means recompiling mid-game, which stutters. Setting
      # it per game is not enough, since any other app still cleans up, so
      # it is set for the whole session (greetd and systemd --user read
      # /etc/pam/environment). The cache then grows unbounded; deleting the
      # folder is safe.
      environment.sessionVariables.__GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
    };
}
