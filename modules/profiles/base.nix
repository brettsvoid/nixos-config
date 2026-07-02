# Always-on minimum: anything every host needs that isn't already pulled in by
# system/* + home/shell/* + home/apps/*. Currently a stub — real content
# accumulates as the migration progresses.
_: {
  flake.modules.homeManager.profile-base = { };
  flake.modules.nixos.profile-base = { };
}
