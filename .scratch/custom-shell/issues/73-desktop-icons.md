# Desktop icons from ~/Desktop

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

The files in `~/Desktop` as icons on the wallpaper, behind the windows. Double-click opens
a file, and a right-click menu does the rest. ambxst has this (`modules/desktop/`: a
Bottom-layer window, a grid, drag to place); ideas only.

- Today there is no `~/Desktop`. `hyprland.nix` sets `xdg.userDirs.desktop = null` on
  purpose ("no desktop icons on a tiling setup"), so `user-dirs.dirs` has no
  `XDG_DESKTOP_DIR`. `xdg-user-dir DESKTOP` still answers `/home/brett/Desktop`.
- Builds on: `FolderListModel`, which the wallpaper picker already uses to watch a folder;
  the icon theme the launcher uses (`QS_ICON_THEME`, Papirus-Dark); `xdg-open` and `gio`,
  both in the system profile today; gvfs (trash), enabled in `system/nixos/hyprland.nix`.

## Proposed choices

1. **Folder: set `xdg.userDirs.desktop` to `~/Desktop` again**, so home-manager makes it
   and apps that save "to the desktop" agree with the shell. Alternative: leave
   user-dirs alone and give the shell a `desktop.folder` setting. Reason: one folder that
   every app and the shell agree on.
2. **Where: one window per chosen screen, on the Bottom layer** (above the wallpaper,
   under every window), no exclusive zone, no keyboard. Its input mask covers only the
   icons, so a click elsewhere goes nowhere, as today. Icons start inside the frame at
   the top left and fill columns downwards.
3. **Which screen: the first screen** (`desktop.iconScreen`, default `"auto"`; a screen
   named as `bar.hiddenScreens` names it, `"DP-1"` or as issue 35 settles, picks
   another). Alternative: every screen, which shows the same files twice. Reason: one desktop folder, one place.
4. **Order: sorted, folders first, then by name; no dragging.** Alternative: drag to
   place, positions saved in the state folder (ambxst). Reason: no saved layout to go
   stale when files change.
5. **Icons:** an image file shows itself (decoded small, off the main thread); other
   files get their type's icon from the theme, by extension; a `.desktop` file shows its
   own `Name=` and `Icon=`. Names elide after two lines.
6. **Actions:** double-click opens (`xdg-open`; `gio launch` for a `.desktop` file).
   Right-click: Open, Show in Thunar, Copy path, Move to trash (`gio trash`).
   Alternative: also rename and new folder. Reason: Thunar does those already.
   Once issue 47 is in, its app options get "Add to desktop", which copies the app's
   `.desktop` file into `~/Desktop`.
7. **Settings** (the **Desktop** page, shared with issues 71, 72 and 74):
   `desktop.icons` (on: the folder is empty until something lands there),
   `desktop.iconScreen` (`"auto"`), `desktop.iconSize` (64 px, 48–96, step 8).
8. **Packages:** none new while `xdg-utils` and `glib` stay in the system profile. The
   build checks that they remain after issue 23, and adds them to `home.packages` if not.
9. **Cost:** no process or timer at rest; the folder watch is the only work. In game
   mode and while a window is fullscreen on that screen the window hides.

## Acceptance criteria

- [ ] `~/Desktop` exists and `user-dirs.dirs` names it.
- [ ] A file copied into `~/Desktop` shows within a second; a removed file goes.
- [ ] Double-click opens a file in its default app and starts a `.desktop` file.
- [ ] Each right-click entry works; Move to trash puts the file in the trash.
- [ ] Windows cover the icons; clicks outside the icons reach nothing new.
- [ ] Icons show on the chosen screen only, and follow the bar's edge and frame.
- [ ] Nothing runs at rest, and it costs nothing in game mode.
- [ ] Each setting applies at once and survives a restart.

## Blocked by

- None
