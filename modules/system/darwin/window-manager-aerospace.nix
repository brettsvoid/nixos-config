# AeroSpace, the window manager on both Macs.
#   - Virtual workspaces rather than macOS Spaces, so no SIP changes.
#   - Its own hotkey engine: all bindings are in
#     modules/home/darwin/aerospace/aerospace.toml.in.
#   - gaps.outer.top reserves the edgebar band (flake.lib.barGeometry.outerTop).
#
# A hand-written launchd user agent, not nix-darwin's services.aerospace
# (which the pinned nix-darwin has). launchd starts it at login, so
# AeroSpace's own start-at-login stays off.
_: {
  flake.modules.darwin.window-manager-aerospace =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.aerospace ];

      # The server is the binary inside the .app; bin/aerospace is only the
      # CLI client. Running the bundle's binary also keeps Accessibility
      # permission tied to the .app's identity.
      launchd.user.agents.aerospace = {
        command = "${pkgs.aerospace}/Applications/AeroSpace.app/Contents/MacOS/AeroSpace";
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          ProcessType = "Interactive";
          StandardOutPath = "/tmp/aerospace.out.log";
          StandardErrorPath = "/tmp/aerospace.err.log";
        };
      };

      # Accessibility permission (TCC) can't be pre-granted with SIP on, so
      # say how to grant it when it's missing. AeroSpace logs "Successfully
      # reset Accessibility approval status" when running without it; the
      # log is truncated afterwards so the notice only reappears if the
      # problem recurs.
      system.activationScripts.postActivation.text = ''
                log="/tmp/aerospace.out.log"
                if [ -f "$log" ] && grep -q "reset Accessibility approval" "$log"; then
                  cat <<'EOM'

          ╭──────────────────────────────────────────────────────────────╮
          │ AeroSpace lacks Accessibility permission — hotkeys are dead. │
          │                                                              │
          │ 1. System Settings → Privacy & Security → Accessibility      │
          │ 2. Enable "AeroSpace" (add the .app from the nix store if    │
          │    not listed).                                              │
          │ 3. Restart AeroSpace so it picks up the new permission:      │
          │                                                              │
          │      launchctl kickstart -k gui/$UID/org.nixos.aerospace     │
          │                                                              │
          ╰──────────────────────────────────────────────────────────────╯

        EOM
                  : > "$log" 2>/dev/null || true
                fi
      '';

      # Disabled: the edgebar Tauri overlay (apps/edgebar) replaced it.
      # services.sketchybar = {
      #   enable = true;
      #   package = pkgs.sketchybar;
      # };
    };
}
