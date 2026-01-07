"use client";

import { useRef, useEffect, useCallback } from "react";
import { gsap } from "@/lib/animation/gsap-config";
import { formaMagnetic, formaReveal, formaDuration } from "@/lib/animation/ease-curves";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";

interface UseTiltOptions {
  /** Maximum rotation angle in degrees (default 15) */
  maxRotation?: number;
  /** Perspective distance in pixels (default 1000) */
  perspective?: number;
  /** Animation duration in seconds */
  duration?: number;
  /** Whether the effect is enabled (false disables even with motion allowed) */
  enabled?: boolean;
  /** Whether to add a glare/shine effect */
  glare?: boolean;
  /** Scale on hover (1 = no scale, 1.05 = 5% larger) */
  scale?: number;
}

/**
 * Creates a 3D tilt effect that rotates an element based on cursor position.
 * The element tilts toward the cursor position and returns to flat on leave.
 *
 * @example
 * ```tsx
 * function TiltCard() {
 *   const tiltRef = useTilt({ maxRotation: 10, scale: 1.02 });
 *   return (
 *     <div ref={tiltRef} className="card">
 *       Hover to tilt
 *     </div>
 *   );
 * }
 * ```
 */
export function useTilt<T extends HTMLElement = HTMLDivElement>(
  options: UseTiltOptions = {}
) {
  const {
    maxRotation = 15,
    perspective = 1000,
    duration = formaDuration.normal,
    enabled = true,
    glare = false,
    scale = 1,
  } = options;

  const ref = useRef<T>(null);
  const animationRef = useRef<gsap.core.Tween | null>(null);
  const glareRef = useRef<HTMLDivElement | null>(null);

  // Create glare element if needed
  useEffect(() => {
    const element = ref.current;
    if (!element || !glare || !enabled) return;

    // Create glare overlay
    const glareElement = document.createElement("div");
    glareElement.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      pointer-events: none;
      background: linear-gradient(
        135deg,
        rgba(255, 255, 255, 0.25) 0%,
        rgba(255, 255, 255, 0) 60%
      );
      opacity: 0;
      border-radius: inherit;
    `;
    glareRef.current = glareElement;

    // Ensure parent has relative positioning
    const computedStyle = window.getComputedStyle(element);
    if (computedStyle.position === "static") {
      element.style.position = "relative";
    }
    element.style.overflow = "hidden";
    element.appendChild(glareElement);

    return () => {
      if (glareElement.parentNode) {
        glareElement.parentNode.removeChild(glareElement);
      }
      glareRef.current = null;
    };
  }, [glare, enabled]);

  const handleMouseMove = useCallback(
    (event: MouseEvent) => {
      const element = ref.current;
      if (!element || !enabled) return;

      const rect = element.getBoundingClientRect();

      // Calculate cursor position relative to element (0-1)
      const relativeX = (event.clientX - rect.left) / rect.width;
      const relativeY = (event.clientY - rect.top) / rect.height;

      // Convert to -1 to 1 range, centered at 0
      const normalizedX = relativeX * 2 - 1;
      const normalizedY = relativeY * 2 - 1;

      // Calculate rotation (inverted for natural feel)
      // Positive Y mouse position = negative rotateX (tilt away)
      // Positive X mouse position = positive rotateY (tilt right)
      const rotateX = -normalizedY * maxRotation;
      const rotateY = normalizedX * maxRotation;

      // Cancel any ongoing animation
      if (animationRef.current) {
        animationRef.current.kill();
      }

      // Animate to the new rotation with magnetic responsiveness
      animationRef.current = gsap.to(element, {
        rotateX,
        rotateY,
        transformPerspective: perspective,
        scale: scale,
        duration: duration * 0.5,
        ease: formaMagnetic,
        overwrite: "auto",
      });

      // Animate glare if enabled
      if (glareRef.current) {
        const glareAngle = Math.atan2(normalizedY, normalizedX) * (180 / Math.PI) + 135;
        const glareOpacity = Math.sqrt(normalizedX ** 2 + normalizedY ** 2) * 0.5;

        gsap.to(glareRef.current, {
          opacity: glareOpacity,
          background: `linear-gradient(${glareAngle}deg, rgba(255, 255, 255, 0.25) 0%, rgba(255, 255, 255, 0) 60%)`,
          duration: duration * 0.5,
          ease: formaMagnetic,
          overwrite: "auto",
        });
      }
    },
    [maxRotation, perspective, duration, enabled, scale]
  );

  const handleMouseLeave = useCallback(() => {
    const element = ref.current;
    if (!element || !enabled) return;

    // Cancel any ongoing animation
    if (animationRef.current) {
      animationRef.current.kill();
    }

    // Smoothly return to flat with reveal easing
    animationRef.current = gsap.to(element, {
      rotateX: 0,
      rotateY: 0,
      scale: 1,
      duration: duration,
      ease: formaReveal,
      overwrite: "auto",
    });

    // Fade out glare
    if (glareRef.current) {
      gsap.to(glareRef.current, {
        opacity: 0,
        duration: duration,
        ease: formaReveal,
        overwrite: "auto",
      });
    }
  }, [duration, enabled]);

  const handleMouseEnter = useCallback(() => {
    const element = ref.current;
    if (!element || !enabled) return;

    // Set initial transform style for 3D effect
    gsap.set(element, {
      transformStyle: "preserve-3d",
      transformPerspective: perspective,
    });
  }, [perspective, enabled]);

  useEffect(() => {
    const element = ref.current;
    if (!element || !enabled) return;

    // Check for reduced motion preference
    // This runs on mount and won't react to changes, but the component
    // using this hook should pass enabled=false when reduced motion is detected
    const reducedMotion = getReducedMotionValue();
    if (reducedMotion) {
      // Don't attach listeners or animate if reduced motion is preferred
      return;
    }

    // Set initial transform origin
    gsap.set(element, {
      transformOrigin: "center center",
      transformStyle: "preserve-3d",
    });

    // Create GSAP context for proper cleanup
    const ctx = gsap.context(() => {
      element.addEventListener("mouseenter", handleMouseEnter);
      element.addEventListener("mousemove", handleMouseMove);
      element.addEventListener("mouseleave", handleMouseLeave);
    });

    return () => {
      element.removeEventListener("mouseenter", handleMouseEnter);
      element.removeEventListener("mousemove", handleMouseMove);
      element.removeEventListener("mouseleave", handleMouseLeave);

      // Kill any ongoing animation and reset transforms
      if (animationRef.current) {
        animationRef.current.kill();
      }

      gsap.set(element, {
        rotateX: 0,
        rotateY: 0,
        scale: 1,
        clearProps: "transform",
      });

      ctx.revert();
    };
  }, [handleMouseEnter, handleMouseMove, handleMouseLeave, enabled]);

  return ref;
}

export default useTilt;
