#version 320 es
// No close effect: the window as it is. The overlay directive below plays it
// over Hyprland's own close animation (windowsOut and fadeOut) instead of
// replacing it, so that is all that shows, on Hyprland's timing. The window
// rule always names a shader (window-effect switches the file it names), so
// "none" is this pass-through, kept as short as the plugin allows.
// @duration 0.05
// @overlay
precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;

void main() {
    fragColor = texture(tex, v_texcoord);
}
