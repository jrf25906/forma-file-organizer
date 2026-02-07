"use client";

import { useEffect, useRef } from "react";
import { cn } from "@/lib/utils";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";

interface SpotlightCursorProps {
  /** Additional CSS classes for the spotlight element */
  className?: string;
  /** Size of the spotlight in pixels (default 48) */
  size?: number;
  /** Whether the spotlight is enabled (default true) */
  enabled?: boolean;
}

/**
 * SpotlightCursor - Cursor-following spotlight effect
 *
 * Renders a 48x48px blurred circle that follows the cursor using
 * requestAnimationFrame for smooth 60fps tracking. The spotlight uses
 * pointer-events: none and mix-blend-mode: soft-light so it does not
 * interfere with interactions underneath.
 *
 * Automatically hidden on touch devices and when reduced motion is preferred.
 *
 * @example
 * ```tsx
 * // In your layout or page
 * <SpotlightCursor />
 *
 * // With custom size
 * <SpotlightCursor size={64} />
 * ```
 */
export function SpotlightCursor({
  className,
  size = 48,
  enabled = true,
}: SpotlightCursorProps) {
  const spotlightRef = useRef<HTMLDivElement>(null);
  const positionRef = useRef({ x: 0, y: 0 });
  const currentRef = useRef({ x: 0, y: 0 });
  const rafRef = useRef<number | undefined>(undefined);
  const visibleRef = useRef(false);

  useEffect(() => {
    if (!enabled) return;

    // Skip on touch devices
    if (typeof window !== "undefined" && window.matchMedia("(pointer: coarse)").matches) {
      return;
    }

    // Skip for reduced motion
    if (getReducedMotionValue()) {
      return;
    }

    const spotlight = spotlightRef.current;
    if (!spotlight) return;

    const handleMouseMove = (event: MouseEvent) => {
      positionRef.current = { x: event.clientX, y: event.clientY };

      if (!visibleRef.current) {
        visibleRef.current = true;
        spotlight.style.opacity = "1";
      }
    };

    const handleMouseLeave = () => {
      visibleRef.current = false;
      spotlight.style.opacity = "0";
    };

    // Animation loop for smooth following
    const animate = () => {
      const target = positionRef.current;
      const current = currentRef.current;

      // Lerp for smooth following
      current.x += (target.x - current.x) * 0.15;
      current.y += (target.y - current.y) * 0.15;

      if (spotlight) {
        spotlight.style.transform = `translate3d(${current.x - size / 2}px, ${current.y - size / 2}px, 0)`;
      }

      rafRef.current = requestAnimationFrame(animate);
    };

    window.addEventListener("mousemove", handleMouseMove, { passive: true });
    document.addEventListener("mouseleave", handleMouseLeave);
    rafRef.current = requestAnimationFrame(animate);

    return () => {
      window.removeEventListener("mousemove", handleMouseMove);
      document.removeEventListener("mouseleave", handleMouseLeave);
      if (rafRef.current) {
        cancelAnimationFrame(rafRef.current);
      }
    };
  }, [enabled, size]);

  if (!enabled) return null;

  return (
    <div
      ref={spotlightRef}
      className={cn(
        "fixed top-0 left-0 z-[9999]",
        "rounded-full",
        "bg-forma-steel-blue/20",
        "blur-[12px]",
        "pointer-events-none",
        "mix-blend-soft-light",
        "opacity-0",
        "transition-opacity duration-300",
        className
      )}
      style={{
        width: size,
        height: size,
        willChange: "transform",
      }}
      aria-hidden="true"
    />
  );
}

export default SpotlightCursor;
