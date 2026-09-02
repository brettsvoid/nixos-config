# Refactor & improvement plan

Audit date 2026-07-02. Seven parallel agents covered the Nix layer, edgebar (Tauri),
quickshell (QML), the edgebar↔quickshell parity spec, security/secrets, the
nvim/shell/terminal/sketchybar dotfiles, and docs/comments. Findings verified against
files on disk; several checked empirically (gitleaks run against synthetic secrets,
deadnix/statix via the devShell, quickshell source at the locked rev, live crates.io/npm
versions, live sshd state).

Companion doc: [bar-spec.md](bar-spec.md) — the normative shared spec for the two bars.

---

## Implementation status (2026-07-02 pass)

A first implementation pass landed the safe, verifiable subset. Verification used:
both hosts eval to derivations (`nix eval …system.build.toplevel.drvPath`), gitleaks
run against synthetic secrets, `cargo check` + `tsc --noEmit` for edgebar, headless
`nvim` loadfile for every touched Lua file, and the repo formatter (`nix fmt`).

**Done & verified**

- **Phase 0** — all of it. S-1..S-4, N-1, Q-1, Q-2, D-1..D-5. The gitleaks `condition
  = "AND"` split was empirically confirmed (synthetic 40-hex/32-char secrets now caught;
  full history still clean). The Phase-1 SSOT refactor produced **byte-identical** host
  derivations, proving it behaviour-preserving.
- **Phase 1** — `flake.lib` made mergeable (`modules/flake/lib.nix` declares the option),
  `flake.lib.theme` + `flake.lib.wallpaper` (`modules/flake/design.nix`); starship's
  25-hex inline palette, the terminal font/opacity/padding, hyprland's border/shadow
  colours, and the wallpaper filename across edgebar/wallpaper/ambxst now all read the
  shared lib. Dead inner `config` args dropped (ghostty/kitty/hyprland → L1).
- **Phase 2** — telescope removed and its consumers repointed to fzf-lua
  (obsidian picker, tailwind dep, `core/helpers.lua`, 4 ported keymaps); deleted
  telescope/nx/neo-tree/none-ls/diagnostics; ~200 lines of dead commented Lua stripped;
  lazygit broken config block + basics.lua duplicate removed; sketchybar `ip_address.sh`
  duplicate `--set` and the contradictory daemon comment fixed; aliases + base.nix
  comment fixes.
- **Phase 3** — edgebar README rewritten; README layout tree + `nix-rebuild` wording;
  bootstrap.sh + SECRETS.md pointers.
- **Phase 4** — pill-height fallback drift (E-3), dead opener plugin + `withGlobalTauri`
  removed (E-4), `hex_to_rgba` panic fixed (E-7). **Plus the async pass** (added once a
  running bar was available to test): `list_wallpapers`, `current_wallpaper`,
  `pick_wallpaper_file`, `set_scheme`, `metrics_sample` all converted to `async` +
  `spawn_blocking` off the main thread (E-1); `set_scheme` no longer holds the ThemeState
  lock across its subprocess; `query_current_wallpaper` extracted from the duplicate in
  `current_wallpaper`/`set_scheme` (E-6); the front-app observer rebuilt to a single
  debounced worker so rapid cmd-tab can't spawn racing threads (E-2). cargo check + clippy
  clean (0 new warnings), tsc clean.
- **Phase 5** — `Clock.qml` → `SystemClock` (Q-3), battery `PendingCharge` (Q-6), the
  Phase-0 bug fixes, **plus the parity groundwork**: geometry aligned to the spec
  (`barHeight 36→32`, `fontSize 14→13`, `exclusiveZone` deduped), and Q-4 magic-number
  routing — `Theme.qml` now holds `segmentPadding`/`barSpacing`/`iconSize`/`animDuration`/
  `fontSizeSmall`/`shadow*` and every segment reads them. Validated with `qmllint`
  (no syntax errors, tokens resolve) + msi eval; **runtime unverified — test on the msi.**
- **Phase 6** — stale geometry comments (N-9), `security.rtkit.enable` (L9).
- **SSOT: username + repoPath** — `flake.lib.username` + `flake.lib.repoDir`
  (`modules/flake/identity.nix`), consumed across the system modules (via the `flake`
  specialArg) and host files. Both hosts eval to **byte-identical** derivations →
  behaviour-preserving. This also makes the previously-unused `inherit (config) flake`
  plumbing purposeful (Nix audit L2).
- **edgebar E-5** — sysinfo 0.33→0.37.2, tauri 2.11.3→2.11.5, vite 6→8.1.3;
  `cargo check` + `pnpm build` clean. **E-8** — frame window level / collection bits
  named, `RECT_WHOLE_WINDOW` const.

**Deferred (with rationale) — do these with a runtime to test against**

- **Full quickshell visual parity** — the chrome rebuild (screen-edge frame, corner
  pills, fillets, surface-polarity flip) and the net-new segments (network/controls/
  notch/launcher/app-icons) are large feature work over NetworkManager/PipeWire/brightness
  APIs that `qmllint` can't resolve and I can't run off-Linux. Building them blind would be
  guesswork; do them iteratively on the msi (same test-loop that worked for edgebar).
  Tracked in [bar-spec.md §5](bar-spec.md).
- **quickshell Q-5** (self-sizing BarSegment) — a `childrenRect`/anchors layout change
  I can't runtime-test; the `+ segmentPadding * 2` magic number is deduped instead.
- **hm-defaults** — spans just two hosts, low drift; skipped.
- **nvim plugin-spec polish** (autopairs/comment `opts`, harpoon lazy, rust.lua) — needs a
  plugin runtime; low-impact.
- **sketchybar deeper dedup** (colors.sh↔rc, icons.sh, yabairc height) — dormant daemon
  under the active aerospace stack; kept per your call, low urgency.
- **N-7 / N-8** (media-player QML → files, host monitor block move) — structural, no
  functional change; safe anytime.

---

## Since the audit (2026-08-21) — yabai/skhd stack removed

The yabai/skhd half of the WM A/B is **deleted**, not deferred. Both hosts had been on
`wmStack = "aerospace"` since the AeroSpace move, so the yabai branch never evaluated:
`modules/system/darwin/window-manager.nix`, `modules/home/darwin/{yabai,skhd}.nix` and
their config trees (~530 lines) are gone, and the `wmStack` let-block collapsed into a
flat import list in both host files. Verified: both hosts still eval to a derivation.

Sketchybar is deliberately **kept** — the daemon stays disabled (edgebar replaced it),
but the config tree is the reference edgebar is being ported from. Its daemon plumbing is
not: `home.activation.reloadSketchybar` ran `sketchybar --reload` on every switch against
a daemon that isn't there, and dropping it takes `pkgs.sketchybar` out of both hosts'
closures (`sketchybar-app-font`, from `apps-fonts`, is now the only sketchybar-shaped
thing left in them).

Backlog items this voids or changes:

- **D-5 (F18)** — void. It asked whether `skhd/skhdrc:7` or `aerospace.toml.in:84` owns
  the F18 mode key; skhdrc is gone, so AeroSpace is the only claimant left.
- **N-9** — the yabai/skhd header half is void (files deleted); the
  `sketchybar.nix` ↔ `bar-geometry.nix` contradiction is fixed (both now say disabled).
  The geometry "60" vs 42 and innerGap/outerGap nits still stand.
- **Phase 2 "sketchybar/yabai"** — the `yabai_env.sh` and `skhdrc` half is void. The
  sketchybar-side findings (`icons.sh` dead ~60%, duplicate `ICON_DISK`, dead plugins)
  still stand but are lower priority now that the tree is reference material only.
- **"A/B pairs are not treated as dead code"** — still the rule, minus this pair.
- `terminal-notifier` (`homebrew.nix`) lost its only consumer with skhdrc. Kept anyway so
  the macOS notification authorisation both Macs already granted isn't thrown away.

---

## Since the audit (2026-09-01) — `~/.env_vars` reduced to the bws bootstrap token

`~/.env_vars` held four exports at audit time: `ANTHROPIC_API_KEY`, `BWS_ACCESS_TOKEN`,
`OPENAI_API_KEY`, `TAVILY_API_KEY`. Three are gone and only `BWS_ACCESS_TOKEN` remains
(0600, one line). `OPENAI_API_KEY` and `TAVILY_API_KEY` moved into Bitwarden Secrets
Manager. `ANTHROPIC_API_KEY` was deleted outright rather than migrated: it had already
been revoked upstream — `GET /v1/models` with it returns `401 authentication_error` and
the Console lists no keys at all — so nothing on this host had been authenticating with
it, and its presence could only ever have produced a confusing failure in tools that
branch on the variable existing rather than on it working.

No `_secrets_load_*` group or `_secrets_preexec` arm was added for the two migrated keys,
deliberately. Nothing on this machine reads either one: across `~/.claude.json`,
`~/.claude/settings*.json` and the repo's Nix/JSON/Lua/TOML, the only matches for
`openai`/`tavily` are the *detection rules* in `.gitleaks.toml`, and there is no
`~/.aider.conf.yml`. That puts them in the same state as `AWS_*_HOME_ASSISTANT` — held in
Bitwarden, reachable via `load-secrets`, with no trigger until a consumer exists.

Worth remembering when rotating any of these: `.zshenv` runs once per shell, so a value
removed from `~/.env_vars` survives in every already-running process until that process
restarts. Long-lived herdr panes inherit from the herdr server, which makes the stale
copy outlast the terminal window it appears in.

Backlog items this voids or changes:

- **Suggestion 4 (S/M4)** — narrowed, not void. The plaintext-secret surface is down from
  four exports to one, but that one is now the bootstrap for all the others: with
  `OPENAI_API_KEY` and `TAVILY_API_KEY` in Bitwarden, reading `~/.env_vars` yields the
  token that fetches them. Phase G's scope shrank to a single value while the payoff grew.
  Any replacement must preserve the current ordering — `.zshenv` sources `~/.env_vars`
  before `~/.config/zsh/local.zsh`, and the bws block is guarded on `BWS_ACCESS_TOKEN`
  being set at that moment, so a lazier source installs no `preexec` hook and silently
  loads no secret at all.

---

The rest of this document is the original findings, kept as the backlog.

IDs: **S**ecurity, **B** bar/parity, **N**ix, **E**dgebar, **Q**uickshell, **D**otfiles,
**C**omments/docs. Severity is the audit's own [HIGH]/[MEDIUM]/[LOW].

---

## What's already good

Worth stating up front, because most of this repo is in good shape and the plan should
not churn it:

- The dendritic layering is clean, and `flake.lib.barGeometry` (single-sourced geometry
  rendered into aerospace/edgebar/sketchybar) is exactly the right pattern — the plan
  mostly proposes *more* of it (`flake.lib.{theme,username,repoPath,defaultWallpaper}`).
- No deprecated home-manager/nix-darwin options; modern idioms throughout
  (`programs.git.settings`, `initContent`, `hardware.graphics`, early `withRuby=false`).
- Comments in the Nix modules, edgebar Rust/TS, and edgebar shell scripts are model
  "why" comments — do **not** touch them. The comment noise is isolated to the
  kickstart-derived Lua and vendored sketchybar/yabai scripts.
- No committed secrets, clean git history, live sshd hardened, agenix architecture sound
  (just not yet carrying load).
- edgebar's `main.ts` and `styles.css` already have disciplined token scales; most hot
  paths are genuinely event-driven.

A/B pairs are **not** treated as dead code anywhere in this plan: yabai/skhd↔aerospace,
sketchybar↔edgebar, tmux↔herdr, ghostty↔kitty, ambxst↔custom-shell, telescope↔fzf-lua.
Items touching them say "confirm before removing".

---

## Phase 0 — Security & correctness (do first; low effort, high value)

These are small, verified, and either a security gap or a user-visible bug.

| ID | Where | Fix |
|---|---|---|
| **S-1** [HIGH] | `.gitleaks.toml:17-37` | Allowlist has `regexes` + `paths` but no `condition = "AND"` — gitleaks defaults to OR, so the `[0-9a-f]{40}` / `(?i)\b[a-z0-9]{32}\b` regexes suppress those secret shapes **repo-wide**, not just in lock files. Empirically confirmed a 40-hex token and 32-char key in a `.nix` file are hidden. Add `condition = "AND"`. |
| **S-2** [MED] | `.gitleaks.toml:40-49` | Delete the `\.github/workflows/.*\.yml$` path allowlist — it hides pasted PATs; `${{ secrets.* }}` doesn't trip gitleaks anyway. |
| **S-3** [MED] | `.github/workflows/secret-scan.yml` | Job named "full history" but gitleaks-action only scans the pushed range on `push`. Add `on: schedule: cron` (+ `workflow_dispatch`) so full scans actually run. |
| **S-4** [MED] | `modules/system/nixos/openssh.nix:14-17` | Add `settings.KbdInteractiveAuthentication = false;` — NixOS default is `true` with `UsePAM yes`, so password-over-keyboard-interactive is still open (the Darwin module already closes this). |
| **N-1** [HIGH] | `modules/home/shell/aliases.nix:11-15` | `nix-rebuild` emits `nh os switch` on Linux, but nh isn't installed on the msi host (it never imports `apps-nh`). Add `apps-nh` to the msi home imports (module is platform-neutral) or gate the alias. |
| **Q-1** [HIGH] | `quickshell/bar/Workspaces.qml:32-40` | `Hyprland.workspaces.count` / `.get(i)` / `.toplevels.count` don't exist (verified against quickshell source — the model exposes `.values`). `hasWindows` is always false, so occupied dots never render, and the loop registers no NOTIFY dep so it wouldn't react. Rewrite using `Hyprland.workspaces.values.find(...)` + `.toplevels.values.length`. |
| **Q-2** [HIGH] | `quickshell/theme/Theme.qml:9` | Hardcoded `/home/brett/.cache/...` breaks on any other user/host. Use `Quickshell.env("HOME") + "/.cache/qs-theme/colors.json"`. |
| **D-1** [HIGH] | `nvim/.../plugins/neo-tree.lua:5` | `enable = false` is not a lazy.nvim key (it's `enabled`); neo-tree is still active. Rename or delete the file. |
| **D-2** [HIGH] | `nvim/.../plugins/noice.lua:49` | `config = function(opts)` — lazy passes `(plugin, opts)`, so the opts block is ignored. Use `function(_, opts)`. |
| **D-3** [HIGH] | `nvim/.../plugins/none-ls.lua` | `vim.list_extend(..., { sources = {...} })` extends with a map → zero sources registered; also duplicates eslint/gofumpt handled elsewhere. Delete the file. |
| **D-4** [HIGH] | `keymaps.lua:42-44` vs `conform.lua:44-52`; `lint.lua:58-60` vs `trouble.lua:21-25` | `<leader>f` and `<leader>cl` are each double-bound; load order silently clobbers the richer handler. Resolve each to one owner. |

**Decision needed — D-5 (F18):** `skhd/skhdrc:7` and `aerospace.toml.in:84` both key their
mode systems on F18 "remapped from capslock by Karabiner", but `karabiner.json` has **no
F18 mapping** (verified). Either the modes' entry key is dead, or another tool emits F18.
Confirm on the live machine (`skhd -o`) before touching — this gates both WM mode systems.

---

## Phase 1 — Single sources of truth (the highest-leverage refactor)

Same move repeated: lift a scattered literal into `flake.lib`, following the existing
`bar-geometry.nix` pattern. Each is mechanical and testable with `nix flake check`.

- **N-2** `flake.lib.username` — "brett" is hardcoded ~12× (`common.nix`, `users.nix`,
  `homebrew.nix` activation, `authorized-keys.nix`, both hosts). [MED]
- **N-3** `flake.lib.repoPath` — `~/nixos-config` hardcoded 8× (`nh.nix`, `aliases.nix`,
  `nvim/default.nix`, skhd/sketchybar/karabiner/yabai, `custom-shell.nix`, `bootstrap.sh`). [MED]
- **N-4** `flake.lib.defaultWallpaper` — `chisato_petals_of_silence_4k.jpg` hardcoded in
  `wallpaper.nix`, `edgebar.nix` (comment literally says "kept in sync"), `ambxst.nix`. [HIGH]
- **N-5** `flake.lib.theme` — a palette + flavor attrset. Today the stack is split:
  **Mocha** (kitty/ghostty/bat/starship — starship inlines the full 27-hex palette at
  `starship.nix:57-84`) vs **Macchiato** (nvim/tmux/indent-blankline/sketchybar accents),
  and sketchybar even mixes macchiato accents on a mocha base. Pick one flavor (or model
  the split explicitly), render `colors.sh` from it, delete the inline starship palette.
  Also folds in the font name, duplicated 5× ("FiraCode Nerd Font[ Mono]" across
  ghostty/kitty/sketchybar/Theme.qml/styles.css). [HIGH]
- **N-6** `hm-defaults` module (or `flake.lib.mkHome`) — both hosts repeat the
  `useGlobalPkgs/useUserPackages/backupFileExtension/extraSpecialArgs` block and
  `home.username`. [MED]
- **B (bar tokens)** `flake.lib.barTokens` + shared matugen template — see
  [bar-spec.md §4](bar-spec.md). This is the parity foundation; do it before any
  quickshell chrome work. [HIGH]

Terminal-appearance duplication (**N/D**): `ghostty.nix:16-24` and `kitty.nix:10-19` hold
near-identical `{ font, size 13, opacity 0.95, padding 8 }` blocks that have already
drifted (scrollback 10000 vs 4000). Hoist the shared attrset — the A/B stays valid, the
constants stop diverging.

---

## Phase 2 — Dead code & comment cleanup (delete-only, low risk)

Genuinely unreferenced, verified. Nothing here is an A/B pair.

**nvim** — delete `core/diagnostics.lua` (100% commented, still `require`d by
`core/init.lua:2`) and `plugins/nx.lua` (returns `{}`); strip ~70 lines of commented
nvim-cmp experiments from `completion.lua`; the telescope "what is telescope" tutorial
(`telescope.lua:104-122`), the commented linter table (`lint.lua:16-46`), the disabled
mini.statusline block (`mini.lua:5-36`). Stale which-key group `<leader>a` "[A]vante"
(no such plugin). **Confirm before removing:** the `enabled = false` carcasses
(auto-session, copilot, luasnip, go) and the telescope↔fzf-lua overlap — those are
deliberate toggles.

**sketchybar/yabai** (daemon replaced by edgebar, but config still applied — confirm the
retirement status first; **two comments contradict each other** on whether the daemon is
enabled: `bar-geometry.nix:14-15` says disabled, `sketchybar.nix:15-18` says enabled —
fix whichever is stale): `icons.sh` is ~60% dead (with `ICON_DISK` defined twice with
*different* glyphs); dead plugins `calendar.sh`/`clock.sh`/`timer.py`/`tyto_current_task.py`;
`ip_address.sh:23-28` duplicate `--set`; `yabai_env.sh` identical if/else branches +
two unreferenced vars + a slow `system_profiler` probe that decides nothing; ~70 of
`skhdrc`'s 137 lines are commented examples.

**Stutter / AI-slop comments** — delete-list (verified restate-the-code or stale tutorial
prose): `aliases.nix:23-25` (the ls contradiction — see D below), `base.nix:6,10` (doubled
"reserved for future"), the kickstart per-line narration in `telescope.lua`/`options.lua`/
`keymaps.lua`/`conform.lua`/`lint.lua`/`lazy.lua`, `debug.lua:53-57,87-89` ("please don't
ask me how to install them :)"), the tripled `$NAME is passed from sketchybar` header in
`date.sh`/`time.sh`/`clock.sh`, and several stale nvim comments that name the wrong
formatter (`nil_ls.lua:4`, `pyright.lua:3`).

**D (aliases contradiction)** [HIGH] `aliases.nix:23-26` — comment says "ls/grep/find/ps
are deliberately NOT aliased — they'd break scripts", directly above `ls = "eza"` (and
`df=duf`, `du=dust` have the same property). Comment and code disagree; pick one. Also
`gd`/`gp` duplicate the oh-my-zsh git plugin and `gl` collides with its `git pull`.

---

## Phase 3 — Docs (small, human)

- **C-1** [HIGH] `apps/edgebar/README.md` is the untouched `create-tauri-app` template
  ("Tauri + Vanilla TS"). Replace with ~6 real lines: what it is, the two-window
  click-through trick (point at `lib.rs:1-13`), `pnpm tauri dev`, where config/palette
  come from (Nix-rendered), that `edgebar.nix` owns deployment.
- **C-2** [HIGH] `README.md:18-30` layout tree omits `apps/` — the most active part of
  the repo. Add the `apps/edgebar/` line.
- **C-3** [LOW] `README.md:35` `nix-rebuild` runs `nh … switch` (diff + activate), not
  the stock rebuilders — reword. `SECRETS.md:95` says `rebuild`, alias is `nix-rebuild`.
- **C-4** [MED] `bootstrap.sh:25` "See modules/system/checks.nix" points at a file that
  doesn't exist here (it means nix-darwin's). Reword.

Do **not** add boilerplate headers — the Nix modules are already uniformly documented.

---

## Phase 4 — edgebar (Tauri)

Correctness/perf, then quality. Full detail from the edgebar agent; highlights:

- **E-1** [HIGH] Several sync Tauri commands do blocking subprocess/FS work on the main
  thread, violating the file's own rule (`lib.rs:650`): `list_wallpapers`/`wallpaper_thumb`
  (`sips` per image), `current_wallpaper`, `set_scheme` (blocks *while holding the
  ThemeState lock*), `pick_wallpaper_file` (freezes the bar until the Finder dialog
  closes), `metrics_sample` (`Disks::new_with_refreshed_list()` every 2s). Convert to
  `async fn` + `spawn_blocking`, matching the network/battery/workspaces commands that
  already do it right. `loadThemeView` awaits three of these right as the open-spring
  runs, so this directly stutters the animation.
- **E-2** [MED] `FrontAppObserver::app_activated` spawns a fresh thread running 4 serial
  `aerospace` subprocesses per activation; rapid cmd-tabbing races out-of-order emits.
  Reuse the network observer's channel + 400ms burst-collapse pattern.
- **E-3** [MED] Pill-height fallback drift: `config.default.json` 32 vs `main.ts FALLBACK`
  30 vs `styles.css --pill-h` 30px (windowHeight 64 is quadruplicated). Align them.
- **E-4** [MED] Dead `tauri-plugin-opener` — registered + capability-granted + JS dep, but
  zero frontend references (`open -a` goes through the Rust launcher). Remove plugin + JS
  dep + capability. Also drop unused `withGlobalTauri`.
- **E-5** [MED] Deps: `sysinfo` 0.33→0.39 (relevant — `Disks` rebuilt per sample),
  `vite` 6→8 (v6 out of support), `cargo update` for tauri 2.11.3→2.11.5.
- **E-6** [MED] Extraction: `openControls`/`openLauncher` are line-for-line identical
  (→ `makeDropdown`); `current_wallpaper` body duplicated inside `set_scheme`; two
  copy-pasted socket-listener loops; `$HOME/.config|.cache` plumbing repeated ~6× (→
  `config_dir()`/`cache_dir()` or the `dirs` crate); colours enumerated by hand in both
  `resolve_colors` and `applyColors` (serialize as a map so adding a role is one edit).
- **E-7** [LOW] `hex_to_rgba` byte-slices → panics on a multibyte char in hand-edited
  config; hand-rolled `base64_encode` → use the `base64` crate; `lock().unwrap()`
  everywhere → `parking_lot::Mutex` removes the poison footgun. Predictable
  `/tmp/edgebar-thumb-*.png` never cleaned up → write under `~/.cache/edgebar/`.
- **E-8** [LOW] Magic values that dodge the file's own token discipline: battery/VPN
  accent hexes triplicated (Rust defaults + config JSON + CSS — single-source in the
  palette), `--warn` exists only in CSS so re-theming can't reach it, NSWindow collection
  bits duplicated (use `objc2-app-kit` named consts), window level `6`, the `settleDelay
  = 600` timing hack (use the animation's `.finished` promise).

---

## Phase 5 — quickshell (QML) toward parity

Foundation first (Phase 1 `barTokens`), then the [bar-spec §5 checklist](bar-spec.md).
Beyond Q-1/Q-2 (Phase 0):

- **Q-3** [MED] `Clock.qml` polls a 1s Timer for a minutes-only display and assigns
  imperatively — replace with `SystemClock { precision: Minutes }` + declarative binding.
- **Q-4** [MED] Magic numbers bypass `Theme.qml` (which exists precisely as the token
  store): `spacing 4/6/8`, shadow `#000000/0.5/1.0`, icon `pixelSize 16`, separator
  `1×16`, pill sizes `24/8`, `radius 4`, anim `duration 150`, `fontSize-1`. Route through
  Theme (and the shared `barTokens`).
- **Q-5** [MED] `BarSegment` — the `implicitWidth: child.implicitWidth + 24` +
  `anchors.centerIn` boilerplate is repeated at all three call sites; make the segment
  self-sizing so call sites shrink to `BarSegment { Workspaces { ... } }`.
- **Q-6** [LOW] `import Quickshell.Hyprland._Ipc` is a private module — use the public
  `Quickshell.Hyprland`. Battery `charging` misses `PendingCharge`/`FullyCharged` enum
  states (100% plugged shows the discharge icon). Dead default-margins block and
  ineffective `mask`/`Layout.alignment` lines.

---

## Phase 6 — Nix polish (lower priority)

- **N-7** [MED] `media-player.nix` inlines ~520 lines of QML as Nix strings using only
  two path interpolations — move to real files with `pkgs.replaceVars` (as `aerospace.nix`
  does); editable and syntax-highlighted.
- **N-8** [MED] `hyprland.nix:93-97` hardcodes the MSI's monitor layout inside the
  *reusable* `desktop-hyprland` module — move it next to the host's workspace bindings in
  `brett-msi-laptop.nix`, matching where the rest of the host-specific split lives.
- **N-9** [MED] Stale geometry comments: `window-manager-aerospace.nix:12` says "60"
  (actual 42), `aerospace.toml.in:46` says "innerGap" (code uses `outerGap`). Also the
  yabai/skhd headers (`yabai.nix:4-7`, `skhd.nix:4`) claim brew owns the daemons, but
  `window-manager.nix` enables the nix-darwin services — misleading during the A/B.
- **N-10** [MED] `bootstrap.sh:54` runs unpinned `nix-darwin/master` as root — pin to the
  locked rev or activate the repo's own `darwinConfigurations`. `screencapture.location`
  (`defaults.nix:29`) points at `~/Pictures/Screenshots`, which nothing creates.
- **N-11** [LOW] deadnix/statix nits: dead `config` args (ghostty/kitty/hyprland),
  unused `inherit (config) flake` specialArg, `lib.hm.dag` vs `config.lib.dag`
  inconsistency, conda prefix hardcoded 3× in `functions.nix` while `env.nix` already
  exports `CONDA_BASE`, `security.rtkit.enable` missing alongside PipeWire.
- **N-12** [LOW] `nix flake update` is due (inputs ~8 weeks old); respected pins (ambxst
  NVIDIA-stutter, herdr tag) verified and must stay.

---

## Suggestions you may have missed

General improvements beyond the brief:

1. **A `nix flake check` "no-drift" test.** The whole Phase 1 SSOT effort is only durable
   if drift is caught. Add a check that asserts the bar `Colors` struct keys == matugen
   template keys == spec roles, and (cheap) that the pill-height/window-height constants
   agree across the JSON/TS/CSS. Turns "kept in sync" comments into enforced invariants.

2. **The `enabled`/`enable` and `config(opts)` bugs suggest no nvim smoke test.** Four
   silent nvim misconfigs got this far because nothing loads the config headlessly. A
   `nix flake check` app that runs `nvim --headless "+lua vim.health or checkhealth"` (or
   at least `+q`) on the built config would catch spec-shape errors and broken plugin
   keys before a rebuild.

3. **Bring edgebar into `nix flake check`.** It's the most active code in the repo but has
   no CI. `cargo clippy -- -D warnings` + `cargo fmt --check` + `tsc --noEmit` +
   `eslint`/`biome` would catch the class of issues this audit found by hand (unused
   plugin, dead imports, the `hex_to_rgba` panic). Consider a `treefmt` covering Rust/TS
   too, not just nixfmt.

4. **The agenix architecture is documented but load-bearing on nothing** (S/M4). Every
   `nix flake update` needs GitHub SSH auth for the `secrets` input, while the real
   `BWS_ACCESS_TOKEN` sits plaintext (0600) in `~/.env_vars`, readable by any process
   running as you. Either finish the "Phase G" migration (move that one token into agenix
   or the macOS Keychain) or note the gap explicitly — right now the safety story reads as
   complete but isn't wired. **Narrowed 2026-09-01** (see "Since the audit (2026-09-01)"):
   `~/.env_vars` is down to this one token, so the migration is smaller and the gap is
   sharper — it is now the single on-disk credential that unlocks every other secret.

5. **`sysinfo` is heavy for what edgebar uses it for** (cpu/mem/disk in the notch). If
   the metrics stay simple, a couple of `sysctl`/`host_statistics` calls would drop a
   large dependency; if they grow, the 0.39 bump (E-5) is the move. Worth a deliberate
   call rather than drift.

6. **known_hosts pinning for your own fleet** (S/L2). The host public keys already exist
   as agenix recipients — declaring them via `programs.ssh.knownHosts` removes the TOFU
   MITM window between your own machines, which matters as the fleet grows (Phases D–F).

7. **A `CONTRIBUTING`-style "conventions" note** (or a short section in README) capturing
   the rules this repo already follows implicitly — dendritic module shape, "why"-only
   comments, `flake.lib.*` for shared constants, A/B toggle pattern. It's the cheapest way
   to keep future-you (and agents) from reintroducing the drift this audit just catalogued.

---

## Suggested order

1. **Phase 0** — security + the verified bugs. Small, independent, high value.
2. **Phase 1** — SSOT lifts, incl. `barTokens`. Unblocks parity and kills most drift.
3. **Phase 2 + 3** — delete dead code, fix comments, docs. Low risk, shrinks surface.
4. **Phase 4** — edgebar perf/quality (the async conversions are the win).
5. **Phase 5** — quickshell toward parity, against [bar-spec.md](bar-spec.md).
6. **Phase 6** — remaining Nix polish.

Decisions to confirm before touching: **D-5** (F18 producer), the sketchybar retirement
status (two contradictory comments), and the "confirm before removing" A/B carcasses in
Phase 2.
