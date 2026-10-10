# Anything every host needs that system/*, home/shell/* and home/apps/* don't
# already provide. Empty for now.
_: {
  flake.modules.homeManager.profile-base = { };
  flake.modules.nixos.profile-base = { };
}
