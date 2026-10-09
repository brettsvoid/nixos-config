#version 320 es
// Window close: the window vanishes in a puff of smoke. Its content breaks up
// along a wispy edge and drifts upwards as it goes, while a cloud billows out
// of where it stood, rises and thins away. The close snapshot covers the whole
// monitor, so this runs for every pixel of it and the smoke can spread past
// the window's edges. Shares its noise and settings with smoke-open.glsl.
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
uniform vec4 window_rect; // the window's sub-rect of the snapshot texture

// ── Tuning (lengths in window heights) ──────────────────────────────────
const float CELLS = 20.0;       // break-up noise blobs across the window's height
const float SOFT = 0.06;        // softness of the break-up edge, in noise units
const float WARP = 0.05;        // how far the smoke's swirl bends the edge
const float DRIFT = 0.04;       // how far content drifts up as it goes
const float SCALE_END = 0.9;    // size the window shrinks to by the end
const float SMOKE_CELLS = 3.5;  // smoke billows across the window's height
const float RISE = 0.3;         // how far the cloud rises over the close
const float SPREAD = 0.2;       // how far the cloud spreads past the window by the end
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
// sweeping linearly breaks the window up at a steady rate (as in the burn).
float burnNoise(vec2 q) {
    float z = (fbm(q * CELLS + seed * 173.0) - NOISE_MEAN) / NOISE_SD;
    return 0.5 + 0.5 * tanh(0.7978846 * (z + 0.044715 * z * z * z));
}

void main() {
    float p = progress;
    // 0..1 across the window; beyond that outside it.
    vec2 local = (v_texcoord - window_rect.xy) / window_rect.zw;
    vec2 size = surface_size * window_rect.zw;
    vec2 aspect = vec2(size.x / size.y, 1.0);
    // From the window's centre, in window heights. y grows downwards.
    vec2 q = (local - 0.5) * aspect;

    // Where the cloud is: the window's box, risen and spread with time. Most
    // of the monitor is nowhere near it, so leave before any noise is computed.
    float spread = 0.03 + SPREAD * p;
    vec2 risen = q + vec2(0.0, RISE * p);
    float outside = length(max(abs(risen) - 0.5 * aspect, 0.0));
    if (outside > spread) {
        fragColor = vec4(0.0);
        return;
    }
    float region = 1.0 - smoothstep(0.0, spread, outside);

    // Smoke: domain-warped fbm, scrolling upwards a little faster than the
    // cloud rises so the billows roll. It thickens at once and is gone by the
    // end.
    vec2 s = q * SMOKE_CELLS + seed * 91.0;
    s.y += p * RISE * SMOKE_CELLS * 1.5;
    vec2 swirl = vec2(fbm(s), fbm(s + vec2(5.2, 1.3))) - 0.5;
    float density = smoothstep(0.3, 0.7, fbm(s + 2.0 * swirl + vec2(0.0, p)));
    float envelope = smoothstep(0.0, 0.2, p) * (1.0 - smoothstep(0.45, 1.0, p));
    float smoke = density * region * envelope * SMOKE_ALPHA;

    // Content: shrinks about the centre and breaks up from the highest noise
    // values down, its edge bent by the swirl. Pixels close to going drift up
    // and sideways with the smoke.
    float ease = 1.0 - (1.0 - p) * (1.0 - p);
    vec2 win = (local - 0.5) / mix(1.0, SCALE_END, ease) + 0.5;
    vec4 content = vec4(0.0);
    if (all(greaterThanEqual(win, vec2(0.0))) && all(lessThanEqual(win, vec2(1.0)))) {
        vec2 bend = swirl * 2.0 * WARP;
        float n = burnNoise((win - 0.5) * aspect + bend);
        float t = mix(1.0 + SOFT, -SOFT, p);
        float keep = 1.0 - smoothstep(t - SOFT, t, n);
        float near = smoothstep(t - 0.3, t, n);
        vec2 uv = win + (bend + vec2(0.0, DRIFT)) * near / aspect;
        // Off the window there is nothing to sample; the texture would repeat
        // its edge pixels there.
        if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0))))
            content = texture(tex, window_rect.xy + uv * window_rect.zw) * keep;
    }

    // Premultiplied: smoke over what is left of the window.
    fragColor = content * (1.0 - smoke) + vec4(SMOKE * smoke, smoke);
}
