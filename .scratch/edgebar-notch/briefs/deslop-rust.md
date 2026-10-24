# Deslop: the Rust side and the IPC boundary

Unit name: `deslop-rust`. Read `briefs/_backend-common.md` and `briefs/_ui-common.md`
first; their rules on the live bar, the debug socket and restoring Brett's state apply.
Work in the main checkout (`/Users/brett/nixos-config`, branch `edgebar-notch`) against
the live `pnpm tauri dev` in herdr pane `w1:p4`; it rebuilds on every `src-tauri` save, so
keep each save compiling. For your own builds and tests use
`CARGO_TARGET_DIR=/Users/brett/.cache/edgebar-agent-target`.

Reviews of this branch found the items below. Each was triaged and accepted. Do each one,
or, if reading the code proves an item wrong, skip it and say why with evidence. Where an
item changes an IPC command or payload, change `src/ipc.ts` and every TS caller in the
same commit so the live bar keeps working. A frontend-only pass (`briefs/deslop-frontend.md`)
runs after you; leave its items alone.

## Items

Config and settings
1. The serde defaults never run. `Config` is deserialised only from
   `merge(bundled, …)` (settings.rs `trial` and `load`), so a missing key never reaches
   serde. Delete `wallpapers.rs` `bundled`, `default_folder`, `default_tint`,
   `default_oled` and `impl Default for WallpaperConfig`, assistant.rs
   `impl Default for AssistantConfig`, the `#[serde(default…)]` attributes on `Config`,
   and main's older `default_battery_*` and `default_window_height`, which are dead for
   the same reason. Delete the tests of that dead path
   (`wallpapers::an_absent_key_takes_its_default…`,
   `assistant::a_config_json_from_before_the_assistant_block_still_loads`, and
   `assistant::config_reads_camel_case…` if it only covers it).
2. One source for the config. `load_config()` re-reads the three files on each of its 7
   calls while `settings::Store` holds the validated config. Add
   `settings::current(app) -> Config` (a clone of the store's applied config), use it in
   every caller, and delete `load_config`. A `theme.sock` ping must still pick up a
   rebuilt config.json and a hand-edited settings.json: make the ping reload the
   settings layers from disk into the store through the same converge `set_setting` uses
   (so every subsystem and the `settings` event follow), then reload the palettes. The
   converge already calls `reload_theme` for some keys, so make sure nothing recurses.
   Prove it live: write a settings.json override by hand, ping `theme.sock`
   (`nc -U ~/.cache/edgebar/theme.sock </dev/null`), show `get_settings` and the
   affected subsystem follow, then delete the file, ping, and show it is back.
3. `settings::write_atomic` becomes `pub(crate)`, and `notifications::save_hidden` uses it
   (update the hidden-file test). One `cache_dir()` beside `settings::dir()` replaces the
   eight places that build `~/.cache/edgebar` from HOME.
4. Delete the `set_appearance` command. Its one caller, `src/notch/wallpapers.ts`, uses
   settings.ts `set("appearance", m)`; remove it from ipc.ts too. `open_pane` and
   `open_settings_pane` are one function: keep one.

Duplication
5. `setup::Player` repeats `notch::PLAYERS`. Make `PLAYERS` `pub(crate)`, index
   `Setup.asked` by its position, delete `setup::Player`.
6. Two Spotify cover fetchers: `spotify_cover`/`CoverCache`/`COVER_ID_640` and main's
   `artwork`, which pipes `curl` through `/bin/sh` and has its own cache. One
   `spotify_image(url, size_id)` that runs curl with direct arguments (no shell) and
   encodes with `crate::base64_encode`, one cache, both callers.
7. Three spawn-with-timeout copies (lib.rs `aerospace`, `notch::run_rule`,
   `toggles::run`): one `pub(crate) fn output_within(Command, Duration)`.

IPC shapes (Rust, ipc.ts and the TS callers together)
8. `Volume.input` holds the live level, or the level to restore while `inputMuted` is
   set: split it into two fields.
9. `notification_dismiss` and `notification_clear` only hide entries in edgebar: rename
   them `notification_hide` and `notification_hide_all`.
10. `SettingsPane`'s `"shortcuts"` member opens `shortcuts://`, not a Settings pane: give it
    a type or command that says what it is.
11. `CpuStat.topPid` uses 0 for "no process walk yet": make it `Option` (TS `number | null`).
12. quick-toggle.ts `FIXES` matches regexes against Rust's English `detail`: have Rust send
    a structured field naming the fix (the pane to open), and delete `FIXES`.
13. Assistant: chunks can arrive before `assistant_send` returns the turn id, hence
    `Phase.sending.early` and a second reset in assistant.ts. Create the turn id in the
    WebView, pass it to `assistant_send`, and delete the early buffer. In the same change
    make `AssistantChunk` a union keyed on `kind`, so new text and an error message are
    different fields. Prove one real round trip (one short haiku prompt, not a loop).
14. Expose the workspace names (`WS_ORDER`) in an existing payload, such as `get_config`,
    for the Settings rules editor, and have `MetricsHistory` report how many seconds its
    history can hold. The frontend pass uses both; you only add them.

Tests
15. Delete `setup::each_action_has_a_button_label`. Trim
    `settings::every_bundled_default_passes_its_own_check` to the part that can fail (the
    `Config` parse). Keep `notifications::the_bundled_config_keeps_history_off`: it guards
    a privacy default. Give the test scratch-folder helpers one shared implementation that
    cleans up on drop.

Reshape flags from the comment review (the comments that explained these are already
deleted; make the code say it instead)
16. settings.rs: `base_layer` drops a config.json that fails `trial` without a word. Push
    the problem into the snapshot's errors (naming config.json, not settings.json), and
    make `Snapshot::error` a list (`errors: Vec<String>`) that the Settings banner renders
    one per line; the banner's button still opens settings.json, so say which file is
    wrong in the text. `read_object` returns a full message with the file name. The keys
    whose children are free-form (an empty object in config.default.json, such as
    `notch.workspaces`) become a named list, so an empty object no longer silently means
    "any key". `Changes::rules` and `flash_hold` take the names of the keys they track.
17. Side effects that names hide: `apply_theme` kicks `wallpapers::spawn_converge` and the
    settings converge relies on that. Make `apply_theme` only apply the theme and call
    the converge where it is needed. `NotchState::set_config` callers must also run
    `refresh_workspace`: make `set_config` do it. `wallpapers::converge` relies on the
    caller holding `DESKTOP`: pass the guard in. `spawn_pick` always tints: name it so.
    `original_of` must be remembered by callers of `query_desktop_picture` and
    `query_current_wallpaper`: leave one query that returns the original and one that
    returns the raw picture, named for it.
18. metrics.rs: `metrics_sample`/`cpu_percent` hold `AppState.sys` while locking
    `MetricsState`; read the CPU figure before taking `sys`. `HISTORY_LEN` derives from
    `SAMPLE_PERIOD` (ten minutes). `install` must run before any bar exists or
    `cpu_state` panics: make `cpu_state` not depend on that order. `Sampler::top` becomes a
    named struct. `CpuStat::mem` and `MetricsHistory::mem` hold a used-memory fraction:
    name them so (`memUsed` or similar on the TS side, all callers). Expose `CPU_HISTORY`
    (main.ts copies it as `CPU_GRAPH.samples`) next to item 14's numbers.
19. toggles.rs: `converge` returns `Result<(), String>`, not `Option<String>`. `write_focus`
    ignores `on`: make it a toggle with no argument (converge already checks the state).
    Named constants for the notify-key value `state == 1`, the `CBManagerAuthorization`
    values, and the Night Shift schedule modes. A second Bluetooth click while a write is
    in flight must say it is busy, not return the permission error. `sys::night_shift` and
    `sys::set_night_shift` transmute `objc_msgSend`: implement `RefEncode`/`Encode` for
    `BlueLightStatus` (encoding `^{?=BBBi{?={?=ii}{?=ii}}QB}` on 26.7.1) and use
    `msg_send!` (`setEnabled:` is `B20@0:8B16`). Every bare `#[ignore]` gets a reason
    (`#[ignore = "…"]`), here and in assistant.rs.
20. assistant.rs: `run_cli` writes the whole prompt to stdin before reading stdout; write
    it on a thread as stderr already is. `run_turn` sends `Done` for a cancelled turn:
    send a distinct kind (fits item 13's union). `Line::Init` means the CLI saved the
    session: name it so. The CLI messages `Failure::classify` matches become named
    constants. `cache_dir` is the CLI's working directory: name it so. `slot` becomes a
    name for what it guards.
21. notifications.rs: `RawRow::delivered` is seconds since 2001: name it so.
    `installed_app_icon` must run on the main thread: take a `MainThreadMarker`. The test
    helper `fake_store` returns a Connection that must stay open: name or wrap it so.
22. lib.rs: `MIN_INK_CONTRAST` and `MIN_ACCENT_CONTRAST` carry their WCAG meaning in the
    name. `FRAME_WINDOW_LEVEL` derives from the bar window's level (one below it).
    `recolor_native_frame` takes a `MainThreadMarker`. `theme_from_wallpaper`'s `wait:
    bool` becomes an enum. `MIC_HELD` (a global faking an input mute) moves into managed
    state as part of item 8. `reload_theme`'s doc still says geometry changes need a
    relaunch; the settings converge rebuilds displays now, so fix or drop that sentence.
23. notch.rs: `ART_HOST` is an allow-list prefix for fetched URLs: name it so.
    `metadata_script` hard-codes `ASCII character 31`: build it from `FIELD_SEP` and keep
    the field order in one place with `parse_track`.
24. setup.rs, keyboard.rs, devtools.rs: `setup::automation` reports the last Ask's answer
    and never probes: name it so. `"-1743"` becomes a named errAEEventNotPermitted
    constant. `tool(.., local_bin: bool, ..)` takes an enum. `keyboard::front_app` returns
    a pid and None when edgebar is in front; `Held::previous` is a pid: name both so.
    devtools `post_keys` posts into edgebar's own queue: name it so; the key codes 53 and
    51 become named constants; `Plane::image` gets an enum for pending versus failed.

Flags not to do (triaged out, see decisions.tsv): `focus_shortcut` as an Option (the
settings layer types each key by its default, so a null default would accept anything),
`Store::writer` and `TINT_VERSION`, `touch_inapp_marker`, the seconds-unit renames,
`FRAME_SHADOW_*` against `--shadow-drawer`, the `Colors` role mini-language type,
`Geometry::bar_height`'s link to AeroSpace, and the bar height's ownership on rebuild.

## Done means

- Small commits in a sensible order, each checked on its own (`cargo test --lib` in your
  target dir, `pnpm exec tsc --noEmit` when TS changed), Conventional
  (`refactor(edgebar): ...`), staged by explicit path (never `git add -A` or
  `commit -a`), body ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  Don't push.
- `nix develop -c pre-commit run --all-files` passes from the repo root, and `cargo clippy
  --all-targets` adds no new warnings.
- The live bar works after each IPC change: the views you touched answer through
  `scripts/dev.sh eval`, and `scripts/snap-states.sh` at the end shows every view.
- No comment in your diff narrates; keep a comment only for a why the code cannot show.
- `~/.config/edgebar/settings.json` is absent at the end, the mode is auto, and the
  desktop picture is what it was when you started.
- Report: commits, each item done or skipped with the reason, what you proved live, and
  anything you could not prove.
