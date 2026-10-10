#version 320 es
// Window open: the window burns into view through a noise pattern. GLOW
// adds a glowing ember edge to the pixels that have just appeared; it is off,
// the plain burn being the chosen look. Noise and settings are shared with
// dissolve-close.glsl: keep the two in step. The highest noise values appear
// first (dissolve-close.glsl says why).
//
// HyprWindowShade reads the duration from this comment (seconds):
// @duration 0.3
//
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
// at a steady rate. NOISE_MEAN and NOISE_SD were measured from this exact
// noise over a window-sized grid.
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
    // Noise coordinates from the window's centre, in units of its height, so
    // the pattern grows with the window (from the corner, it slid as popin
    // grew the box). dissolve-close.glsl computes the same value for the same
    // spot, which a close during an open relies on.
    float n = burnNoise((local - 0.5) * aspect);

    // The threshold sweeps 1 → 0 (just past both ends), and pixels with noise
    // above it are visible. The ember band fades out over the last few percent
    // so nothing is still glowing when the shader hands the window back.
    float t = mix(1.0 + SOFT, -SOFT, progress);
    float keep = smoothstep(t, t + SOFT, n);
    float glow = (1.0 - smoothstep(t, t + EDGE, n)) * (1.0 - smoothstep(0.92, 1.0, progress));

    vec4 src = texture(tex, v_texcoord);
    vec3 ember = mix(EMBER_COOL, EMBER_HOT, glow * glow);
    // Premultiplied: the ember takes the window's own alpha, then the cut
    // scales everything. Transparent parts of the window stay transparent.
    vec3 rgb = mix(src.rgb, ember * src.a, glow * GLOW);
    fragColor = vec4(rgb, src.a) * keep;
}
