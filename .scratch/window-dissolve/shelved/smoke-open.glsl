#version 320 es
// Window open: the window condenses out of a puff of smoke. The smoke is
// thickest as the window starts to appear and rises and thins as it settles;
// content gathers along a wispy edge, drifting in from below. Shares its
// noise and settings with smoke-close.glsl. A live window only draws inside
// its own box, so here the smoke cannot spread past it; it fades out towards
// the edges instead of stopping at them.
//
// HyprWindowShade reads the duration from this comment (seconds):
// @duration 0.4
//
precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;   // 0 → 1 over @duration
uniform float seed;       // stable per window, 0..1
uniform vec2 surface_size;
uniform vec4 window_rect; // (0,0,1,1) for a live window

// ── Tuning (lengths in window heights) ──────────────────────────────────
const float CELLS = 20.0;       // gathering noise blobs across the window's height
const float SOFT = 0.06;        // softness of the gathering edge, in noise units
const float WARP = 0.05;        // how far the smoke's swirl bends the edge
const float DRIFT = 0.04;       // how far content drifts up as it settles
const float SMOKE_CELLS = 3.5;  // smoke billows across the window's height
const float RISE = 0.3;         // how far the smoke rises over the open
const float EDGE_FADE = 0.08;   // smoke thins out over this much of each edge
const vec3 SMOKE = vec3(0.70, 0.70, 0.74);
const float SMOKE_ALPHA = 0.65; // densest the smoke gets
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

// Four octaves, normalised to 0..1, roughly normal around 0.5.
float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * valueNoise(p);
        p = p * 2.03 + 17.1;
        amp *= 0.5;
    }
    return v / 0.9375;
}

// The fbm spread evenly over 0..1 through its own normal CDF, so a threshold
// sweeping linearly gathers the window at a steady rate (as in the burn).
float burnNoise(vec2 q) {
    float z = (fbm(q * CELLS + seed * 173.0) - NOISE_MEAN) / NOISE_SD;
    return 0.5 + 0.5 * tanh(0.7978846 * (z + 0.044715 * z * z * z));
}

void main() {
    // kitty maps with a 1x1 placeholder buffer stretched over the window and
    // attaches its first real frame up to ~0.2 s later (WAYLAND_DEBUG,
    // 2026-10-09). The plugin runs this shader at the buffer's size, so on the
    // placeholder it shades one pixel and the whole window gets that pixel's
    // smoke: a flat grey veil. Draw nothing until there is real content.
    if (textureSize(tex, 0).x <= 1) {
        fragColor = vec4(0.0);
        return;
    }

    float p = progress;
    vec2 local = v_texcoord;
    vec2 size = surface_size * window_rect.zw;
    vec2 aspect = vec2(size.x / size.y, 1.0);
    // From the window's centre, in window heights. y grows downwards.
    vec2 q = (local - 0.5) * aspect;

    // Smoke: the same rolling, upward-scrolling fbm as the close. Thick from
    // the first frame, gone before the window has fully settled.
    vec2 s = q * SMOKE_CELLS + seed * 91.0;
    s.y += p * RISE * SMOKE_CELLS * 1.5;
    vec2 swirl = vec2(fbm(s), fbm(s + vec2(5.2, 1.3))) - 0.5;
    float density = smoothstep(0.3, 0.7, fbm(s + 2.0 * swirl + vec2(0.0, p)));
    float envelope = smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.25, 0.85, p));
    vec2 toEdge = min(q + 0.5 * aspect, 0.5 * aspect - q);
    float region = smoothstep(0.0, EDGE_FADE, min(toEdge.x, toEdge.y));
    float smoke = density * region * envelope * SMOKE_ALPHA;

    // Content gathers from the highest noise values down (the same order the
    // close takes them away), its edge bent by the swirl while the smoke is
    // still moving. Pixels that have only just appeared are still drifting
    // up into place.
    vec2 bend = swirl * 2.0 * WARP * (1.0 - p);
    float n = burnNoise(q + bend);
    float t = mix(1.0 + SOFT, -SOFT, p);
    float keep = smoothstep(t, t + SOFT, n);
    float fresh = 1.0 - smoothstep(t, t + 0.3, n);
    vec2 uv = local + (bend - vec2(0.0, DRIFT)) * fresh / aspect;
    // Off the window there is nothing to sample; the texture would repeat its
    // edge pixels there.
    vec4 content = vec4(0.0);
    if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0))))
        content = texture(tex, uv) * keep;

    // Premultiplied: smoke over the window as it gathers.
    fragColor = content * (1.0 - smoke) + vec4(SMOKE * smoke, smoke);
}
