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

    # Caelestia, a Quickshell desktop shell: brett-desktop's session shell
    # (modules/home/desktop/caelestia.nix). Its quickshell stays on upstream's
    # pin, not ours: it rebuilds quickshell with X11 and i3 off, so following
    # would not share a build, and upstream tests against its own rev.
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Crimson Ronin (MIT), a red/black Caelestia theme. Its palette,
    # wallpaper, mark and GTK theme are used; its Arch installer is not.
    crimson-ronin = {
      url = "github:corund207/crimson-ronin";
      flake = false;
    };

    # Reopens the last session's apps at login
    # (modules/home/desktop/session-restore.nix). Pinned to a release tag,
    # which `nix flake update` does not move: bump it by hand.
    hyprsession = {
      url = "github:joshurtree/hyprsession/v0.2.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # HyprWindowShade (MIT), a Hyprland plugin that runs GLSL shaders over
    # windows, for modules/home/desktop/window-dissolve.nix. It builds against
    # Hyprland's internal headers, so pin the commit that the `commit_pins` in
    # upstream main's hyprpm.toml names for nixpkgs' Hyprland (here 0.56.2),
    # and bump it with Hyprland.
    hyprwindowshade = {
      url = "github:ManofJELLO/HyprWindowShade/a4c6b8af424a189072427c4c90ef2938e1b481d3";
      flake = false;
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Prebuilt nix-index database for `comma` (run a nixpkgs binary without
    # installing it) and command-not-found. Refreshed on `nix flake update`.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ASD-STE100 Simplified Technical English skill, linked into
    # ~/.claude/skills by apps/claude-code.nix. The repo also holds evals and
    # examples, so the module uses its skills/ subdirectory.
    simple-english = {
      url = "github:AminBlg/SimpleEnglish";
      flake = false;
    };

    # Matt Pocock's agent skills (/grill-with-docs, /tdd, /diagnose,
    # /triage, …), linked into ~/.claude/skills by apps/claude-code.nix.
    # Pinned to a rev on purpose: upstream renames and deletes skills often,
    # so tracking a branch would silently swap slash commands on an update.
    # `nix flake update` won't move it; bump the rev by hand after reading
    # the diff.
    mattpocock-skills = {
      url = "github:mattpocock/skills/694fa30311e02c2639942308513555e61ee84a6f";
      flake = false;
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Installs and owns /opt/homebrew, so `darwin-rebuild switch` bootstraps
    # Homebrew on a fresh Mac. Taps stay mutable (the default) and brew adds
    # them, so no homebrew/{core,cask,bundle} tap inputs are needed.
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "brew-src";
    };

    # Homebrew itself, pinned ahead of nix-homebrew's own pin (6.0.12). Cask
    # definitions come from Homebrew's live API, so when one uses a feature
    # the pinned brew lacks, `brew bundle` aborts the switch (the kitty cask's
    # `command_wrapper`, added in 6.0.13, did). Keep this near the latest
    # release and bump it when a cask breaks.
    #
    # The store path still reads brew-6.0.12: nix-homebrew takes the name from
    # its own lock (its flake.nix:25-26). The brew code is 6.0.13.
    brew-src = {
      url = "github:Homebrew/brew/6.0.13";
      flake = false;
    };

    # Terminal multiplexer for coding agents (modules/home/terminals/herdr.nix).
    # Pinned to a release tag, which `nix flake update` does not move: bump it
    # by hand.
    herdr = {
      url = "github:ogulcancelik/herdr/v0.7.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      # Share our home-manager and nix-darwin rather than agenix's own copies.
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
