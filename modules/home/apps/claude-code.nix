# Claude Code — Anthropic's agentic CLI. https://claude.com/claude-code
#
# This module owns the config, not the binary. The binary is upstream's native
# build, installed once by its own installer (into
# ~/.local/share/claude/versions, launcher ~/.local/bin/claude) and
# self-updating from then on. A nixpkgs copy would lag behind it, and
# ~/.local/bin is ahead of the nix profile on PATH anyway. NixOS hosts must
# also import the nixos half below (nix-ld).
#
# Not managed: the runtime state Claude Code writes under ~/.claude
# (sessions/, projects/, history.jsonl, .credentials.json, plugins/,
# statsig/, todos/).
{ inputs, ... }:
{
  # The native Linux build is a generic glibc binary (interpreter
  # /lib64/ld-linux-x86-64.so.2; needs only libc, libm, libdl, libpthread and
  # librt). NixOS has only a stub loader at that path, so without nix-ld the
  # installer and every self-update would fetch a binary that cannot run.
  # nix-ld sets NIX_LD for login sessions only, but falls back to the same
  # loader without it (nix-ld 2.0.6, src/main.rs), so the install also works
  # from home-manager's activation service.
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
      # The model and context-gauge cells of worktrunk's status line, e.g.
      # `Opus 5.5 (1M context)  🌕 44%`, matching format_context_gauge in
      # worktrunk's src/commands/statusline.rs: the moon comes from the
      # percentage clamped to 0–100 and truncated; the number is the unclamped
      # value rounded half to even (Rust's {:.0}, and printf's). Before the
      # first reply there is no used_percentage, so the gauge is left out.
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
      # Not `programs.claude-code.settings`: that symlinks in a read-only
      # store file, and Claude Code saves settings by writing a temp file
      # beside the target and renaming it over, so every write (`/config`,
      # `/plugin`, "always allow") fails with EACCES. Instead the file stays
      # real and writable, and these keys are merged over it on every
      # activation (see mergeSettings). A key declared here reverts on the
      # next rebuild if changed from inside Claude; delete it here to make it
      # machine-local.
      settings = {
        env = {
          ENABLE_TOOL_SEARCH = "auto:0";

          # Uncomment to pin effort for every session; `/effort` then reports
          # "Not applied" and changes nothing. This env var is the only way
          # to get `max`: settings.effortLevel accepts low | medium | high |
          # xhigh and silently drops anything else.
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

        # worktrunk's status line (branch, worktree and merge state, then
        # model and context gauge). Without `wt` it would render an error
        # line, so those hosts get modelAndGauge above.
        statusLine = {
          type = "command";
          command = if hasWorktrunk then "wt list statusline --format=claude-code" else "${modelAndGauge}";
        };

        # Declared so a fresh machine comes up with these plugins on. The
        # marketplace clone under ~/.claude/plugins stays runtime state,
        # fetched on first use from the source registered here.
        #
        # The worktrunk plugin only where `wt` exists: all its hooks call it,
        # and its WorktreeCreate hook replaces Claude's own worktree creation
        # with `wt switch --create`, so without `wt`, `--worktree` would break.
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

        # `/config` toggles: shared preferences, not machine facts.
        # The default effort; xhigh is the most this key accepts (see
        # CLAUDE_CODE_EFFORT_LEVEL above).
        effortLevel = "xhigh";
        tui = "fullscreen";
        agentPushNotifEnabled = true;
        skipAutoPermissionPrompt = true;

        # The self-updater's channel: latest | stable | rc (unset means
        # latest). Declared because the installer writes the channel it was
        # bootstrapped with; installNative passes `latest` to match.
        autoUpdatesChannel = "latest";
      };

      settingsJson = (pkgs.formats.json { }).generate "claude-code-settings.json" settings;

      # Merge, not overwrite: `.[0] * .[1]` is jq's recursive object merge,
      # right-hand side winning, so keys Claude wrote that are not declared
      # above (theme, onboarding flags) survive. Arrays are replaced wholesale,
      # as wanted for permissions.allow.
      #
      # Deleting a key here does not delete it from the live file; remove it
      # by hand on each machine.
      mergeSettings = pkgs.writeShellScript "claude-code-merge-settings" ''
        set -euo pipefail

        live="${configDir}/settings.json"
        mkdir -p "${configDir}"

        # A symlink here is a leftover from `programs.claude-code.settings`;
        # it points into the store, so replace it with a real file.
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
      # mattpocock/skills nests skills as skills/<bucket>/<name>/SKILL.md, the
      # bucket being a maturity tier (engineering, in-progress, …); Claude Code
      # wants the leaf directories, flat. Buckets are discovered, so a skill
      # moving between them needs no edit here, but a rev bump can add or
      # remove skills on its own, which is why flake.nix pins the rev by hand.
      subdirs = dir: lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir);

      flattenBuckets =
        root:
        lib.concatMapAttrs (
          bucket: _: lib.mapAttrs (name: _: "${root}/${bucket}/${name}") (subdirs "${root}/${bucket}")
        ) (subdirs root);

      # Local skills last: `//` lets the right-hand side win, so a skill in
      # claude/skills always beats a third-party one of the same name.
      localSkills = lib.mapAttrs (name: _: ./claude/skills + "/${name}") (subdirs ./claude/skills);

      # Upstream's installer. Runs once (the binary is the guard); after that
      # Claude Code updates itself. It reaches the network during activation,
      # which beats an undeclared manual step on every new machine.
      #
      # https://claude.ai/install.sh redirects to
      # downloads.claude.ai/claude-code-releases/bootstrap.sh, which installs
      # under $HOME only and refuses to run under sudo.
      installNative = pkgs.writeShellScript "claude-code-install-native" ''
        set -euo pipefail

        if [ -e "${nativeBin}" ]; then
          exit 0
        fi

        # The installer needs curl or wget on PATH, and home-manager's
        # activation PATH has neither. zstd is optional; with it the
        # installer fetches the compressed binary.
        export PATH="${
          lib.makeBinPath [
            pkgs.curl
            pkgs.zstd
          ]
        }:$PATH"

        echo "claude-code: no native install at ${nativeBin}, bootstrapping…"
        # `latest`, matching autoUpdatesChannel above.
        curl -fsSL https://claude.ai/install.sh | ${pkgs.bash}/bin/bash -s latest
      '';
    in
    {
      programs.claude-code = {
        enable = true;

        # No nix-managed binary (see the header); `enable` only switches on
        # the config half of the module.
        package = null;

        # ~/.claude/CLAUDE.md — the global instruction file, prepended to
        # every session on every project.
        context = ./claude/CLAUDE.md;

        # ~/.claude/skills/. Each skill is linked recursively, so the
        # directory and the skill folders stay real and writable (only the
        # files are store symlinks), and `claude plugin init` can still
        # scaffold into it. The attrset form lets skills come from flake
        # inputs; dropping a folder into claude/skills is still all a local
        # skill needs.
        skills = {
          # ASD-STE100 Simplified Technical English. Pinned in flake.lock;
          # `nix flake update simple-english` is the upgrade.
          simple-english = "${inputs.simple-english}/skills/simple-english";
        }
        // flattenBuckets "${inputs.mattpocock-skills}/skills"
        // localSkills;
      };

      # The installer puts the launcher in ~/.local/bin. The Macs get that on
      # PATH from shell/env.nix, which the NixOS hosts do not import.
      home.sessionPath = lib.mkIf pkgs.stdenv.isLinux [ "$HOME/.local/bin" ];

      home.activation = {
        claudeCodeNative = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${installNative}
        '';

        claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD ${mergeSettings}
        '';
      };
    };
}
