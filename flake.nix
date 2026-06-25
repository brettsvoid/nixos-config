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

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Installs/owns /opt/homebrew so `darwin-rebuild switch` bootstraps
    # Homebrew on a fresh Mac with no separate install step. We keep
    # mutableTaps (the default) and manage taps imperatively, so the
    # homebrew/{core,cask,bundle} tap inputs aren't needed.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

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
