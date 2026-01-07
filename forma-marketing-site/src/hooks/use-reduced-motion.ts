"use client";

import { useState, useEffect } from "react";

/**
 * useReducedMotion - Detects user's motion preference
 *
 * Respects the prefers-reduced-motion media query to provide
 * accessible experiences for users who are sensitive to motion.
 *
 * When reduced motion is preferred:
 * - Complex animations (flying files, parallax) should become instant
 * - Simple transitions (opacity, color) can remain for UI feedback
 * - Scroll-driven animations should snap to final state
 *
 * @example
 * ```tsx
 * function AnimatedComponent() {
 *   const reducedMotion = useReducedMotion();
 *
 *   return (
 *     <div
 *       style={{
 *         // Use instant position instead of flying animation
 *         transform: reducedMotion
 *           ? `translate(${finalX}px, ${finalY}px)`
 *           : `translate(${animatedX}px, ${animatedY}px)`,
 *         // Keep subtle opacity transitions for UI feedback
 *         transition: reducedMotion
 *           ? 'opacity 0.15s ease'
 *           : 'all 0.6s cubic-bezier(0.16, 1, 0.3, 1)',
 *       }}
 *     >
 *       Content
 *     </div>
 *   );
 * }
 * ```
 *
 * @returns {boolean} Whether the user prefers reduced motion
 */
export function useReducedMotion(): boolean {
  // Default to false during SSR to avoid hydration mismatch
  const [reducedMotion, setReducedMotion] = useState(false);

  useEffect(() => {
    // Check if matchMedia is supported
    if (typeof window === "undefined" || !window.matchMedia) {
      return;
    }

    const mediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

    // Set initial value
    setReducedMotion(mediaQuery.matches);

    // Listen for changes (user can toggle in system settings)
    const handleChange = (event: MediaQueryListEvent) => {
      setReducedMotion(event.matches);
    };

    mediaQuery.addEventListener("change", handleChange);

    return () => {
      mediaQuery.removeEventListener("change", handleChange);
    };
  }, []);

  return reducedMotion;
}

/**
 * getReducedMotionValue - Static check for reduced motion preference
 *
 * Use this for one-off checks where a hook isn't appropriate.
 * Note: This won't react to changes in user preferences.
 *
 * @returns {boolean} Whether the user prefers reduced motion
 */
export function getReducedMotionValue(): boolean {
  if (typeof window === "undefined" || !window.matchMedia) {
    return false;
  }
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

export default useReducedMotion;
