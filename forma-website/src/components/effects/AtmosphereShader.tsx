"use client";

import { useEffect, useRef } from "react";
import { useTheme } from "@/components/ThemeProvider";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";

type Vec3 = [number, number, number];

const vertexShaderSource = `
attribute vec2 a_position;
varying vec2 v_uv;

void main() {
  v_uv = (a_position + 1.0) * 0.5;
  gl_Position = vec4(a_position, 0.0, 1.0);
}
`;

const fragmentShaderSource = `
precision mediump float;

varying vec2 v_uv;

uniform vec2 u_resolution;
uniform float u_time;
uniform vec3 u_bg_primary;
uniform vec3 u_bg_secondary;
uniform vec3 u_accent_a;
uniform vec3 u_accent_b;
uniform float u_intensity;
uniform float u_grain_intensity;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 78.233);
  return fract(p.x * p.y);
}

void main() {
  vec2 uv = v_uv;

  float drift =
    sin((uv.y + u_time * 0.030) * 7.0) * 0.020 +
    cos((uv.x - u_time * 0.022) * 5.0) * 0.016;
  float grad_mix = clamp(uv.y + drift, 0.0, 1.0);

  vec3 color = mix(u_bg_primary, u_bg_secondary, grad_mix);

  vec2 glow_center_a = vec2(
    0.23 + sin(u_time * 0.035) * 0.045,
    0.27 + cos(u_time * 0.028) * 0.030
  );
  vec2 glow_center_b = vec2(
    0.78 + cos(u_time * 0.030) * 0.035,
    0.64 + sin(u_time * 0.022) * 0.028
  );

  float glow_a = smoothstep(0.52, 0.0, distance(uv, glow_center_a));
  float glow_b = smoothstep(0.58, 0.0, distance(uv, glow_center_b));

  color += u_accent_a * glow_a * (0.22 * u_intensity);
  color += u_accent_b * glow_b * (0.18 * u_intensity);

  float grain = hash(gl_FragCoord.xy + vec2(mod(u_time * 160.0, 2048.0), 0.0)) - 0.5;
  color += grain * u_grain_intensity;

  float vignette = smoothstep(0.98, 0.28, distance(uv, vec2(0.5, 0.5)));
  color *= mix(0.97, 1.03, vignette);

  gl_FragColor = vec4(color, u_intensity);
}
`;

function createShader(
  gl: WebGLRenderingContext,
  type: number,
  source: string
): WebGLShader | null {
  const shader = gl.createShader(type);
  if (!shader) return null;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    gl.deleteShader(shader);
    return null;
  }
  return shader;
}

function createProgram(
  gl: WebGLRenderingContext,
  vertexSource: string,
  fragmentSource: string
): WebGLProgram | null {
  const vertexShader = createShader(gl, gl.VERTEX_SHADER, vertexSource);
  const fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, fragmentSource);
  if (!vertexShader || !fragmentShader) return null;

  const program = gl.createProgram();
  if (!program) return null;

  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  gl.linkProgram(program);

  gl.deleteShader(vertexShader);
  gl.deleteShader(fragmentShader);

  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    gl.deleteProgram(program);
    return null;
  }

  return program;
}

function parseColorToVec3(value: string | null, fallback: Vec3): Vec3 {
  if (!value) return fallback;
  const color = value.trim();

  if (color.startsWith("#")) {
    const hex = color.slice(1);
    const normalized =
      hex.length === 3
        ? hex
            .split("")
            .map((c) => c + c)
            .join("")
        : hex;

    if (normalized.length === 6) {
      const r = Number.parseInt(normalized.slice(0, 2), 16) / 255;
      const g = Number.parseInt(normalized.slice(2, 4), 16) / 255;
      const b = Number.parseInt(normalized.slice(4, 6), 16) / 255;
      if (!Number.isNaN(r) && !Number.isNaN(g) && !Number.isNaN(b)) {
        return [r, g, b];
      }
    }
  }

  const rgbMatch = color.match(/rgba?\(([^)]+)\)/i);
  if (rgbMatch) {
    const parts = rgbMatch[1]
      .split(",")
      .map((p) => Number.parseFloat(p.trim()))
      .slice(0, 3);
    if (parts.length === 3 && parts.every((n) => Number.isFinite(n))) {
      return [parts[0] / 255, parts[1] / 255, parts[2] / 255];
    }
  }

  return fallback;
}

function setUniformVec3(
  gl: WebGLRenderingContext,
  location: WebGLUniformLocation | null,
  value: Vec3
) {
  if (!location) return;
  gl.uniform3f(location, value[0], value[1], value[2]);
}

export default function AtmosphereShader() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rafRef = useRef<number | null>(null);
  const { resolvedTheme } = useTheme();

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    if (getReducedMotionValue()) return;
    if (typeof window !== "undefined" && window.innerWidth < 768) return;

    const gl = canvas.getContext("webgl", {
      alpha: true,
      antialias: false,
      depth: false,
      stencil: false,
      preserveDrawingBuffer: false,
      powerPreference: "low-power",
    });
    if (!gl) return;

    const program = createProgram(gl, vertexShaderSource, fragmentShaderSource);
    if (!program) return;

    gl.useProgram(program);

    const positionBuffer = gl.createBuffer();
    if (!positionBuffer) {
      gl.deleteProgram(program);
      return;
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([
        -1, -1,
         1, -1,
        -1,  1,
        -1,  1,
         1, -1,
         1,  1,
      ]),
      gl.STATIC_DRAW
    );

    const positionLocation = gl.getAttribLocation(program, "a_position");
    gl.enableVertexAttribArray(positionLocation);
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

    const timeLocation = gl.getUniformLocation(program, "u_time");
    const resolutionLocation = gl.getUniformLocation(program, "u_resolution");
    const intensityLocation = gl.getUniformLocation(program, "u_intensity");
    const grainLocation = gl.getUniformLocation(program, "u_grain_intensity");
    const bgPrimaryLocation = gl.getUniformLocation(program, "u_bg_primary");
    const bgSecondaryLocation = gl.getUniformLocation(program, "u_bg_secondary");
    const accentALocation = gl.getUniformLocation(program, "u_accent_a");
    const accentBLocation = gl.getUniformLocation(program, "u_accent_b");

    const applyThemeUniforms = () => {
      const styles = getComputedStyle(document.documentElement);

      const bgPrimary = parseColorToVec3(
        styles.getPropertyValue("--bg-primary"),
        resolvedTheme === "light" ? [0.98, 0.98, 0.97] : [0.05, 0.05, 0.06]
      );
      const bgSecondary = parseColorToVec3(
        styles.getPropertyValue("--bg-secondary"),
        resolvedTheme === "light" ? [0.95, 0.95, 0.94] : [0.10, 0.10, 0.11]
      );
      const accentA = parseColorToVec3(
        styles.getPropertyValue("--forma-steel-blue"),
        [0.29, 0.42, 0.53]
      );
      const accentB = parseColorToVec3(
        styles.getPropertyValue("--forma-sage"),
        [0.42, 0.56, 0.44]
      );

      setUniformVec3(gl, bgPrimaryLocation, bgPrimary);
      setUniformVec3(gl, bgSecondaryLocation, bgSecondary);
      setUniformVec3(gl, accentALocation, accentA);
      setUniformVec3(gl, accentBLocation, accentB);

      if (intensityLocation) {
        gl.uniform1f(intensityLocation, resolvedTheme === "light" ? 0.22 : 0.28);
      }
      if (grainLocation) {
        gl.uniform1f(grainLocation, resolvedTheme === "light" ? 0.014 : 0.018);
      }
    };

    const resize = () => {
      const pixelRatio = Math.min(window.devicePixelRatio || 1, 1.5);
      const qualityScale = 0.85;
      const width = Math.max(1, Math.floor(window.innerWidth * pixelRatio * qualityScale));
      const height = Math.max(1, Math.floor(window.innerHeight * pixelRatio * qualityScale));
      canvas.width = width;
      canvas.height = height;
      gl.viewport(0, 0, width, height);
      if (resolutionLocation) {
        gl.uniform2f(resolutionLocation, width, height);
      }
    };

    const startTime = performance.now();
    const render = (now: number) => {
      if (timeLocation) {
        gl.uniform1f(timeLocation, (now - startTime) / 1000);
      }
      gl.drawArrays(gl.TRIANGLES, 0, 6);
      rafRef.current = requestAnimationFrame(render);
    };

    const mql = window.matchMedia("(prefers-color-scheme: light)");
    const onSystemThemeChange = () => applyThemeUniforms();

    const observer = new MutationObserver(() => applyThemeUniforms());
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"],
    });

    resize();
    applyThemeUniforms();
    rafRef.current = requestAnimationFrame(render);

    window.addEventListener("resize", resize);
    mql.addEventListener("change", onSystemThemeChange);

    return () => {
      if (rafRef.current !== null) {
        cancelAnimationFrame(rafRef.current);
      }
      window.removeEventListener("resize", resize);
      mql.removeEventListener("change", onSystemThemeChange);
      observer.disconnect();
      gl.deleteBuffer(positionBuffer);
      gl.deleteProgram(program);
    };
  }, [resolvedTheme]);

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      className="pointer-events-none fixed inset-0 z-[0] h-full w-full opacity-70 mix-blend-soft-light"
    />
  );
}
