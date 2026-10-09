#version 320 es
// Test effect for the plugin trial: a closing window fades out. HyprWindowShade
// reads the duration from the comment below, and `progress` runs 0 → 1 over it.
// @duration 0.4
//
// The overlay directive below plays the shader over Hyprland's own close
// animation (windowsOut) instead of replacing it, so the window animates away
// while its neighbours reflow on Hyprland's normal timing. Without it the
// plugin holds the window still at its old size while the neighbours slide in
// underneath. Delete the directive to compare; the change shows on the next
// close. The plugin finds directives by pattern anywhere in the file, so keep
// the directive's name out of comments.
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
