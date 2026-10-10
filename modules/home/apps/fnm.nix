# Pins fnm's `default` alias: the Node version every new shell starts on.
#
# fnm keeps its state in $FNM_DIR: versions under node-versions/, and
# aliases/default as a symlink into one of them. That alias, not anything
# else in this repo, decides a new shell's `node --version`. A project's
# .nvmrc / .node-version still wins through `--use-on-cd`
# (modules/home/shell/tools.nix).
#
# The alias is mutable state fnm owns, so activation drives `fnm alias` rather
# than symlinking it into place. It does not install a missing version, so a
# switch never blocks on a download from nodejs.org; it says so and moves on.
#
# Uses nixpkgs' fnm rather than the Homebrew one on PATH, so activation does
# not depend on Homebrew. Both share $FNM_DIR.
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
