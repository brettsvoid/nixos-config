_: {
  flake.modules.homeManager.shell-starship = {
    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        palette = "catppuccin_mocha";

        # format = builtins.concatStringsSep "" [
        #   "$directory"
        #   "$git_branch"
        #   "$git_status"
        #   "$nix_shell"
        #   "$rust"
        #   "$python"
        #   "$nodejs"
        #   "$cmd_duration"
        #   "$line_break"
        #   "$character"
        # ];

        aws = {
          format = "aws [$symbol($profile )(\($region\) )(\[$duration\] )]($style)";
          symbol = "☁️ ";
        };

        character = {
          error_symbol = "[✖](bold red)";
          success_symbol = "[❯](bold green)";
        };

        cmd_duration = {
          style = "bold yellow";
          min_time = 2000;
          format = "took [$duration]($style) ";
        };

        directory = {
          style = "bold lavender";
          truncate_to_repo = false;
          truncation_length = 4;
          truncation_symbol = "…/";
        };

        direnv = {
          disabled = false;
        };

        gcloud = {
          format = "gcloud [$symbol$account(@$domain)(\($region\))]($style) ";
          symbol = "☁️ ";
        };

        git_branch = {
          format = "[$symbol$branch(:$remote_branch)]($style) ";
          style = "bold mauve";
        };

        git_status = {
          ahead = "⇡$count";
          behind = "⇣$count";
          diverged = "⇕⇡$ahead_count⇣$behind_count";
        };

        nix_shell = {
          format = "[$symbol$state( \($name\))]($style) ";
          symbol = "❄️ ";
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
