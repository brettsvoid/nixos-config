# Redistributable firmware blobs for hardware quirks (Wi-Fi cards, GPUs, etc.)
_: {
  flake.modules.nixos.firmware = {
    hardware.enableAllFirmware = true;
  };
}
