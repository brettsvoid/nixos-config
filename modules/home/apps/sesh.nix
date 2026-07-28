# sesh — smart tmux session picker. https://github.com/joshmedeski/sesh
#
# Fuzzy-finds across running tmux sessions, zoxide directories and named
# startups in ~/.config/sesh/sesh.toml, then attaches to the choice (creating
# it if it does not exist yet). Answers "which workspace do I want", where
# tmuxinator ([[apps-tmuxinator]]) answers "how should this one be arranged".
#
# This module owns BOTH the package and the tmux keybinding. Before it, the
# binding lived in terminals-tmux — a module imported by every host — while
# `sesh` itself was a Homebrew entry on brett-m1-mbp only, so the mac mini got
# a `prefix + T` that popped open a window and immediately died with
# "sesh: command not found". Same failure the repo's refactor-plan records as
# finding N-1. Keeping the two together makes that combination unexpressible.
_: {
  flake.modules.homeManager.apps-sesh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      sesh = lib.getExe pkgs.sesh;

      # Absolute store paths rather than bare names, because this runs in a
      # tmux popup, not an interactive shell: display-popup spawns the command
      # through default-command, so it inherits the environment the tmux
      # SERVER was started with. That server may long predate the current
      # generation — it survives logout and is not restarted by a rebuild — so
      # its PATH can point at a previous profile, or at no profile at all when
      # tmux was started by launchd rather than from a shell. Store paths make
      # the binding independent of all of it.
      fzf = lib.getExe config.programs.fzf.package;
    in
    {
      home.packages = [ pkgs.sesh ];

      # `-t` running tmux sessions, `-c` configured ones, `-d` dedupes so a
      # session that is both configured and running shows once. Deliberately
      # no `-z`: zoxide would flood the list with every directory ever visited,
      # which is the noise this picker exists to avoid.
      programs.tmux.extraConfig = lib.mkIf config.programs.tmux.enable ''

        # Sesh: curated project session picker (prefix + T).
        bind T display-popup -E -w 60% -h 60% \
          "${sesh} connect \"\$(${sesh} list -tcd | ${fzf} --prompt='sessions  ' --header='enter: attach or create')\""
      '';
    };
}
