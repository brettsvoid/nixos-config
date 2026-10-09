# Choose which windows dissolve

Status: done
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

## Comments

**2026-10-09:** Decided by the user: every window for now, with an exclusion list later
for apps that have trouble. The rules match `class .*`. Removing the tags in a later rule
excludes an app (`tag -shader_open:<path>, match:class ^(app)$`, and the same for
`shader_close`). Tested with a runtime rule: the excluded class got no tags, and others
still got both.

What "every window" means in practice (plugin source and recordings):
- Fullscreen windows get no shader unless a rule opts them in
  (`+shader_fullscreen:` / `+shader_fullscreen_stack:1`). The plugin takes a fast path
  for them, so a fullscreen game is untouched, which covers most of the game exclusions
  planned above. Windowed games and Steam do burn.
- Popups and subsurfaces borrow their window's shader. A menu only burns if it opens
  during its window's own 0.3 s open. Close shaders are only attached to windows and
  layers (`hkFadeoutCreate`, `hkLayerFadeoutCreate`), so a closing menu never burns.
- Recorded at 60 fps on ws 3: ghostty, thunar, a floating zenity dialog and xterm
  (XWayland) all got both tags. Thunar, zenity and xterm burn in and out correctly.
  ghostty's close burns, but its open shows nothing. It attaches full-size buffers within
  7 ms of mapping, but they stay empty for ~230 ms (only the border shows), and then the
  window pops in whole near the end of the 0.3 s open. That comes from ghostty's start-up
  and can't be fixed in the shader; it's a candidate for the exclusion list if it bothers
  the user.
