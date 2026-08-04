# TODO

Work that has to happen on a specific machine, and so cannot be finished
from wherever the repo was last edited. Delete an entry once it is done.

---

## Remove the stale Claude Code notify hook (brett-m1-mbp only)

**Do this on the MacBook.** The Mac mini is already done. The MSI laptop does
not import `apps-claude-code`.

### Why

`a7c5748` dropped the `Notification` hook and the `notify.sh` that shelled out
to `terminal-notifier`. Removing it from `modules/home/apps/claude-code.nix`
stops nix re-asserting the key — it does not delete the copy already written to
`~/.claude/settings.json`. Activation merges (`jq -s '.[0] * .[1]'`, see the
comment above `mergeSettings`), and a merge has no way to express "no longer
declared", so the entry survives every rebuild until it is deleted by hand.

Not urgent: after the rebuild the script it points at is gone, so no
notification is delivered either way. The entry is dead weight — though it may
show up as a failed hook rather than being ignored outright.

### Steps

1. Rebuild first, so the hook script is unlinked and nix stops re-adding the
   key underneath you:

   ```sh
   nix-rebuild
   ```

2. Check that `Notification` is the only hook — if Claude has written others
   since, delete just that one (`del(.hooks.Notification)`) instead:

   ```sh
   jq '.hooks | keys' ~/.claude/settings.json   # expect ["Notification"]
   ```

3. Delete the key. Via a temp file, not a redirect onto the same path — a
   redirect truncates the file before jq reads it:

   ```sh
   cd ~/.claude
   cp settings.json settings.json.bak
   jq 'del(.hooks)' settings.json > .settings.tmp
   mv .settings.tmp settings.json
   chmod 644 settings.json
   ```

4. Verify, then clean up:

   ```sh
   jq 'has("hooks")' ~/.claude/settings.json    # expect false
   ls ~/.claude/hooks                           # notify.sh symlink gone
   rm ~/.claude/settings.json.bak
   ```

5. **Delete this section** from this file.

---

## Migrate Firefox to the XDG config path (brett-msi-laptop only)

**Do this on the MSI laptop.** It is the only host importing `apps-firefox`;
neither Mac is affected (macOS has its own `Library/Application Support/Firefox`
path, and home-manager excludes Darwin from the warning entirely).

### Why

Home-manager 26.05 changed the Linux default for `programs.firefox.configPath`
from `.mozilla/firefox` to `$XDG_CONFIG_HOME/mozilla/firefox`. The effective
default is gated on `home.stateVersion`, which is `"24.11"`
(`modules/home/base.nix:5`), so the legacy path is still in use and **nothing is
broken today**. This is a decision to make before the state version moves, not a
repair.

Evaluating `brett-msi-laptop` prints:

```
The default value of `programs.firefox.configPath` has changed from
`".mozilla/firefox"` to `"${config.xdg.configHome}/mozilla/firefox"`.
You are currently using the legacy default because `home.stateVersion`
is less than "26.05".
```

### The trap

Changing the option does **not** move any data. Home-manager only writes
`profiles.ini` at the new location. Point it at the XDG path without moving the
directory and Firefox finds no profile there, creates a fresh empty one, and
every bookmark, saved login, history entry and open tab stays behind in
`~/.mozilla/firefox` — present, but unused. The config change and the move have
to happen together.

Home-manager also notes that **native messaging hosts are not moved**. Anything
that talks to a local helper (password manager bridges, `ff2mpv`, and similar)
needs its host manifest relocated by hand, or it silently stops working.

### Steps

1. **Quit Firefox completely.** Not just the window — check with
   `pgrep -a firefox`. Copying a live profile risks a corrupt `places.sqlite`.

2. **Back up first.** This is the only copy of your browser state:

   ```sh
   tar -C ~ -czf ~/mozilla-firefox-backup-$(date +%F).tar.gz .mozilla/firefox
   ```

3. **Move the directory**, respecting `$XDG_CONFIG_HOME` (falls back to
   `~/.config`):

   ```sh
   mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla"
   mv ~/.mozilla/firefox "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox"
   ```

4. **Check what is left behind.** `~/.mozilla` often holds more than `firefox/` —
   `native-messaging-hosts/` in particular:

   ```sh
   ls -la ~/.mozilla
   ```

   Move any `native-messaging-hosts/` to
   `${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/native-messaging-hosts/`. Only
   remove `~/.mozilla` once it is empty.

5. **Set the option** in `modules/home/apps/firefox.nix`, inside
   `programs.firefox`:

   ```nix
   configPath = "${config.xdg.configHome}/mozilla/firefox";
   ```

   Note this needs `config` in the module's argument set — the module currently
   takes none.

6. **Rebuild, then verify before trusting it:**

   - `nix eval` no longer prints the `configPath` warning
   - `ls "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox"` shows
     `profiles.ini` and the profile directory
   - Firefox opens with your bookmarks, history and logins intact
   - `about:profiles` reports the new path as the root directory
   - any extension using native messaging still works

7. **Delete this section** from this file, and close task #24.

### If it goes wrong

Restore from the tarball in step 2 and revert step 5:

```sh
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox"
tar -C ~ -xzf ~/mozilla-firefox-backup-<date>.tar.gz
```

---

## Known warnings that are not ours to fix (brett-msi-laptop)

Both come from flake inputs, not from this repo. They are harmless — the host
evaluates and builds — and will clear when the inputs update. Do not chase them.

- **`'system' has been renamed to/replaced by 'stdenv.hostPlatform.system'`** —
  `ambxst`, `flake.nix:20`: `self.packages.${pkgs.system}.default`
- **`The xorg package set has been deprecated, 'xorg.libxcb' has been renamed to
  'libxcb'`** — `quickshell`, `default.nix:22`: `libxcb ? xorg.libxcb`
