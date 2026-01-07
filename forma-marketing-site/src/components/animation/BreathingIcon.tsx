"use client";

import React, { useRef, useEffect, forwardRef } from "react";
import { gsap } from "@/lib/animation/gsap-config";
import { useReducedMotion } from "@/hooks/use-reduced-motion";
import { cn } from "@/lib/utils";

interface BreathingIconProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Maximum scale during the breathing animation (default 1.05) */
  scale?: number;
  /** Duration of one breath cycle in seconds (default 2) */
  duration?: number;
  /** Delay before starting the animation for staggering (default 0) */
  delay?: number;
  /** Additional CSS classes */
  className?: string;
  /** Whether the animation is enabled (overrides reduced motion check) */
  enabled?: boolean;
  /** Children to render (typically an icon) */
  children?: React.ReactNode;
}

/**
 * BreathingIcon - Ambient breathing animation for icons
 *
 * Creates a subtle scale/opacity pulse animation that gives icons
 * a living, organic feel. The animation uses sine easing for smooth,
 * natural movement and pauses when not visible to save resources.
 *
 * Accessibility: Automatically disables when user prefers reduced motion,
 * as continuous looping animations can be distracting or uncomfortable
 * for users with vestibular disorders.
 *
 * @example
 * ```tsx
 * // Basic usage
 * <BreathingIcon>
 *   <CheckCircleIcon />
 * </BreathingIcon>
 *
 * // Staggered icons in a row
 * <div className="flex gap-4">
 *   <BreathingIcon delay={0}>
 *     <Icon1 />
 *   </BreathingIcon>
 *   <BreathingIcon delay={0.3}>
 *     <Icon2 />
 *   </BreathingIcon>
 *   <BreathingIcon delay={0.6}>
 *     <Icon3 />
 *   </BreathingIcon>
 * </div>
 *
 * // Custom timing
 * <BreathingIcon scale={1.1} duration={3}>
 *   <StatusIcon />
 * </BreathingIcon>
 * ```
 */
export const BreathingIcon = forwardRef<HTMLDivElement, BreathingIconProps>(
  (
    {
      children,
      scale = 1.05,
      duration = 2,
      delay = 0,
      className,
      enabled,
      ...props
    },
    ref
  ) => {
    const containerRef = useRef<HTMLDivElement>(null);
    const tweenRef = useRef<gsap.core.Tween | null>(null);
    const observerRef = useRef<IntersectionObserver | null>(null);

    // Check if user prefers reduced motion
    const reducedMotion = useReducedMotion();

    // Determine if animation should be enabled
    // If enabled prop is explicitly set, use it; otherwise, disable for reduced motion
    const shouldAnimate = enabled !== undefined ? enabled : !reducedMotion;

    // Combine refs
    const combinedRef = (node: HTMLDivElement | null) => {
      (containerRef as React.MutableRefObject<HTMLDivElement | null>).current =
        node;
      if (typeof ref === "function") {
        ref(node);
      } else if (ref) {
        ref.current = node;
      }
    };

    useEffect(() => {
      const element = containerRef.current;
      if (!element || !shouldAnimate) return;

      // Create the breathing animation
      const ctx = gsap.context(() => {
        tweenRef.current = gsap.to(element, {
          scale: scale,
          opacity: 0.85,
          duration: duration,
          delay: delay,
          ease: "sine.inOut",
          repeat: -1,
          yoyo: true,
          paused: true, // Start paused, let IntersectionObserver control
        });
      });

      // Create IntersectionObserver to pause/resume based on visibility
      observerRef.current = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (tweenRef.current) {
              if (entry.isIntersecting) {
                tweenRef.current.play();
              } else {
                tweenRef.current.pause();
              }
            }
          });
        },
        {
          threshold: 0.1,
          rootMargin: "50px",
        }
      );

      observerRef.current.observe(element);

      return () => {
        // Cleanup
        if (observerRef.current) {
          observerRef.current.disconnect();
          observerRef.current = null;
        }

        if (tweenRef.current) {
          tweenRef.current.kill();
          tweenRef.current = null;
        }

        ctx.revert();
      };
    }, [scale, duration, delay, shouldAnimate]);

    // If animation is disabled (either explicitly or via reduced motion),
    // render children without animation wrapper overhead
    if (!shouldAnimate) {
      return (
        <div
          ref={combinedRef}
          className={cn("inline-flex items-center justify-center", className)}
          {...props}
        >
          {children}
        </div>
      );
    }

    return (
      <div
        ref={combinedRef}
        className={cn(
          "inline-flex items-center justify-center",
          "will-change-transform",
          className
        )}
        {...props}
      >
        {children}
      </div>
    );
  }
);

BreathingIcon.displayName = "BreathingIcon";

export default BreathingIcon;
