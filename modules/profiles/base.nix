# Always-on minimum: anything every host needs that isn't already pulled in by
# system/* + home/shell/* + home/apps/*. Currently a stub — real content
# accumulates as the migration progresses.
_: {
  flake.modules.homeManager.profile-base = {
    # Reserved for future shared baseline configuration.
  };

  flake.modules.nixos.profile-base = {
    # Reserved for future shared baseline configuration.
  };
}
