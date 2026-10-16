# Launcher favourite and hidden apps

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Favourite apps come first in the launcher. Hidden apps never show in it.

- Caelestia keeps `favouriteApps` and `hiddenApps` lists (patterns over entry ids) and
  sorts favourites before use counts (`plugin/src/Caelestia/Models/appdb.cpp`). Its
  settings app has an Apps page. Ideas only.
- Issue 29 built ranking by use, with a reset. `services/AppUsage.qml` counts starts in
  the state folder, `AppsMode` adds 4·log2(1 + starts) to the match, and the Launcher
  page has "Rank by use" and "Forget N apps".

## Proposed choices

1. **Two settings, `launcher.favouriteApps` and `launcher.hiddenApps`: lists of desktop
   entry ids** (the schema's string lists, default `[]`), so Nix can set them too.
   Alternative: keep them in AppUsage's state file. Reason: they are choices, not
   counts, and resetting one returns it to the Nix value.
2. **An empty query shows the favourites first, in the order added, then the rest as
   today. While typing, a favourite gets +12** (the use bonus of seven starts), so a
   clearly better match still wins. Alternative: favourites above every other match.
   Reason: otherwise a stray subsequence match on a favourite beats the app typed.
3. **A star after a favourite's name.**
4. **Set them from the row options (issue 47)**: "Add to favourites" or "Remove from
   favourites", and "Hide from the launcher". Alternative: keys on the selected row
   (for example Alt+F and Alt+H), without issue 47.
5. **The Launcher page gets an Apps heading.** It lists the favourites and the hidden
   apps by name, each with a button that removes it or shows it again. An id that is no
   longer installed shows as the id, marked "not installed". The page has no app
   picker: adding is from the launcher.
6. **Hidden apps leave the apps mode and field search (issue 44)** entirely, rather
   than ranking last.
7. **Favourites and the dock's pins (issue 72) are separate lists.** Alternative: one
   list for both. Question: which do you want?
- Cost: nothing new runs, so nothing in game mode.

## Acceptance criteria

- [ ] A favourite comes first with an empty query, and shows a star.
- [ ] While typing, a favourite ranks above an equal match but not above a clearly
      better one.
- [ ] A hidden app no longer appears, and comes back from the Launcher page.
- [ ] Both lists survive a restart and can be set from `local.customShell.settings`.
- [ ] "Forget N apps" leaves the favourites and hidden apps alone.

## Blocked by

- .scratch/custom-shell/issues/47-per-app-actions.md
