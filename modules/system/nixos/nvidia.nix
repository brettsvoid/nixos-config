# NVIDIA + Intel hybrid GPU configuration
# NOTE: prime.intelBusId and prime.nvidiaBusId are machine-specific.
#       Find yours with: lspci | grep VGA
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

      # Force EGL loader to use NVIDIA's implementation. Without this, Wayland
      # compositors may default to the Intel GPU on NVIDIA-driven displays.
      environment.variables = {
        __EGL_VENDOR_LIBRARY_FILENAMES = "/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json";
      };
    };
}
