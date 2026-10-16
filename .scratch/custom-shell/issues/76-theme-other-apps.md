# Theming other apps with the palette

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Apps beyond the shell take the wallpaper's palette, and change when it changes. ambxst
writes a file per app from QML (`modules/theme/*Generator.qml`: kitty, GTK, Qt,
Discord through Vesktop, NvChad); ideas only. Here each app gets a matugen template
beside the GTK ones, wired in `custom-shell.nix` only where `themeApps` is true (the
custom shell is the session shell: the desktop now, the laptop after issue 23).

What is there today, checked:

- **GTK 3 and 4: done** (issue 22). `generate-theme` writes `gtk-{3,4}.0/gtk.css` and sets
  dconf's theme and light or dark. Firefox follows light or dark through the portal.
- **kitty** (`terminals/kitty.nix`): home-manager owns `kitty.conf`, with
  `themeFile = "Catppuccin-Mocha"`. kitty 0.49 reloads its config on SIGUSR1 (its own
  `reload_conf_in_all_kitties` does that) and ignores a missing include. matugen 4.2
  runs a template's `post_hook` after writing it.
- **Neovim** (`nvim/config/lua/plugins/colorscheme.lua`): Catppuccin Macchiato with a
  transparent background, so its background is the terminal's. The same config runs
  on the Macs.
- **Qt: nothing configures it.** No `qt.*` option, no `QT_QPA_PLATFORMTHEME`. The
  `~/.config/qt{5,6}ct/colors/ambxst.colors` files are ambxst's.
- **Discord** is the stock client (`profiles/gaming.nix`). It loads no themes without a
  client mod. nixpkgs has `discord.override { withVencord = true; }` and `vesktop`.

## Proposed choices

1. **Which apps** (please choose): **kitty and Neovim**, recommended. Optional: ghostty
   (installed; how it reloads is unchecked), Qt apps (say which you use), Discord,
   Firefox's full palette (pywalfox: an extension plus `pywalfox-native`). Not offered: starship and tmux, whose palettes are in Nix.
2. **kitty:** a template writes `~/.cache/qs-theme/kitty.conf` (background, foreground,
   cursor, selection, tab bar, `color0`–`color15` from matugen's blended red, green,
   yellow, blue, magenta, cyan and white). A `globinclude` of it goes in
   `programs.kitty.extraConfig`, which home-manager writes after the Catppuccin include
   (that one is `mkOrder 520`), so it wins; a missing file is fine.
   `post_hook = "pkill -USR1 -x kitty"`. Alternative: `kitty @ set-colors`, which
   needs `allow_remote_control` and a socket any process of yours could use. Reason:
   no new control socket.
3. **Neovim:** a template writes `~/.cache/qs-theme/nvim.lua`, Catppuccin
   `color_overrides` for Macchiato. `colorscheme.lua` uses it when present and plain
   Catppuccin otherwise (the Macs). It watches the folder with `vim.uv.new_fs_event`,
   as the file may be replaced, and applies the colours again. Alternative: only at
   start. Reason: no restart needed, and no process.
4. **Qt, if chosen:** `qt.enable`, `qt.platformTheme.name = "qtct"`, and a template for a
   qt5ct and qt6ct colour scheme. Whether open Qt apps pick up a change is unchecked.
5. **Discord, if chosen:** Vencord through the nixpkgs override, and a template for a
   theme CSS. Recommended: leave Discord alone. Reason: client mods break Discord's terms.
6. **No per-app switch in the settings window**: Nix wires each template, gated on
   `themeApps`. Alternative: a Nix list, `local.customShell.themedApps`.
7. **Cost:** a template is written once per theme change, within the matugen run that
   happens anyway; one `pkill` for kitty. Nothing runs at rest or in game mode.

## Acceptance criteria

- [ ] A wallpaper change recolours open kitty windows within a second, light and dark.
- [ ] Open Neovim recolours on a theme change; on a Mac it looks as it does today.
- [ ] Each other chosen app follows the theme (at its next start where it cannot reload).
- [ ] On a host without `themeApps`, kitty and Neovim look as they do today.
- [ ] `nix develop -c pre-commit run --all-files` passes.

## Blocked by

- None
