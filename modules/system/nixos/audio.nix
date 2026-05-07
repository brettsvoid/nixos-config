# PipeWire audio stack
_: {
  flake.modules.nixos.audio = {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
  };
}
