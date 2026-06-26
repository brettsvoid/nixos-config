# Brett's M1 MacBook Pro (16 GB, aarch64-darwin).
{ config, inputs, ... }:
let
  # ─── Window-manager stack swap ──────────────────────────────────────
  # One switch drives BOTH halves of the WM stack — the system-side
  # launchd agents and the home-manager config — so the two can't drift
  # out of sync. Set to "yabai" or "aerospace"; files for both stacks
  # live side-by-side, so switching is a one-word edit — no deletes.
  wmStack = "aerospace";
  wm =
    {
      yabai = {
        system = with config.flake.modules.darwin; [ window-manager ];
        home = with config.flake.modules.homeManager; [
          darwin-yabai
          darwin-skhd
        ];
      };
      aerospace = {
        system = with config.flake.modules.darwin; [ window-manager-aerospace ];
        home = with config.flake.modules.homeManager; [ darwin-aerospace ];
      };
    }
    .${wmStack};
in
{
  flake.darwinConfigurations.brett-m1-mbp = inputs.nix-darwin.lib.darwinSystem {
    specialArgs = {
      inherit inputs;
      inherit (config) flake;
    };
    modules = [
      inputs.home-manager.darwinModules.home-manager
      (_: {
        # WM stack (system half) is appended below via `wm.system`; the
        # `wmStack` switch at the top of this file selects it.
        imports =
          (with config.flake.modules.darwin; [
            agenix
            common
            defaults
            users
            homebrew
            tailscale
            nh-gc
          ])
          ++ wm.system;

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
            # WM stack (home half) is appended below via `wm.home`; the
            # `wmStack` switch at the top of this file selects it.
            # `darwin-sketchybar` stays enabled for either stack.
            imports =
              (with config.flake.modules.homeManager; [
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
                darwin-sketchybar
                darwin-karabiner
                nvim
                apps-git
                apps-ssh
                apps-fonts
                apps-sql-formatter
                apps-nh
                apps-comma
                profile-base
                profile-code
                profile-work
              ])
              ++ wm.home;
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
