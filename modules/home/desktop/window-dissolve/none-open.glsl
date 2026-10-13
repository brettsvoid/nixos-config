#version 320 es
// No open effect: the window as it is, so Hyprland's own open animation
// (windowsIn and fadeIn) is all that shows. The window rule always names a
// shader (window-effect switches the file it names), so "none" is this
// pass-through, kept as short as the plugin allows.
// @duration 0.05
precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;

void main() {
    fragColor = texture(tex, v_texcoord);
}
