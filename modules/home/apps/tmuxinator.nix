# tmuxinator (`mux`): declarative tmux workspaces.
# https://github.com/tmuxinator/tmuxinator
#
# One YAML file per project describes its windows, panes and the command each
# pane runs; `mux start <name>` rebuilds it. Complements [[apps-sesh]]: sesh
# picks which session, tmuxinator defines how one is arranged.
#
# The package and the `mux` alias live together so the alias only exists
# where the binary does.
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
