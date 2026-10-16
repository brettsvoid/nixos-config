# Workspaces: app icons and special workspaces

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

The bar's workspace pills show which apps each workspace holds, and special workspaces
(the scratchpad, Super+S) get pills of their own. Scrolling came with issue 29.

Caelestia: `modules/bar/components/workspaces/`. ambxst: `modules/bar/workspaces/`, which
runs `hyprctl clients -j | jq` on nearly every event, the PRD's cost to avoid. Ideas
only. `bar/Workspaces.qml` keys its pills by a string, so events do not rebuild them.
Each workspace's `toplevels` gives its windows, and a window's app id is `wayland.appId`
(issue 38 says why not `lastIpcObject.class`). Special workspaces are in
`Hyprland.workspaces` with negative ids; this config has one, `special:magic`. Hyprland
0.56.2 sends `activespecialv2>>id,name,monitor` when one is shown or hidden (empty id
and name when hidden), which Quickshell's Hyprland module does not track; Hyprland's
monitor JSON has `specialWorkspace` for the start.

## Proposed choices

1. **Icons.** **An occupied pill widens to hold one icon per app on it, at the bar's icon
   size; empty workspaces stay dots; the active pill keeps its colour behind its
   icons.** At most `bar.workspaceIcons` per pill (default 3; 0 gives today's pills),
   then "+N". The icon is the app's desktop entry (`DesktopEntries.heuristicLookup`),
   else a generic one (Steam games have no entry). A click still goes to the workspace.
   Alternative: the number in each pill, with icons beside it. Reason: least width.
2. **No rebuilds.** **The icons' model is a string of app ids per pill**, so a pill's
   icons are made again only when its apps change (`docs/quickshell-notes.md`).
3. **Room.** **If the pills would reach the clock, each shows one icon.** The portrait
   Dell is 1080 px wide, so its clock is centred at 540 px. Alternative: the cap alone.
   Reason: by estimate (three 16 px icons and padding a pill), ten busy workspaces need
   about 650 px.
4. **Special workspaces.** **A pill per special workspace that has windows, after the
   numbered ones: a star glyph for `magic`, else its first app's icon. Filled while
   shown on this screen; a click toggles it (`togglespecialworkspace <name>`).** The
   shown one comes from `activespecialv2` through `Hyprland.rawEvent`, as `shell.qml`
   reads `workspacev2` (a string split, no request), and at start from each monitor's
   `lastIpcObject.specialWorkspace`. With per-screen workspaces, only that screen's.
   Setting `bar.showSpecialWorkspaces` (default on). Alternative: a scratchpad button
   that always shows. Reason: it shows only what exists.
5. **Settings** go under Bar → Workspaces; both are per screen with issue 35.

Cost: bindings on the Hyprland module's data and one raw-event handler; no process, no
timer. In game mode and fullscreen the bar is hidden: nothing.

## Acceptance criteria

- [ ] A workspace with kitty and Firefox shows both icons; opening or closing a window
      changes only its pill; `bar.workspaceIcons` 0 gives today's pills.
- [ ] Moving a window to another workspace moves its icon.
- [ ] With a window on the scratchpad, Super+S fills its pill on that screen and empties
      it again; a click on the pill does the same.
- [ ] On the Dell, ten busy workspaces never reach the clock.
- [ ] No process starts on workspace or window events (watch with `procs` while
      switching). Costs nothing in game mode.

## Blocked by

- None
