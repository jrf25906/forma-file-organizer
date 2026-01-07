"use client";

/**
 * Forma Brand Easing Curves
 *
 * These easing functions define the motion personality of the Forma brand.
 * Use consistently throughout the marketing site for cohesive animations.
 */

/**
 * formaSnap - Elastic bounce for signature file snap effect
 * Use for: file cards landing, drag-and-drop completion, satisfying "click" moments
 * Creates that delightful bouncy landing that makes organization feel fun
 */
export const formaSnap = "elastic.out(1, 0.5)";

/**
 * formaReveal - Smooth power curve for general reveals
 * Use for: section reveals, fade-ins, content appearing on scroll
 * Professional and polished, with a satisfying deceleration
 */
export const formaReveal = "power3.out";

/**
 * formaSettle - Back easing for landing/settling animations
 * Use for: elements finding their final position, modals appearing, tooltips
 * Slight overshoot creates anticipation and organic movement
 */
export const formaSettle = "back.out(1.7)";

/**
 * formaMagnetic - Responsive curve for magnetic button effects
 * Use for: button hover states, cursor following, interactive elements
 * Quick response with smooth follow-through
 */
export const formaMagnetic = "power2.out";

/**
 * formaExit - Quick exit for elements leaving the viewport
 * Use for: elements animating out, closing modals, dismissing notifications
 */
export const formaExit = "power2.in";

/**
 * formaStagger - Timing for staggered animations
 * Use as stagger values in GSAP timeline configurations
 */
export const formaStagger = {
  fast: 0.06,
  normal: 0.12,
  slow: 0.18,
  cascade: 0.1,
};

/**
 * formaDuration - Standard durations for consistent timing
 * Use for duration values in GSAP animations
 */
export const formaDuration = {
  instant: 0.2,
  fast: 0.4,
  normal: 0.85,
  slow: 1.1,
  reveal: 1.5,
};

/**
 * Preset animation configurations for common patterns
 */
export const formaPresets = {
  fadeUp: {
    from: { opacity: 0, y: 30 },
    to: { opacity: 1, y: 0, ease: formaReveal, duration: formaDuration.normal },
  },
  fadeIn: {
    from: { opacity: 0 },
    to: { opacity: 1, ease: formaReveal, duration: formaDuration.fast },
  },
  scaleIn: {
    from: { opacity: 0, scale: 0.9 },
    to: { opacity: 1, scale: 1, ease: formaSettle, duration: formaDuration.normal },
  },
  snapIn: {
    from: { opacity: 0, y: 50, scale: 0.95 },
    to: { opacity: 1, y: 0, scale: 1, ease: formaSnap, duration: formaDuration.slow },
  },
};
