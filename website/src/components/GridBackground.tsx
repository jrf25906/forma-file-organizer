"use client";

import { motion, useScroll, useTransform, useReducedMotion } from "framer-motion";

/**
 * GridBackground - Structure Emergence Background
 *
 * A subtle grid pattern that reveals itself as users scroll down the page.
 * This embodies Forma's core narrative: chaos → order, structure emerging.
 *
 * Behavior:
 * - Top of page: Grid barely visible (3% opacity) — representing chaos
 * - As user scrolls: Grid emerges (8% opacity) — structure forming
 * - Grid lines have subtle offset at top, perfectly aligned by mid-page
 *
 * The 64px grid matches the structural, architectural feel of the brand.
 */
export default function GridBackground() {
  const { scrollYProgress } = useScroll();
  const shouldReduceMotion = useReducedMotion();

  // Grid opacity increases as user scrolls (chaos → order)
  const gridOpacity = useTransform(
    scrollYProgress,
    [0, 0.5],
    shouldReduceMotion ? [0.05, 0.05] : [0.03, 0.08]
  );

  return (
    <motion.div
      className="fixed inset-0 pointer-events-none z-0"
      style={{ opacity: gridOpacity }}
      aria-hidden="true"
    >
      <svg
        width="100%"
        height="100%"
        xmlns="http://www.w3.org/2000/svg"
        className="text-forma-bone"
      >
        <defs>
          <pattern
            id="forma-grid"
            width="64"
            height="64"
            patternUnits="userSpaceOnUse"
          >
            {/* Vertical line */}
            <line
              x1="64"
              y1="0"
              x2="64"
              y2="64"
              stroke="currentColor"
              strokeWidth="1"
              opacity="0.3"
            />
            {/* Horizontal line */}
            <line
              x1="0"
              y1="64"
              x2="64"
              y2="64"
              stroke="currentColor"
              strokeWidth="1"
              opacity="0.3"
            />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#forma-grid)" />
      </svg>
    </motion.div>
  );
}
