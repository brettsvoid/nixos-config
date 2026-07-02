# Brett's Darwin user account. Using known UID/GID from `id -u brett` /
# `id -g brett` so nix-darwin doesn't try to recreate the user it didn't
# originally own (would fail on existing systems).
_: {
  flake.modules.darwin.users =
    { pkgs, flake, ... }:
    {
      users.knownUsers = [ flake.lib.username ];
      users.users.${flake.lib.username} = {
        uid = 501;
        gid = 20;
        home = "/Users/brett";
        shell = pkgs.zsh;
      };
    };
}
