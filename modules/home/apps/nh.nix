# nh: a front-end for `darwin-rebuild`/`nixos-rebuild` that shows a diff of
# what will change before activating and renders nom build trees, both
# included in pkgs.nh. Uses the upstream home-manager module and nixpkgs' nh.
#
# No programs.nh.clean: it runs `nh clean user`, which refuses to run as root
# and so cannot prune system generations. GC is system-level instead:
# modules/system/darwin/nh-gc.nix on the Macs, nix.gc in
# modules/system/nixos/common.nix on NixOS.
{ config, ... }:
let
  repoDir = config.flake.lib.repoDir;
in
{
  flake.modules.homeManager.apps-nh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # `nix-update-lagged [days]`: move nixpkgs and the inputs that follow it
      # to what their branch pointed at N days ago (default 3). Here because
      # it is the other half of `nix-rebuild` and every host imports this
      # module. See the script's header.
      home.packages = [
        (pkgs.writeShellApplication {
          name = "nix-update-lagged";
          # GNU date (-d) and sed, on the Macs too. Not nix: the system's own
          # nix on PATH writes the lock.
          runtimeInputs = with pkgs; [
            coreutils
            curl
            gnugrep
            gnused
            jq
          ];
          text = builtins.readFile ./nh/nix-update-lagged.sh;
        })
      ];

      programs.nh = {
        enable = true;
        # Sets NH_FLAKE, so `nh os/darwin switch` needs no path and picks
        # the configuration named after the hostname.
        flake = "${config.home.homeDirectory}/${repoDir}";
      };

      # Export it from .zshrc too. The session-vars file only runs once per
      # environment (the __HM_SESS_VARS_SOURCED guard), and a tmux server
      # started before NH_FLAKE existed hands that guard to every new pane,
      # so their shells would never pick it up.
      programs.zsh.initContent = lib.mkIf config.programs.zsh.enable (
        lib.mkOrder 600 ''
          export NH_FLAKE="${config.home.homeDirectory}/${repoDir}"
        ''
      );
    };
}
