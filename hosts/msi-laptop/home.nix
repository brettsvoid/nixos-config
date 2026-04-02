{ ... }:

{
  # Host-specific Hyprland settings for MSI GE75 Raider
  # DP-1 = external monitor, eDP-1 = laptop screen
  wayland.windowManager.hyprland.settings.workspace = [
    "1, monitor:DP-1, default:true"
    "2, monitor:DP-1"
    "3, monitor:DP-1"
    "4, monitor:DP-1"
    "5, monitor:DP-1"
    "6, monitor:eDP-1, default:true"
    "7, monitor:eDP-1"
    "8, monitor:eDP-1"
    "9, monitor:eDP-1"
    "10, monitor:eDP-1"
  ];
}
