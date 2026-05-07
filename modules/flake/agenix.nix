# Wires agenix into the NixOS and Darwin module classes. Hosts opt in by
# importing `flake.modules.<class>.agenix` and declaring secrets via
#   age.secrets.<name>.file = "${inputs.secrets}/<name>.age";
{ inputs, ... }:
{
  flake.modules.nixos.agenix = _: {
    imports = [ inputs.agenix.nixosModules.default ];
    # Host SSH key is the activation-time decryption identity. Your user
    # key (the other recipient in nix-secrets/secrets.nix) only decrypts
    # locally during `agenix -e`.
    age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  flake.modules.darwin.agenix = _: {
    imports = [ inputs.agenix.darwinModules.default ];
    age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
}
