# herdr — terminal agent-multiplexer: run coding agents in one terminal,
# sessions persist over ssh (https://herdr.dev). Trialled alongside tmux
# (terminals-tmux); both stay installed so they can be compared side by side.
# Pulled from the `herdr` flake input rather than nixpkgs (not packaged there).
{ inputs, ... }:
{
  flake.modules.homeManager.terminals-herdr =
    { pkgs, ... }:
    {
      home.packages = [
        inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];

      # Only the keys we deviate on — everything else stays on herdr's
      # defaults (see `herdr --default-config`). Herdr reads this at start-up;
      # `herdr server reload-config` picks up changes in a running session.
      xdg.configFile."herdr/config.toml".text = ''
        # Skip the first-run picker. Herdr normally writes this itself once
        # you have chosen, but it cannot: this file is a read-only symlink
        # into the store. Declaring it is the only way it sticks — without
        # it the onboarding screen returns on every start.
        onboarding = false

        [keys]
        # Alt+arrow moves between panes without the prefix, matching the
        # tmux bindings in terminals-tmux. The prefix+hjkl defaults are
        # listed alongside so they keep working.
        focus_pane_left = ["prefix+h", "alt+left"]
        focus_pane_down = ["prefix+j", "alt+down"]
        focus_pane_up = ["prefix+k", "alt+up"]
        focus_pane_right = ["prefix+l", "alt+right"]
      '';
    };
}
