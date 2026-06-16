# Secrets architecture

## TL;DR

This repository is **public**. Secrets live in a separate **private** repository (`brettsvoid/nix-secrets`) and are referenced by the public flake as a `flake = false` input. Encrypted `.age` files in the private repo are decrypted on-host at activation time using each host's SSH private key.

The private repo is not visible to anyone without GitHub access to it. The public repo's `flake.lock` records only an opaque commit SHA + narHash for the secrets input — neither filenames nor contents leak.

## Threat model

| What we defend against | How |
|---|---|
| Casual recon ("which services does Brett run?") | Filenames live in the **private** repo, not the public one |
| Accidental commit of a credential to the public repo | gitleaks pre-commit + GitHub Actions backstop |
| Accidental commit via `git commit --no-verify` | GitHub Actions runs gitleaks + semgrep on every push |
| `.env` / API key / SSH private key sneaking in | Pre-commit hook `detect-private-keys`; gitleaks rules; reviewer's eye |
| Compromise of one host | agenix only decrypts to that host; other hosts' secrets unchanged |
| Stolen GitHub auth → access to public repo | All secrets are in the private repo; public repo holds no secrets |
| Stolen GitHub auth → access to private repo | Last line of defense: `.age` files are still encrypted to host SSH keys, useless without a host's `/etc/ssh/ssh_host_ed25519_key` |

## Repository topology

```
brettsvoid/nixos-config (PUBLIC)              brettsvoid/nix-secrets (PRIVATE)
├── flake.nix                                 ├── secrets.nix      (registry: pubkey -> .age files)
│   └── inputs.secrets = git+ssh://...          ├── service-a-token.age
│                                              ├── service-b-token.age
├── modules/                                  ├── service-c-token.age
│   ├── flake/agenix.nix                      ├── host-ssh-key.age
│   └── system/{nixos,darwin}/                ├── service-d-cert.age
│       (per-host secret references)          └── ...  (nothing visible to the public)
│
└── docs/SECRETS.md
```

## Bootstrap a new host

Each host needs a unique SSH host key (used by agenix as the decryption identity).

1. **Generate the host key** during NixOS / nix-darwin install:
   - On NixOS: `services.openssh.enable = true` already creates `/etc/ssh/ssh_host_ed25519_key` on first boot.
   - On nix-darwin: macOS ships with `/etc/ssh/ssh_host_ed25519_key.pub` from the moment SSH is enabled in System Settings → General → Sharing → Remote Login. (You don't need to leave Remote Login on; the key persists.)

2. **Capture the public half**:
   ```sh
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub
   ```

3. **Register the key in the private repo's `secrets.nix`**:
   ```nix
   let
     brett-mac-mini = "ssh-ed25519 AAAAC3...";   # the .pub from step 2
     # ... existing host keys
     all-hosts = [ brett-msi-laptop brett-m1-mbp brett-mac-mini ];
   in
   {
     "service-a-token.age".publicKeys = all-hosts;
     # ...
   }
   ```

4. **Re-encrypt every existing `.age` to include the new host's pubkey**:
   ```sh
   cd ~/nix-secrets
   agenix --rekey
   git add . && git commit -m "rekey for brett-mac-mini" && git push
   ```

5. **Update the public flake's lock pointer** so the new host's nixos/darwin-rebuild sees the rekeyed files:
   ```sh
   cd ~/nixos-config
   nix flake update --update-input secrets
   git add flake.lock && git commit -m "bump nix-secrets lock" && git push
   ```

6. **First switch on the new host** activates secrets via agenix:
   ```sh
   sh <(curl -fsSL https://.../bootstrap.sh) brett-mac-mini
   ```

## Adding a new secret

1. Create the encrypted file in the private repo:
   ```sh
   cd ~/nix-secrets
   agenix -e my-new-secret.age
   ```
   The editor that opens writes plaintext; agenix encrypts on save.
2. Add an entry to `secrets.nix` (private repo) declaring which host pubkeys can decrypt it.
3. Reference it from a host module in the public repo:
   ```nix
   age.secrets.my-new-secret.file = "${inputs.secrets}/my-new-secret.age";
   age.secrets.my-new-secret.path = "/etc/my-secret";   # where it gets decrypted to
   ```
4. Push both repos. Run `rebuild` on the affected host(s).

## Things that must NEVER be committed to the public repo

- `.env` files
- AWS credentials (`~/.aws/credentials`, `aws_access_key_id=...`)
- GitHub Personal Access Tokens (`ghp_...`, `gho_...`, `ghs_...`)
- OpenAI / Anthropic API keys (`sk-...`, `sk-ant-...`)
- SSH private keys (anything starting with `-----BEGIN ... PRIVATE KEY-----`)
- PGP private keys (anything starting with `-----BEGIN PGP ... PRIVATE KEY BLOCK-----`)
- Age private keys (`AGE-SECRET-KEY-1...`)
- Bitwarden Secrets Manager access tokens (`0.<uuid>.<base64>:<base64>`)
- Plain database connection strings with credentials
- Internal hostnames or IPs of services that aren't already public

The pre-commit hooks and GitHub Actions backstop will refuse most of these. They are not perfect — your eyes are the final filter.

## Things that ARE OK to have in the public repo

- Public SSH keys (`ssh-ed25519 AAAA...`)
- PGP public keys
- nix store hashes / narHashes
- Git commit SHAs
- Bitwarden Secrets Manager *secret IDs* (just UUIDs — useless without the access token; safe to reference but worth thinking twice about)
- Service names (kept abstract: prefer `code-helper-token` over `claude-code-token` in filenames if you want extra opacity)

## Bypasses and incident response

- **You committed a secret by mistake.** The hooks should have caught it. If they didn't and it reached `main`:
  1. **Immediately rotate the secret** — assume it's compromised.
  2. Force-push history rewrite is messy and not always possible. Do step 1 first.
  3. Use `git filter-repo` or BFG to scrub the history; force-push.
  4. Audit `git log --all -p -- <path>` to confirm it's gone.
- **You bypassed pre-commit with `--no-verify`.** GitHub Actions will catch you on push. Don't bypass.
- **A new false-positive in gitleaks.** Add an allowlist entry to `.gitleaks.toml`. Do not disable rules globally.

## Why two repos and not one?

A single public repo with `.age` files (à la hlissner/dotfiles) is genuinely safe — the encryption is solid. We split anyway because:

- **Filename leak**: a filename like `wg0PrivateKey.age` would announce "I run WireGuard," and `backup-server-key.age` would announce a backup server. For a personal threat model with low value-of-data, that's fine. For someone whose full digital life is on these machines, keeping service names out of the public repo is cheap insurance.
- **Belt-and-suspenders**: if a future weakness is found in age or in the host key handling, the encrypted blobs in a public repo become a problem. With them in a private repo, a second wall (GitHub auth on the private repo) is in the way.
- **Operational cost is small**: two repos means one extra `nix flake update --update-input secrets` per secret rotation. Not zero, but not painful.

## References

- [agenix](https://github.com/ryantm/agenix) — the encryption layer
- [hlissner/dotfiles](https://github.com/hlissner/dotfiles) — single-repo agenix pattern
- [dustinlyons/nixos-config](https://github.com/dustinlyons/nixos-config) — two-repo agenix pattern (the one we follow)
- [cachix/git-hooks.nix](https://github.com/cachix/git-hooks.nix) — pre-commit integration
- [gitleaks](https://github.com/gitleaks/gitleaks)
- [semgrep](https://semgrep.dev)
