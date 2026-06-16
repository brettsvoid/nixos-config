# Brett's Darwin user account. Using known UID/GID from `id -u brett` /
# `id -g brett` so nix-darwin doesn't try to recreate the user it didn't
# originally own (would fail on existing systems).
_: {
  flake.modules.darwin.users =
    { pkgs, ... }:
    {
      users.knownUsers = [ "brett" ];
      users.users.brett = {
        uid = 501;
        gid = 20;
        home = "/Users/brett";
        shell = pkgs.zsh;
      };
    };
}
