"use client";

import { useRef, type ElementType, type ComponentPropsWithoutRef } from "react";
import SplitType from "split-type";
import { gsap, ScrollTrigger, useGSAP } from "@/lib/animation/gsap-config";
import {
  formaReveal,
  formaSettle,
  formaDuration,
  formaStagger,
} from "@/lib/animation/ease-curves";

type SplitTypeOption = "chars" | "words" | "lines" | "chars,words";
type AnimationType = "fadeUp" | "fadeIn" | "scaleIn" | "blur" | "rotate";

interface SplitTextProps {
  children: string;
  type?: SplitTypeOption;
  animation?: AnimationType;
  trigger?: React.RefObject<HTMLElement | null> | string;
  stagger?: number;
  duration?: number;
  delay?: number;
  scrub?: boolean | number;
  className?: string;
  as?: "div" | "span" | "p" | "h1" | "h2" | "h3" | "h4" | "h5" | "h6";
}

/**
 * Animation presets for split text elements
 */
const animationPresets: Record<
  AnimationType,
  { from: gsap.TweenVars; to: gsap.TweenVars }
> = {
  fadeUp: {
    from: { opacity: 0, y: 30 },
    to: { opacity: 1, y: 0 },
  },
  fadeIn: {
    from: { opacity: 0 },
    to: { opacity: 1 },
  },
  scaleIn: {
    from: { opacity: 0, scale: 0.8 },
    to: { opacity: 1, scale: 1 },
  },
  blur: {
    from: { opacity: 0, filter: "blur(10px)" },
    to: { opacity: 1, filter: "blur(0px)" },
  },
  rotate: {
    from: { opacity: 0, rotationX: 90, transformOrigin: "bottom center" },
    to: { opacity: 1, rotationX: 0 },
  },
};

/**
 * SplitText Component
 *
 * A text splitting animation component using SplitType and GSAP.
 * Splits text into chars, words, or lines and animates them with various effects.
 *
 * @example
 * ```tsx
 * <SplitText animation="fadeUp" type="words" stagger={0.05}>
 *   Organize your files with Forma
 * </SplitText>
 * ```
 */
export function SplitText({
  children,
  type = "chars",
  animation = "fadeUp",
  trigger,
  stagger = formaStagger.cascade,
  duration = formaDuration.normal,
  delay = 0,
  scrub = false,
  className,
  as = "div",
}: SplitTextProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const splitInstanceRef = useRef<SplitType | null>(null);

  useGSAP(
    () => {
      const container = containerRef.current;
      if (!container) return;

      // Check for reduced motion preference
      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (prefersReducedMotion) {
        // Skip animation entirely for reduced motion users
        return;
      }

      // Split the text
      splitInstanceRef.current = new SplitType(container, {
        types: type as "chars" | "words" | "lines" | "chars,words",
        tagName: "span",
      });

      // Determine which elements to animate based on split type
      let elements: Element[] = [];
      if (type.includes("chars") && splitInstanceRef.current.chars) {
        elements = splitInstanceRef.current.chars;
      } else if (type.includes("words") && splitInstanceRef.current.words) {
        elements = splitInstanceRef.current.words;
      } else if (type === "lines" && splitInstanceRef.current.lines) {
        elements = splitInstanceRef.current.lines;
      }

      if (elements.length === 0) return;

      const preset = animationPresets[animation];
      const ease = animation === "scaleIn" ? formaSettle : formaReveal;

      // Set initial state
      gsap.set(elements, preset.from);

      // Resolve trigger element
      const triggerElement = trigger
        ? typeof trigger === "string"
          ? trigger
          : trigger.current
        : container;

      // Create animation configuration
      const animationConfig: gsap.TweenVars = {
        ...preset.to,
        duration,
        delay,
        stagger,
        ease,
      };

      if (scrub !== false) {
        // Scroll-scrubbed animation
        gsap.to(elements, {
          ...animationConfig,
          scrollTrigger: {
            trigger: triggerElement,
            start: "top 80%",
            end: "top 30%",
            scrub: typeof scrub === "number" ? scrub : 1,
          },
        });
      } else {
        // Triggered animation
        gsap.to(elements, {
          ...animationConfig,
          scrollTrigger: {
            trigger: triggerElement,
            start: "top 85%",
            toggleActions: "play none none none",
          },
        });
      }

      // Cleanup function - revert SplitType on unmount
      return () => {
        if (splitInstanceRef.current) {
          splitInstanceRef.current.revert();
          splitInstanceRef.current = null;
        }
      };
    },
    { scope: containerRef, dependencies: [children, type, animation, scrub] }
  );

  // Render the appropriate element type
  const Tag = as;

  return (
    <Tag ref={containerRef as React.RefObject<HTMLDivElement>} className={className}>
      {children}
    </Tag>
  );
}

export default SplitText;
