# herdr: a terminal multiplexer for coding agents whose sessions persist over
# ssh (https://herdr.dev). Trialled alongside tmux (terminals-tmux), both
# installed for comparison. Taken from the `herdr` flake input.
{ inputs, ... }:
{
  flake.modules.homeManager.terminals-herdr =
    { lib, pkgs, ... }:
    let
      herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      home.packages = [
        herdr
      ]
      # The Claude hook below needs `python3` on PATH and silently does
      # nothing without it. The Macs have /usr/bin/python3; the NixOS hosts
      # have none on PATH.
      ++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.python3;

      # Claude Code session restore: after a server restart herdr reruns
      # `claude --resume <id>`, but only in panes whose session id a
      # SessionStart hook reported. This installs that hook; otherwise only
      # the first-run screen (skipped by `onboarding = false`) offers it.
      # Safe to rerun: the installer replaces its own entries. Runs after
      # claudeCodeSettings, which makes settings.json a real file; that merge
      # leaves `hooks` alone because nix declares none.
      home.activation.herdrClaudeIntegration =
        lib.hm.dag.entryAfter [ "writeBoundary" "claudeCodeSettings" ]
          ''
            if [ -d "$HOME/.claude" ]; then
              $DRY_RUN_CMD ${lib.getExe herdr} integration install claude >/dev/null \
                || echo "herdr: claude integration install failed, session restore stays off" >&2
            fi
          '';

      # Only the keys that differ from `herdr --default-config`.
      # `herdr server reload-config` applies edits to a running server.
      xdg.configFile."herdr/config.toml".text = ''
        # Skip the first-run picker. herdr would record the choice itself,
        # but this file is a read-only store symlink, so without this line
        # the picker returns on every start.
        onboarding = false

        [keys]
        # Alt+arrow moves between panes without the prefix, as in
        # terminals-tmux. The prefix+hjkl defaults are kept alongside.
        focus_pane_left = ["prefix+h", "alt+left"]
        focus_pane_down = ["prefix+j", "alt+down"]
        focus_pane_up = ["prefix+k", "alt+up"]
        focus_pane_right = ["prefix+l", "alt+right"]

        # These actions have no default key. Arrows mirror navigate mode
        # (prefix+g), where up/down walks the workspace list. Avoid prefix+[
        # (copy mode) and prefix+shift+j/k (swap_pane_down/up): neither shows
        # in `herdr --default-config`, and a user binding silently disables
        # the default it collides with.
        previous_workspace = "prefix+up"
        next_workspace = "prefix+down"
        previous_agent = "prefix+shift+up"
        next_agent = "prefix+shift+down"

        # The 1..9 range syntax is literal. Both need cmd on the Mac:
        # aerospace takes alt+N and alt+shift+N, and ctrl+N is taken on 1, 2
        # and 9. shift+N never matches, because kitty sends shift+digit as
        # bare text ("!"); cmd forces an escape code. cmd+shift+3/4/5 are
        # macOS screenshots. cmd+N needs the no_op mappings in
        # terminals-kitty; kitty leaves ctrl+cmd+N alone.
        switch_workspace = "prefix+ctrl+cmd+1..9"
        focus_agent = "prefix+cmd+1..9"
      '';
    };
}
