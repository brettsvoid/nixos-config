# Node through fnm, and pnpm for packages, on every host that imports this.
#
# fnm keeps its state in $FNM_DIR: versions under node-versions/, and
# aliases/default as a symlink into one of them. That alias, not anything
# else in this repo, decides a new shell's `node --version`. A project's
# .nvmrc / .node-version still wins through `--use-on-cd`
# (modules/home/shell/tools.nix).
#
# Activation installs the pinned version if fnm lacks it, then points the
# default alias at it. Both are mutable state fnm owns, so activation drives
# `fnm` rather than symlinking. An offline switch says so and moves on.
#
# Uses nixpkgs' fnm in activation, so it does not depend on Homebrew. On the
# Macs, Homebrew's fnm and pnpm are the ones on PATH (darwin/homebrew.nix,
# PNPM_HOME in shell/env.nix); Linux gets both from nixpkgs here. Both fnms
# share $FNM_DIR.
#
# NixOS: fnm downloads nodejs.org's generic glibc builds, which run only
# through nix-ld. The nixos half of apps-claude-code enables it.
_: {
  flake.modules.homeManager.apps-fnm =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # The baseline Node version: what a new shell, and anything run
      # outside one (Claude Code plugin hooks), gets as `node`.
      nodeVersion = "24.22.1";

      fnmDir = "${config.xdg.dataHome}/fnm";
      isLinux = pkgs.stdenv.hostPlatform.isLinux;
    in
    {
      home = {
        # pnpm 12 is a standalone binary with its own runtime, so it adds no
        # second Node. Its content-addressed store links each package version
        # once on disk, across every project.
        packages = lib.optionals isLinux [
          pkgs.fnm
          pkgs.pnpm
        ];

        sessionVariables = lib.mkIf isLinux {
          PNPM_HOME = "${config.xdg.dataHome}/pnpm";
        };

        # pnpm 12 puts `pnpm add -g` binaries in $PNPM_HOME/bin and refuses
        # to install globally unless that is on PATH. The default alias puts
        # Node on PATH for processes no interactive shell started; in a shell,
        # `fnm env` prepends its own per-shell path, so a project's version
        # still wins.
        sessionPath = lib.mkIf isLinux [
          "${config.xdg.dataHome}/pnpm/bin"
          "${fnmDir}/aliases/default/bin"
        ];
      };

      home.activation.fnmDefaultNode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export FNM_DIR="''${FNM_DIR:-${fnmDir}}"
        _want="$FNM_DIR/node-versions/v${nodeVersion}/installation"

        if [ ! -d "$_want" ]; then
          echo "apps-fnm: installing node v${nodeVersion}"
          run ${pkgs.fnm}/bin/fnm install "v${nodeVersion}" \
            || echo "apps-fnm: install failed (offline?); re-switch to retry."
        fi

        if [ -d "$_want" ] && [ "$(readlink "$FNM_DIR/aliases/default" 2>/dev/null)" != "$_want" ]; then
          echo "apps-fnm: pointing the fnm default alias at v${nodeVersion}"
          run ${pkgs.fnm}/bin/fnm alias "v${nodeVersion}" default
        fi
      '';
    };
}
