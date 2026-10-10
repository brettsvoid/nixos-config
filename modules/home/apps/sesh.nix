# sesh: tmux session picker. https://github.com/joshmedeski/sesh
#
# Lists running tmux sessions, sessions configured in
# ~/.config/sesh/sesh.toml and zoxide directories, then attaches to the
# choice, creating it if need be. sesh picks which workspace; tmuxinator
# ([[apps-tmuxinator]]) defines how one is arranged.
#
# The package and the tmux binding live together so `prefix + T` only exists
# where sesh is installed.
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

      # Store paths, not bare names: the popup gets the tmux server's
      # environment, and a server that outlived a rebuild (it survives
      # logout) can carry a stale PATH.
      fzf = lib.getExe config.programs.fzf.package;
    in
    {
      home.packages = [ pkgs.sesh ];

      # `-t` running tmux sessions, `-c` configured ones, `-d` shows a session
      # that is both only once. No `-z`: zoxide would flood the list with
      # every directory ever visited.
      programs.tmux.extraConfig = lib.mkIf config.programs.tmux.enable ''

        # Sesh: curated project session picker (prefix + T).
        bind T display-popup -E -w 60% -h 60% \
          "${sesh} connect \"\$(${sesh} list -tcd | ${fzf} --prompt='sessions  ' --header='enter: attach or create')\""
      '';
    };
}
