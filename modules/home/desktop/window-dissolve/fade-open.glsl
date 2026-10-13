#version 320 es
// Window open: the window fades in, over Hyprland's own popin. HyprWindowShade
// reads the duration from the comment below, and `progress` runs 0 → 1 over it.
// @duration 0.3
precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;

void main() {
    // kitty and others map a 1x1 placeholder before their first real frame, which
    // the plugin would stretch over the window: show nothing until the real one.
    if (textureSize(tex, 0).x <= 1) {
        fragColor = vec4(0.0);
        return;
    }
    // Surface colours are premultiplied, so fading scales all four channels.
    fragColor = texture(tex, v_texcoord) * progress;
}
