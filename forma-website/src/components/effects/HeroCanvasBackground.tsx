"use client";

import { cn } from "@/lib/utils";
import type { HTMLAttributes } from "react";

type HeroCanvasBackgroundProps = HTMLAttributes<HTMLDivElement>;

/**
 * Static editorial background for the hero. Layers:
 *   1. Warm canvas base (inherits --canvas-paper)
 *   2. Diagonal warm wash (top-right → bottom-left) for light direction
 *   3. Subtle grain via SVG fractalNoise filter
 *   4. A single hairline horizontal rule where hero meets next section
 *
 * No RAF, no scroll listener, no IntersectionObserver. Respects reduced motion by default.
 */
export function HeroCanvasBackground({ className, ...rest }: HeroCanvasBackgroundProps) {
  return (
    <div
      aria-hidden
      className={cn("pointer-events-none absolute inset-0 -z-10 overflow-hidden", className)}
      {...rest}
    >
      {/* Base canvas */}
      <div className="absolute inset-0 bg-[var(--canvas-paper)]" />

      {/* Diagonal warm wash */}
      <div
        className="absolute inset-0"
        style={{
          background:
            "radial-gradient(120% 80% at 85% 10%, rgba(201, 126, 102, 0.10) 0%, rgba(201, 126, 102, 0) 55%), radial-gradient(100% 70% at 10% 90%, rgba(91, 124, 153, 0.08) 0%, rgba(91, 124, 153, 0) 50%)",
        }}
      />

      {/* Grain */}
      <svg
        className="absolute inset-0 h-full w-full opacity-[0.035] mix-blend-multiply"
        xmlns="http://www.w3.org/2000/svg"
      >
        <filter id="hero-grain">
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" stitchTiles="stitch" />
          <feColorMatrix type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.6 0" />
        </filter>
        <rect width="100%" height="100%" filter="url(#hero-grain)" />
      </svg>

      {/* Closing rule */}
      <div className="absolute inset-x-0 bottom-0 h-px bg-[var(--rule-faint)]" />
    </div>
  );
}
