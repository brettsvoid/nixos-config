# PipeWire audio stack
_: {
  flake.modules.nixos.audio = {
    # rtkit lets PipeWire acquire realtime scheduling priority.
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
  };
}
