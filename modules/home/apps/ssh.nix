# User-side SSH client. First push of the session prompts for the passphrase
# in the terminal; ssh adds the unlocked key to the running agent so subsequent
# pushes don't prompt again until next login.
_: {
  flake.modules.homeManager.apps-ssh = {
    programs.ssh = {
      enable = true;
      addKeysToAgent = "yes";
    };
  };
}
