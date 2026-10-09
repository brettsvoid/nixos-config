# Window open/close shader effects through HyprWindowShade
# (github:ManofJELLO/HyprWindowShade, MIT), a Hyprland plugin that runs a
# GLSL fragment shader over a window as it opens or closes. Hyprland keeps a
# snapshot of a closing window for its close animation; the plugin shades that
# snapshot, so it works however the window closes.
#
# Windows burn in and out through a noise pattern
# (window-dissolve/dissolve-{open,close}.glsl), a plain burn with the shaders'
# ember edge turned off (GLOW). fade-close.glsl is the simple fallback for a
# machine where the dissolve misbehaves.
#
# The plugin is built against Hyprland's internal headers. mkHyprlandPlugin
# builds it against pkgs.hyprland, which is the Hyprland that
# programs.hyprland installs (home-manager uses the system's pkgs), so the two
# always match after a rebuild.
#
# ~/.config/hypr/shaders links to window-dissolve/ in the repo checkout, not
# to the store. The plugin stat()s a shader on every use and recompiles it
# when the mtime changes (directives such as `// @duration` included), so a
# saved edit shows on the next window close with no rebuild.
{ inputs, config, ... }:
let
  inherit (config.flake.lib) repoDir;
in
{
  flake.modules.homeManager.desktop-window-dissolve =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      shaderDir = "${config.xdg.configHome}/hypr/shaders";

      plugin = pkgs.hyprlandPlugins.mkHyprlandPlugin {
        pluginName = "hyprwindowshade";
        version = "0-unstable-2026-09-18";
        src = inputs.hyprwindowshade;

        # The Makefile's default target builds HyprWindowShade.so in the
        # source root.
        installPhase = ''
          runHook preInstall
          install -Dm755 HyprWindowShade.so $out/lib/libhyprwindowshade.so
          runHook postInstall
        '';

        meta = {
          description = "Per-window and per-layer fragment shaders for Hyprland, with open and close animations";
          homepage = "https://github.com/ManofJELLO/HyprWindowShade";
          license = lib.licenses.mit;
          platforms = lib.platforms.linux;
        };
      };
    in
    {
      xdg.configFile."hypr/shaders".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${repoDir}/modules/home/desktop/window-dissolve";

      wayland.windowManager.hyprland.settings = {
        # Loaded once the session is up, not with a `plugin =` line, which
        # loads it while the config is parsed. A plugin that fails at parse
        # time takes Hyprland down on every login (the plugin's README); one
        # loaded here costs the effect for that session only. exec-once does
        # not run again on a rebuild: after the plugin changes, reload it by
        # hand (hyprctl plugin unload/load) or log in again.
        exec-once = [ "hyprctl plugin load ${plugin}/lib/libhyprwindowshade.so" ];

        # Windows grow in from 85% while the open shader burns them in. The
        # shaders measure their noise from the window's centre in units of its
        # height, so the pattern grows with the window. The close needs no
        # Hyprland animation: the plugin holds the window still and
        # dissolve-close.glsl does its own shrink. windowsIn and fadeIn are
        # set explicitly, so the `windows` and `fade` lines in
        # desktop-hyprland do not override them. Speed is in tenths of a
        # second: 3 matches dissolve-open.glsl's `@duration`, so the popin,
        # the fade-in and the burn end together.
        animations.animation = [
          "windowsIn, 1, 3, ease, popin 85%"
          "fadeIn, 1, 3, ease"
        ];

        # A `tag` on a window rule picks the shader; `+shader_open:` and
        # `+shader_close:` play it once as the window opens or closes. Every
        # window gets it. The plugin skips fullscreen windows unless a rule
        # opts them in, so a fullscreen game costs nothing. Menus and tooltips
        # borrow their window's shader, which for these only matters while
        # the window itself is still opening. To exclude an app with trouble,
        # add a rule after these that removes both tags, e.g.
        # "tag -shader_open:${shaderDir}/dissolve-open.glsl, match:class ^(app)$"
        # (tested on brett-desktop, 2026-10-09).
        windowrule = [
          "tag +shader_open:${shaderDir}/dissolve-open.glsl, match:class .*"
          "tag +shader_close:${shaderDir}/dissolve-close.glsl, match:class .*"
        ];
      };
    };
}
