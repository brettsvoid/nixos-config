# Pre-commit + flake-check hooks. Defense-in-depth for secret leaks and
# basic file hygiene. Hooks run on `git commit` AND via `nix flake check`.
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
          trim-trailing-whitespace.enable = true;

          # ─── deadnix / statix: devShell tools, NOT pre-commit hooks ───
          # Run on demand: `nix develop -c deadnix` and `nix develop -c statix check`.
          # They are noisy on auto-generated hardware-configuration.nix and on
          # imports-only host files, so they're advisory rather than blocking.
        };
      };

      # Make hook tools available inside the devShell so `pre-commit run`
      # works manually too.
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
