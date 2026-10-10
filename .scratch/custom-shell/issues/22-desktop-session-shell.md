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
