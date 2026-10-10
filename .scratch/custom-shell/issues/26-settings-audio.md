# Settings: audio page

Status: ready-for-agent
Type: AFK

## Parent

.scratch/custom-shell/PRD.md

## What to build

An Audio page in the settings window (issue 25), using Quickshell's PipeWire module. The
bar's audio icon and the OSD already read the same PipeWire state.

- Output and input device pickers, which set the default device.
- Volume and mute for the chosen output and input.
- Volume and mute for each app that is playing or recording, listed while it is active.

## Acceptance criteria

- [ ] Choosing another output moves the audio that is playing to it. The bar's icon and
      the OSD follow.
- [ ] Output and input volume and mute work, and match `wpctl status`.
- [ ] An app that is playing audio shows with its own volume. Changing it affects only
      that app, and the app leaves the list when it stops.
- [ ] The default device chosen here is still chosen after the shell restarts. Record
      whether WirePlumber keeps it across a logout.

## Blocked by

- .scratch/custom-shell/issues/25-settings-window.md
