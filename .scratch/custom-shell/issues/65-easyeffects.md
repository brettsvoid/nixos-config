# EasyEffects bypass and presets

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Turn EasyEffects' audio effects on and off, and pick a preset, from the shell. ambxst
runs EasyEffects' command line for this (`modules/services/EasyEffectsService.qml`;
ideas only).

What exists (checked):

- EasyEffects 8.2.9 comes only from ambxst (its `nix/packages/apps.nix`), so issue 23
  removes it from both hosts.
- On the desktop it has been opened: its settings were last saved on 5 October, with
  one Loudness effect on the PRO X headset's output. There are no saved presets
  (`~/.local/share/easyeffects/output` and `input` are empty). It is not running.
- Its command line can set and read the global bypass (`-b 1`, `-b 2`, `-b 3`), load a
  preset (`-l <name>`) and list them (`-p`). It talks to the running instance through
  `$XDG_RUNTIME_DIR/EasyEffectsServer`. Unchecked: what `-b` does when no instance
  runs.
- home-manager has `services.easyeffects`: a user service with the session, a preset
  to load at start, and presets declared in Nix (`extraPresets`).

## Proposed choices

1. **Do you use EasyEffects?** **If not, close this issue.** Nothing then needs
   building, and EasyEffects leaves with ambxst. If you do, say what for (the headset's
   loudness?), and choices 2 to 4 apply.
2. **Install.** **`services.easyeffects.enable` in home-manager, on both hosts.** It
   then always runs, so the bypass switch has something to talk to. Your presets can
   move into Nix (`extraPresets`) once you have made them. Alternative: the package
   only, started by hand. Cost: EasyEffects processes all audio while it runs; how
   much CPU that takes here is unchecked.
3. **How the shell controls it.** **The command line: `easyeffects -b 1|2|3` and
   `easyeffects -l <name>`, one process per click.** The presets come from listing
   the two preset folders, with no process. The shell calls nothing while the socket
   file is missing (EasyEffects not running). Alternative: its local socket, with no
   process, but that protocol is internal to EasyEffects. Reason: clicks are rare, and
   the command line is the documented way in.
4. **Where.** **An Effects section on the Audio settings page:** a bypass switch, and
   an output and an input preset choice, shown only while EasyEffects runs. Plus an
   "Effects" toggle in issue 48's row (`"effects"` in `dashboard.hiddenToggles`),
   added by whichever of the two lands second. No new settings: the state lives in
   EasyEffects, read when the page or the row opens. No bar entry. Alternative: a
   launcher action (`>`) per preset.
5. **Cost.** No timers. One process per click, and one when the page or the toggles
   open. Nothing runs in game mode.

## Acceptance criteria

- [ ] The user's answer to choice 1 is recorded here.
- [ ] If built: the switch bypasses and restores the effects. After the bypass is
      changed in EasyEffects' own window, the page shows it when opened again.
- [ ] Picking a preset loads it.
- [ ] With EasyEffects not running, the section hides and no process starts.
- [ ] It costs nothing in game mode.

## Blocked by

- None. The toggle needs .scratch/custom-shell/issues/48-quick-toggles.md's row.
