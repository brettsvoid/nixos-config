#version 440

// The frame and everything joined to it (the bar, open drawers) as one shape, with its
// drop shadow, in one pass. Distances are in logical pixels; negative is inside.
//
// - The frame is the screen minus a rounded hole. The hole can reach past the screen
//   edge, which leaves that side without a band (the bar draws the top instead).
// - Each extra shape is a rounded box, joined to the rest with a circular fillet, so a
//   concave corner where two parts meet gets a quarter circle of radius `fillet`.
// - The shadow falls outside the shape and fades out over `shadowSize`.
//
// Compiled to .qsb by the Nix build (custom-shell.nix) and by qs-dev.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

#define MAX_SHAPES 8

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    vec2 viewSize;
    // Premultiplied, as Qt passes every colour.
    vec4 fillColor;
    vec4 shadowColor;

    // x, y, width, height of the hole, and its corner radius.
    vec4 hole;
    float holeRadius;

    float fillet;
    float shadowSize;

    int shapeCount;
    // x, y, width, height of each shape; corner radii in shapeRadii (0-3) and
    // shapeRadii2 (4-7).
    vec4 shape0;
    vec4 shape1;
    vec4 shape2;
    vec4 shape3;
    vec4 shape4;
    vec4 shape5;
    vec4 shape6;
    vec4 shape7;
    vec4 shapeRadii;
    vec4 shapeRadii2;
};

// Signed distance from p to a box with rounded corners.
float roundedBox(vec2 p, vec4 rect, float radius) {
    vec2 halfSize = rect.zw * 0.5;
    float r = clamp(radius, 0.0, min(halfSize.x, halfSize.y));
    vec2 q = abs(p - (rect.xy + halfSize)) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Union of two shapes. Where both are within `k` of a point, the distance follows a
// circle of radius k that touches both, which rounds the concave corner between them.
float filletUnion(float a, float b, float k) {
    if (k <= 0.0)
        return min(a, b);
    vec2 u = max(vec2(k - a, k - b), 0.0);
    return max(k, min(a, b)) - length(u);
}

void main() {
    vec2 p = qt_TexCoord0 * viewSize;

    float d = -roundedBox(p, hole, holeRadius);

    vec4 shapes[MAX_SHAPES] = vec4[](shape0, shape1, shape2, shape3,
                                     shape4, shape5, shape6, shape7);
    float radii[MAX_SHAPES] = float[](shapeRadii.x, shapeRadii.y, shapeRadii.z, shapeRadii.w,
                                      shapeRadii2.x, shapeRadii2.y, shapeRadii2.z, shapeRadii2.w);
    for (int i = 0; i < MAX_SHAPES; ++i) {
        if (i >= shapeCount)
            break;
        if (shapes[i].z <= 0.0 || shapes[i].w <= 0.0)
            continue;
        d = filletUnion(d, roundedBox(p, shapes[i], radii[i]), fillet);
    }

    // Coverage over about one device pixel, so edges stay smooth at any scale.
    float aa = max(fwidth(d), 1e-4);
    float cover = clamp(0.5 - d / aa, 0.0, 1.0);

    float falloff = shadowSize > 0.0 ? clamp(1.0 - d / shadowSize, 0.0, 1.0) : 0.0;
    float shadow = d > 0.0 ? falloff * falloff : 0.0;

    fragColor = (fillColor * cover + shadowColor * shadow * (1.0 - cover)) * qt_Opacity;
}
