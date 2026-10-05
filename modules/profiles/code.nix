# Development tooling profile. Installed on every machine that does code work
# (essentially: all of them). Includes language toolchains, git helpers,
# and language servers consumed by nvim's lsp config.
_: {
  flake.modules.homeManager.profile-code =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # No claude-code here: every host imports apps-claude-code, which owns
      # the tool. It installs upstream's native, self-updating build, where a
      # nixpkgs package would lag behind it.
      home.packages =
        with pkgs;
        [
          # Git helpers
          # gh is installed by programs.gh in apps/git.nix, which also makes it
          # git's HTTPS credential helper.
          lazygit
          git-lfs

          # Universal CLI dev tools
          # `delta` is installed by programs.delta in apps/git.nix, which also
          # configures git to use it — listing it here too would be a second,
          # silent source of truth for the same package.
          direnv
          nix-direnv
          just

          # LLVM's linker, used as the Rust linker — `-C link-arg=-fuse-ld=lld`
          # in .cargo/config.toml, or via a `[target.*] linker` setting. Much
          # faster than the default on large crate graphs.
          #
          # Was a Homebrew formula before the mac mini migration and got
          # uninstalled by the first switch, which is what surfaced the gap: it
          # had never been declared anywhere. Here rather than on a single host
          # because both Macs and the MSI laptop build Rust.
          lld
        ]
        # Rust on the shell's PATH. The Macs get rustup from Homebrew
        # (system/darwin/homebrew.nix), so this is Linux only: a second rustup
        # from nix would race brew's for the front of PATH. Before this, the
        # only cargo on NixOS was the one in nvim's extraPackages, which is on
        # nvim's PATH and nowhere else.
        #
        # rustup rather than nixpkgs' cargo/rustc so rust-toolchain.toml pins
        # work the same as on the Macs. nixpkgs patches it to patchelf the
        # toolchains it downloads, so they run on NixOS. They live in
        # ~/.rustup, outside nix: run `rustup default stable` once per machine.
        #
        # gcc because rustc links through `cc`, and build scripts fail without
        # one. Nothing else puts a C compiler on the shell's PATH.
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          rustup
          gcc
        ];

      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      # GOPATH out of ~ and into XDG data. Unset, Go defaults to ~/go, where
      # it keeps the module cache and `go install` binaries. On brett-desktop
      # it was gopher.nvim's old build hook that created it.
      #
      # Written to Go's own env file (~/.config/go/env; on darwin,
      # ~/Library/Application Support/go/env) rather than as a session
      # variable, so it holds for every go process: nvim's gopls and
      # launcher-started editors as much as shells. A GOPATH in the
      # environment would override it.
      #
      # package = null: this only writes config. Go itself comes from nvim's
      # extraPackages on NixOS and from Homebrew on the Macs.
      programs.go = {
        enable = true;
        package = null;
        env.GOPATH = "${config.xdg.dataHome}/go";
      };
    };

  # Linux-only system-side bits (docker, etc.). Darwin uses Docker Desktop cask
  # via the homebrew bridge in Phase B+.
  flake.modules.nixos.profile-code = {
    virtualisation.docker.enable = true;
  };
}
