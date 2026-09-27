# Claude Code — Anthropic's agentic CLI. https://claude.com/claude-code
#
# This module owns the CONFIG, not the binary. That split is deliberate and is
# the whole reason the module looks unusual:
#
#   * The binary is the NATIVE build, installed by upstream's own installer
#     into ~/.local/share/claude/versions/<v> with ~/.local/bin/claude pointing
#     at it. It self-updates daily (`auto-updates: enabled`), so pinning it in
#     nixpkgs would mean a package that is stale within a week and a second
#     copy on PATH that never wins — ~/.local/bin is prepended ahead of the nix
#     profile in shell/env.nix, which is why `pkgs.claude-code` in profile-code
#     was shadowed and doing nothing. Nix bootstraps the installer once and
#     then stays out of the version's way.
#
#   * The config IS declarative, and this host (brett-mac-mini) is the
#     reference the MacBook follows.
#
# The NixOS hosts use the same native build, which is why this file also has
# a NixOS half (nix-ld, below). Import both halves there.
#
# What is NOT managed here: everything under ~/.claude that Claude Code writes
# at runtime — sessions/, projects/, history.jsonl, .credentials.json, plugins/
# (marketplace clones), statsig/, todos/. Those are state, not config.
{ inputs, ... }:
{
  # The native Linux build is a generic glibc binary: its interpreter is
  # /lib64/ld-linux-x86-64.so.2, and it needs only libc, libm, libdl,
  # libpthread and librt. NixOS has no loader at that path, only a stub
  # that refuses to start anything, so without nix-ld the installer and
  # every self-update would download a binary that cannot run. nix-ld sets
  # NIX_LD for login sessions only, but it falls back to the same default
  # loader when NIX_LD is unset (nix-ld 2.0.6, src/main.rs), so the install
  # also works from home-manager's activation service.
  flake.modules.nixos.apps-claude-code = {
    programs.nix-ld.enable = true;
  };

  flake.modules.homeManager.apps-claude-code =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      configDir = "${config.home.homeDirectory}/.claude";
      nativeBin = "${config.home.homeDirectory}/.local/bin/claude";

      jq = lib.getExe pkgs.jq;

      # Both Macs import apps-worktrunk; the NixOS hosts do not. The status
      # line and the worktrunk plugin below both call `wt`.
      hasWorktrunk = pkgs.stdenv.isDarwin;

      # ─── status line without worktrunk ─────────────────────────────────
      # Only the last two cells of worktrunk's status line: the model name
      # and the context gauge, e.g. `Opus 5.5 (1M context)  🌕 44%`. Same
      # thresholds and format as format_context_gauge in worktrunk 0.71.0
      # (src/commands/statusline.rs). The moon wanes 🌕→🌑 as the context
      # fills and is picked from the percentage clamped to 0–100 and
      # truncated. The number shown is the unclamped value rounded half to
      # even, which is what Rust's {:.0} does and what printf does too.
      # Before the first reply there is no used_percentage, and worktrunk
      # then leaves the gauge out, so this does too.
      modelAndGauge = pkgs.writeShellScript "claude-code-statusline" ''
        export LC_NUMERIC=C

        {
          IFS= read -r model
          IFS= read -r moon
          IFS= read -r pct
        } < <(${jq} -r '
          (.model.display_name // ""),
          (.context_window.used_percentage as $p
            | if $p == null then "", ""
              else
                ($p | if . < 0 then 0 elif . > 100 then 100 else . end | floor) as $c
                | (if $c <= 51 then "🌕"
                   elif $c <= 77 then "🌔"
                   elif $c <= 90 then "🌓"
                   elif $c <= 97 then "🌒"
                   else "🌑" end),
                  $p
              end)
        ')

        cells=()
        [ -n "$model" ] && cells+=("$model")
        [ -n "$moon" ] && cells+=("$moon $(printf '%.0f' "$pct")%")

        # Two spaces between cells, as worktrunk joins them.
        out=""
        for cell in "''${cells[@]}"; do
          out+="''${out:+  }$cell"
        done
        printf '%s\n' "$out"
      '';

      # ─── settings.json ────────────────────────────────────────────────
      # Deliberately NOT `programs.claude-code.settings`. That option writes
      # the file as a mode-444 file inside a store directory and symlinks it
      # in, and Claude Code saves settings by writing a temp file BESIDE the
      # target and renaming over it. Against a store path that fails outright:
      #
      #   ✘ Failed to disable plugin: EACCES: permission denied, open
      #     '/nix/store/…-cc-settings/settings.json.tmp.97171.…'
      #
      # Verified against 2.1.220 with a real store symlink. Nothing is
      # corrupted — the read path is fine and the file survives — but every
      # write breaks: `/config` toggles, `/plugin` enable/disable/install,
      # marketplace registration, and user-scope "always allow". Same shape as
      # the herdr `onboarding = false` regression: a program that writes its
      # own config cannot be handed a read-only one.
      #
      # So instead the file stays a REAL, WRITABLE file and the keys below are
      # merged over it on every activation (see claudeCodeSettings). Claude
      # keeps full write access; nix is authoritative for what it declares.
      #
      # Consequence worth knowing: a key declared here reverts on the next
      # `nix-rebuild` if you change it through `/config` or `/plugin`. That is
      # the point — but if a key turns out to be one you flip per-machine or
      # per-mood, delete it here and it becomes machine-local again.
      settings = {
        env = {
          ENABLE_TOOL_SEARCH = "auto:0";

          # Effort. This is the ONLY way to get `max`, which is why it is
          # here and not just in `effortLevel` below: the two values go
          # through different validators in 2.1.245.
          #
          #   settings.effortLevel -> low | medium | high | xhigh
          #   CLAUDE_CODE_EFFORT_LEVEL -> low | medium | high | xhigh | max
          #                               (+ auto/unset to hand control back)
          #
          # `max` is session-scoped upstream — `/effort max` says "this
          # session only" and saves nothing, and a settings.json carrying
          # "max" is silently DROPPED, not clamped: the resolver returns
          # undefined and the model falls back to its own default. So the
          # `effortLevel = "max"` this replaces was doing nothing at all.
          #
          # Consequence, and the intent: with this set, `/effort` reports
          # "Not applied: CLAUDE_CODE_EFFORT_LEVEL=max overrides effort this
          # session" and changes nothing. Max everywhere, no per-session
          # drift. Drop this line to get `/effort` back — effortLevel below
          # then applies, capped at xhigh.
          # CLAUDE_CODE_EFFORT_LEVEL = "xhigh";
        };

        permissions = {
          # Read-only inspection, pre-approved. Anything that mutates state is
          # left to prompt.
          allow = [
            "Bash(cat:*)"
            "Bash(bat:*)"
            "Bash(fd:*)"
            "Bash(find:*)"
            "Bash(grep:*)"
            "Bash(ls:*)"
          ];
          deny = [
            "AskUserQuestion"
            "CronCreate"
            "CronDelete"
            "CronList"
          ];
          defaultMode = "auto";
        };

        # worktrunk's own status line — branch, worktree and merge state for
        # the checkout the session is in, then the model and context gauge.
        # Where there is no `wt` it would render an error line, so those
        # hosts get the model and gauge alone (modelAndGauge above).
        statusLine = {
          type = "command";
          command = if hasWorktrunk then "wt list statusline --format=claude-code" else "${modelAndGauge}";
        };

        # Written by `/plugin` rather than by hand, but shared on purpose:
        # these are the same three plugins on both Macs, and declaring them is
        # what makes a fresh machine come up with them already on. The
        # marketplace CLONE is still runtime state under ~/.claude/plugins —
        # Claude fetches it on first use from the source registered here.
        #
        # The worktrunk plugin only where `wt` is installed. Every one of its
        # hooks calls `wt`, and its WorktreeCreate hook replaces Claude's own
        # worktree creation with `wt switch --create`, so without `wt` the
        # `--worktree` flag would stop working.
        enabledPlugins = {
          "rust-analyzer-lsp@claude-plugins-official" = true;
          "typescript-lsp@claude-plugins-official" = true;
        }
        // lib.optionalAttrs hasWorktrunk {
          "worktrunk@worktrunk" = true;
        };
        extraKnownMarketplaces = lib.optionalAttrs hasWorktrunk {
          worktrunk.source = {
            source = "github";
            repo = "max-sixty/worktrunk";
          };
        };

        # `/config` toggles. Shared because they are preferences, not machine
        # facts — the MacBook should behave identically.
        # Fallback for anything that does not see the env var above; xhigh is
        # the ceiling this key accepts (see CLAUDE_CODE_EFFORT_LEVEL).
        effortLevel = "xhigh";
        tui = "fullscreen";
        agentPushNotifEnabled = true;
        skipAutoPermissionPrompt = true;
      };

      settingsJson = (pkgs.formats.json { }).generate "claude-code-settings.json" settings;

      # Merge, not overwrite. `.[0] * .[1]` is jq's recursive object merge with
      # the right-hand side winning, so keys Claude has written that are NOT
      # declared above (theme, onboarding flags, per-machine bits) survive
      # untouched. Arrays are replaced wholesale, which is what we want for
      # permissions.allow.
      #
      # Known limitation: DELETING a key here does not delete it from the live
      # file — merge has no concept of "no longer declared". Remove it by hand
      # once, on each machine.
      mergeSettings = pkgs.writeShellScript "claude-code-merge-settings" ''
        set -euo pipefail

        live="${configDir}/settings.json"
        mkdir -p "${configDir}"

        # A symlink here is a leftover from `programs.claude-code.settings`
        # (or from trying it). It points into the store and is unwritable, so
        # replace it with a real file rather than merging through it.
        if [ -L "$live" ]; then
            rm -f "$live"
        fi

        [ -s "$live" ] || printf '{}\n' >"$live"

        if ! ${jq} -e . "$live" >/dev/null 2>&1; then
            echo "claude-code: $live is not valid JSON — leaving it untouched." >&2
            exit 0
        fi

        tmp="$(mktemp "$live.XXXXXX")"
        ${jq} -s '.[0] * .[1]' "$live" ${settingsJson} >"$tmp"
        mv -f "$tmp" "$live"
        chmod 644 "$live"
      '';

      # ─── third-party skill collections ────────────────────────────────
      # mattpocock/skills lays its repo out as skills/<bucket>/<name>/SKILL.md,
      # where the bucket is a maturity tier (engineering, productivity, misc,
      # in-progress, …). Claude Code wants the leaf directories, flat.
      #
      # The bucket is DISCOVERED rather than written out, so a skill that gets
      # promoted from in-progress/ to engineering/ needs no edit here — only a
      # rev bump. Discovery also means a rev bump adds and removes skills on
      # its own, which is why the rev is pinned by hand in flake.nix.
      subdirs = dir: lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir);

      flattenBuckets =
        root:
        lib.concatMapAttrs (
          bucket: _: lib.mapAttrs (name: _: "${root}/${bucket}/${name}") (subdirs "${root}/${bucket}")
        ) (subdirs root);

      # Local skills last: `//` lets the right-hand side win, so a skill in
      # claude/skills always beats a third-party one of the same name.
      localSkills = lib.mapAttrs (name: _: ./claude/skills + "/${name}") (subdirs ./claude/skills);

      # Upstream's installer. Runs ONCE — the guard is the binary itself, and
      # after that Claude Code updates itself and nix never touches it again.
      # This is the one place in the repo that reaches the network during
      # activation; the alternative is an undeclared manual step on every new
      # machine, which is exactly what this repo exists to remove.
      #
      # https://claude.ai/install.sh 302s to
      # downloads.claude.ai/claude-code-releases/bootstrap.sh, which installs
      # under $HOME only and refuses to run under sudo.
      installNative = pkgs.writeShellScript "claude-code-install-native" ''
        set -euo pipefail

        if [ -e "${nativeBin}" ]; then
          exit 0
        fi

        # The installer finds its downloader on PATH ("Either curl or wget
        # is required"), and home-manager's activation PATH has neither, on
        # either platform. This step had never actually run until
        # brett-desktop: both Macs already had a native install, so the
        # guard above skipped it. zstd is optional; with it the installer
        # fetches the compressed binary.
        export PATH="${
          lib.makeBinPath [
            pkgs.curl
            pkgs.zstd
          ]
        }:$PATH"

        echo "claude-code: no native install at ${nativeBin}, bootstrapping…"
        curl -fsSL https://claude.ai/install.sh | ${pkgs.bash}/bin/bash -s stable
      '';
    in
    {
      programs.claude-code = {
        enable = true;

        # No nix-managed binary — see the header. `enable` here is only
        # switching on the config-file half of the module.
        package = null;

        # ~/.claude/CLAUDE.md — the global instruction file, prepended to
        # every session on every project.
        context = ./claude/CLAUDE.md;

        # ~/.claude/skills/. Either half of this is linked recursively, so
        # ~/.claude/skills stays a real writable directory with only the skill
        # folders symlinked into the store — `claude plugin init` can still
        # scaffold a new skill alongside them.
        #
        # The attrset form (rather than plain `skills = ./claude/skills`) is
        # what lets a third-party skill live next to the local ones: values
        # may be store paths, so a skill can come from a flake input instead
        # of from this repo. readDir keeps the local half behaving as before —
        # dropping a folder into claude/skills is still all it takes.
        #
        # This replaces the `npx skills add` install on the mac mini, which
        # unpacked into ~/.agents/skills and symlinked from ~/.claude/skills.
        # That tree is now redundant for Claude Code — delete it once, by
        # hand, on any machine that has it. Leave it alone if another agent
        # reads ~/.agents.
        skills = {
          # ASD-STE100 Simplified Technical English. Pinned in flake.lock;
          # `nix flake update simple-english` is the upgrade.
          simple-english = "${inputs.simple-english}/skills/simple-english";
        }
        // flattenBuckets "${inputs.mattpocock-skills}/skills"
        // localSkills;
      };

      # The installer puts the launcher in ~/.local/bin. The Macs have that on
      # PATH from shell/env.nix, which the NixOS hosts do not import, so
      # without this the native build would be installed but never found.
      home.sessionPath = lib.mkIf pkgs.stdenv.isLinux [ "$HOME/.local/bin" ];

      home.activation = {
        claudeCodeNative = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${installNative}
        '';

        # Ordering against home-manager's own linkGeneration (which also sits
        # after writeBoundary) is not pinned, so this may run before
        # hooks/notify.sh is linked. That is harmless: nothing reads
        # settings.json during activation, only the next `claude` does.
        claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${mergeSettings}
        '';
      };
    };
}
