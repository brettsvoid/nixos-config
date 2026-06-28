# nix-darwin window-manager stack for AeroSpace. Sibling of
# `window-manager.nix` (the yabai/skhd/sketchybar stack). Only one of the
# two should be imported into a host at a time — see the swap notes in
# modules/hosts/brett-m1-mbp.nix.
#
# AeroSpace differences vs. yabai:
#   - Uses virtual workspaces (not native macOS Spaces), so no SIP work
#     and no scripting addition are needed.
#   - Built-in hotkey engine (no skhd). The aerospace.toml under
#     modules/home/darwin/aerospace/ holds all bindings.
#   - Sketchybar still works; it doesn't depend on yabai. We keep it
#     enabled here so the menubar reservation (gaps.outer.top = 60)
#     continues to make sense.
#
# nix-darwin has no `services.aerospace` module yet, so we register a
# launchd user agent manually. `--start-at-login`-style behaviour is
# unnecessary because launchd loads us at user-session start.
_: {
  flake.modules.darwin.window-manager-aerospace =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.aerospace ];

      # AeroSpace ships two binaries:
      #   - bin/aerospace        — CLI client (what `aerospace reload-config` etc. uses)
      #   - Applications/AeroSpace.app/Contents/MacOS/AeroSpace — the GUI/server
      # Running the CLI as a daemon just prints the help banner and exits;
      # the server lives in the .app bundle. macOS also needs the launchd
      # process to be visible as the .app for Accessibility permission to
      # stick to the right identity, which is why we exec the bundle's
      # binary directly.
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

      # macOS Accessibility (TCC) can't be pre-seeded without SIP off —
      # which is the whole reason we picked AeroSpace. So when permission
      # is missing, the only honest thing to do is tell the user how to
      # grant it and how to restart AeroSpace afterward. No auto-restart.
      #
      # AeroSpace itself writes "Successfully reset Accessibility approval
      # status" to /tmp/aerospace.out.log when it's running without
      # permission, so we use that as the detection signal. Truncating
      # the log after printing means the message will reappear if the
      # condition recurs after the next rebuild.
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

      # Disabled — replaced by the edgebar Tauri overlay (apps/edgebar).
      # Re-enable to bring the sketchybar daemon back.
      # services.sketchybar = {
      #   enable = true;
      #   package = pkgs.sketchybar;
      # };
    };
}
