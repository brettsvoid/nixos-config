# Syncthing as a system service that runs as brett, so syncing starts at boot
# and does not wait for a login. It shares the Obsidian vault and the default
# ~/Sync folder with the M1 MBP.
# The Macs run the Homebrew `syncthing-app` cask (darwin/homebrew.nix) and keep
# their Syncthing settings outside this repo. The mac mini does not share the
# vault.
#
# Devices and folders are declared here only. overrideDevices and
# overrideFolders are on (the module's default), so the next start removes
# anything that was added in the web UI at http://127.0.0.1:8384.
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
        # TCP/UDP 22000 for sync connections, UDP 21027 for LAN discovery.
        # The firewall is on, so without these the Macs cannot connect in.
        openDefaultPorts = true;

        settings = {
          # Device IDs are hashes of each device's certificate, not secrets:
          # a device still has to be accepted on the other side to connect.
          devices.brett-m1-mbp.id = "557JM7Q-TI6DBXU-RXW62UQ-C55SUI3-DM4GF46-J6FXDKA-2764JPV-WZLT4Q4";

          folders."Obsidian Vault (personal)" = {
            # The ID the MBP gave the folder when it created it. Folders are
            # matched by ID, not label or path, so it must be this exact one.
            id = "m4ff3-zan2d";
            # Same place as on the Macs, and where obsidian.nvim looks.
            path = "${home}/Documents/Obsidian Vault";
            devices = [ "brett-m1-mbp" ];
            # As on the MBP: keep the last 5 versions of a changed or deleted
            # file in .stversions, and never clean them out by age.
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
