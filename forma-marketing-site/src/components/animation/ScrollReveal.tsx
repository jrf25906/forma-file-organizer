"use client";

import { useRef, type ReactNode } from "react";
import { gsap, ScrollTrigger, useGSAP } from "@/lib/animation/gsap-config";
import { formaReveal, formaDuration, formaStagger } from "@/lib/animation/ease-curves";

type Direction = "up" | "down" | "left" | "right";

interface ScrollRevealProps {
  children: ReactNode;
  direction?: Direction;
  distance?: number;
  duration?: number;
  delay?: number;
  stagger?: number;
  scrub?: boolean | number;
  threshold?: number;
  className?: string;
  once?: boolean;
}

/**
 * Get initial transform values based on direction
 */
function getDirectionTransform(direction: Direction, distance: number) {
  switch (direction) {
    case "up":
      return { y: distance, x: 0 };
    case "down":
      return { y: -distance, x: 0 };
    case "left":
      return { x: distance, y: 0 };
    case "right":
      return { x: -distance, y: 0 };
    default:
      return { y: distance, x: 0 };
  }
}

/**
 * ScrollReveal Component
 *
 * A GSAP-powered scroll reveal wrapper that animates children when they enter the viewport.
 * Supports directional animations, stagger effects, and scroll-scrubbing.
 *
 * @example
 * ```tsx
 * <ScrollReveal direction="up" distance={50} stagger={0.1}>
 *   <Card>Content 1</Card>
 *   <Card>Content 2</Card>
 *   <Card>Content 3</Card>
 * </ScrollReveal>
 * ```
 */
export function ScrollReveal({
  children,
  direction = "up",
  distance = 50,
  duration = formaDuration.normal,
  delay = 0,
  stagger = 0,
  scrub = false,
  threshold = 95, // Higher threshold = triggers earlier when element enters viewport
  className,
  once = true,
}: ScrollRevealProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const container = containerRef.current;
      if (!container) return;

      // Check for reduced motion preference
      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (prefersReducedMotion) {
        // Ensure elements are visible but skip animation
        gsap.set(container.children, { opacity: 1, x: 0, y: 0 });
        return;
      }

      const { x, y } = getDirectionTransform(direction, distance);
      const elements = container.children;

      if (elements.length === 0) return;

      // Set initial state
      gsap.set(elements, {
        opacity: 0,
        x,
        y,
      });

      // Animation configuration
      const animationConfig: gsap.TweenVars = {
        opacity: 1,
        x: 0,
        y: 0,
        duration,
        delay: delay / 1000, // Convert ms to seconds for GSAP
        stagger: stagger > 0 ? stagger : undefined,
        ease: formaReveal,
      };

      // ScrollTrigger base config
      const scrollTriggerBase = {
        trigger: container,
        start: `top ${threshold}%`,
        invalidateOnRefresh: true, // Recalculate on resize/refresh
      };

      if (scrub !== false) {
        // Scroll-scrubbed animation
        gsap.to(elements, {
          ...animationConfig,
          scrollTrigger: {
            ...scrollTriggerBase,
            end: "top 20%",
            scrub: typeof scrub === "number" ? scrub : 1,
          },
        });
      } else {
        // Triggered animation - use onEnter to handle already-visible elements
        const trigger = ScrollTrigger.create({
          ...scrollTriggerBase,
          onEnter: () => {
            gsap.to(elements, animationConfig);
          },
          onRefresh: (self) => {
            // If element is already past the start point, show it immediately
            if (self.progress > 0) {
              gsap.set(elements, { opacity: 1, x: 0, y: 0 });
            }
          },
          once: once, // Only trigger once if once=true
        });

        // Cleanup
        return () => trigger.kill();
      }
    },
    { scope: containerRef, dependencies: [direction, distance, scrub, threshold, once] }
  );

  return (
    <div ref={containerRef} className={className}>
      {children}
    </div>
  );
}

export default ScrollReveal;
