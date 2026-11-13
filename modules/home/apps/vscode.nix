# VS Code's user settings, from vscode/settings.json. The app itself is not
# installed from here. settings.json stays writable, as Settings Sync also
# writes it: each switch merges this file's keys over it. Extensions, snippets
# and keybindings are left to Settings Sync.
_: {
  flake.modules.homeManager.apps-vscode = {
    programs.vscode = {
      enable = true;
      package = null;
      profiles.default = {
        userSettings = ./vscode/settings.json;
        mutableUserSettings = true;
      };
    };
  };
}
