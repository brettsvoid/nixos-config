# OpenSSH server (pubkey only, no root) and a per-session ssh-agent, so the
# key's passphrase is asked for once per session. Authorised keys:
# modules/system/authorized-keys.nix.
_: {
  flake.modules.nixos.openssh = {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        # With UsePAM (the NixOS default), keyboard-interactive would still
        # accept the account password.
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    programs.ssh.startAgent = true;

    # startAgent sets SSH_AUTH_SOCK only when it is unset (in
    # /etc/set-environment), so interactive zsh points it at the agent anyway.
    programs.zsh.interactiveShellInit = ''
      if [ -S "$XDG_RUNTIME_DIR/ssh-agent" ]; then
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent"
      fi
    '';
  };
}
