# Theme presets: save, rename and switch whole looks

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Save the current look under a name, and switch back to it later in one step. ambxst
has presets (`modules/services/PresetsService.qml`: a folder of copied config files per
preset, some shipped in `assets/presets/`); ideas only.

A look today is spread over three places:

- **Wallpaper, scheme, light or dark:** `~/.local/state/custom-shell/wallpaper.json`,
  written by `generate-theme` (`services/Wallpaper.qml` calls it).
- **The Appearance settings:** `appearance.fontFamily`, `textScale`, `cornerScale`,
  `frameThickness`, `animationSpeed`, and `wallpaper.fill` (`config/Settings.qml`).
- **Window effects:** `{ open, close }` ids in `~/.local/state/window-effects/active.json`,
  set with `window-effect open|close <id>` (`window-dissolve.nix`).

## Proposed choices

1. **A preset holds: the wallpaper path, scheme and mode; every `appearance.*` key and
   `wallpaper.fill`; the open and close effect ids.** New `appearance.*` keys (issue 77's
   opacity, for example) join by that rule. Once issue 16 lands, its theme source and
   recolour settings join too. Not in a preset: the wallpaper folder, the timed change,
   and the bar, dashboard and other behaviour settings.
2. **A setting the user has not chosen is saved as "not chosen"**, and applying the
   preset resets it, so the Nix value (`local.customShell.settings`) or the default still
   applies. Alternative: save every value as chosen. Reason: it keeps the settings'
   three layers working.
3. **Stored in `~/.config/custom-shell/presets.json`**, beside `settings.json`, written by
   the shell: a list of `{ name, wallpaper: { path, scheme, mode }, settings: {...},
   effects: { open, close } }`. Alternative: presets also from Nix, read-only, like
   `defaults.json`. Reason: start with the user's own; add Nix ones when wanted.
4. **No built-in presets.** Alternative: ship one ("Default", every setting at its
   default with the current wallpaper). Reason: the first save gives the user their own.
5. **Applying** runs `generate-theme <path> --scheme X --mode Y` once (one matugen run),
   `window-effect` for each kind, and sets or resets each key. A missing wallpaper or
   effect is skipped, and a notification says which. The timed change (issue 29, option
   43) keeps running and may change the wallpaper at its next tick.
6. **"In use"** is worked out by comparing the preset with the current look, not stored.
7. **Where it shows:**
   - The Appearance page, above "Text and shape": a **Presets** row with each preset
     (Apply, Rename, Delete) and **Save this look…**, which asks for a name. Names are
     unique and not empty; saving under an existing name asks before replacing it.
   - The launcher's actions (`>`): "Look: <name>", subtitle "In use" when it matches,
     as "Colour scheme: …" does today.
   - Once issue 34 is in, an IPC call that applies a preset by name.
   No keybind.
8. **Cost:** no timers or watchers beyond one `FileView` on `presets.json`. Applying is
   one matugen run; nothing runs in game mode unless the user applies one.

## Acceptance criteria

- [ ] Save a look, change the wallpaper, scheme, text size and effects, apply the preset:
      all come back.
- [ ] A setting left at its Nix value before saving follows a later Nix change after the
      preset is applied.
- [ ] Rename and delete work; names stay unique.
- [ ] A preset whose wallpaper was deleted applies the rest and says so.
- [ ] "Look: <name>" in the launcher applies it, and the matching one says "In use".
- [ ] Presets survive a restart and a rebuild.

## Blocked by

- None
