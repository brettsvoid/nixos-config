# Find out whether game mode needs to turn the dissolve off

Status: ready-for-human
Type: HITL (needs a game running on brett-desktop, with MangoHud)

## What to build

A measured answer to one question: does the window dissolve cost a game anything, in
frame time or on the GPU? If it does, game mode turns it off. If it does not, game mode
leaves it alone, and custom-shell/18 drops its "switch off the window dissolve" step.

What is already known (plugin source at a4c6b8a, and issue 03):

- The shaders only run while a window opens or closes. They do not declare the `time`
  uniform, so the plugin schedules no continuous redraws for them (plugin README).
- The plugin stays loaded the whole session. It hooks Hyprland's texture draw
  (`hkGLDrawTex`) and `useShader`, and checks every window for motion on each frame,
  with a fast path for idle windows (all in `Hooks.cpp`). That is compositor CPU work
  on every frame, even when no effect is playing. Its cost has not been measured.
- Fullscreen windows get no shader. The plugin skips them early
  (`fullscreenRendersNothing` in `Hooks.cpp`), and its comment says this keeps a
  fullscreen game "costing what it would cost with the plugin unloaded". Not measured.
- Windowed games and Steam windows do burn (issue 03).

Questions to answer:

1. Fullscreen game, plugin loaded and unloaded (`hyprctl plugin unload` / `load`), in
   the same scene: frame times, GPU use and VRAM.
2. The same comparison for a windowed or borderless-windowed game, which the plugin
   does not skip.
3. Hyprland's own CPU use while a game runs, plugin loaded and unloaded.
4. A window that opens or closes over a running game (a Steam popup, a dialog): does
   its dissolve cause a hitch in the game?
5. Game mode turns Hyprland's animations off (Caelestia's on Super+Shift+G today,
   custom-shell/17 later). What does the plugin do then: does the dissolve still play?

If there is a cost, choose how game mode turns the effect off. Unloading the plugin
removes its hooks too; removing the `shader_open` / `shader_close` tags with a runtime
window rule only stops the shaders. Check that a reload after an unload is clean.

## Acceptance criteria

- [ ] Frame times (average and 1% low), GPU use and VRAM recorded for a fullscreen game
      with the plugin loaded and unloaded, in the same scene.
- [ ] The same recorded for a windowed game.
- [ ] Recorded what the dissolve does while game mode is on.
- [ ] A decision: game mode leaves the dissolve alone, or turns it off (and how).
      custom-shell/17 and 18 updated to match.

## Blocked by

None - can start immediately.
