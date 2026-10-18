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

**2026-10-10 (from custom-shell 18):** Question 5 answered: with `animations:enabled 0`
(set by `game-mode on`, desktop-game-mode), a kitty window opened in a single frame in a
60 fps recording of DP-2, with no burn. The dissolve does not play while animations are
off; only the plugin's per-frame hooks remain to measure.

**2026-10-16:** A script now does the measuring, so your part is only playing:
`.scratch/window-dissolve/measure-game-cost.sh`. MangoHud logs the same scene with the
plugin loaded, unloaded, then loaded again, and the script reads Hyprland's CPU time
over each phase. `--popups` adds two phases in which a small window opens over the game
every 5 seconds, with the plugin loaded and then unloaded (question 4). It loads the
plugin again at the end, also after Ctrl+C. It starts and stops MangoHud's logs through
MangoHud's control socket, now set in `modules/profiles/gaming.nix`
(`control = "mangohud-%p"`).

To run it, after a rebuild:

1. Start a game fullscreen and stand somewhere quiet.
2. In a terminal on the other screen, run
   `bash ~/nixos-config/.scratch/window-dissolve/measure-game-cost.sh --popups fullscreen`.
   Go back to the game during the 10-second countdown and keep still for about six
   minutes, until it prints a table.
3. Do the same with the game windowed or borderless, with `windowed` as the label.
4. Tell me when they are done. The tables are saved as
   `~/.local/state/mangohud/dissolve-cost-*.txt`, and I will fill in the criteria from
   them.

Checked in a nested Hyprland 0.56.2 (in a headless mutter, on the Intel iGPU) with the
same plugin build and effect files, and vkcube on lavapipe with MangoHud as the game:

- The control socket started and stopped a log per phase, and the table came out with a
  row per phase.
- The plugin was unloaded and loaded again three times, and the config was reloaded
  while it was unloaded. Hyprland stayed up, and the plugin was loaded at the end.
- The popup is a floating 480x270 kitty at 40,40 that does not take focus.
- MangoHud logged single frames of over an hour when a popup opened (3,944,260 ms),
  which wrecked its own summary's averages. The script works from the per-frame log
  instead and leaves out frames over 10 seconds, counting them in a column.

The test's figures mean nothing for the desktop: lavapipe draws on the CPU.

**2026-10-17:** MangoHud's control socket doesn't work with a Proton game. With The Crust
it listened but never accepted a connection. In MangoHud's source, each Vulkan instance
tries to listen on `mangohud-<pid>`, only the first in a process gets it, and an instance
answers it only while it presents frames. Proton games make several instances. The
`control` setting is gone from `modules/profiles/gaming.nix`.

The script now waits for the log that Left Shift+F2 (MangoHud's log key) starts, keeps
that one log for the whole run, and splits it into phases by its `elapsed` column. A
notification says when it is done; Left Shift+F2 then stops the log.

Before the change, the 2026-10-17 run measured nothing: it waited on the socket for 47
minutes. During that wait, at 22:59:38, both monitors disconnected and reconnected, with
The Crust holding 8.85 GB of the 3080 Ti's 12 GB and the Godot editor 1.2 GB. The driver
ran out of video memory, and the custom shell crashed in NVIDIA's Vulkan driver. Steam's
web helper crashed in its GL library. The script had not loaded or unloaded the plugin,
or opened any windows, since 22:12.

**2026-10-18:** Parked: the runs with a game took too much of your time. Unloading the
plugin in game mode without measuring was turned down, as a change made without knowing
the cost. Two ways to pick this up later:

- Unattended, no game: vkmark under MangoHud on the 3080 Ti, fullscreen and windowed,
  with the plugin loaded and unloaded, while you are away. It measures the plugin's
  overhead, not a real game's.
- With a game: start it fullscreen, run the script, press Left Shift+F2 in the game, and
  keep still for about six minutes. The Shift+F2 version of the script has not run on a
  game yet.
