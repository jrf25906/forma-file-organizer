"use client";

import React, { useRef, useEffect, useCallback, forwardRef } from "react";
import { gsap } from "@/lib/animation/gsap-config";
import { formaMagnetic, formaReveal } from "@/lib/animation/ease-curves";
import { cn } from "@/lib/utils";

interface HoverScaleProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Scale factor on hover (default 1.05) */
  scale?: number;
  /** Animation duration in seconds (default 0.3) */
  duration?: number;
  /** Additional CSS classes */
  className?: string;
  /** Whether the effect is enabled (default true) */
  enabled?: boolean;
  /** Children to render */
  children?: React.ReactNode;
}

/**
 * HoverScale - Simple hover scale effect wrapper
 *
 * Scales up the element on hover with spring easing and returns
 * to normal size with smooth easing on leave. Uses GSAP for
 * butter-smooth animation.
 *
 * @example
 * ```tsx
 * // Basic usage
 * <HoverScale>
 *   <button>Hover me</button>
 * </HoverScale>
 *
 * // Custom scale and duration
 * <HoverScale scale={1.1} duration={0.2}>
 *   <Card>
 *     <p>Interactive card</p>
 *   </Card>
 * </HoverScale>
 *
 * // Subtle scale for list items
 * <ul>
 *   {items.map((item) => (
 *     <HoverScale key={item.id} scale={1.02}>
 *       <li>{item.name}</li>
 *     </HoverScale>
 *   ))}
 * </ul>
 * ```
 */
export const HoverScale = forwardRef<HTMLDivElement, HoverScaleProps>(
  (
    {
      children,
      scale = 1.05,
      duration = 0.3,
      className,
      enabled = true,
      ...props
    },
    ref
  ) => {
    const containerRef = useRef<HTMLDivElement>(null);
    const tweenRef = useRef<gsap.core.Tween | null>(null);

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

    const handleMouseEnter = useCallback(() => {
      const element = containerRef.current;
      if (!element || !enabled) return;

      // Kill any ongoing animation
      if (tweenRef.current) {
        tweenRef.current.kill();
      }

      // Scale up with spring easing (magnetic responsiveness)
      tweenRef.current = gsap.to(element, {
        scale: scale,
        duration: duration,
        ease: formaMagnetic,
        overwrite: "auto",
      });
    }, [scale, duration, enabled]);

    const handleMouseLeave = useCallback(() => {
      const element = containerRef.current;
      if (!element || !enabled) return;

      // Kill any ongoing animation
      if (tweenRef.current) {
        tweenRef.current.kill();
      }

      // Return to normal with smooth easing
      tweenRef.current = gsap.to(element, {
        scale: 1,
        duration: duration,
        ease: formaReveal,
        overwrite: "auto",
      });
    }, [duration, enabled]);

    useEffect(() => {
      const element = containerRef.current;
      if (!element || !enabled) return;

      // Create GSAP context for proper cleanup
      const ctx = gsap.context(() => {
        // Set initial state
        gsap.set(element, { scale: 1 });

        element.addEventListener("mouseenter", handleMouseEnter);
        element.addEventListener("mouseleave", handleMouseLeave);
      });

      return () => {
        element.removeEventListener("mouseenter", handleMouseEnter);
        element.removeEventListener("mouseleave", handleMouseLeave);

        // Kill any ongoing animation
        if (tweenRef.current) {
          tweenRef.current.kill();
          tweenRef.current = null;
        }

        ctx.revert();
      };
    }, [handleMouseEnter, handleMouseLeave, enabled]);

    return (
      <div
        ref={combinedRef}
        className={cn(
          "inline-block",
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

HoverScale.displayName = "HoverScale";

export default HoverScale;
