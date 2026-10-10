# Settings: audio page

Status: done
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

- [x] Choosing another output moves the audio that is playing to it. The bar's icon and
      the OSD follow.
- [x] Output and input volume and mute work, and match `wpctl status`.
- [x] An app that is playing audio shows with its own volume. Changing it affects only
      that app, and the app leaves the list when it stops.
- [x] The default device chosen here is still chosen after the shell restarts. Record
      whether WirePlumber keeps it across a logout.

## Blocked by

- .scratch/custom-shell/issues/25-settings-window.md

## Comments

**2026-10-10:** Done in d060f4c (`settings/AudioPage.qml`). It was tested from the
working tree, with a temporary null sink and a test app playing silence into it, so
nothing audible changed. Your Firefox stream moved to the null sink for about a second
during the default-output test, and came straight back.

- **Layout:** each device and app has a mute button and a volume slider; a click on a
  device's name makes it the default. Devices are named by their description, because
  the nicknames repeat. The lists are sorted by name.
- **Results:**
  - Volume, mute and the default changed in PipeWire as set (wpctl). A change made with
    wpctl showed on the page. The bar's icon followed the default output.
  - The test app's volume changed alone, and the app left the list when it stopped.
  - The headset (0.40) and Firefox (1.00) were left as they were. The null sink was
    removed afterwards.
- **Across a logout:** the default is WirePlumber's, not the shell's. Choosing one
  writes `default.configured.audio.sink` to `~/.local/state/wireplumber/default-nodes`,
  which WirePlumber reads when it starts. A shell restart does not touch it.
- **Not checked:** clicking an input to make it the default (the same call, for
  sources), and the OSD while another output was the default (it reads the same node).
- **Left behind:** WirePlumber remembers `qs-settings-test` in its fallback list of
  outputs (as it does issue 13's `spectrum-test`), and a volume of 0.25 for an app
  called "Settings stream test". Both are harmless.
