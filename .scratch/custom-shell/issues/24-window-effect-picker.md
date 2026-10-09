# Window effect picker

Status: ready-for-agent
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
