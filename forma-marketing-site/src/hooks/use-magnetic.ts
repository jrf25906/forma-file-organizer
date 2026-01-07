"use client";

import { useRef, useEffect, useCallback } from "react";
import { gsap } from "@/lib/animation/gsap-config";
import { formaSnap, formaMagnetic, formaDuration } from "@/lib/animation/ease-curves";

interface UseMagneticOptions {
  /** Strength of the magnetic pull (0-1, default 0.5) */
  strength?: number;
  /** Duration of the animation in seconds */
  duration?: number;
  /** Whether the effect is enabled */
  enabled?: boolean;
}

/**
 * Creates a magnetic effect that pulls an element toward the cursor position.
 * The element smoothly translates toward the cursor when hovering and springs
 * back to center when the cursor leaves.
 *
 * @example
 * ```tsx
 * function MagneticButton() {
 *   const magneticRef = useMagnetic({ strength: 0.3 });
 *   return <button ref={magneticRef}>Hover me</button>;
 * }
 * ```
 */
export function useMagnetic<T extends HTMLElement = HTMLDivElement>(
  options: UseMagneticOptions = {}
) {
  const { strength = 0.5, duration = formaDuration.normal, enabled = true } = options;
  const ref = useRef<T>(null);
  const animationRef = useRef<gsap.core.Tween | null>(null);

  const handleMouseMove = useCallback(
    (event: MouseEvent) => {
      const element = ref.current;
      if (!element || !enabled) return;

      const rect = element.getBoundingClientRect();
      const centerX = rect.left + rect.width / 2;
      const centerY = rect.top + rect.height / 2;

      // Calculate distance from center
      const deltaX = event.clientX - centerX;
      const deltaY = event.clientY - centerY;

      // Apply strength multiplier
      const moveX = deltaX * strength;
      const moveY = deltaY * strength;

      // Cancel any ongoing animation
      if (animationRef.current) {
        animationRef.current.kill();
      }

      // Animate to the new position with responsive magnetic easing
      animationRef.current = gsap.to(element, {
        x: moveX,
        y: moveY,
        duration: duration * 0.5, // Faster follow for responsive feel
        ease: formaMagnetic,
        overwrite: "auto",
      });
    },
    [strength, duration, enabled]
  );

  const handleMouseLeave = useCallback(() => {
    const element = ref.current;
    if (!element || !enabled) return;

    // Cancel any ongoing animation
    if (animationRef.current) {
      animationRef.current.kill();
    }

    // Spring back to center with elastic snap easing
    animationRef.current = gsap.to(element, {
      x: 0,
      y: 0,
      duration: duration,
      ease: formaSnap,
      overwrite: "auto",
    });
  }, [duration, enabled]);

  useEffect(() => {
    const element = ref.current;
    if (!element || !enabled) return;

    // Create GSAP context for proper cleanup
    const ctx = gsap.context(() => {
      element.addEventListener("mousemove", handleMouseMove);
      element.addEventListener("mouseleave", handleMouseLeave);
    });

    return () => {
      element.removeEventListener("mousemove", handleMouseMove);
      element.removeEventListener("mouseleave", handleMouseLeave);

      // Kill any ongoing animation
      if (animationRef.current) {
        animationRef.current.kill();
      }

      ctx.revert();
    };
  }, [handleMouseMove, handleMouseLeave, enabled]);

  return ref;
}

export default useMagnetic;
