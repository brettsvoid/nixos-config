# NVIDIA Optimus laptops, where the Intel iGPU drives the panel and NVIDIA
# the external monitors. Import alongside `nvidia`; not on desktops or
# single-GPU hosts. Override the bus IDs per host if they differ
# (`lspci | grep VGA`).
_: {
  flake.modules.nixos.nvidia-prime = {
    hardware.nvidia.prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };

    # NVIDIA EGL first so compositors render with it, then Mesa so Aquamarine
    # can blit to the Intel-driven eDP-1. Without Mesa, Hyprland crashes in
    # CMonitorFrameScheduler::onFinishRender bringing up that panel.
    environment.variables = {
      __EGL_VENDOR_LIBRARY_FILENAMES = "/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json:/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json";
    };
  };
}
