# Development tooling profile. Installed on every machine that does code work
# (essentially: all of them). Includes the agentic CLI, language toolchains,
# git helpers, and language servers consumed by nvim's lsp config.
_: {
  flake.modules.homeManager.profile-code =
    {
      lib,
      pkgs,
      ...
    }:
    {
      home.packages =
        with pkgs;
        [
          # Git helpers
          gh
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
        ++ lib.optionals stdenv.isLinux [
          # Agentic CLI, Linux only.
          #
          # On the Macs this package was installed, shadowed and never run:
          # shell/env.nix prepends ~/.local/bin ahead of the nix profile, and
          # that is where the native, self-updating build lives.
          # apps-claude-code owns the tool there — it bootstraps upstream's
          # installer and manages the config, not the version. The MSI laptop
          # has neither that PATH prepend nor apps-claude-code, so it keeps
          # the nixpkgs build, which is the only claude it has ever run.
          claude-code
        ];

      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
    };

  # Linux-only system-side bits (docker, etc.). Darwin uses Docker Desktop cask
  # via the homebrew bridge in Phase B+.
  flake.modules.nixos.profile-code = {
    virtualisation.docker.enable = true;
  };
}
