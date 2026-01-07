"use client";

import { useRef, type ReactNode } from "react";
import { gsap, ScrollTrigger, useGSAP } from "@/lib/animation/gsap-config";

interface ParallaxLayerProps {
  children: ReactNode;
  speed?: number;
  className?: string;
  direction?: "vertical" | "horizontal";
}

/**
 * ParallaxLayer Component
 *
 * A parallax container that moves at different speeds relative to scroll.
 * Uses GSAP ScrollTrigger scrub for smooth, performant parallax effects.
 *
 * Speed values:
 * - speed < 1: Element moves slower than scroll (lags behind)
 * - speed = 1: Element moves with scroll (no parallax)
 * - speed > 1: Element moves faster than scroll (rushes ahead)
 * - speed < 0: Element moves in opposite direction to scroll
 *
 * @example
 * ```tsx
 * <div className="relative">
 *   <ParallaxLayer speed={0.5} className="absolute inset-0">
 *     <img src="/background.jpg" alt="" />
 *   </ParallaxLayer>
 *   <ParallaxLayer speed={1.2}>
 *     <h1>Fast moving text</h1>
 *   </ParallaxLayer>
 * </div>
 * ```
 */
export function ParallaxLayer({
  children,
  speed = 0.5,
  className,
  direction = "vertical",
}: ParallaxLayerProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const container = containerRef.current;
      const content = contentRef.current;
      if (!container || !content) return;

      // Check for reduced motion preference
      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (prefersReducedMotion) {
        // Skip parallax animation for reduced motion users
        return;
      }

      // Calculate the movement distance based on speed
      // A speed of 0.5 means element moves at half the scroll rate
      // A speed of -0.5 means element moves opposite at half rate
      const scrollDistance = window.innerHeight;
      const movementFactor = 1 - speed;
      const moveDistance = scrollDistance * movementFactor * 0.5;

      // Set up the animation properties based on direction
      const animationProps =
        direction === "vertical"
          ? { y: -moveDistance }
          : { x: -moveDistance };

      // Create the parallax scroll animation
      gsap.to(content, {
        ...animationProps,
        ease: "none",
        scrollTrigger: {
          trigger: container,
          start: "top bottom",
          end: "bottom top",
          scrub: true,
          invalidateOnRefresh: true,
        },
      });

      // Handle resize to recalculate distances
      const handleResize = () => {
        ScrollTrigger.refresh();
      };

      window.addEventListener("resize", handleResize);

      return () => {
        window.removeEventListener("resize", handleResize);
      };
    },
    { scope: containerRef, dependencies: [speed, direction] }
  );

  return (
    <div ref={containerRef} className={className}>
      <div ref={contentRef} className="will-change-transform">
        {children}
      </div>
    </div>
  );
}

export default ParallaxLayer;
