# Move the Hyprland config from .conf to Lua before Hyprland 0.57

Status: ready-for-human
Type: HITL (touches the whole desktop config)

## What to build

Hyprland 0.56 prints at startup that `.conf` support will be removed in 0.57 (quoted in
HyprWindowShade's README). Our config is generated as `hyprland.conf` from the
home-manager `settings` block, with `configType = "hyprlang"` pinned on purpose.
home-manager 26.05 supports `configType = "lua"`, but switching means rewriting the
config, not flipping the flag.

Move the generated config to Lua with the same behaviour on both hosts: monitors and GPU
selection per host, keybinds and their descriptions, window rules, exec-once entries,
and whatever the shell and dissolve issues have added by then (HyprWindowShade's rules
and plugin load, game mode binds).

Also check:

- Plugin dispatchers fire from `.conf` binds but are not available to Lua configs. Lua
  configs use the plugin's own Lua API instead (HyprWindowShade README, "Legacy:
  hyprland.conf").
- Hyprland loads `hyprland.lua` in preference to `hyprland.conf` when both exist. Make
  sure no stray file shadows the generated one.
- The keymap cheatsheet reads `hyprctl binds -j` and relies on each bind's description.

## Acceptance criteria

- [ ] Both hosts log in to an identical desktop on the Lua config.
- [ ] Hyprland no longer shows the `.conf` deprecation warning.
- [ ] Every keybind still works and still shows its description in the cheatsheet.
- [ ] HyprWindowShade rules (if already in place) work under Lua.
- [ ] Nothing pins Hyprland below 0.57 any more.

## Blocked by

None - can start immediately. Coordinate with window-dissolve if it lands first.
