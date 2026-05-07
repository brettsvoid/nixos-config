# Brett's M1 MacBook Pro (16 GB, aarch64-darwin).
#
# Phase B: nix-darwin runs alongside chezmoi. nix manages shell + tools +
# tmux + ghostty + git config. chezmoi still owns nvim, kitty, p10k (now
# stale), yabai, skhd, sketchybar. Phase C migrates each piece in turn.
{ config, inputs, ... }:
{
  flake.darwinConfigurations.brett-m1-mbp = inputs.nix-darwin.lib.darwinSystem {
    specialArgs = {
      inherit inputs;
      inherit (config) flake;
    };
    modules = [
      inputs.home-manager.darwinModules.home-manager
      (_: {
        imports = with config.flake.modules.darwin; [
          agenix
          common
          defaults
          users
          homebrew
        ];

        # ─── Identity ──────────────────────────────────────────────────
        networking.hostName = "brett-m1-mbp";
        networking.computerName = "brett-m1-mbp";
        networking.localHostName = "brett-m1-mbp";

        nixpkgs.hostPlatform = "aarch64-darwin";

        # ─── Home Manager wiring ───────────────────────────────────────
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          extraSpecialArgs = { inherit inputs; };
          users.brett = {
            # Phase C migrating in pieces. Currently nix-managed: shell,
            # tools, tmux, ghostty, git, ssh, fonts, nvim. Still chezmoi:
            # kitty config, p10k (stale), yabai/skhd/sketchybar, tmuxinator.
            imports = with config.flake.modules.homeManager; [
              base
              shell-zsh
              shell-aliases
              shell-starship
              shell-tools
              terminals-tmux
              terminals-ghostty
              nvim
              apps-git
              apps-ssh
              apps-fonts
              profile-base
              profile-code
              profile-work
            ];
            home = {
              username = "brett";
              homeDirectory = "/Users/brett";
            };
          };
        };
      })
    ];
  };
}
