# agenix for the NixOS and Darwin module classes. Hosts import
# `flake.modules.<class>.agenix` and declare secrets as
#   age.secrets.<name>.file = "${inputs.secrets}/<name>.age";
{ inputs, ... }:
{
  flake.modules.nixos.agenix = _: {
    imports = [ inputs.agenix.nixosModules.default ];
    # The host SSH key decrypts at activation. The user keys (the other
    # recipients in nix-secrets/secrets.nix) are only for `agenix -e`.
    age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  flake.modules.darwin.agenix = _: {
    imports = [ inputs.agenix.darwinModules.default ];
    age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
}
