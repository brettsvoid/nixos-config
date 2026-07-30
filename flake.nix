{
  description = "brett's nix config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    import-tree.url = "github:vic/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ambxst = {
      # Pinned: newer versions cause stutter on NVIDIA external monitors
      url = "github:Axenide/Ambxst/59edec9a0430eb2f679697f4a817a1f44ffcfb8b";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Prebuilt nix-index database → `comma` (run any nixpkgs binary ad-hoc,
    # no install) and a working command-not-found on a flakes system. The DB
    # is CI-built and refreshed on `nix flake update`; only input is nixpkgs,
    # which we follow to keep flake.lock lean.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Installs/owns /opt/homebrew so `darwin-rebuild switch` bootstraps
    # Homebrew on a fresh Mac with no separate install step. We keep
    # mutableTaps (the default) and manage taps imperatively, so the
    # homebrew/{core,cask,bundle} tap inputs aren't needed.
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "brew-src";
    };

    # Homebrew itself, pinned ahead of what nix-homebrew ships.
    #
    # This pin is load-bearing, not cosmetic. nix-homebrew fixes the brew CODE
    # to a tag, but cask DEFINITIONS come from Homebrew's live JSON API and
    # always move. When the API starts using a DSL feature the pinned code
    # lacks, `brew bundle` aborts — which is exactly what happened on the mac
    # mini's first switch:
    #
    #   Error: Cask 'kitty' definition is invalid:
    #          undefined method 'command_wrapper' for Cask 'kitty'
    #
    # 6.0.13 adds Library/Homebrew/cask/artifact/command_wrapper.rb; 6.0.12,
    # which nix-homebrew pins, does not. Keep this at or near Homebrew's
    # latest release, and expect to bump it when a cask breaks rather than on
    # a schedule.
    #
    # Note nix-homebrew derives its derivation name from ITS OWN lock, so the
    # store path still reads brew-6.0.12 while containing 6.0.13. That is
    # metadata only — `name` and `version` in flake.nix:25-26 — and does not
    # affect the brew code or the version brew reports at runtime.
    brew-src = {
      url = "github:Homebrew/brew/6.0.13";
      flake = false;
    };

    # Terminal agent-multiplexer (run coding agents in one terminal, persists
    # over ssh). Trialled alongside tmux. Pinned to a release tag; bump on
    # `nix flake update`.
    herdr = {
      url = "github:ogulcancelik/herdr/v0.7.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      # Drop agenix's own (stale) home-manager and nix-darwin copies — we
      # use the top-level inputs everywhere. Keeps flake.lock lean.
      inputs.home-manager.follows = "home-manager";
      inputs.darwin.follows = "nix-darwin";
    };

    secrets = {
      url = "git+ssh://git@github.com/brettsvoid/nix-secrets.git";
      flake = false;
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
