# User-side SSH client. First push of the session prompts for the passphrase
# in the terminal; ssh adds the unlocked key to the running agent so subsequent
# pushes don't prompt again until next login.
_: {
  flake.modules.homeManager.apps-ssh =
    { lib, ... }:
    {
      programs.ssh = {
        enable = true;
        # Keep home-manager from emitting its own `Host *` block on top of the
        # one below. Home-manager's docs say this option will itself be
        # deprecated, and give the replacement as exactly what we already do:
        # declare `settings."*"` by hand.
        enableDefaultConfig = false;
        # Per-host blocks (internal IPs, work hostnames, which key unlocks which
        # box) are infrastructure recon and this repo is public, so they live in
        # ~/.ssh/config.local — outside git, next to the .pem keys they reference.
        # nix only emits the `Include` line; the global defaults below are generic
        # and safe to publish.
        includes = [ "config.local" ];
        # `settings`, not the older `matchBlocks`, which home-manager now warns
        # on. The keys are upstream ssh_config(5) directive names, verbatim —
        # `settings` is a freeform attrset that passes them straight through,
        # instead of the curated camelCase mapping matchBlocks used
        # (`identityFile`, `addKeysToAgent`, …).
        #
        # The cost of freeform: nothing type-checks these any more. Under
        # matchBlocks a typo failed at eval; here `IdentiyFile` would sail
        # through and render a directive ssh silently ignores. Check the
        # generated ~/.ssh/config after editing this block.
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

      # Warn when the `Include` above points at nothing.
      #
      # This is the trap that cost the mac mini its SSH config. home-manager
      # writes ~/.ssh/config fresh, moving any existing one to .backup, and
      # emits `Include config.local` — but nothing creates that target. ssh
      # ignores a missing include silently, so every per-host block vanishes
      # and connections quietly fall back to the global defaults: wrong user,
      # wrong hostname, wrong key, no error. It went unnoticed for days.
      #
      # A comment was not enough. This file already documented that per-host
      # blocks live in config.local, a dozen lines above, and the mini shipped
      # broken anyway — whoever runs a first switch is reading activation
      # output, not the module. So the warning goes where they are looking.
      #
      # Deliberately does NOT create a stub. An empty config.local would make
      # the include resolve and this warning stop firing, while ssh still
      # resolved to the defaults — turning a detectable problem into an
      # undetectable one.
      #
      # Silent once the file exists, so it costs nothing on a settled host.
      # `|| true` because a warning must never fail an activation.
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
