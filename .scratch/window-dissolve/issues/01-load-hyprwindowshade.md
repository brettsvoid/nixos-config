# Load HyprWindowShade on brett-desktop with a test fade on close

Status: ready-for-human
Type: HITL (needs someone watching the screen on the NVIDIA desktop)

## What to build

Get the HyprWindowShade Hyprland plugin (https://github.com/ManofJELLO/HyprWindowShade,
MIT) running on brett-desktop. Prove it works there with a deliberately simple shader:
kitty windows fade out when they close.

The plugin runs a GLSL shader on a window's last frame when it opens or closes. A window
rule tag attaches the shader (`+shader_close:/path.glsl`, optionally `@seconds`). The
shader gets `progress` (0 to 1) and `seed` uniforms and declares its length with a
`// @duration 0.4` comment. The README documents both the Lua config and the `.conf`
form, which is what home-manager writes today (see hyprland-lua-config/01).

Things to respect:

- Package it with nixpkgs' `hyprlandPlugins.mkHyprlandPlugin`, pinned to a commit and
  built against the same Hyprland the system runs (nixpkgs' `programs.hyprland`, 0.56.2
  at the time of writing), so a Hyprland update rebuilds it. `hyprpm` does not work on
  NixOS.
- Load it once the session has started (`exec-once = hyprctl plugin load …`), not while
  the config is parsed. The plugin's README warns that a broken plugin loaded at parse
  time kills Hyprland on every login.
- Keep the shader file in the repo and let home-manager deploy it.
- The author has only tested on AMD. This desktop is an RTX 3080 Ti on the proprietary
  driver, so this issue is where we find out.

## Acceptance criteria

- [ ] `hyprctl plugin list` shows HyprWindowShade after login, with no rebuild or manual
      step.
- [ ] A kitty window fades out when closed with the close-window keybind.
- [ ] A kitty window fades out when it closes itself (for example `exit` in the shell).
- [ ] Other apps close as before.
- [ ] A fullscreen game runs as before (the plugin drops shaders on fullscreen windows
      by default; check frame pacing with MangoHud).
- [ ] No crash or visual glitch over a normal session; note anything odd in a comment
      below.
- [ ] If it does not work on NVIDIA, record what failed and stop here. The fallback is
      Hyprland's built-in close animations.

## Blocked by

None - can start immediately.

## Comments

**2026-10-09:** Wired up, not yet tested on screen.

- `flake.nix` input `hyprwindowshade`, pinned to a4c6b8a, the plugin's own release pin
  for Hyprland 0.56.2 (its hyprpm.toml names Hyprland efb5099, the commit running here).
- `modules/home/desktop/window-dissolve.nix` (home-manager `desktop-window-dissolve`,
  imported by brett-desktop) builds it with `mkHyprlandPlugin` against `pkgs.hyprland`,
  the same store path as `programs.hyprland.package` and the running compositor. It loads
  it from exec-once and tags kitty with `+shader_close:` the test fade
  (`window-dissolve/fade-close.glsl`).
- The brett-desktop system builds; nixfmt, deadnix and statix are clean.
- home-manager does not reload Hyprland on switch here (`package = null` turns off its
  `onChange` reload), so after `nix-rebuild` run `hyprctl reload` for the window rule.
  The plugin loads at the next login, or now with `hyprctl plugin load` on the path in
  the generated `hyprland.conf`.

**2026-10-09:** Loaded at login on brett-desktop (`hyprctl plugin list`); the fade plays
on kitty.

- Reported "kitty isn't tiling": not the plugin. kitty 0.49 saves `"window-state":
  "maximized"` to `~/.cache/kitty/main.json` when a lone tiled window closes, and the next
  kitty window asks to be maximised. Reproduced with untagged kitty windows; Ghostty tiles
  normally. Fixed with `remember_window_size no` in terminals-kitty (Linux only).
- The plugin has no option to keep a closing window's tile until the effect ends (no
  config values; the reflow retiming in `Hooks.cpp` is all-or-nothing). By default it
  holds the snapshot still while the neighbours slide in over the shader's `@duration`.
  `// @overlay` instead plays the shader over Hyprland's own `windowsOut` (currently
  `slide`, 0.4 s) with normal reflow timing. The test shader has it on for comparison.
- `~/.config/hypr/shaders` links to the repo's `window-dissolve/`, so shader edits apply
  on the next close without a rebuild.
