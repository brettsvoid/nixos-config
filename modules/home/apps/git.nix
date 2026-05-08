_: {
  flake.modules.homeManager.apps-git = {
    programs.git = {
      enable = true;
      lfs.enable = true;
      ignores = [
        "*~"
        "._*"
        "*.swp"
        "*.tmp"
        ".DS_Store"
      ];
      settings = {
        user.name = "Brett Henderson";
        user.email = "brettsvoid@gmail.com";
        init.defaultBranch = "main";
        pull.rebase = true;
        core.editor = "nvim";
      };
    };
  };
}
