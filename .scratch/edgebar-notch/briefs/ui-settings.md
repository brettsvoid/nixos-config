# UI: the Settings view

Read `briefs/_ui-common.md` first; its rules apply. Unit name: `ui-settings`. You add
`src/notch/settings.ts` (and CSS), turn the Settings rail button (pinned to the rail's
foot) into a real view, and add the Rust it needs. Backend merged: `get_settings`,
`set_setting`, the `settings` event (`src-tauri/src/settings.rs`; read its docs: three
layers, type-checked overrides, `null` resets, converge per subsystem) and the TS
accessor `src/settings.ts`.

Brett asked for "the settings view with whatever needs to be filled in to set up the
edgebar". So it has two jobs: change edgebar's settings, and show what edgebar still
needs from him to work fully.

## Layout (the custom shell's settings grammar, sized for the notch)

A section list on the left (full-round entries, the active one `--primary`), the section's
rows on the right, scrolling. A row: the label, its control, and a small reset button
(an undo glyph) shown only while the key is overridden (`isSet`), which calls `reset`.
Controls: a switch (on = `--primary` track), a segmented choice (full-round pills), a
slider with its value, a text field (full-round, commits on Enter or blur), a folder
field with a Browse button. Values come from `current()`; every change goes through
`set`/`reset` and re-renders from the `settings` event, never from local state. If
`SettingsSnapshot.error` is set, show it in a banner at the top with a button that opens
settings.json.

## Sections and keys

Every key below needs its default in `config.default.json` and a consumer; many already
exist (grep before adding). Where the consumer doesn't exist yet, wire it: a setting that
changes nothing must not be shown.

1. **Setup.** A checklist, one row per thing edgebar needs, each with a status (ready,
   missing, unknown) and an action button. Back it with one Rust command,
   `setup_status`, returning a list of `{ id, label, state, detail, action }` built from
   a table of checks (each check one entry, not branches spread through the file):
   - Full Disk Access (notification history, Focus state): from whether the usernoted
     store and `~/Library/DoNotDisturb/DB/Assertions.json` open. Action: the Privacy pane.
     The detail says plainly that edgebar inherits permissions from the app that started
     it (today kitty, via herdr), so the grant goes to that app.
   - Bluetooth permission (the Bluetooth toggle's writes): from the toggle's state.
   - Automation for Spotify and Music (the player's metadata and transport): unknown until
     asked; action runs one harmless AppleScript read so macOS asks.
   - A Focus shortcut named as `toggles.focusShortcut` exists (`shortcuts list`);
     action opens the Shortcuts app.
   - Tools found on PATH: `aerospace`, the theme command, the wallpaper command
     (`desktoppr`), the Claude CLI (`assistant.command`), each with the path found.
2. **Appearance.** Mode (light/dark/auto), scheme, OLED (the top-level `oled` key), and the frame's geometry keys the
   restyle made configurable (thickness, corner radius). Mode and scheme have their own
   stores today (`~/.config/edgebar/appearance`, `scheme`) with commands that scripts also
   use; decisions.tsv records that the settings backend left appearance in two stores.
   Fix it: route `set_appearance` through the settings layer so there is one store for
   the mode (import the old file once at startup, then stop reading it), and keep the
   scheme file as the store for the scheme (the Nix activation and `select-scheme` read
   it), shown here through `set_scheme`.
3. **Bar.** Clock: 24-hour, seconds, date (new keys under `clock`; main.ts's clock reads
   them; with seconds on, the clock ticks each second only while shown). Segments: show
   the CPU segment (new key; hidden means its sampler's event is ignored, not stopped:
   the notch's chart still uses it).
4. **Notch.** Idle look (`notch.idle`: handle, clock, user@host, or custom text), OSD
   duration (`notch.transientMs`), and an editor for `notch.workspaces` rules: one row per
   rule (workspace name, source "focused window" or "command", the command and its
   interval for command rules), add and remove. README.md's "The notch" section documents
   the rule shape.
5. **Wallpapers.** Folder (`wallpaper.folder`, with Browse: add a folder picker command
   next to `pick_wallpaper_file`), Tint. The Nix scripts `select-wallpaper.sh` and
   `cycle-wallpaper.sh` still hardcode `~/Pictures/Wallpapers`; make them read the folder
   from the effective settings or say why not.
6. **Calendar.** Week starts on.
7. **Assistant.** Model (haiku, sonnet, opus), CLI command.
8. **Quick toggles.** The Focus shortcut's name (`toggles.focusShortcut`; the settings
   converge doesn't refresh `toggles.rs` yet, so add that).
9. **About.** The version, where each layer lives (bundled default, the Nix config.json,
   settings.json) and a button that opens settings.json in the default editor.

Prove: every control round-trips (set it through a real click or input event, read
`settings.json` and `get_settings` back, reset it, read back again), the Setup checklist
on this machine (describe each row's real state), a changed notch rule taking effect on
the live notch, and the mode store fix (toggle the mode from the Wallpapers view and from
Settings and show both read the same value after a relaunch). Restore every setting you
changed: when you finish, `~/.config/edgebar/settings.json` must be absent or exactly as
it was before you started (save a copy first).
