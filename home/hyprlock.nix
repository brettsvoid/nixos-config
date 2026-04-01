{ config, pkgs, ... }:

{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };

      background = [
        {
          monitor = "";
          color = "rgb(1e1e2e)";
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "300, 60";
          outline_thickness = 4;
          dots_size = 0.2;
          dots_spacing = 0.2;
          dots_center = true;
          outer_color = "rgb(cba6f7)";
          inner_color = "rgb(313244)";
          font_color = "rgb(cdd6f4)";
          fade_on_empty = false;
          placeholder_text = ''<span foreground="##cdd6f4"><i>󰌾  Logged in as </i><span foreground="##cba6f7">$USER</span></span>'';
          hide_input = false;
          check_color = "rgb(cba6f7)";
          fail_color = "rgb(f38ba8)";
          fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
          capslock_color = "rgb(f9e2af)";
          position = "0, -47";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        {
          monitor = "";
          text = "$TIME";
          color = "rgb(cdd6f4)";
          font_size = 90;
          font_family = "FiraCode Nerd Font Mono";
          position = "-30, 0";
          halign = "right";
          valign = "top";
        }
        {
          monitor = "";
          text = ''cmd[update:43200000] date +"%A, %d %B %Y"'';
          color = "rgb(cdd6f4)";
          font_size = 25;
          font_family = "FiraCode Nerd Font Mono";
          position = "-30, -150";
          halign = "right";
          valign = "top";
        }
      ];
    };
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          timeout = 300;
          on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10";
          on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";
        }
        {
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
      ];
    };
  };
}
