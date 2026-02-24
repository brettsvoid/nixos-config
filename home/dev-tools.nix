{ config, pkgs, ... }:

{
  # ─── Git ───────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    userName = "Brett Henderson";
    userEmail = "brettsvoid@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "nvim";
    };
  };
}
