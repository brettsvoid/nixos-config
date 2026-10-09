# Choose which windows dissolve

Status: ready-for-agent
Type: AFK

## What to build

Decide which windows get the dissolve and write that as window rules, so the effect
only appears where it looks right and never gets in the way.

- **Dissolve:** normal application windows, tiled or floating.
- **Do not dissolve:** games and game launchers (Steam, its game windows, the rofi game
  library, Nolvus), fullscreen windows, picture-in-picture, and short-lived windows such
  as file-picker dialogs if the effect looks wrong on them.
- **Check first:** the plugin applies a window's shader to that window's menus, dropdowns
  and tooltips. Confirm what that looks like and exclude them if it is distracting.

Prefer matching on window properties (class, floating, fullscreen) over a long list of
app names where possible.

## Acceptance criteria

- [ ] App windows dissolve; game windows and the game library never do.
- [ ] Menus and tooltips behave in a way that is either confirmed fine or excluded.
- [ ] The rules carry a short comment explaining each exclusion.
- [ ] A new app needs no new rule to get the effect.

## Blocked by

- window-dissolve/02-dissolve-shader.md
