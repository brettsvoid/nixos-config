# NVIDIA + Intel hybrid GPU configuration
# NOTE: prime.intelBusId and prime.nvidiaBusId are machine-specific.
#       Find yours with: lspci | grep VGA

{ config, lib, pkgs, ... }:

{
  # Nvidia drivers
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    # Required for Wayland support - enables kernel modesetting for NVIDIA
    modesetting.enable = true;
    # Enables power management to allow the GPU to suspend/resume properly
    powerManagement.enable = true;
    # Use NVIDIA's proprietary drivers instead of the open-source kernel modules
    # The open-source modules don't support GPUs older than Turing (RTX 20 series is Turing,
    # but open = false is more stable for most setups)
    open = false;
    # Tracks the latest stable driver version from nixpkgs
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      # Reverse sync makes the NVIDIA GPU the primary renderer and copies frames
      # back to the Intel iGPU only for displays wired to it (e.g. laptop screen).
      # This is better suited to Wayland than regular sync mode, which has known
      # issues where compositors still pick Intel as the primary GPU.
      reverseSync.enable = true;
      # Bus IDs for each GPU - find these with: lspci | grep VGA
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  hardware.graphics = {
    # Enable GPU acceleration
    enable = true;
    # Enable 32-bit graphics libraries - required for Steam, Wine, and most gaming
    enable32Bit = true;
  };

  # Forces the EGL loader to use NVIDIA's implementation instead of Intel's.
  # Without this, Wayland compositors (Mutter, Niri, etc.) may default to the
  # Intel GPU for rendering even when NVIDIA is available, causing poor
  # performance and refresh rate issues on displays driven by the NVIDIA GPU.
  environment.variables = {
    __EGL_VENDOR_LIBRARY_FILENAMES = "/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json";
  };
}
