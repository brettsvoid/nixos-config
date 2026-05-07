# Development tooling profile. Installed on every machine that does code work
# (essentially: all of them). Includes the agentic CLI, language toolchains,
# git helpers, and language servers consumed by nvim's lsp config.
_: {
  flake.modules.homeManager.profile-code =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # Agentic / IDE adjuncts
        claude-code

        # Git helpers
        gh
        lazygit
        git-lfs

        # Universal CLI dev tools
        delta
        direnv
        nix-direnv
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
