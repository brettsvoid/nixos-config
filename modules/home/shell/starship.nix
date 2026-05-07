_: {
  flake.modules.homeManager.shell-starship = {
    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        palette = "catppuccin_mocha";

        format = builtins.concatStringsSep "" [
          "$directory"
          "$git_branch"
          "$git_status"
          "$nix_shell"
          "$rust"
          "$python"
          "$nodejs"
          "$cmd_duration"
          "$line_break"
          "$character"
        ];

        directory = {
          style = "bold lavender";
          truncation_length = 4;
          truncation_symbol = "…/";
        };

        git_branch = {
          style = "bold mauve";
          symbol = " ";
        };

        git_status = {
          style = "bold red";
        };

        nix_shell = {
          style = "bold blue";
          symbol = " ";
          format = "via [$symbol$state]($style) ";
        };

        rust = {
          style = "bold peach";
          symbol = " ";
        };

        python = {
          style = "bold yellow";
          symbol = " ";
        };

        nodejs = {
          style = "bold green";
          symbol = " ";
        };

        cmd_duration = {
          style = "bold yellow";
          min_time = 2000;
          format = "took [$duration]($style) ";
        };

        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };

        palettes.catppuccin_mocha = {
          rosewater = "#f5e0dc";
          flamingo = "#f2cdcd";
          pink = "#f5c2e7";
          mauve = "#cba6f7";
          red = "#f38ba8";
          maroon = "#eba0ac";
          peach = "#fab387";
          yellow = "#f9e2af";
          green = "#a6e3a1";
          teal = "#94e2d5";
          sky = "#89dceb";
          sapphire = "#74c7ec";
          blue = "#89b4fa";
          lavender = "#b4befe";
          text = "#cdd6f4";
          subtext1 = "#bac2de";
          subtext0 = "#a6adc8";
          overlay2 = "#9399b2";
          overlay1 = "#7f849c";
          overlay0 = "#6c7086";
          surface2 = "#585b70";
          surface1 = "#45475a";
          surface0 = "#313244";
          base = "#1e1e2e";
          mantle = "#181825";
          crust = "#11111b";
        };
      };
    };
  };
}
