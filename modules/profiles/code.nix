# Development tooling, imported by every host: git helpers, direnv, just,
# and the Rust toolchain. Language servers are in nvim's extraPackages.
_: {
  flake.modules.homeManager.profile-code =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # No claude-code here: apps-claude-code (on every host) installs
      # upstream's native, self-updating build.
      home.packages =
        with pkgs;
        [
          # Git helpers. gh comes from programs.gh in apps/git.nix.
          lazygit
          git-lfs

          # CLI dev tools. delta comes from programs.delta in apps/git.nix.
          direnv
          nix-direnv
          just

          # LLVM's linker, for Rust via `-C link-arg=-fuse-ld=lld` in
          # .cargo/config.toml or a `[target.*] linker` setting. Much faster
          # than the default on large crate graphs.
          lld
        ]
        # Linux only: the Macs get rustup from Homebrew (darwin/homebrew.nix),
        # and a second one from nix would race it on PATH. rustup rather than
        # nixpkgs' cargo/rustc so rust-toolchain.toml pins work as on the Macs;
        # nixpkgs' rustup patchelfs the toolchains it downloads. Toolchains
        # live in ~/.rustup: run `rustup default stable` once per machine.
        # gcc because rustc links through `cc`; nothing else puts a C
        # compiler on the shell's PATH.
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          rustup
          gcc
        ];

      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      # GOPATH in XDG data rather than ~/go. Written to Go's own env file
      # (~/.config/go/env; ~/Library/Application Support/go/env on darwin),
      # not a session variable, so every go process sees it, gopls included.
      # A GOPATH in the environment would override it. package = null: Go
      # itself comes from nvim's extraPackages on NixOS and Homebrew on the
      # Macs.
      programs.go = {
        enable = true;
        package = null;
        env.GOPATH = "${config.xdg.dataHome}/go";
      };
    };

  # Docker on NixOS. The Macs use the docker-desktop cask (darwin/homebrew.nix).
  flake.modules.nixos.profile-code = {
    virtualisation.docker.enable = true;
  };
}
