# User / repo identity, shared so a rename is one edit. System modules read these
# via the `flake` specialArg (hosts pass `inherit (config) flake`); host files and
# home modules via `config.flake.lib`.
_: {
  flake.lib.username = "brett";

  # Clone location of this repo, relative to $HOME. Used by the rebuild aliases,
  # nh, and the WM/editor configs that point at the flake.
  flake.lib.repoDir = "nixos-config";
}
