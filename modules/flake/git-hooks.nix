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

          # ─── Nix lint (blocking) ──────────────────────────────────────
          # Not on the generated hardware/*.nix. statix checks the whole tree
          # on any .nix change; deadnix only the changed files. .claude/* holds
          # worktrees of other branches, which their own commits check.
          statix = {
            enable = true;
            settings.ignore = [
              "hardware/*"
              ".claude/*"
            ];
          };
          deadnix = {
            enable = true;
            excludes = [ "^hardware/" ];
          };
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
