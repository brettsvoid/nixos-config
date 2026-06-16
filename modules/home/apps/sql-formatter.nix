# sql-formatter config consumed by nvim's conform.nvim plugin.
# Lives at ~/.config/sql_formatter.json.
_: {
  flake.modules.homeManager.apps-sql-formatter = {
    xdg.configFile."sql_formatter.json".text = builtins.toJSON {
      language = "postgresql";
      keywordCase = "upper";
      tabWidth = 2;
      useTabs = true;
    };
  };
}
