# Window open/close shader effects through HyprWindowShade
# (github:ManofJELLO/HyprWindowShade, MIT), a Hyprland plugin that runs a
# GLSL fragment shader over a window as it opens or closes. It shades the
# snapshot Hyprland keeps of a closing window, so it works however the window
# closes.
#
# Windows burn in and out through a noise pattern
# (window-dissolve/dissolve-{open,close}.glsl), with the shaders' ember edge
# turned off (GLOW). fade-close.glsl is a simple fallback for a machine where
# the dissolve misbehaves.
#
# The plugin builds against Hyprland's internal headers. mkHyprlandPlugin uses
# pkgs.hyprland, the Hyprland programs.hyprland installs (home-manager uses
# the system's pkgs), so the two match after a rebuild.
#
# ~/.config/hypr/shaders links to window-dissolve/ in the repo checkout, not
# the store. The plugin recompiles a shader when its mtime changes (its
# `@duration` included), so a saved edit shows on the next open or close
# without a rebuild.
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
        # Loaded once the session is up, not by a `plugin =` line while the
        # config is parsed: a plugin that fails then takes Hyprland down on
        # every login (the plugin's README), while here it costs the effect
        # for one session. exec-once does not rerun on a rebuild: after the
        # plugin changes, `hyprctl plugin unload`/`load` it or log in again.
        exec-once = [ "hyprctl plugin load ${plugin}/lib/libhyprwindowshade.so" ];

        # Windows grow in from 85% while the open shader burns them in. The
        # close needs no Hyprland animation: the plugin holds the window still
        # and dissolve-close.glsl does its own shrink. windowsIn and fadeIn are
        # set explicitly, so desktop-hyprland's `windows` and `fade` lines do
        # not override them. Speed is in tenths of a second: 3 matches
        # dissolve-open.glsl's `@duration`, so popin, fade-in and burn end
        # together.
        animations.animation = [
          "windowsIn, 1, 3, ease, popin 85%"
          "fadeIn, 1, 3, ease"
        ];

        # A `tag` on a window rule picks the shader; `+shader_open:` and
        # `+shader_close:` play it once as the window opens or closes. The
        # plugin skips fullscreen windows unless a rule opts them in, so a
        # fullscreen game costs nothing. Menus and tooltips borrow their
        # window's shader, which only matters while that window is opening. To
        # exclude an app, add a rule after these that removes both tags, e.g.
        # "tag -shader_open:${shaderDir}/dissolve-open.glsl, match:class ^(app)$"
        # and the same with -shader_close.
        windowrule = [
          "tag +shader_open:${shaderDir}/dissolve-open.glsl, match:class .*"
          "tag +shader_close:${shaderDir}/dissolve-close.glsl, match:class .*"
        ];
      };
    };
}
