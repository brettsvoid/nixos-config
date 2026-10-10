# Brett's Darwin user account. knownUsers lets nix-darwin manage it (it sets
# the login shell only on known users). uid/gid must match the existing
# account (`id -u`, `id -g`), or activation skips it with a warning.
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
