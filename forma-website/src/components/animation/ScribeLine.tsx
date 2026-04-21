"use client";

import { useEffect, useLayoutEffect, useRef, useState, useSyncExternalStore, type CSSProperties } from "react";
import { cn } from "@/lib/utils";

// useLayoutEffect warns during SSR; fall back to useEffect on the server.
const useIsomorphicLayoutEffect = typeof window === "undefined" ? useEffect : useLayoutEffect;

function subscribeReducedMotion(onChange: () => void) {
  if (typeof window === "undefined") return () => {};
  const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
  mq.addEventListener("change", onChange);
  return () => mq.removeEventListener("change", onChange);
}

function getReducedMotionSnapshot(): boolean {
  if (typeof window === "undefined") return false;
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

function getReducedMotionServerSnapshot(): boolean {
  return false;
}

export interface ScribeLineProps {
  /** SVG path `d` attribute. */
  path: string;
  /** viewBox — default "0 0 100 100". */
  viewBox?: string;
  /** Draw duration. */
  durationMs?: number;
  /** Delay before drawing starts after entering the viewport. */
  delayMs?: number;
  /** Stroke color — default `var(--ink-draft)`. */
  stroke?: string;
  /** Stroke width in SVG units. */
  strokeWidth?: number;
  /** Dash pattern (optional). */
  strokeDasharray?: string;
  className?: string;
}

export interface ShouldAnimateScribeInput {
  reducedMotion: boolean;
}

/**
 * Pure helper — returns false when the user prefers reduced motion
 * (in which case the line should render in its finished state immediately).
 */
export function shouldAnimateScribe({ reducedMotion }: ShouldAnimateScribeInput): boolean {
  return !reducedMotion;
}

export function ScribeLine({
  path,
  viewBox = "0 0 100 100",
  durationMs = 600,
  delayMs = 0,
  stroke = "var(--ink-draft)",
  strokeWidth = 1.2,
  strokeDasharray,
  className,
}: ScribeLineProps) {
  const ref = useRef<SVGPathElement>(null);
  const [entered, setEntered] = useState(false);
  // Measured path length. 0 until the path mounts, then set from getTotalLength().
  const [pathLength, setPathLength] = useState(0);
  const reducedMotion = useSyncExternalStore(
    subscribeReducedMotion,
    getReducedMotionSnapshot,
    getReducedMotionServerSnapshot
  );

  // Measure the actual path length on mount. Falls back to 320 if measurement fails.
  useIsomorphicLayoutEffect(() => {
    const node = ref.current;
    if (!node) return;
    try {
      const measured = node.getTotalLength();
      setPathLength(Number.isFinite(measured) && measured > 0 ? measured : 320);
    } catch {
      setPathLength(320);
    }
  }, [path]);

  useEffect(() => {
    const node = ref.current;
    if (!node) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          setEntered(true);
          observer.disconnect();
        }
      },
      { threshold: 0.35, rootMargin: "0px 0px -8% 0px" }
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  const animate = shouldAnimateScribe({ reducedMotion });
  const effectiveLength = pathLength || 320;
  const style: CSSProperties = animate
    ? {
        strokeDasharray: strokeDasharray ?? `${effectiveLength} ${effectiveLength}`,
        strokeDashoffset: entered ? 0 : effectiveLength,
        transition: `stroke-dashoffset ${durationMs}ms cubic-bezier(0.22, 1, 0.36, 1) ${delayMs}ms`,
      }
    : { strokeDasharray, strokeDashoffset: 0 };

  return (
    <svg
      aria-hidden="true"
      viewBox={viewBox}
      className={cn("pointer-events-none", className)}
      fill="none"
    >
      <path
        ref={ref}
        d={path}
        stroke={stroke}
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        style={style}
      />
    </svg>
  );
}
