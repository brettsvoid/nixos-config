# All firmware blobs (Wi-Fi, GPUs, …), unfree ones included; common.nix sets
# allowUnfree.
_: {
  flake.modules.nixos.firmware = {
    hardware.enableAllFirmware = true;
  };
}
