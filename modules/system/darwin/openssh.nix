# Apple's built-in OpenSSH server (Remote Login), managed by nix-darwin.
#
# Without extraConfig, sshd_config.d/100-nix-darwin.conf is empty and sshd
# falls back to OpenSSH's default of accepting passwords. The block below
# makes it pubkey-only with no root login, as modules/system/nixos/openssh.nix
# does on NixOS. Authorised keys: modules/system/authorized-keys.nix.
_: {
  flake.modules.darwin.openssh = {
    services.openssh = {
      enable = true;
      extraConfig = ''
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        PermitRootLogin no
      '';
    };
  };
}
