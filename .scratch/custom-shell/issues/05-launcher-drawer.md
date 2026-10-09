# Launcher drawer, replacing Fuzzel on Super+R

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

An app launcher drawer that grows out of the frame. It lists installed desktop entries
(Quickshell's DesktopEntries) with icons, filters as you type with fuzzy matching, and
starts the selected app. Most-used apps rank higher; keep the usage counts in a small
file in the shell's state directory.

Design it so later issues can add prefix modes (clipboard history first) without
reworking the drawer: typing a prefix switches what the list shows.

Super+R opens it instead of Fuzzel. Caelestia's Super+Space launcher binding should
also open it once Caelestia is retired; decide whether to keep both keys.

Apps that launch through wrappers today must keep working from the new launcher. The
Nolvus and Steam entries detach on purpose, because Fuzzel and rofi exit straight
after starting them.

## Acceptance criteria

- [ ] Super+R opens the launcher; typing filters; Enter launches; Escape closes.
- [ ] Icons show for installed apps, including ones installed through home-manager.
- [ ] Frequently used apps rank above rarely used ones with the same match quality.
- [ ] Apps that need to detach (Nolvus, Steam games) still start and keep running.
- [ ] Fuzzel is no longer bound to any key (the package can stay until the cheatsheet
      issue removes its last use).
- [ ] Opening the launcher feels instant on both hosts (no visible delay on the first
      open after login).

## Blocked by

- .scratch/custom-shell/issues/04-session-menu-drawer.md
