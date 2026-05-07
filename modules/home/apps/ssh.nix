# User-side SSH client. First push of the session prompts for the passphrase
# in the terminal; ssh adds the unlocked key to the running agent so subsequent
# pushes don't prompt again until next login.
_: {
  flake.modules.homeManager.apps-ssh = {
    programs.ssh = {
      enable = true;
      # HM 25.x deprecated the standalone `programs.ssh.addKeysToAgent`
      # option in favour of putting defaults under matchBlocks."*". Disabling
      # the auto-generated default block silences the deprecation warning
      # and keeps everything explicit here.
      enableDefaultConfig = false;
      matchBlocks."*" = {
        addKeysToAgent = "yes";
        forwardAgent = false;
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
    };
  };
}
