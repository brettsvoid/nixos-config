# nixos-config

- Custom shell (Quickshell, `modules/home/desktop/quickshell`): read
  `docs/quickshell-notes.md` before changing or testing it. It covers `qs-test`, known
  QML and Hyprland gotchas, and where to read upstream source.
- Issues: markdown files under `.scratch/<feature>/issues/`, each with a `Status:` line.
- Checks: `nix develop -c pre-commit run --all-files` runs nixfmt, statix, deadnix and
  gitleaks. Building a host's home also loads the custom shell headless and fails on QML
  errors.
