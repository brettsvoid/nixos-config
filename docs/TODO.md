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

**Do this on the MSI laptop.** brett-desktop also imports `apps-firefox`, but
it was installed after the change and sets the XDG path explicitly, so it has
nothing to migrate. Neither Mac is affected (macOS has its own `Library/Application Support/Firefox`
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

## Headset dongle that failed to enumerate at boot (brett-desktop only)

**Watch for it at the desktop.** It may already be fixed: see Status.

### Status

Identified, and working since a replug. The device is the **Logitech PRO X
Wireless headset dongle** (`046d:0aba`), plugged into the **KVM switch**:
hub `1-9` (Genesys Logic USB 2.1, `05e3:0610`, the USB 2 half of the KVM's
USB 3 hub, `05e3:0626` on `2-8`), port 3, next to the Moonlander (`1-9.1`) and
the mouse's receiver (`1-9.2`). Unplugged and replugged on 2026-09-27, it
enumerated at once, and on the next boot it came up at 5.6 s with no errors.
The boot after that logged one `device descriptor read/64, error -32` (a
stall, not the -110 timeout) and then found it at 10.4 s, so it is still not
entirely clean behind the KVM, but it recovers on the first retry.
If the -110 timeouts below ever come back, it is a boot-time problem behind the KVM:
move the dongle to a motherboard port (unless it has to follow the KVM between
machines).

### Why it mattered

On the boots where it failed, the kernel logged this 4 times each, installer
included:

```
usb 1-9.3: device descriptor read/64, error -110
usb 1-9.3: device descriptor read/8, error -110
```

`-110` is a timeout: the dongle answered the first electrical handshake but
never sent its descriptor, so it was never set up and the headset had no
audio device.

**It also locked out the keyboard and mouse for about 2 minutes after boot.**
The kernel retries the port until it gives up (`unable to enumerate USB
device`, ~131 s after boot). Meanwhile the udev worker for hub `1-9` is stuck
("taking a long time"), and udev holds back the hub's child devices until it
finishes, so the Moonlander and the mouse are not set up yet. If Hyprland
starts in that window, libinput logs `skip unconfigured input device` for them
and there is no keyboard or mouse until udev catches up. Seen on the first
Hyprland login, 2026-09-27. The same messages were printed over the tuigreet
login screen; greetd.nix now sets `boot.consoleLogLevel = 3` so they stay in
the journal.

### Check

```sh
journalctl -k -b | grep 'usb 1-9.3'    # healthy: "New USB device found … 0aba"
```

Once it has stayed healthy for a while, delete this entry.

---

## Migrate the Hyprland config from hyprlang to Lua (Linux hosts)

**Do this on a Linux host**, and test on both brett-desktop and
brett-msi-laptop before relying on it.

### Why

Hyprland 0.56 shows a warning at login that the `.conf` (hyprlang) format will
not be supported going forward. It still works and there are no config
errors, so nothing is broken today. `modules/home/desktop/hyprland.nix` pins
`configType = "hyprlang"` on purpose: home-manager 26.05 defaults to `"lua"`,
but the `settings` block is hyprlang, so switching means rewriting the config,
not flipping the flag. It becomes forced when a Hyprland release drops
hyprlang.

### The traps

- **Host files too.** Each host adds monitors, workspaces and env in
  hyprlang syntax: all of it moves with the shared module.
- **The laptop's `source` line.** brett-msi-laptop sources
  `/tmp/hypr-drm-devices.conf`, a hyprlang fragment written at boot by its
  `hyprland-drm-config` service. A Lua config cannot source that. Either have
  the service write Lua, or replace it with the udev-symlink approach
  brett-desktop uses for `AQ_DRM_DEVICES` (`/dev/dri/nvidia-dgpu`).
- **The `##` escape is hyprlang-only.** brett-desktop's Dell description has
  its `#` doubled because hyprlang treats `#` as a comment. In a Lua string it
  must be a single `#` again, or the rule stops matching.
- **Stray `hyprland.lua` files.** Hyprland prefers `hyprland.lua` over
  `hyprland.conf`, and writes a default one if it ever starts with no config.
  Check `~/.config/hypr/` for leftovers (brett-desktop has a renamed
  `hyprland.lua.autogenerated` that can be deleted).

---

## Replace tuigreet with a graphical greeter (Linux hosts)

**Do this on brett-desktop**, where the problem shows. It changes the shared
`greetd` module, so check the laptop afterwards.

### Why

tuigreet draws on the kernel text console. With two monitors of different
resolutions the console runs at a mode both can show: on brett-desktop that is
1920x1080 (the Dell's maximum) on a 2560x1440 framebuffer, so the login screen
fills only part of the Odyssey. The console is also not rotated for the
portrait Dell. Hyprland itself is unaffected.

### Options

nixpkgs has `services.displayManager.regreet` (formerly `programs.regreet`),
which points greetd's `default_session` at ReGreet running inside the `cage`
compositor. Check how cage handles two monitors and the rotated Dell before
switching. The session list and remembered user that tuigreet provides
(`--sessions`, `--remember`) need an equivalent.

---

## Known warnings that are not ours to fix (brett-msi-laptop)

Both come from flake inputs, not from this repo. They are harmless — the host
evaluates and builds — and will clear when the inputs update. Do not chase them.

- **`'system' has been renamed to/replaced by 'stdenv.hostPlatform.system'`** —
  `ambxst`, `flake.nix:20`: `self.packages.${pkgs.system}.default`
- **`The xorg package set has been deprecated, 'xorg.libxcb' has been renamed to
  'libxcb'`** — `quickshell`, `default.nix:22`: `libxcb ? xorg.libxcb`
