# Apple's built-in OpenSSH server, managed declaratively (darwin half).
#
# Password login on this Mac was never *set* anywhere — `sudo sshd -T` reports
# `passwordauthentication yes` purely from OpenSSH's compiled-in default, since
# nix-darwin left sshd_config.d/100-nix-darwin.conf empty. The block below
# closes that: pubkey-only auth, no keyboard-interactive/PAM password path,
# no root. (The NixOS hosts get the equivalent from
# modules/system/nixos/openssh.nix.)
#
# Authorised keys are shared across every machine and live in
# modules/system/authorized-keys.nix, which grafts onto this same module.
_: {
  flake.modules.darwin.openssh = {
    services.openssh = {
      enable = true; # keep Remote Login on, managed by nix rather than macOS
      extraConfig = ''
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        PermitRootLogin no
      '';
    };
  };
}
