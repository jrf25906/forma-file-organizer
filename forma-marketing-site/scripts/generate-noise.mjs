/**
 * Generate a static noise PNG tile to replace CPU-intensive SVG feTurbulence filter.
 *
 * This creates a tileable noise texture that matches the visual appearance of:
 * <feTurbulence type='fractalNoise' baseFrequency='0.8' numOctaves='4' stitchTiles='stitch'/>
 *
 * Usage: node scripts/generate-noise.mjs
 */

import sharp from 'sharp';
import { writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PUBLIC_DIR = join(__dirname, '..', 'public');

// Configuration - test different sizes for Retina seamlessness
const SIZES = [128, 256]; // 128x128 and 256x256 for testing
const PRIMARY_SIZE = 256; // Primary size to use

/**
 * Generate Perlin-like noise with multiple octaves (fractal noise)
 * Mimics feTurbulence with numOctaves='4'
 */
function generateFractalNoise(size, octaves = 4, baseFrequency = 0.8) {
  const data = new Uint8Array(size * size);

  // Pre-compute random permutation table for consistent noise
  const perm = new Uint8Array(512);
  const p = new Uint8Array(256);
  for (let i = 0; i < 256; i++) p[i] = i;

  // Fisher-Yates shuffle with fixed seed for reproducibility
  let seed = 42;
  const random = () => {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 0x7fffffff;
  };

  for (let i = 255; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [p[i], p[j]] = [p[j], p[i]];
  }
  for (let i = 0; i < 512; i++) perm[i] = p[i & 255];

  // Gradient vectors for 2D noise
  const grads = [
    [1, 1], [-1, 1], [1, -1], [-1, -1],
    [1, 0], [-1, 0], [0, 1], [0, -1]
  ];

  // Fade function for smooth interpolation
  const fade = (t) => t * t * t * (t * (t * 6 - 15) + 10);

  // Linear interpolation
  const lerp = (a, b, t) => a + t * (b - a);

  // Dot product of gradient and distance
  const grad = (hash, x, y) => {
    const g = grads[hash & 7];
    return g[0] * x + g[1] * y;
  };

  // 2D Perlin noise function
  const perlin = (x, y) => {
    const xi = Math.floor(x) & 255;
    const yi = Math.floor(y) & 255;
    const xf = x - Math.floor(x);
    const yf = y - Math.floor(y);

    const u = fade(xf);
    const v = fade(yf);

    const aa = perm[perm[xi] + yi];
    const ab = perm[perm[xi] + yi + 1];
    const ba = perm[perm[xi + 1] + yi];
    const bb = perm[perm[xi + 1] + yi + 1];

    return lerp(
      lerp(grad(aa, xf, yf), grad(ba, xf - 1, yf), u),
      lerp(grad(ab, xf, yf - 1), grad(bb, xf - 1, yf - 1), u),
      v
    );
  };

  // Generate fractal noise (multiple octaves)
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let noise = 0;
      let amplitude = 1;
      let frequency = baseFrequency;
      let maxAmplitude = 0;

      for (let oct = 0; oct < octaves; oct++) {
        // Scale coordinates to create tileable noise
        const nx = (x / size) * frequency * size * 0.1;
        const ny = (y / size) * frequency * size * 0.1;

        noise += perlin(nx, ny) * amplitude;
        maxAmplitude += amplitude;

        amplitude *= 0.5; // Persistence
        frequency *= 2;   // Lacunarity
      }

      // Normalize to 0-255 range
      noise = (noise / maxAmplitude + 1) * 0.5;
      data[y * size + x] = Math.floor(noise * 255);
    }
  }

  return data;
}

/**
 * Create a proper grayscale noise buffer for sharp
 */
async function createNoisePNG(size, filename) {
  console.log(`Generating ${size}x${size} noise texture...`);

  const noiseData = generateFractalNoise(size, 4, 0.8);

  // Convert to RGBA (grayscale with full alpha for proper tiling)
  const rgba = Buffer.alloc(size * size * 4);
  for (let i = 0; i < size * size; i++) {
    const val = noiseData[i];
    rgba[i * 4] = val;     // R
    rgba[i * 4 + 1] = val; // G
    rgba[i * 4 + 2] = val; // B
    rgba[i * 4 + 3] = 255; // A (fully opaque - opacity controlled by CSS)
  }

  const outputPath = join(PUBLIC_DIR, filename);

  await sharp(rgba, {
    raw: {
      width: size,
      height: size,
      channels: 4
    }
  })
    .png({
      compressionLevel: 9,
      effort: 10
    })
    .toFile(outputPath);

  console.log(`Created: ${outputPath}`);
  return outputPath;
}

/**
 * Main execution
 */
async function main() {
  console.log('Generating noise textures for grain overlay optimization...\n');

  // Generate test sizes
  for (const size of SIZES) {
    const filename = size === PRIMARY_SIZE ? 'noise.png' : `noise-${size}.png`;
    await createNoisePNG(size, filename);
  }

  console.log('\n--- Performance Comparison ---');
  console.log('SVG feTurbulence: Continuous GPU/CPU computation every frame');
  console.log('Static PNG tile:  Zero runtime cost (single texture load)\n');

  console.log('Update GrainOverlay component to use:');
  console.log(`  backgroundImage: 'url(/noise.png)'`);
  console.log(`  backgroundRepeat: 'repeat'`);
  console.log(`  opacity: 0.015 (matches current setting)\n`);

  console.log('Done!');
}

main().catch(console.error);
