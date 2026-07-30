# nixos-config

Cross-platform Nix flake (NixOS + nix-darwin), built on the [dendritic
pattern](https://github.com/mightyiam/dendritic) (flake-parts + import-tree).

## Hosts

| Host | Platform | Profiles | Status |
|---|---|---|---|
| `brett-msi-laptop` | NixOS (x86_64-linux, Hyprland, NVIDIA, greetd) | base, code, gaming | active |
| `brett-m1-mbp` | nix-darwin (aarch64-darwin, AeroSpace) | base, code, work | active |
| `brett-mac-mini` | nix-darwin (aarch64-darwin, AeroSpace) | base, code, work | config landed, first switch pending |
| `brett-main-desktop` | NixOS (x86_64-linux) | base, code, gaming, art | planned (Phase E) |
| `server-pi` | NixOS (aarch64-linux, headless, colmena-deployed) | base, server | planned (Phase F) |

## Layout

```
flake.nix                  # inputs + flake-parts + import-tree
modules/
  flake/                   # flake-parts wiring (parts, systems, formatter, hooks, agenix, lib)
  system/{nixos,darwin}/   # platform-specific composables
  home/                    # cross-platform home-manager modules
  profiles/                # opt-in module bundles (code, work, gaming)
  hosts/                   # one file per machine
apps/edgebar/              # Tauri overlay status bar (macOS), replaces sketchybar
hardware/                  # nixos-generate-config output, per host
docs/SECRETS.md            # secrets architecture & operational guide
docs/bar-spec.md           # shared edgebar ⇄ quickshell design spec
docs/TODO.md               # work that can only be done on a particular machine
docs/chezmoi-retirement.md # plan for switching the old dotfile manager off
docs/refactor-plan.md      # dendritic-pattern refactor notes and findings
.gitleaks.toml             # secret-scanner config
.semgrep.yml               # custom static-analysis rules
```

## Daily use

```sh
nix-rebuild       # nh os/darwin switch for the current host (diff, then activate)
edit              # cd ~/nixos-config && $EDITOR .
```

## First-time setup on a new machine

```sh
sh <(curl -fsSL https://raw.githubusercontent.com/brettsvoid/nixos-config/main/bootstrap.sh) <hostname>
```

## Development

```sh
nix develop            # enter the devShell with linters + scanners + formatter
pre-commit run --all-files
```

The devShell installs the pre-commit hooks on first entry. Hooks:
- `gitleaks` — secret scanner
- `detect-private-keys` — blocks SSH/PGP private keys
- `nixfmt-rfc-style` — formatter
- `check-added-large-files`, `end-of-file-fixer`, `trim-trailing-whitespace`

`nix flake check` runs the full hook set. GitHub Actions runs it again on every
push, plus a full-history `gitleaks detect` and a `semgrep` scan with custom
rules, community auto-rulesets, and the OWASP Top Ten preset.

## See also

- [docs/SECRETS.md](docs/SECRETS.md) — secrets architecture
- [docs/TODO.md](docs/TODO.md) — pending work that is tied to a specific machine
- [docs/chezmoi-retirement.md](docs/chezmoi-retirement.md) — retiring the old dotfile manager
