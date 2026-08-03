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

        # Workspace and agent navigation ships unbound — herdr documents the
        # actions but gives them no default key, so they do nothing until
        # named here. Arrows mirror navigate mode (prefix+g), where up/down
        # already walks the workspace list.
        #
        # Avoid the obvious tmux-style picks: prefix+[ is copy mode and
        # prefix+shift+j/k are swap_pane_down/up. Neither appears in
        # `herdr --default-config`, and a user binding silently disables the
        # default it collides with.
        previous_workspace = "prefix+up"
        next_workspace = "prefix+down"
        previous_agent = "prefix+shift+up"
        next_agent = "prefix+shift+down"

        # Indexed forms; the 1..9 range syntax is literal. Both need cmd,
        # for two separate reasons. Aerospace binds alt+N and alt+shift+N
        # globally and ctrl+N on 1/2/9, so nothing alt- or ctrl-only ever
        # reaches the terminal. Plain shift+N fails further down: kitty only
        # escape-encodes a key when it carries a modifier other than shift,
        # so shift+1 arrives as a bare "!" with no shift flag and never
        # matches. Cmd forces the escape encoding. cmd+shift is unusable in
        # turn — macOS owns cmd+shift+3/4/5 for screenshots.
        # cmd+N needs the matching no_op in terminals-kitty; ctrl+cmd+N is
        # unclaimed by kitty and passes through as-is.
        switch_workspace = "prefix+ctrl+cmd+1..9"
        focus_agent = "prefix+cmd+1..9"
      '';
    };
}
