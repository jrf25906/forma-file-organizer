"use client";

import { useEffect, useRef, useState, useSyncExternalStore, type CSSProperties } from "react";
import { cn } from "@/lib/utils";

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
  const reducedMotion = useSyncExternalStore(
    subscribeReducedMotion,
    getReducedMotionSnapshot,
    getReducedMotionServerSnapshot
  );

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
  const length = 320;
  const style: CSSProperties = animate
    ? {
        strokeDasharray: strokeDasharray ?? `${length} ${length}`,
        strokeDashoffset: entered ? 0 : length,
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
