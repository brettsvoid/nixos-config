# Rules for every edgebar backend worker

You own your diff. Do not spawn subagents. Read first, in full:
`/Users/brett/.claude/skills/poteto-mode/SKILL.md` (Principles section included),
`/Users/brett/nixos-config/CLAUDE.md`, `/Users/brett/.claude/CLAUDE.md` (UK English
everywhere, no conjecture, pragmatic), `.scratch/edgebar-notch/PLAN.md`,
`.scratch/edgebar-notch/decisions.tsv`, and `apps/edgebar/src/ipc.ts`, the IPC contract.
Your Rust types serialise to exactly the shapes in ipc.ts (`#[serde(rename_all =
"camelCase")]` where the TS uses camelCase). If the contract is wrong for your feature,
change ipc.ts in your branch and say why in your report.

## Where you work

- You are in your own git worktree off branch `edgebar-notch`. Check `pwd` and
  `git log --oneline -1` first. Never edit `/Users/brett/nixos-config` itself: Brett's
  live edgebar runs from there.
- Link node_modules once: `ln -s /Users/brett/nixos-config/apps/edgebar/node_modules
  apps/edgebar/node_modules`.
- Cargo: always `CARGO_TARGET_DIR=/Users/brett/.cache/edgebar-target-<your unit name>`,
  run in `apps/edgebar/src-tauri`. Prefer `cargo check` and `cargo test <module>`; the
  first build is slow.
- Don't touch `~/.config/edgebar/` or `~/.cache/edgebar/` on this machine except where
  your brief says so.

## Code shape

- Your feature lives in its own module file. lib.rs gets only the `mod` line, your
  commands in `generate_handler!`, and at most one call in `setup`. Fields you add to
  `Config` get `#[serde(default)]`, and their defaults go in `src-tauri/config.default.json`
  only (another worker is layering user settings over that file; don't repeat a default
  in Rust or TS).
- A `#[tauri::command]` that is not `async` runs on the main thread. Anything that spawns
  a process, waits, or does IO is `async` and uses `tauri::async_runtime::spawn_blocking`.
  AppKit work hops to the main thread with `run_on_main_thread`, as lib.rs does.
- Parsing of anything external (command output, files, plists) is a pure function with
  unit tests that pass literal input and assert literal output. A test that would pass if
  the function returned a default value is not a test.
- Prove the real source on this Mac with a `#[test] #[ignore]` "live" test that calls
  your read path and prints a summary; run it with `cargo test <module> -- --ignored
  --nocapture`.
- Comments: only a non-obvious why, written clean (no long dashes). Match lib.rs's style
  (doc comments on items, let-else early returns).

## Safety on Brett's machine (hard rules)

- Never turn Wi-Fi off and never change network settings: this session runs over the
  network and would die.
- Never call anything that sets Bluetooth power, and never call IOBluetooth's getters
  either: they raise a Bluetooth permission prompt and can hang or abort the process.
- Don't change media playback, Night Shift, Focus, AirDrop or sleep settings in tests.
  Prove a write path exists (the selector responds, the command's usage text) without
  calling it, unless your brief says a write is safe and reversible.
- Notifications, calendar data and anything personal: never print contents into your
  transcript or report. Print counts and which fields parsed.

## Proof (in your report)

1. `cargo test <your module>` output; the live test's summary output.
2. `cargo check` clean, with no new warnings.
3. `node_modules/.bin/tsc -p .` in `apps/edgebar` exits 0 (only if you touched TS).
4. `nix develop -c pre-commit run --all-files` in the worktree root passes.
5. One or more commits on your worktree branch (Conventional Commits, `feat(edgebar):
   …`, short bodies, each ending with `Co-Authored-By: Claude Opus 5.5
   <noreply@anthropic.com>`). Don't push. Report the branch name and SHAs.

## Report (under 40 lines)

The commands and events you added with their payloads, the macOS mechanism behind each
read and write and what you measured, anything in the contract you changed and why,
proof 1-5, and what the UI worker who builds on you must know.
