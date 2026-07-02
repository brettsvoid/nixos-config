# SSH public keys allowed to log into ANY of Brett's machines.
#
# `users.users.brett.openssh.authorizedKeys.keys` is the same option on both
# NixOS and nix-darwin, so this single list is grafted onto both platforms'
# `openssh` server modules (flake-parts deferredModule merge). Add a key here
# once and every host that imports its `openssh` module accepts it.
#
# - "SSH ID @brettsvoid" is the mobile key from https://sshid.io/brettsvoid.
_:
let
  shared =
    { flake, ... }:
    {
      users.users.${flake.lib.username}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHR5ymoo2RDbdGoOktlNbJfw2VW1VEgNXbie7TFWnKi9 SSH ID @brettsvoid"
      ];
    };
in
{
  flake.modules.darwin.openssh = shared;
  flake.modules.nixos.openssh = shared;
}
