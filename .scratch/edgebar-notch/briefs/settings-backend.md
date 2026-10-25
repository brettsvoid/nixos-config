# Brief: edgebar settings storage (Rust + a small TS accessor)

You own this diff. Do not spawn subagents. Read first, in full:
`/Users/brett/.claude/skills/poteto-mode/SKILL.md` (Principles section included),
`/Users/brett/nixos-config/CLAUDE.md`, `/Users/brett/.claude/CLAUDE.md` (UK English
everywhere, no conjecture, pragmatic), `.scratch/edgebar-notch/PLAN.md`, and
`apps/edgebar/src/ipc.ts` (the IPC contract: `SettingsSnapshot`, `get_settings`,
`set_setting`, the `settings` event).

## Why

edgebar's config.json is a read-only symlink into the Nix store (rendered by
`modules/home/darwin/edgebar.nix` from `src-tauri/config.default.json`). A settings view
is coming, and features need user-changeable settings now. The custom shell solves the
same problem with Nix defaults plus a user overrides file (`modules/home/desktop/
quickshell/config/Settings.qml`); do the same.

## Data shape

Three JSON layers, merged deep (objects merge key by key, anything else replaces):
1. the bundled `config.default.json` (`include_str!`), so a key added to it works before
   Brett rebuilds his Nix config;
2. `~/.config/edgebar/config.json` (Nix);
3. `~/.config/edgebar/settings.json` (the user's overrides, written only by edgebar).

`effective = merge(merge(bundled, nix), user)`. The typed `Config` that lib.rs already
uses is deserialised from `effective`, so every existing consumer sees overrides for free.
Default values live only in `config.default.json`: no second copy of a default anywhere.

Validation sits at the boundary (loading settings.json and `set_setting`), nowhere else:
- An override's JSON type must match the bundled default's type at the same path
  (bool, number, string, array, object). A key under an object whose default is `{}`
  (e.g. `notch.workspaces`) is an open map: any key, any JSON value under it.
- A key not in the bundled defaults and not under an open map is rejected.
- On load, mismatching or unknown overrides are dropped from `effective` and listed in
  `SettingsSnapshot.error`; an unparseable file is ignored entirely, with its parse
  error there. The file itself is never rewritten on load.

`set_setting(key, value)`: dotted key; `value: null` removes the override and prunes
emptied parent objects. Writes atomically (temp file + rename in the same directory).
Then it converges the running app to the new `Config`: compare the old and new typed
config per subsystem and re-apply only what changed (the notch's rules and idle look,
see `notch.rs`'s config; the theme via `apply_theme`; the native frame via
`rebuild_displays` on the main thread when geometry changed). Emit `settings` with the
new snapshot every time. Make it idempotent: setting the same value twice is a no-op
apart from the event.

Put the pure parts (merge, set/remove by dotted path with pruning, type check against
defaults) in a new module `src-tauri/src/settings.rs` with unit tests that call them
on literal JSON and assert literal JSON results. lib.rs changes: `load_config` goes
through the merge, the two commands are registered, and the converge step lives in
settings.rs or lib.rs (your call, keep lib.rs's part small).

The `#[tauri::command]` functions must not block the main thread: file IO and the
converge step run async (`tauri::async_runtime::spawn_blocking`), except UI work, which
hops to the main thread with `run_on_main_thread` as lib.rs already does.

TS side, new file `apps/edgebar/src/settings.ts`:
- `import defaults from "../src-tauri/config.default.json"`; export
  `type Settings = typeof defaults` so feature code gets typed keys from the one file
  that owns defaults.
- `current(): Settings`, `isSet(key: string): boolean`, `set(key, value)`,
  `reset(key)`, `onChange(fn)`, backed by `call("get_settings")` and `on("settings")`
  from ipc.ts. A `ready` promise that resolves after the first load.
Don't wire it into main.ts; feature workers will.

## Where you work

You are in your own git worktree. Before building, link the main tree's node_modules
(`ln -s /Users/brett/nixos-config/apps/edgebar/node_modules apps/edgebar/node_modules`)
and use a shared target dir for cargo:
`CARGO_TARGET_DIR=/Users/brett/.cache/edgebar-agent-target cargo test` and `cargo check`
in `apps/edgebar/src-tauri` (the first run compiles everything; that's expected). Never
build in the main tree's `apps/edgebar/src-tauri/target`. Brett's live edgebar runs from
the main tree; don't touch it, don't touch `~/.config/edgebar/settings.json` on this
machine (tests use temp dirs or pure functions).

## Proof (in your report)

1. `cargo test` output for settings.rs: the cases you cover (at least: deep merge, a
   reset that prunes, a type mismatch rejected, an open-map key accepted, an unknown key
   rejected, an unparseable file reported).
2. `cargo check` clean, no new warnings.
3. `node_modules/.bin/tsc -p .` in `apps/edgebar` exits 0.
4. `cd <worktree root> && nix develop -c pre-commit run --all-files` passes.
5. Commit on your worktree branch: `feat(edgebar): layer user settings over the Nix
   config`, short body, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
   Don't push. Report the branch name and commit SHA.

Comments: only a non-obvious why, written clean (no long dashes). UK English. Match
lib.rs's style (doc comments, let-else early returns).

## Report (under 40 lines)

What you built, the converge rules per subsystem, test list, proof 1-5, branch + SHA.
