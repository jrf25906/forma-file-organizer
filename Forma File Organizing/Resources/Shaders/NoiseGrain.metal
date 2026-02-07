#include <metal_stdlib>
using namespace metal;

// MARK: - Steel slab shader
// Smooth, non-directional metallic surface with subtle cloudy reflections.
// Evokes a sheet of stainless steel or a filing cabinet panel.

// 2D value noise with smooth interpolation
static float hash2(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float smoothNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    // Quintic interpolation for extra smoothness
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float a = hash2(i);
    float b = hash2(i + float2(1.0, 0.0));
    float c = hash2(i + float2(0.0, 1.0));
    float d = hash2(i + float2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Layered noise at decreasing frequencies
static float metalNoise(float2 p) {
    float value = 0.0;
    value += 0.50 * smoothNoise(p * 1.0);
    value += 0.25 * smoothNoise(p * 2.0 + float2(17.0, 31.0));
    value += 0.15 * smoothNoise(p * 4.0 + float2(53.0, 97.0));
    value += 0.10 * smoothNoise(p * 8.0 + float2(71.0, 13.0));
    return value;
}

[[ stitchable ]] half4 brushedMetal(float2 position, half4 color, float2 size, float blend) {
    float2 uv = position / size;

    // Two noise layers at different scales for depth
    float broad  = metalNoise(uv * 4.0);
    float detail = metalNoise(uv * 10.0 + float2(43.0, 67.0));
    float surface = broad * 0.7 + detail * 0.3;

    // Lighting gradient — brighter at top, darker at bottom (overhead light source)
    float lighting = mix(1.08, 0.88, uv.y);

    // Wider steel palette for real contrast
    half3 steelDark  = half3(0.58, 0.60, 0.64);
    half3 steelMid   = half3(0.74, 0.75, 0.78);
    half3 steelLight = half3(0.90, 0.91, 0.93);

    // Two-stage ramp: dark -> mid -> bright
    half3 metalColor;
    if (surface < 0.5) {
        metalColor = mix(steelDark, steelMid, half(surface * 2.0));
    } else {
        metalColor = mix(steelMid, steelLight, half((surface - 0.5) * 2.0));
    }

    // Specular highlights — sharp bright spots where noise peaks
    float spec = pow(clamp(surface * 1.3, 0.0, 1.0), 5.0);
    metalColor += half3(spec * 0.15);

    // Apply lighting
    metalColor *= half(lighting);

    // Blend with panel color (higher blend = more steel)
    half3 result = mix(color.rgb, metalColor, half(blend));

    return half4(clamp(result, half3(0.0), half3(1.0)), color.a);
}
