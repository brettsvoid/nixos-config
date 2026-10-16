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

## Comments

**2026-10-17:** Looked into moving now, against Hyprland 0.56.2's source. The move breaks
more than the config file. Under a Lua config, Hyprland refuses `hyprctl keyword`
("keyword can't work with non-legacy parsers. Use eval."). It also runs
`hyprctl dispatch X` as Lua, `return hl.dispatch(X)`, so every old-style dispatch fails
(`dispatchKeyword` and `dispatchRequest` in `src/debug/HyprCtl.cpp`).

- **Ours, changed as part of the move:**
  - `hyprctl keyword`: the shell's window borders (`quickshell/theme/WindowBorders.qml`),
    game mode's batch and its saved values (`game-mode.nix`), `lock-recover`
    (`misc:allow_session_lock_restore`), and the laptop's resume service
    (`monitor eDP-1,disable`).
  - Old-style dispatches: `Hyprland.dispatch` in `bar/Workspaces.qml`, `lock/Idle.qml`
    and `services/Windows.qml`; `hyprctl dispatch` in `custom-shell.nix` (the rebuild's
    restart), `lock-recover` and `thunar-quick-look-keys.sh`; and hypridle's `lock_cmd`
    on the laptop branch.
  - Every module's `wayland.windowManager.hyprland.settings`. In home-manager's Lua mode
    each attribute becomes an `hl.<name>(...)` call, so binds, rules, monitors, env and
    exec-once are each rewritten with `_args` and `lib.generators.mkLuaInline`. That is
    `hyprland.nix`, `custom-shell.nix`, `window-dissolve.nix`, `game-mode.nix`,
    `screenshots.nix`, `session-restore.nix`, the gaming profile and both hosts.
  - qs-test's fake Hyprland, which answers the old requests.
- **Others' tools:**
  - hyprsession (session restore) relaunches each app with `dispatch exec [rules] cmd`
    and moves, floats and pins them with old-style dispatches, through the `hyprland`
    Rust crate (`src/session.rs`). Under Lua nothing would be restored. Upstream's last
    commit is 4 Jan 2026, before Hyprland's Lua config.
  - Already fine: Quickshell (its own workspace switching checks for Lua), hyprshutdown
    (it has a Lua path), HyprWindowShade (it documents Lua first) and grimblast. grimblast
    already sends `hyprctl eval`, which today's `.conf` refuses, so its freeze silently
    skips one layer rule now.
- **Testing it:** a Hyprland nested in a headless mutter on the Intel iGPU runs apart from
  the desktop (sway and Weston offer protocol versions too old for it). Both configs can
  load there and their `hyprctl binds -j`, options and rules can be compared. Its exec
  lines have to be stubbed, or they start the real apps.

Question for you: **wait until 0.57 is close, or move now?** Moving now loses session
restore until hyprsession is patched (it already carries one patch here) or replaced.
I'd wait. 0.56 keeps parsing `.conf`, and nothing here needs Lua yet.
