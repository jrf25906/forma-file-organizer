"use client";

import { motion, useScroll, useTransform, useSpring } from "framer-motion";
import { useRef } from "react";

interface ParallaxOrbProps {
  color: "sage" | "blue" | "orange";
  size: "sm" | "md" | "lg" | "xl";
  position: {
    top?: string;
    bottom?: string;
    left?: string;
    right?: string;
  };
  speed?: number; // Parallax speed multiplier (negative = move up on scroll, positive = move down)
  opacity?: number;
  className?: string;
}

const sizeClasses = {
  sm: "w-32 h-32",
  md: "w-64 h-64",
  lg: "w-80 h-80",
  xl: "w-96 h-96",
};

const colorClasses = {
  sage: "orb-sage",
  blue: "orb-blue",
  orange: "orb-orange",
};

export default function ParallaxOrb({
  color,
  size,
  position,
  speed = -50, // Default: moves up slightly as you scroll down
  opacity = 0.3,
  className = "",
}: ParallaxOrbProps) {
  const ref = useRef<HTMLDivElement>(null);

  // Track scroll progress across the entire page
  const { scrollYProgress } = useScroll();

  // Transform scroll progress to Y translation
  // scrollYProgress goes from 0 to 1 as page scrolls
  // speed of -100 means move -100px total as you scroll the full page
  const yRaw = useTransform(scrollYProgress, [0, 1], [0, speed]);

  // Also add subtle X movement for more organic feel
  const xRaw = useTransform(scrollYProgress, [0, 1], [0, speed * 0.3]);

  // Add subtle rotation based on scroll
  const rotateRaw = useTransform(scrollYProgress, [0, 1], [0, speed * 0.1]);

  // Smooth the motion with springs for a floaty feel
  const y = useSpring(yRaw, { stiffness: 50, damping: 20 });
  const x = useSpring(xRaw, { stiffness: 50, damping: 20 });
  const rotate = useSpring(rotateRaw, { stiffness: 30, damping: 15 });

  // Scale slightly based on scroll for depth effect
  const scaleRaw = useTransform(
    scrollYProgress,
    [0, 0.5, 1],
    [1, 1 + Math.abs(speed) * 0.001, 1]
  );
  const scale = useSpring(scaleRaw, { stiffness: 50, damping: 20 });

  return (
    <motion.div
      ref={ref}
      className={`orb ${colorClasses[color]} ${sizeClasses[size]} absolute pointer-events-none ${className}`}
      style={{
        ...position,
        y,
        x,
        rotate,
        scale,
        opacity,
      }}
    />
  );
}

// Preset configurations for common orb placements
export const orbPresets = {
  // Hero section orbs
  heroTopRight: {
    color: "sage" as const,
    size: "xl" as const,
    position: { top: "-10%", right: "-10%" },
    speed: -80,
    opacity: 0.25,
  },
  heroBottomLeft: {
    color: "blue" as const,
    size: "lg" as const,
    position: { bottom: "20%", left: "-15%" },
    speed: -40,
    opacity: 0.2,
  },
  // Features section
  featuresTopLeft: {
    color: "sage" as const,
    size: "xl" as const,
    position: { top: "0", right: "25%" },
    speed: -60,
    opacity: 0.4,
  },
  featuresBottomRight: {
    color: "blue" as const,
    size: "md" as const,
    position: { bottom: "25%", left: "0" },
    speed: -30,
    opacity: 0.3,
  },
  // Personas section
  personasTopRight: {
    color: "blue" as const,
    size: "lg" as const,
    position: { top: "0", right: "-10%" },
    speed: -50,
    opacity: 0.2,
  },
  personasBottomLeft: {
    color: "sage" as const,
    size: "md" as const,
    position: { bottom: "25%", left: "-8%" },
    speed: -35,
    opacity: 0.2,
  },
  // Pricing section
  pricingTopRight: {
    color: "sage" as const,
    size: "xl" as const,
    position: { top: "-12%", right: "25%" },
    speed: -70,
    opacity: 0.3,
  },
  pricingBottomLeft: {
    color: "blue" as const,
    size: "md" as const,
    position: { bottom: "0", left: "25%" },
    speed: -25,
    opacity: 0.2,
  },
};
