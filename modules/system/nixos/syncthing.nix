# Syncthing as a system service running as brett, so it syncs from boot
# without a login. Shares the Obsidian vault and ~/Sync with the M1 MBP. The
# Macs run the `syncthing-app` cask (darwin/homebrew.nix), configured outside
# this repo; the mini does not share the vault.
#
# Declare devices and folders here only: overrideDevices/overrideFolders
# (on by default) remove anything added in the web UI on the next start.
_: {
  flake.modules.nixos.syncthing =
    { flake, ... }:
    let
      home = "/home/${flake.lib.username}";
    in
    {
      services.syncthing = {
        enable = true;
        user = flake.lib.username;
        group = "users";
        dataDir = home;
        # 22000 for sync and 21027 for LAN discovery, through the firewall.
        openDefaultPorts = true;

        settings = {
          # Device IDs are hashes of each device's certificate, not secrets:
          # a device still has to be accepted on the other side to connect.
          devices.brett-m1-mbp.id = "557JM7Q-TI6DBXU-RXW62UQ-C55SUI3-DM4GF46-J6FXDKA-2764JPV-WZLT4Q4";

          folders."Obsidian Vault (personal)" = {
            # The ID the MBP gave the folder; folders match by ID, not label.
            id = "m4ff3-zan2d";
            # Same place as on the Macs, and where obsidian.nvim looks.
            path = "${home}/Documents/Obsidian Vault";
            devices = [ "brett-m1-mbp" ];
            # As on the MBP: keep the last 5 versions in .stversions, with no
            # age-based clean-out.
            versioning = {
              type = "simple";
              params = {
                keep = "5";
                cleanoutDays = "0";
              };
            };
          };

          folders."Default Folder" = {
            # The ID the MBP offers for its default ~/Sync folder.
            id = "default";
            path = "${home}/Sync";
            devices = [ "brett-m1-mbp" ];
          };
        };
      };
    };
}
