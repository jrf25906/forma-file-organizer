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

// MARK: - Gradient Drift
// Subtle hue/brightness shift via slow-moving Perlin noise.
// Two octaves at large scale with very slow time coefficients (~0.015)
// for a 45-60 second drift cycle. RGB-space hue rotation avoids
// color-space conversion overhead.

[[ stitchable ]] half4 gradientDrift(float2 position, half4 color, float2 size, float time, float intensity) {
    float2 uv = position / size;

    // Two octaves of noise at large scale, very slow drift
    float n1 = smoothNoise(uv * 3.0 + float2(time * 0.015, time * 0.012));
    float n2 = smoothNoise(uv * 5.0 + float2(time * 0.018 + 7.0, time * 0.010 + 13.0));
    float drift = n1 * 0.6 + n2 * 0.4;

    // Map noise to a small hue rotation angle (-15° to +15°)
    float angle = (drift - 0.5) * 0.52 * intensity; // ~±15° in radians
    float cosA = cos(angle);
    float sinA = sin(angle);

    // RGB hue rotation matrix (Rodrigues around (1,1,1)/√3)
    float3 rgb = float3(color.rgb);
    float3 rotated;
    rotated.r = rgb.r * (cosA + (1.0 - cosA) / 3.0)
              + rgb.g * ((1.0 - cosA) / 3.0 - sqrt(1.0/3.0) * sinA)
              + rgb.b * ((1.0 - cosA) / 3.0 + sqrt(1.0/3.0) * sinA);
    rotated.g = rgb.r * ((1.0 - cosA) / 3.0 + sqrt(1.0/3.0) * sinA)
              + rgb.g * (cosA + (1.0 - cosA) / 3.0)
              + rgb.b * ((1.0 - cosA) / 3.0 - sqrt(1.0/3.0) * sinA);
    rotated.b = rgb.r * ((1.0 - cosA) / 3.0 - sqrt(1.0/3.0) * sinA)
              + rgb.g * ((1.0 - cosA) / 3.0 + sqrt(1.0/3.0) * sinA)
              + rgb.b * (cosA + (1.0 - cosA) / 3.0);

    // Subtle brightness modulation
    float brightness = 1.0 + (drift - 0.5) * 0.06 * intensity;
    rotated *= brightness;

    return half4(half3(clamp(rotated, 0.0, 1.0)), color.a);
}

// MARK: - Specular Rim
// Position-based fresnel with noise modulation. Top-left highlight
// bias (matching LinearGradient direction) + edge rim + noise breakup
// to prevent perfect linearity. Screen blending computed in-shader.

[[ stitchable ]] half4 specularRim(float2 position, half4 color, float2 size, float tierIntensity) {
    float2 uv = position / size;

    // Top-left highlight bias (matching existing LinearGradient direction)
    float highlight = 1.0 - length(uv - float2(0.15, 0.1));
    highlight = clamp(highlight, 0.0, 1.0);
    highlight = pow(highlight, 2.5);

    // Edge rim: stronger at edges, fading toward center
    float edgeX = min(uv.x, 1.0 - uv.x);
    float edgeY = min(uv.y, 1.0 - uv.y);
    float edgeDist = min(edgeX, edgeY);
    float rim = 1.0 - smoothstep(0.0, 0.15, edgeDist);
    rim *= 0.3;

    // Noise breakup to prevent perfect linearity
    float noiseBreak = smoothNoise(uv * 12.0 + float2(23.0, 41.0));
    noiseBreak = noiseBreak * 0.4 + 0.6; // Range: 0.6 - 1.0

    // Combine: highlight + rim, modulated by noise
    float specular = (highlight * 0.7 + rim) * noiseBreak * tierIntensity;

    // Screen blend: result = 1 - (1 - base) * (1 - specular)
    half3 specColor = half3(specular);
    half3 result = half3(1.0) - (half3(1.0) - color.rgb) * (half3(1.0) - specColor);

    return half4(result, color.a);
}

// MARK: - Frosted Texture
// Three-octave grain: fine pixel noise + medium texture + broad undulation.
// Uses pixel coordinates for resolution-independent grain size.
// Static (no time param). Very subtle multiplier.

[[ stitchable ]] half4 frostedTexture(float2 position, half4 color, float2 size, float grainIntensity) {
    // Fine pixel-level noise
    float fine = hash2(position * 1.0);

    // Medium texture noise
    float medium = smoothNoise(position * 0.15);

    // Broad undulation
    float broad = smoothNoise(position * 0.03 + float2(97.0, 53.0));

    // Combine three octaves
    float grain = fine * 0.5 + medium * 0.35 + broad * 0.15;

    // Center around 0 and apply intensity
    float offset = (grain - 0.5) * 0.08 * grainIntensity;

    half3 result = color.rgb + half3(offset);
    return half4(clamp(result, half3(0.0), half3(1.0)), color.a);
}
