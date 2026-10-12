#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Page dissolve, ported from the CrossFade pass on shopify.com/editions/winter2026
// and re-tuned for the paper ground: the old page turns into an ink sketch of
// itself, then burns away along a ragged edge rising from the CTA. Twin of the
// AGSL in Android `PageDissolve.kt` — change both together.

constant half3 PD_PAPER = half3(0.949h, 0.929h, 0.882h); // BK.paper
constant half3 PD_INK   = half3(0.082h, 0.082h, 0.075h); // BK.ink
constant half3 PD_EMBER = half3(0.824h, 0.231h, 0.149h); // BK.accent
constant half3 PD_OCHRE = half3(0.788h, 0.588h, 0.169h); // BK.ochre

float pd_hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float pd_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(pd_hash(i), pd_hash(i + float2(1.0, 0.0)), u.x),
               mix(pd_hash(i + float2(0.0, 1.0)), pd_hash(i + float2(1.0, 1.0)), u.x), u.y);
}

// 4-octave fbm in [0, 1], standing in for Shopify's baked Perlin texture.
float pd_fbm(float2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * pd_noise(p);
        p = p * 2.03 + 17.0;
        a *= 0.5;
    }
    return v / 0.9375;
}

half pd_luma(half4 c) { return dot(c.rgb, half3(0.299h, 0.587h, 0.114h)); }

[[ stitchable ]] half4 pageDissolve(float2 pos, SwiftUI::Layer layer, float2 size, float progress) {
    float2 uv = pos / size;
    float aspect = size.x / size.y;
    float t = progress * 0.8; // seconds in, drives the flicker
    float p = progress * (2.0 - progress); // ease-out: answers the tap at once

    // Burn front: an arch growing from just below the CTA, roughed up by drifting
    // fbm (their noise texture) and a finer fibre layer (their mud normal map).
    float2 q = float2(uv.x * aspect, uv.y);
    float shape = length((uv - float2(0.5, 1.08)) * float2(aspect, 1.0)) / length(float2(0.5 * aspect, 1.08));
    float n = pd_fbm(q * 2.5 + float2(0.0, t * 0.4)) * 2.0 - 1.0;
    float fibre = pd_noise(q * 40.0 + t * 3.0) * 0.66 + pd_noise(q * 110.0 - t * 2.0) * 0.34;
    float threshold = shape * 0.66 + 0.17 + n * 0.15 + (fibre * 2.0 - 1.0) * 0.035;
    threshold *= 1.0 - smoothstep(0.9, 1.0, progress); // their hero pass: sweep up stragglers
    float edge = mix(0.12, 0.84, p) - threshold; // > 0: burnt through. 0.12–0.84 brackets the field on phones

    float aa = 1.5 / size.y;
    if (edge > aa) return half4(0.0h);

    // The old page leans in a touch as it goes (their 10% zoom, toned down)...
    float2 c = size * 0.5;
    float2 sp = c + (pos - c) * (1.0 - 0.05 * smoothstep(0.1, 1.0, p));
    half4 col = layer.sample(sp);

    // ...and is an ink sketch of itself by mid-way (their fwidth edge pass).
    float o = size.y / 850.0; // ~1pt
    half gx = pd_luma(layer.sample(sp + float2(o, 0.0))) - pd_luma(layer.sample(sp - float2(o, 0.0)));
    half gy = pd_luma(layer.sample(sp + float2(0.0, o))) - pd_luma(layer.sample(sp - float2(0.0, o)));
    half3 sketch = mix(PD_PAPER, PD_INK, saturate((abs(gx) + abs(gy)) * 3.0h));
    half3 rgb = mix(col.rgb, sketch, half(smoothstep(0.0, 0.5, p)));

    // Ochre-hot ember cooling to red behind a charred lip, flickering like
    // their rim light.
    float x = -edge;
    float flicker = 0.75 + 0.25 * sin(t * 9.0 + uv.x * 18.0 + n * 6.0);
    float heat = exp(-max(x, 0.0) / 0.003) * flicker;
    rgb = mix(rgb, mix(PD_EMBER, PD_OCHRE, half(heat)), half(min(heat * 1.6, 1.0)));
    rgb = mix(rgb, PD_INK, half((1.0 - smoothstep(0.0, 0.002, x)) * 0.8));

    half a = half(1.0 - smoothstep(-aa, aa, edge));
    return half4(rgb * a, a);
}
