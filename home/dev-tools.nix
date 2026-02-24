{ config, pkgs, ... }:

{
  # ─── Git ───────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings = {
      user.name = "Brett Henderson";
      user.email = "brettsvoid@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "nvim";
    };
  };
}
