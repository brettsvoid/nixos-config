# OpenSSH server with key-only auth + per-session ssh-agent.
#
# - sshd: pubkey-only, no password auth, no root login.
# - ssh-agent: started by `programs.ssh.startAgent`. Caches the unlocked key
#   for the user's session so terminal pushes only prompt for the passphrase
#   on first use.
# - SSH_AUTH_SOCK: re-pointed at the real agent socket on every interactive
#   zsh, because /etc/zshenv leaves a stale gcr-ssh-agent path in the systemd
#   user environment.
_: {
  flake.modules.nixos.openssh = {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    programs.ssh.startAgent = true;

    programs.zsh.interactiveShellInit = ''
      if [ -S "$XDG_RUNTIME_DIR/ssh-agent" ]; then
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent"
      fi
    '';
  };
}
