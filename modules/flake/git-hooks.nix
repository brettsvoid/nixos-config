# Pre-commit hooks for secret leaks and file hygiene. They run on `git commit`
# and in `nix flake check`.
{ inputs, ... }:
{
  imports = [ inputs.git-hooks.flakeModule ];

  perSystem =
    { config, pkgs, ... }:
    {
      pre-commit.settings = {
        hooks = {
          # ─── Secret scanning (blocking) ───────────────────────────────
          gitleaks = {
            enable = true;
            name = "gitleaks";
            entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged --redact --verbose";
            pass_filenames = false;
          };

          detect-private-keys.enable = true;

          # ─── Nix format (blocking) ────────────────────────────────────
          nixfmt-rfc-style.enable = true;

          # ─── General hygiene ──────────────────────────────────────────
          check-added-large-files.enable = true; # default 500 KB; LFS-tracked images excluded
          end-of-file-fixer.enable = true;
          trim-trailing-whitespace = {
            enable = true;
            # A diff's blank context lines are a single space.
            excludes = [ "\\.patch$" ];
          };

          # ─── deadnix / statix: devShell tools, not pre-commit hooks ───
          # Run on demand (`nix develop -c deadnix`, `nix develop -c statix
          # check`). Too noisy on the generated hardware/*.nix and the host
          # files to block commits.
        };
      };

      # Hook tools in the devShell, so `pre-commit run` works by hand too.
      devShells.default = pkgs.mkShell {
        inputsFrom = [ config.pre-commit.devShell ];
        packages = with pkgs; [
          gitleaks
          semgrep
          nixfmt
          deadnix
          statix
          nix-output-monitor
          git
        ];
        shellHook = ''
          ${config.pre-commit.installationScript}
          echo "==> pre-commit hooks installed. Run 'pre-commit run --all-files' to scan everything."
        '';
      };
    };
}
