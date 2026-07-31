# Pins fnm's `default` alias — the Node version every new shell starts on.
#
# fnm keeps its state in $FNM_DIR: installed versions under `node-versions/`,
# and `aliases/default` as a symlink into one of them. Every shell that runs
# `fnm env` resolves to whatever that symlink points at, so the alias — not
# anything in this repo — is what decides your baseline `node --version`. It
# had been left on v20.19.5 since it was first set, which is why new shells
# kept "going back" to v20.
#
# Only the BASELINE is pinned here. `--use-on-cd` (wired up in
# modules/home/shell/tools.nix, where the `fnm env` hook lives) still honours
# a project's .nvmrc / .node-version, so repos that pin an older Node are
# unaffected. This is the fallback for everywhere that pins nothing.
#
# WHY AN ACTIVATION SCRIPT, and not a declarative file: the alias is mutable
# state fnm owns, pointing at version directories fnm downloads at runtime.
# home-manager cannot symlink it into place without hardcoding fnm's on-disk
# layout, which is an internal detail. Driving the CLI is the honest way to
# express "make this alias say v24" — so this converges the alias on every
# switch, and goes quiet once it already matches.
#
# The activation script deliberately does NOT install a missing version. It
# reports and moves on, because `fnm install` downloads ~50MB from
# nodejs.org, and a rebuild that silently blocks on the network — or fails
# when it is unavailable — is worse than a one-line prompt. Swap the `echo`
# for `run ${...}/bin/fnm install` if you would rather it self-heal.
#
# It uses a nixpkgs fnm rather than the Homebrew one on PATH
# (modules/system/darwin/homebrew.nix), so activation does not depend on
# Homebrew having been set up first. Both are 1.39.0, and either writes the
# same alias — FNM_DIR is the only state that matters, and it is shared.
_: {
  flake.modules.homeManager.apps-fnm =
    { pkgs, lib, ... }:
    let
      # The baseline Node version. Must be a version fnm has installed —
      # `fnm ls` to check, `fnm install v${nodeVersion}` to add it.
      nodeVersion = "24.16.0";
    in
    {
      home.activation.fnmDefaultNode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _fnm_dir="''${FNM_DIR:-$HOME/.local/share/fnm}"
        _want="$_fnm_dir/node-versions/v${nodeVersion}/installation"

        if [ ! -d "$_want" ]; then
          echo "apps-fnm: node v${nodeVersion} is not installed, leaving the default alias alone."
          echo "apps-fnm: run 'fnm install v${nodeVersion}' and re-switch to pin it."
        elif [ "$(readlink "$_fnm_dir/aliases/default" 2>/dev/null)" != "$_want" ]; then
          echo "apps-fnm: pointing the fnm default alias at v${nodeVersion}"
          run ${pkgs.fnm}/bin/fnm alias "v${nodeVersion}" default
        fi
      '';
    };
}
