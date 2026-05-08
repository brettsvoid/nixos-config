# nixos-config

Brett's cross-platform Nix flake (NixOS + nix-darwin), built on the [dendritic
pattern](https://github.com/mightyiam/dendritic) (flake-parts + import-tree).

> ⚠️ **This repository is public.** It contains no secrets. Encrypted secrets
> live in a separate private repo (`brettsvoid/nix-secrets`). See
> [`docs/SECRETS.md`](docs/SECRETS.md) before committing anything that looks
> credential-shaped.

## Hosts

| Host | Platform | Profiles | Status |
|---|---|---|---|
| `brett-msi-laptop` | NixOS (x86_64-linux, Hyprland, NVIDIA, greetd) | base, code, gaming | active |
| `brett-m1-mbp` | nix-darwin (aarch64-darwin) | base, code, work | active |
| `brett-mac-mini` | nix-darwin (aarch64-darwin) | base, code, work | planned (Phase D) |
| `brett-main-desktop` | NixOS (x86_64-linux) | base, code, gaming, art | planned (Phase E) |
| `server-pi` | NixOS (aarch64-linux, headless, colmena-deployed) | base, server | planned (Phase F) |

## Layout

```
flake.nix                  # ~50 lines: inputs + flake-parts + import-tree
modules/
  flake/                   # flake-parts wiring (parts, systems, formatter, hooks, agenix)
  system/{nixos,darwin}/   # platform-specific composables
  home/                    # cross-platform home-manager modules
  profiles/                # opt-in module bundles (code, work, gaming)
  hosts/                   # one file per machine
hardware/                  # nixos-generate-config output, per host
docs/SECRETS.md            # secrets architecture & operational guide
.gitleaks.toml             # secret-scanner config
.semgrep.yml               # custom static-analysis rules
```

## Daily use

```sh
nix-rebuild       # alias: nixos-rebuild / darwin-rebuild for the current host
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

The devShell auto-installs pre-commit hooks on first entry. Hooks:
- `gitleaks` — secret scanner
- `detect-private-keys` — refuses SSH/PGP private key blobs
- `nixfmt-rfc-style` — auto-formatter
- `check-added-large-files`, `end-of-file-fixer`, `trim-trailing-whitespace`

`nix flake check` runs the full hook set. GitHub Actions runs it again on every
push as a backstop, plus a full-history `gitleaks detect` and a `semgrep`
scan with custom rules + community auto-rulesets.

## See also

- [docs/SECRETS.md](docs/SECRETS.md) — secrets architecture
