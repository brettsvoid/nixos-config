# Retiring chezmoi

The mac mini's dotfiles are still managed by chezmoi (source at
`~/.local/share/chezmoi`, published as `github.com/brettsvoid/dotfiles`). This
is the plan for switching that off once nix-darwin owns the machine.

Written before the first `darwin-rebuild switch`. Everything below was measured
on brett-mac-mini; the MacBook is presumably similar but was not checked.

**The chezmoi source is not a faithful record of this machine.** `chezmoi
status` reports three files where the live copy has drifted from the source, and
at least one important dotfile is not managed by chezmoi at all. Plan from a
live-vs-source diff, not from reading the source.

---

## 1. `~/.gitconfig` — handled automatically, verify afterwards

This was going to be a manual pre-switch step. It is now done by an activation
script in `modules/home/apps/git.nix`, so no action is needed before switching —
but it is worth understanding, and worth verifying afterwards.

It is **not chezmoi-managed** and **not written by home-manager**, so nothing
removes it, and — because there is no collision — nothing backs it up either. It
just stays.

That matters because it wins. Home-manager writes `~/.config/git/config`, and
git reads `~/.gitconfig` afterwards, so its values take precedence. Verified
with both files present and conflicting values:

```
$ HOME=$tmp git config --global --get user.email
dotgitconfig@example.com        # ~/.gitconfig, not ~/.config/git/config
```

Left in place it would silently restore `user.email = BrettH@m2north.com`
globally and re-add the Git Credential Manager helper lines, undoing the
work-identity split, the delta pager and the zdiff3 conflict style in one go —
with no error and no obvious symptom beyond commits attributed to the wrong
address.

`home.activation.retireLegacyGitconfig` renames it to `~/.gitconfig.pre-nix` on
activation — never overwriting an existing rescue copy (it appends a timestamp
instead), skipping symlinks, and going quiet once there is nothing to move.

After the switch, confirm the nix config is the one in force:

```sh
git config --list --show-origin --global | grep -E 'user\.|pager|conflictstyle'
# expect file:~/.config/git/config, user.email = brettsvoid@gmail.com
git -C ~/work/projects/m2north-www config user.email   # BrettH@m2north.com
git -C ~/projects/tyto config user.email               # brettsvoid@gmail.com
```

Delete `~/.gitconfig.pre-nix` once satisfied.

---

## 2. What the first switch will move aside

`backupFileExtension = "backup"`, so each of these gets renamed to
`<name>.backup` and replaced. Eleven paths are managed by both chezmoi and
home-manager:

```
.config/kitty/kitty.conf      .config/nvim/lua           .config/sketchybar
.config/nvim/init.lua         .config/nvim/queries       .config/sql_formatter.json
.config/nvim/lazy-lock.json   .config/nvim/README.md     .config/tmux/tmux.conf
.config/nvim/lsp              .zshrc
```

Nothing is lost — the originals remain as `.backup`, and the chezmoi source
still has its copy. Review them after the switch, then delete.

## 3. Drift already reconciled

`chezmoi status` flags three files. All three are accounted for, so no content
needs rescuing before retirement:

| file                     | drift                                                                  | where it went                                                                                        |
| ------------------------ | ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `.zshrc`                 | live has bun, pnpm, worktrunk and direnv blocks absent from the source | bun dropped (#9); pnpm already in `env.nix`; worktrunk is `apps-worktrunk`; direnv is `profile-code` |
| `.zsh-custom/env.zsh`    | live has `TY_API_KEY` and `NX_KEY`, source does not                    | both now in `~/.config/zsh/local.zsh` (#14)                                                          |
| `.config/tmux/tmux.conf` | live lacks the sesh binding the source has                             | now in `apps-sesh` (#25)                                                                             |

## 4. What chezmoi manages that nix does not

None of these are written by home-manager, so the switch leaves them untouched.
They can be deleted with the chezmoi source.

**Dead — the aerospace stack replaced them** (`wmStack = "aerospace"`):
`.config/yabai`, `.config/skhd`, `.config/borders`

**Superseded by nix:**

| chezmoi                                                 | replaced by                                                                                                                                                  |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `.p10k.zsh`                                             | starship (`shell-starship`)                                                                                                                                  |
| `.gitignore_global`                                     | `~/.config/git/ignore` via `programs.git.ignores` — and `core.excludesfile` is already unset, so it is inert today                                           |
| `.zsh-custom/{00-path,env,aliases,functions,tools}.zsh` | `shell-env`, `shell-aliases`, `shell-functions`, `shell-tools`                                                                                               |
| `install.sh`, `install/brew*.sh`, `brew-import.sh`      | `bootstrap.sh` + the declarative `homebrew` module                                                                                                           |
| `.config/kitty/*.png`, `.config/ghostty/*.jpg`          | the repo's own copies — `kitty.nix:56` and `ghostty.nix:54` reference `${./kitty/...}` / `${./ghostty/...}` store paths, so the chezmoi images are redundant |
| `.config/{colors,icons,config}.sh`                      | the repo's `modules/home/darwin/sketchybar/` tree, symlinked over `~/.config/sketchybar`; its scripts source `$CONFIG_DIR/...` from there                    |

**Never used:** `.config/tmuxinator/sample.yml` (placeholder, never filled in —
see #21), `iterm-colors/`, `wezterm/`

**Check before deleting:** `cht.sh`, `functions.sh`, `install-rust-analyzer.sh`,
`scripts/`, `chezmoi.toml`, `README.md`

## 5. Retirement procedure

Do this only after the switch has been verified, and after the `.backup` files
in section 2 have been reviewed.

1. Keep `chezmoi` installed until the end. It is declared in
   `brett-mac-mini.nix` specifically so the old config stays readable and
   diffable during migration.

2. Take a final diff, so anything still only in chezmoi is visible:

   ```sh
   chezmoi status
   chezmoi diff | tee ~/chezmoi-final-diff.txt
   ```

3. Work through section 4 and delete what is confirmed dead.

4. Detach the machine without destroying anything:

   ```sh
   chezmoi forget --force ~/.zshrc          # etc., per path
   ```

   `chezmoi forget` removes a path from chezmoi's control and leaves the file
   alone. `chezmoi destroy` deletes the file too — do not use it here.

5. Archive the source rather than deleting it. It is a git repo with history
   (`github.com/brettsvoid/dotfiles`), so archiving the GitHub repo and removing
   the local clone is enough:

   ```sh
   rm -rf ~/.local/share/chezmoi ~/.config/chezmoi
   ```

6. Drop `"chezmoi"` from `brews` in `modules/hosts/brett-mac-mini.nix`, and
   remove the transitional comment above it.

7. Repeat on brett-m1-mbp, re-checking section 1 and section 3 there — the drift
   found on the mini may differ.

8. Delete this file and close #18.

## Note on the dotfiles repo

`github.com/brettsvoid/dotfiles` is **public** and its history contains a
Bitwarden Secrets Manager UUID (the CodeCompanion Anthropic key reference,
removed in `73d202e`). A UUID is a lookup ID, not a credential — reading the
secret still needs a `BWS_ACCESS_TOKEN` — so archiving rather than history
rewriting is a reasonable call. Worth knowing before making the repo more
prominent.
