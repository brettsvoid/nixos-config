#version 320 es
// Fallback close effect: a closing window fades out. HyprWindowShade reads the
// duration from the comment below, and `progress` runs 0 → 1 over it.
// @duration 0.4
//
// The overlay directive below plays the shader over Hyprland's own close
// animation (windowsOut) instead of replacing it, so the window animates away
// while its neighbours reflow on Hyprland's timing; without it the plugin holds
// the window still at its old size while the neighbours slide in. The plugin
// reads a directive from any `//` comment in the file that begins with one, so
// begin no other comment with a directive's name.
// @overlay
precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;

void main() {
    // Surface colours are premultiplied, so fading scales all four channels.
    fragColor = texture(tex, v_texcoord) * (1.0 - progress);
}
