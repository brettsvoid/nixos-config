# Update checker

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

A sign in the shell that the flake's inputs are behind upstream, so it is time to
update. ambxst checks the distro's package manager
(`modules/services/UpdateService.qml`; ideas only). On NixOS "behind" means a flake
input.

What exists (checked):

- `nix-update-lagged` (`modules/home/apps/nh/`) moves nixpkgs, home-manager and
  nix-darwin to what their branch pointed at 3 days ago, from GitHub's push history
  (the activity API), and writes `flake.lock` only. Without a token GitHub allows 60
  API requests an hour per IP address. The script uses `gh auth token` when it can;
  gh has a stored login on the desktop (whether it is still valid is unchecked).
- `flake.lock` has 23 direct inputs; seven are pinned to a revision or a tag. nixpkgs
  was locked on 24 September. The running shell has no `NH_FLAKE`, which the script
  needs.

## Proposed choices

1. **What counts as behind.** **What `nix-update-lagged` would move.** It gets a
   `--check` flag that prints the moves and writes nothing, and the shell runs it with
   `NH_FLAKE=~/nixos-config`. Alternatives: every input that follows a branch, through
   `git ls-remote` (one request each, `secrets` left out as it is over SSH), compared
   with the tip, so nixpkgs would show behind most days; or no requests at all, only
   the lock's age once nixpkgs is older than N days. Reason: it matches how this repo
   updates, and keeps the 3-day lag.
2. **Requests and how often.** **One check a day, about five HTTPS requests to
   api.github.com.** nixpkgs takes one activity page. home-manager and nix-darwin take
   one request each for the default branch (`flake.nix` names none), then one page
   each. Further pages come only when 100 pushes do not reach back 3 days (how often
   is unchecked). No request is made when every input's locked date in `flake.lock`
   is newer than the cutoff, as the script would not move it. The last check's time is
   kept in the shell's state, so a restart does not check again. A failed check
   (offline, rate limit) tries again an hour later, at most three times a day.
   Alternative: every 6 hours. Settings: `updates.check` (true) and `updates.inputs`
   (`["nixpkgs", "home-manager", "nix-darwin"]`), on the Session page.
3. **Where it shows.** **A bar icon, shown only while an input is behind, with a
   tooltip of which and since when.** A click opens a terminal (`launcher.terminal`)
   in the repo running `nix-update-lagged` on those inputs. That writes `flake.lock`
   only; the rebuild and the commit stay yours. A launcher action (`>`), "Check for
   updates", checks at once. Setting: `bar.showUpdates` (true), on the Bar page.
   Alternative: one notification per new result, and no bar icon.
4. **Cost.** One process (bash, curl and jq) a day. The daily timer waits while game
   mode is on and runs after it ends. A FileView watches `flake.lock`: when it changes,
   the icon clears and the no-request check runs again.

## Acceptance criteria

- [ ] `nix-update-lagged --check` prints what a run would move and leaves `flake.lock`
      as it was.
- [ ] With nixpkgs locked more than 3 days behind, the icon shows within a day, and
      the click runs the update in a terminal.
- [ ] After the update the icon goes, and no request is made until the lock is older
      than the cutoff again. A restart does not check again the same day.
- [ ] It costs nothing in game mode.

## Blocked by

- None
