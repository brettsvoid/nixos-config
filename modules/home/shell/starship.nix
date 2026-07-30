{ config, ... }:
{
  flake.modules.homeManager.shell-starship = {
    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        palette = "catppuccin_mocha";

        aws = {
          format = "aws [$symbol($profile )(\\($region\\) )(\\[$duration\\] )]($style)";
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
          format = "gcloud [$symbol$account(@$domain)(\\($region\\))]($style) ";
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
          format = "[$symbol$state( \\($name\\))]($style) ";
          symbol = "❄️ ";
        };

        palettes.catppuccin_mocha = config.flake.lib.theme.catppuccin.mocha;
      };
    };
  };
}
