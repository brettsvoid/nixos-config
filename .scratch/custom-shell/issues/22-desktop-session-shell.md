# Custom shell as brett-desktop's session shell; retire Caelestia

Status: ready-for-human
Type: HITL (switching the daily desktop)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Make the custom shell start at login on brett-desktop instead of Caelestia, then remove
Caelestia from the config.

Caelestia's module does more than run the shell. Go through it and keep what is still
wanted somewhere else:

- Its keybinds (launcher, dashboard, sidebar, session, game mode, screenshots) now point
  at the custom shell or the standalone tools.
- The Crimson Ronin window border colours, GTK 3 theme and dark preference for apps.
- The session commands that go through `session-exit`.
- The Crimson Ronin wallpaper in the wallpapers folder.

The `crimson-ronin` flake input stays (the game library uses it). The `caelestia-shell`
input goes. `toggle-shell` drops its Caelestia case. Update comments in other modules
that mention Caelestia.

Run it as the daily desktop for a few days before removing Caelestia, so it is easy to
switch back.

## Acceptance criteria

- [ ] Logging in to brett-desktop starts the custom shell; nothing starts Caelestia.
- [ ] Every keybind that used to call Caelestia does something sensible.
- [ ] Window borders, GTK apps and the dark preference look as they do today (or as you
      decide).
- [ ] Log out, reboot and shut down still restore apps at the next login.
- [ ] After a few days of daily use, the Caelestia module and flake input are removed and
      the flake builds.
- [ ] A fullscreen game runs with the same frame pacing as under Caelestia (MangoHud).

## Blocked by

- .scratch/custom-shell/issues/05-launcher-drawer.md
- .scratch/custom-shell/issues/06-keymap-cheatsheet.md
- .scratch/custom-shell/issues/08-notifications.md
- .scratch/custom-shell/issues/09-osd.md
- .scratch/custom-shell/issues/10-bar-status.md
- .scratch/custom-shell/issues/11-dashboard-drawer.md
- .scratch/custom-shell/issues/12-rust-stats.md
- .scratch/custom-shell/issues/14-wallpaper-background.md
- .scratch/custom-shell/issues/15-wallpaper-picker.md
- .scratch/custom-shell/issues/17-game-mode-toggle.md
- .scratch/custom-shell/issues/20-screenshots.md
- .scratch/custom-shell/issues/21-lock-screen.md
- .scratch/custom-shell/issues/25-settings-window.md
- .scratch/custom-shell/issues/26-settings-audio.md
- .scratch/custom-shell/issues/27-settings-network.md
- .scratch/custom-shell/issues/28-settings-bluetooth.md

## Comments

**2026-10-10:** When the custom shell becomes the session's shell, drop the fallbacks
added by issues 05 and 06: bind Super+R and Super+/ to `global, custom-shell:launcher`
and `global, custom-shell:cheatsheet` directly, remove `custom-shell-or`, Fuzzel and
`hypr-cheatsheet`, and decide whether Super+Space also opens the launcher.

**2026-10-10:** Notifications: mako is D-Bus activated and won the race for
org.freedesktop.Notifications at login against Caelestia (it owned it all of the
2026-10-09 session). When the custom shell starts from `exec-once`, stop or stop
installing mako (it is in `modules/system/nixos/hyprland.nix`), or the shell's server
waits until mako exits.

**2026-10-10:** Start the shell from Hyprland (`exec-once`, or a user unit after
Hyprland's environment import), not from a terminal. A herdr pane kept a dead
Hyprland's signature, and a shell started there opened no drawers. See
.scratch/hyprland-session-env/issues/01-stale-hyprland-signature.md.

**2026-10-13:** The custom shell now starts at login on brett-desktop
(`local.customShell.atLogin = true`, which runs `toggle-shell custom` from exec-once).
Caelestia stays installed and no longer starts itself. You chose to keep it until the
migration is done, and `toggle-shell caelestia` switches back.

- `toggle-shell` and `lock-recover` now check that the pid in `/tmp/custom-shell.pid`
  still belongs to the custom shell. `/tmp` outlives a reboot here, so a reused pid
  could otherwise mean no shell at login, or lock-recover killing the wrong process.
  Tested with the built script: the real pid reads as running, while a reused pid and
  a dead one both read as stopped.
- Still open: Super+Space, which opens Caelestia's launcher and does nothing under the
  custom shell; window borders and GTK colours after Caelestia is removed; and the
  rest of the criteria once you have used it for a few days.

**2026-10-13:** Decisions:

- **Super+Space:** the launcher stays on Super+R for now. Super+Space goes with
  Caelestia's module when that is removed.
- **Window borders and GTK apps:** these follow the shell's theme (matugen, from the
  wallpaper), not Crimson Ronin. So does the light/dark preference.

**2026-10-13:** Borders, GTK and light/dark now follow the theme (worktree branch
`worktree-theme-following-apps`):

- The shell sets Hyprland's border colours with `hyprctl keyword`
  (`quickshell/theme/WindowBorders.qml`). It keeps Crimson Ronin's gradient shape and
  sets them again after every config reload. It doesn't use a sourced file: Hyprland
  reloads its whole config when a sourced file changes, and that would undo game mode.
- `generate-theme` writes `~/.config/gtk-{3,4}.0/gtk.css` from `matugen/gtk.css`. It
  then sets dconf's `gtk-theme` (`adw-gtk3` or `adw-gtk3-dark`) and `color-scheme`
  from the mode. This only happens where `local.customShell.atLogin` is set, so the
  laptop doesn't change. `caelestia.nix` no longer sets GTK there.
- GTK reads `gtk.css` once, when an app starts, so open apps keep their old colours
  until they're reopened. Light/dark applies at once. Plain GTK 4 apps that don't use
  libadwaita aren't recoloured: adw-gtk3's GTK 4 stylesheet doesn't use the named
  colours.

To check after the rebuild:

1. Look at a window's border. It should be the theme's (currently grey to white,
   monochrome), not crimson.
2. Run `hyprctl reload`. The border should change back to the theme's within a second.
3. Open Thunar (GTK 3) and Loupe (libadwaita). They should use the shell's palette.
4. Dashboard → Wallpaper: switch to light, then reopen Thunar and Loupe. Firefox should
   switch to light without being reopened. Then switch back to dark.

**2026-10-16:** Steps 1 to 4 checked, all but Firefox:

1. (13 Oct) The border is the theme's, `1f1f1f → d4d4d4 → ffffff`.
2. On the desktop, with game mode off: just after `hyprctl reload` the border was the
   config's crimson (`720b12 → e21a28`). The theme's was back by the next reading,
   162 ms later, and stayed.
3. and 4. In qs-test's headless sway, with a throwaway home and the session's portals
   (xdg-desktop-portal with its gtk backend) on the test's bus. The installed
   `generate-theme` made the theme from the current wallpaper and scheme, dark and then
   light:
   - dconf got `adw-gtk3-dark` / `prefer-dark`, then `adw-gtk3` / `prefer-light`. The
     portal reported the colour scheme as 1 (dark), then 2 (light).
   - Thunar and Loupe, opened after each, drew with `gtk.css`'s colours. In dark,
     Thunar's view was `#0e0e0e` and its menu bar was `window_bg_color` (`#131313`);
     Loupe's header was `headerbar_bg_color` (`#1f1f1f`). In light they were `#ffffff`
     (`view_bg_color`), `#f9f9f9` and `#eeeeee`.
   - Loupe draws the space around the image itself, not from `gtk.css`: `#222226` in
     dark and near-white in light (`src/widgets/image.rs`). Without a portal on the
     bus it took the dark one in light mode too. With the portal it was light.
   - Not checked: Firefox's switch without reopening. It needs your session's Firefox.

Left for you: a few days of daily use, logging out and rebooting to check that apps come
back, and a game's frame pacing in MangoHud.
