# NVIDIA Optimus configuration: Intel iGPU + discrete NVIDIA GPU on the same
# laptop, with Intel driving at least one display (typically the internal
# panel) and NVIDIA driving external monitors.
#
# Do NOT import this on:
#   - pure-NVIDIA desktops or single-GPU NVIDIA laptops — prime.* is wrong and
#     the Mesa EGL entry below is unnecessary
#   - hosts without an NVIDIA GPU
#
# Per-host overrides: prime.intelBusId / prime.nvidiaBusId
# (find yours with `lspci | grep VGA`).
_: {
  flake.modules.nixos.nvidia =
    { config, ... }:
    {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement.enable = true;
        open = false;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        prime = {
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
        };
      };
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      # Load NVIDIA EGL first (priority 10) so compositors prefer it for rendering,
      # but also load Mesa EGL so Aquamarine can create a renderer on the Intel GPU
      # for multi-GPU blitting to eDP-1. Dropping Mesa here makes Hyprland crash in
      # CMonitorFrameScheduler::onFinishRender when bringing up the Intel-driven panel.
      environment.variables = {
        __EGL_VENDOR_LIBRARY_FILENAMES = "/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json:/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json";
      };
    };
}
