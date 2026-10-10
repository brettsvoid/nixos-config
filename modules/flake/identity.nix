# User and repo identity, shared so a rename is one edit. System modules read
# these via the `flake` specialArg (hosts pass `inherit (config) flake`); host
# files and home modules via `config.flake.lib`.
_: {
  flake.lib.username = "brett";

  # Clone location of this repo, relative to $HOME. Used by the `edit` alias,
  # nh, and the configs that link back into the checkout (nvim, sketchybar,
  # the custom shell, the window dissolve).
  flake.lib.repoDir = "nixos-config";
}
