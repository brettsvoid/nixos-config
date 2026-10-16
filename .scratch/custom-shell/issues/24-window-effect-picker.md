# Window effect picker

Status: ready-for-human
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

A drawer in the shell for choosing the window open and close effects from the effect
library (window-dissolve/04), the way the wallpaper picker chooses wallpapers.

- Lists the library's effects by name, with separate choices for open and close.
- Previews an effect on a sample surface inside the drawer before it is chosen (the
  library shaders are plain GLSL, so a QML ShaderEffect can run them on a static image
  with a looping progress value; check what adapting the uniforms takes).
- Choosing one calls the library's switch command, so the next window uses it.
- Shows which effects are active, and offers "none" for each.
- Decide whether it is its own drawer, a dashboard tab or a launcher prefix mode, and
  record why.

## Acceptance criteria

- [ ] The picker lists every effect in the library.
- [ ] Previews animate in the drawer and stop when it closes.
- [ ] Choosing an open or close effect applies to the next window, with no rebuild.
- [ ] "None" turns the effect off.
- [ ] The choice survives a logout.

## Blocked by

- .scratch/window-dissolve/issues/04-shader-library.md
- .scratch/custom-shell/issues/04-session-menu-drawer.md

## Comments

**2026-10-13:** Built as a dashboard tab, Effects (`dashboard/EffectsTab.qml`).

- **Why a tab:** it chooses how the desktop looks, like the Wallpaper tab, and it needs
  room for previews. A tab is also only loaded while it shows, so the previews stop
  when the dashboard closes or another tab shows. A launcher mode has no room for
  previews, and a drawer of its own would need another keybind. The launcher's
  `>Window effects` action opens the tab.
- **The tab:** every effect in the library's `index.json`, with its source and a short
  description. Each has Open and Close pills, filled while active. On the right, the
  current row's open and close effects loop on a sample window.
  - Keys: arrow keys or Ctrl+N/P move, O chooses for opening, C for closing.
  - Choosing runs `window-effect`. The tab watches `active.json`, so a choice from the
    command shows there too.
- **Previews (`EffectPreview.qml`)** run the library's own shaders, compiled for Qt
  (`previews/*.frag.qsb`). An open shades the window's box. A close shades a
  screen-sized snapshot with the window in `window_rect`, as the plugin does, so
  effects that spill outside the window show. The shaders are told 1920x1080 sizes, as
  the effects are tuned in pixels. None mimics Hyprland's popin and slide in QML.
- **Checked** with a test copy of the shell on the fallback output, through the real
  Vulkan renderer. All 50 effects listed. Explode, smoke and none previews were
  recorded and played as on screen. Choosing from the tab changed `active.json` and
  the tab followed changes made by the command. No QML warnings.
- **Left for you,** after the rebuild in window-dissolve 04:
  - Open the dashboard and press Tab to reach Effects. Look through a few previews.
  - Choose an open and a close effect, then open and close a window.
  - Choose None for both, and check you see Hyprland's own animations.

**2026-10-13 (later):** Moved to the settings window as the Window effects page
(`settings/EffectsPage.qml`), and the list became a grid, as the user asked.

- **Why it moved:** an effect is chosen once in a while, not glanced at, and the
  settings window has room for a grid. The launcher's `>Window effects` action now
  opens that page. The dashboard no longer has an Effects tab.
- **The grid:** one tile per effect, labelled with its name. Where two effects share a
  name (Dissolve, Fade, Glitch, Pixelate), the label also names the collection of the
  one that is not ours. Each tile loops open, then close, at half speed
  (`EffectPreview.slowdown`).
  - Clicking a tile uses it for both opening and closing. The Open and Close chips
    under a tile choose it for one of the two only. They show on hover, and stay
    filled while that effect is in use.
  - Keys: the arrow keys move, Enter chooses for both, O for opening and C for
    closing, and Ctrl+D and Ctrl+U move half a page.
- **Checked** with a test copy of the shell in a headless sway on the Intel GPU (not
  the NVIDIA card that drives the screens), with the real library: the previews
  animate, and open and close alternate. Clicks on a tile and on a chip, and the
  keys, ran the right `window-effect` calls. Changing `active.json` updated the
  chips. No QML warnings.
- **Left for you,** after a rebuild:
  - Open Settings → Window effects. Do the half-speed previews and the chips look
    right in your theme's colours?
  - Click a tile, then open and close a window. Both should use that effect.
  - Hover another tile, click its Close chip, and close a window to check it.

**2026-10-16:** Committed after issue 29's settings were merged. The settings window's
Dashboard page lost its Effects switch (`dashboard.showEffects`), as the tab it hid is
gone. Window effects sits after Appearance in the settings window's list.
