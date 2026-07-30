# TODO

Work that has to happen on a specific machine, and so cannot be finished
from wherever the repo was last edited. Delete an entry once it is done.

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

## Retire chezmoi (both Macs)

Planned in [chezmoi-retirement.md](chezmoi-retirement.md). Mostly post-switch
cleanup. The one trap it documents — a leftover `~/.gitconfig` silently
overriding the `~/.config/git/config` home-manager writes — is now handled by
an activation script in `modules/home/apps/git.nix`, but section 1 has the
commands to verify it actually took effect.

---

## Known warnings that are not ours to fix (brett-msi-laptop)

Both come from flake inputs, not from this repo. They are harmless — the host
evaluates and builds — and will clear when the inputs update. Do not chase them.

- **`'system' has been renamed to/replaced by 'stdenv.hostPlatform.system'`** —
  `ambxst`, `flake.nix:20`: `self.packages.${pkgs.system}.default`
- **`The xorg package set has been deprecated, 'xorg.libxcb' has been renamed to
  'libxcb'`** — `quickshell`, `default.nix:22`: `libxcb ? xorg.libxcb`
