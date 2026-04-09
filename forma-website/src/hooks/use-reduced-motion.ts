"use client";

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
