# User-side SSH client. First push of the session prompts for the passphrase
# in the terminal; ssh adds the unlocked key to the running agent so subsequent
# pushes don't prompt again until next login.
_: {
  flake.modules.homeManager.apps-ssh = {
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
  };
}
