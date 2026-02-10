"use client";

import { useEffect, useRef } from "react";
import { cn } from "@/lib/utils";
import { gsap } from "@/lib/animation/gsap-config";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";

interface SpotlightCursorProps {
  /** Additional CSS classes for the spotlight container */
  className?: string;
  /** Whether the spotlight is enabled (default true) */
  enabled?: boolean;
}

/**
 * SpotlightCursor - Dual-layer cursor-following spotlight effect
 *
 * Renders two blurred circles that follow the cursor using GSAP quickTo
 * for buttery-smooth 60fps tracking:
 *
 * - **Primary spotlight**: 200px diameter, very low opacity (~0.06),
 *   ambient glow that follows with a slower lerp (0.08 factor).
 * - **Secondary spotlight**: 24px diameter, slightly brighter (~0.15),
 *   precise follower with a faster lerp (0.15 factor).
 *
 * Together they create a "flashlight" Raycast-style dual glow on the
 * dark background. Both use mix-blend-screen and pointer-events: none.
 *
 * Automatically hidden on touch devices and when reduced motion is preferred.
 *
 * @example
 * ```tsx
 * // In your layout or page
 * <SpotlightCursor />
 * ```
 */
export function SpotlightCursor({
  className,
  enabled = true,
}: SpotlightCursorProps) {
  const primaryRef = useRef<HTMLDivElement>(null);
  const secondaryRef = useRef<HTMLDivElement>(null);
  const visibleRef = useRef(false);

  useEffect(() => {
    if (!enabled) return;

    // Skip on touch devices
    if (
      typeof window !== "undefined" &&
      window.matchMedia("(pointer: coarse)").matches
    ) {
      return;
    }

    // Skip for reduced motion
    if (getReducedMotionValue()) {
      return;
    }

    const primary = primaryRef.current;
    const secondary = secondaryRef.current;
    if (!primary || !secondary) return;

    // GSAP quickTo for smooth, performant cursor following
    // Primary: slower lerp (0.08) for ambient, dreamy glow
    const primaryX = gsap.quickTo(primary, "x", {
      duration: 0.6,
      ease: "power3.out",
    });
    const primaryY = gsap.quickTo(primary, "y", {
      duration: 0.6,
      ease: "power3.out",
    });

    // Secondary: faster lerp (0.15) for precise, responsive dot
    const secondaryX = gsap.quickTo(secondary, "x", {
      duration: 0.3,
      ease: "power3.out",
    });
    const secondaryY = gsap.quickTo(secondary, "y", {
      duration: 0.3,
      ease: "power3.out",
    });

    // Center offsets
    const PRIMARY_SIZE = 200;
    const SECONDARY_SIZE = 24;

    const handleMouseMove = (event: MouseEvent) => {
      const px = event.clientX - PRIMARY_SIZE / 2;
      const py = event.clientY - PRIMARY_SIZE / 2;
      const sx = event.clientX - SECONDARY_SIZE / 2;
      const sy = event.clientY - SECONDARY_SIZE / 2;

      primaryX(px);
      primaryY(py);
      secondaryX(sx);
      secondaryY(sy);

      if (!visibleRef.current) {
        visibleRef.current = true;
        gsap.to(primary, { opacity: 1, duration: 0.3 });
        gsap.to(secondary, { opacity: 1, duration: 0.3 });
      }
    };

    const handleMouseLeave = () => {
      visibleRef.current = false;
      gsap.to(primary, { opacity: 0, duration: 0.3 });
      gsap.to(secondary, { opacity: 0, duration: 0.3 });
    };

    window.addEventListener("mousemove", handleMouseMove, { passive: true });
    document.addEventListener("mouseleave", handleMouseLeave);

    return () => {
      window.removeEventListener("mousemove", handleMouseMove);
      document.removeEventListener("mouseleave", handleMouseLeave);
      gsap.killTweensOf(primary);
      gsap.killTweensOf(secondary);
    };
  }, [enabled]);

  if (!enabled) return null;

  return (
    <>
      {/* Primary spotlight: 200px ambient glow */}
      <div
        ref={primaryRef}
        className={cn(
          "fixed top-0 left-0 z-[50]",
          "rounded-full",
          "pointer-events-none",
          "mix-blend-screen",
          "opacity-0",
          // Hidden on mobile / coarse pointers
          "hidden md:block",
          className
        )}
        style={{
          width: 200,
          height: 200,
          background:
            "radial-gradient(circle, rgba(74, 107, 136, 0.06) 0%, transparent 70%)",
          filter: "blur(30px)",
          willChange: "transform, opacity",
        }}
        aria-hidden="true"
      />

      {/* Secondary spotlight: 24px precise follower */}
      <div
        ref={secondaryRef}
        className={cn(
          "fixed top-0 left-0 z-[50]",
          "rounded-full",
          "pointer-events-none",
          "mix-blend-screen",
          "opacity-0",
          // Hidden on mobile / coarse pointers
          "hidden md:block"
        )}
        style={{
          width: 24,
          height: 24,
          background:
            "radial-gradient(circle, rgba(74, 107, 136, 0.15) 0%, transparent 70%)",
          filter: "blur(6px)",
          willChange: "transform, opacity",
        }}
        aria-hidden="true"
      />
    </>
  );
}

export default SpotlightCursor;
