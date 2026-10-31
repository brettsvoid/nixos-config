# REA (Reverse Engineer Anything): an MCP server and skill for inspecting
# binaries, JavaScript/Electron apps, .NET assemblies and websites.
# https://github.com/morluto/rea
#
# Not the Claude Code plugin: its marketplace pins rea-agents@6.8.0, and that
# npm release has no .claude-plugin/plugin.json or plugin launcher, so
# `/plugin install rea@rea` cannot work yet. Instead activation installs the
# pinned package with pnpm, links its skill into ~/.claude/skills and
# registers the server through apps-claude-code. Switch to the plugin once a
# release ships its manifest (and remove the user-scope `rea` server then, as
# upstream warns against running both).
#
# Needs apps-fnm (Node >= 24.22.1, pnpm, PNPM_HOME) and apps-claude-code.
# Linux only for now: the Macs' pnpm is Homebrew's, with another PNPM_HOME.
# Native analysis also wants Ghidra, IDA, Hopper or Kuna; without one, static
# JavaScript/Electron analysis still works.
_: {
  flake.modules.homeManager.apps-rea =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      version = "6.8.0";

      pnpmHome = config.home.sessionVariables.PNPM_HOME;
      skillLink = "${config.home.homeDirectory}/.claude/skills/reverse-engineer-anything";
    in
    {
      local.claudeCode.mcpServers.rea = {
        type = "stdio";
        command = "${pnpmHome}/bin/rea";
        args = [ "mcp" ];
      };

      # The global install's directory name is a hash pnpm picks, so the
      # package is found by glob, not by a fixed path. pnpm skips frida's
      # build script (it only allows approved ones); frida is optional and
      # only used for live instrumentation.
      home.activation.reaInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PNPM_HOME=${lib.escapeShellArg pnpmHome}
        export PATH="$PNPM_HOME/bin:$PATH"

        _rea_pkg() {
          for p in "$PNPM_HOME"/global/*/*/node_modules/rea-agents; do
            [ -f "$p/package.json" ] && printf '%s\n' "$p" && return
          done
        }

        _have="$(_rea_pkg)"
        if [ -z "$_have" ] || [ "$(${lib.getExe pkgs.jq} -r .version "$_have/package.json")" != "${version}" ]; then
          echo "apps-rea: installing rea-agents@${version}"
          run ${lib.getExe pkgs.pnpm} add -g "rea-agents@${version}" \
            || echo "apps-rea: install failed (offline?); re-switch to retry."
          _have="$(_rea_pkg)"
        fi

        if [ -n "$_have" ] && [ "$(readlink "${skillLink}" 2>/dev/null)" != "$_have/skills/reverse-engineer-anything" ]; then
          run ln -sfn "$_have/skills/reverse-engineer-anything" "${skillLink}"
        fi
      '';
    };
}
