# Brett's M1 MacBook Pro (16 GB, aarch64-darwin).
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
          window-manager
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
            imports = with config.flake.modules.homeManager; [
              base
              shell-zsh
              shell-aliases
              shell-env
              shell-functions
              shell-starship
              shell-tools
              terminals-tmux
              terminals-ghostty
              terminals-kitty
              darwin-yabai
              darwin-skhd
              darwin-sketchybar
              nvim
              apps-git
              apps-ssh
              apps-fonts
              apps-sql-formatter
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
