#version 320 es
// Window close: the window burns away through a noise pattern. GLOW adds a
// glowing ember edge where pixels are about to go; it is off, the plain burn
// being the chosen look (2026-10-09). It shares its noise and settings
// with dissolve-open.glsl; keep the two in step when tuning. Both work from
// the highest noise values down: the open reveals them first and the close
// burns them first. So a window closed while it is still opening (its last
// frame only shows the high values) starts burning at once, rather than
// first burning pixels the open never showed.
//
// HyprWindowShade reads the duration from this comment (seconds):
// @duration 0.25
//
// The plugin replaces Hyprland's close animation here: it holds the window's
// last frame still at full size, and its neighbours slide into the freed tile
// over the same duration. So the shader does its own shrink (to SCALE_END,
// like windowsIn's popin), with the burn pattern shrinking with the window.
// The plugin's overlay mode, which keeps Hyprland's popin instead, drew the
// burn at the window's full size while the window shrank under it (recorded on
// brett-desktop, 2026-10-09).
precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;   // 0 → 1 over @duration
uniform float seed;       // stable per window, 0..1
uniform vec2 surface_size;
uniform vec4 window_rect; // the window's sub-rect of the snapshot texture

// ── Tuning ──────────────────────────────────────────────────────────────
const float CELLS = 20.0;       // largest noise blobs across the window's height
const float EDGE = 0.10;        // width of the glowing band, in noise units
const float SOFT = 0.015;       // anti-aliasing at the cut, in noise units
const float SCALE_END = 0.85;   // size the window shrinks to by the end
const vec3 EMBER_HOT = vec3(1.00, 0.85, 0.55);  // nearest the cut
const vec3 EMBER_COOL = vec3(0.89, 0.10, 0.16); // outer edge (Crimson Ronin red)
const float GLOW = 0.0;         // ember strength: 0 a plain burn, 1 glowing edge
const float NOISE_MEAN = 0.499; // measured distribution of the fbm (see burnNoise)
const float NOISE_SD = 0.1335;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Four octaves, normalised to 0..1, then spread evenly. The fbm is roughly
// normal around 0.5, so a threshold sweeping linearly would burn little at the
// start and end and most in the middle. Mapping through its own normal CDF
// (tanh approximation) makes every value equally likely, so the burn advances
// at a steady rate with no plateaus. NOISE_MEAN and NOISE_SD were measured
// from this exact noise over a window-sized grid (2026-10-09).
float burnNoise(vec2 q) {
    vec2 p = q * CELLS + seed * 173.0;
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * valueNoise(p);
        p = p * 2.03 + 17.1;
        amp *= 0.5;
    }
    float z = (v / 0.9375 - NOISE_MEAN) / NOISE_SD;
    return 0.5 + 0.5 * tanh(0.7978846 * (z + 0.044715 * z * z * z));
}

void main() {
    // 0..1 across the window. The close snapshot is monitor-sized, so this goes
    // through window_rect; for an open window window_rect is (0,0,1,1).
    vec2 local = (v_texcoord - window_rect.xy) / window_rect.zw;
    // The window's shape. surface_size is the box being drawn, which grows
    // during Hyprland's popin, but popin scales evenly, so the ratio holds.
    vec2 size = surface_size * window_rect.zw;
    vec2 aspect = vec2(size.x / size.y, 1.0);

    // Shrink about the window's centre, easing out. `win` is where this
    // fragment lands in the shrunken window; outside it there is nothing.
    float ease = 1.0 - (1.0 - progress) * (1.0 - progress);
    float scale = mix(1.0, SCALE_END, ease);
    vec2 win = (local - 0.5) / scale + 0.5;
    if (any(lessThan(win, vec2(0.0))) || any(greaterThan(win, vec2(1.0)))) {
        fragColor = vec4(0.0);
        return;
    }

    // Same noise coordinates as dissolve-open.glsl (from the centre, in units
    // of the window's height), taken in the shrinking window.
    float n = burnNoise((win - 0.5) * aspect);

    // The threshold sweeps 1 → 0 (just past both ends, so nothing is lost at
    // the start or left at the end), and pixels with noise above it are gone.
    // Burning starts on the first frame; the ember band, just below the
    // threshold, fades in over the first few percent instead of popping.
    float t = mix(1.0 + SOFT, -SOFT, progress);
    float keep = 1.0 - smoothstep(t - SOFT, t, n);
    float glow = smoothstep(t - EDGE, t, n) * smoothstep(0.0, 0.08, progress);

    vec4 src = texture(tex, window_rect.xy + win * window_rect.zw);
    vec3 ember = mix(EMBER_COOL, EMBER_HOT, glow * glow);
    // Premultiplied: the ember takes the window's own alpha, then the cut
    // scales everything. Transparent parts of the window stay transparent.
    vec3 rgb = mix(src.rgb, ember * src.a, glow * GLOW);
    fragColor = vec4(rgb, src.a) * keep;
}
