{ config, pkgs, ... }:

{
  # ─── Git ───────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user.name = "Brett Henderson";
      user.email = "brettsvoid@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "nvim";
    };
  };

  # ─── SSH ───────────────────────────────────────────────────────────
  # First push of the session prompts for the passphrase in the terminal,
  # then ssh adds the unlocked key to the running agent so subsequent
  # pushes don't prompt again until next login.
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
  };
}
