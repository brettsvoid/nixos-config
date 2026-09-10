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
docs/refactor-plan.md      # dendritic-pattern refactor notes and findings
.gitleaks.toml             # secret-scanner config
.semgrep.yml               # custom static-analysis rules
```

## Daily use

```sh
nix-rebuild       # nh os/darwin switch for the current host (diff, then activate)
edit              # cd ~/nixos-config && $EDITOR .
```

## Adding a package

nixpkgs first; Homebrew is the fallback on the macOS hosts. Check the repo's
own pinned nixpkgs rather than `nixpkgs#...`, which resolves through the
floating registry:

```sh
nix eval .#darwinConfigurations.brett-m1-mbp.pkgs.<pkg>.meta.platforms
nix build --dry-run .#darwinConfigurations.brett-m1-mbp.pkgs.<pkg>
```

The platform list must include `aarch64-darwin`, and the dry run must say
"will be fetched" rather than "will be built" — a from-source build of a
large GUI app is not worth taking. It prints nothing when the closure is
already local.

If both pass, add `modules/home/apps/<name>.nix` exposing
`flake.modules.homeManager.apps-<name>` with `home.packages`, then import
`apps-<name>` from the host file. `modules/home/apps/blender.nix` is the
worked example. Home-manager symlinks any `$out/Applications` bundle into
`~/Applications/Home Manager Apps`, so GUI apps need no cask.

Only when nixpkgs has no working darwin build does the package go in
`modules/system/darwin/homebrew.nix` (every Mac) or a host file (one Mac).
That file's header covers the cask-specific traps.

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
