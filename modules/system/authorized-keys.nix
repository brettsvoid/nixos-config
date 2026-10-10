# SSH public keys accepted by every host that imports its platform's
# `openssh` module. The option is the same on NixOS and nix-darwin, so this
# one list merges into both modules. Host-only keys go in the host file.
#
# "SSH ID @brettsvoid" is the mobile key from https://sshid.io/brettsvoid.
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
