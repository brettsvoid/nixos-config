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
# What is NOT managed here: everything under ~/.claude that Claude Code writes
# at runtime — sessions/, projects/, history.jsonl, .credentials.json, plugins/
# (marketplace clones), statsig/, todos/. Those are state, not config.
{ inputs, ... }:
{
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
        env.ENABLE_TOOL_SEARCH = "auto:0";

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
            "EnterPlanMode"
            "ExitPlanMode"
            "AskUserQuestion"
            "CronCreate"
            "CronDelete"
            "CronList"
          ];
          defaultMode = "auto";
        };

        # worktrunk's own status line — branch, worktree and merge state for
        # the checkout the session is in. Both Macs import apps-worktrunk, so
        # `wt` resolves on either; this would render an error line on a host
        # that did not.
        statusLine = {
          type = "command";
          command = "wt list statusline --format=claude-code";
        };

        # Written by `/plugin` rather than by hand, but shared on purpose:
        # these are the same three plugins on both Macs, and declaring them is
        # what makes a fresh machine come up with them already on. The
        # marketplace CLONE is still runtime state under ~/.claude/plugins —
        # Claude fetches it on first use from the source registered here.
        enabledPlugins = {
          "rust-analyzer-lsp@claude-plugins-official" = true;
          "typescript-lsp@claude-plugins-official" = true;
          "worktrunk@worktrunk" = true;
        };
        extraKnownMarketplaces.worktrunk.source = {
          source = "github";
          repo = "max-sixty/worktrunk";
        };

        # `/config` toggles. Shared because they are preferences, not machine
        # facts — the MacBook should behave identically.
        effortLevel = "high";
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

        [ -s "$live" ] || printf '{}\n' > "$live"

        if ! ${jq} -e . "$live" > /dev/null 2>&1; then
          echo "claude-code: $live is not valid JSON — leaving it untouched." >&2
          exit 0
        fi

        tmp="$(mktemp "$live.XXXXXX")"
        ${jq} -s '.[0] * .[1]' "$live" ${settingsJson} > "$tmp"
        mv -f "$tmp" "$live"
        chmod 644 "$live"
      '';

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

        echo "claude-code: no native install at ${nativeBin}, bootstrapping…"
        ${lib.getExe pkgs.curl} -fsSL https://claude.ai/install.sh \
          | ${pkgs.bash}/bin/bash -s stable
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
        skills =
          lib.mapAttrs (name: _: ./claude/skills + "/${name}") (
            lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./claude/skills)
          )
          // {
            # ASD-STE100 Simplified Technical English. Pinned in flake.lock;
            # `nix flake update simple-english` is the upgrade.
            simple-english = "${inputs.simple-english}/skills/simple-english";
          };
      };

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
