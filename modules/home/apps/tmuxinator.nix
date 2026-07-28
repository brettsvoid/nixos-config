# tmuxinator (`mux`) — declarative tmux workspaces.
# https://github.com/tmuxinator/tmuxinator
#
# One YAML file per project describes the layout — windows, panes, the command
# each pane runs — and `mux start <name>` rebuilds it identically every time.
# Complementary to [[apps-sesh]] rather than a rival: sesh picks WHICH session,
# tmuxinator defines how one is ARRANGED. sesh can even launch a tmuxinator
# project as a session.
#
# This module owns the package and the `mux` alias together. The alias used to
# sit in shell/aliases.nix, which ships to every host unconditionally, while
# the package was a per-host Homebrew entry — so splitting the brew lists in
# 984a97c silently left the mac mini with an alias for a binary it does not
# have. Bundling them makes the alias arrive if and only if the tool does.
_: {
  flake.modules.homeManager.apps-tmuxinator =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = [ pkgs.tmuxinator ];

      programs.zsh.shellAliases = lib.mkIf config.programs.zsh.enable {
        mux = "tmuxinator";
      };
    };
}
