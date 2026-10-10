# User-side SSH client. The first push of a session asks for the key's
# passphrase; AddKeysToAgent then keeps it in the agent until next login.
_: {
  flake.modules.homeManager.apps-ssh =
    { lib, ... }:
    {
      programs.ssh = {
        enable = true;
        # Off: home-manager's built-in defaults are deprecated (it warns while
        # they are on). settings."*" below declares them explicitly instead.
        enableDefaultConfig = false;
        # Per-host blocks (internal IPs, work hostnames, which key opens which
        # box) stay out of this public repo, in ~/.ssh/config.local next to the
        # keys they reference. Only the `Include` line is emitted here.
        includes = [ "config.local" ];
        # `settings` (not the deprecated `matchBlocks`) takes ssh_config(5)
        # directive names verbatim and type-checks nothing: a typo such as
        # `IdentiyFile` passes eval, then ssh refuses to run ("Bad
        # configuration option"). Check with `ssh -G <host>` after editing.
        settings."*" = {
          IdentityFile = "~/.ssh/id_ed25519";
          AddKeysToAgent = "yes";
          ForwardAgent = false;
          Compression = false;
          ServerAliveInterval = 0;
          ServerAliveCountMax = 3;
          HashKnownHosts = false;
          UserKnownHostsFile = "~/.ssh/known_hosts";
          ControlMaster = "no";
          ControlPath = "~/.ssh/master-%r@%n:%p";
          ControlPersist = "no";
        };
      };

      # Warn when the `Include` above points at nothing. home-manager replaces
      # ~/.ssh/config (the old one goes to .backup) but nothing creates
      # config.local, and ssh ignores a missing include silently: every host
      # falls back to the global defaults (wrong user, hostname, key) with no
      # error. The warning goes in the activation output because that is
      # what a first switch is reading.
      #
      # Don't create a stub: an empty config.local would silence this while
      # ssh still used the defaults. The trailing `true` keeps a warning from
      # ever failing activation.
      home.activation.checkSshConfigLocal = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ -e "$HOME/.ssh/config" ] && ! [ -e "$HOME/.ssh/config.local" ]; then
          if grep -q '^Include config.local' "$HOME/.ssh/config" 2>/dev/null; then
            echo "apps-ssh: ~/.ssh/config.local is MISSING — per-host blocks are not in effect." >&2
            echo "          ssh will silently use the global defaults for every host." >&2
            if [ -e "$HOME/.ssh/config.backup" ]; then
              echo "          ~/.ssh/config.backup exists; recover the blocks with:" >&2
              echo "            awk '/^Host /{p = (\$2 != \"*\")} p' ~/.ssh/config.backup > ~/.ssh/config.local" >&2
              echo "            chmod 600 ~/.ssh/config.local" >&2
            else
              echo "          Create it (mode 600) with your per-host blocks; see modules/home/apps/ssh.nix." >&2
            fi
          fi
        fi
        true
      '';
    };
}
