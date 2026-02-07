"use client";

import { useRef } from "react";
import { gsap, useGSAP } from "@/lib/animation/gsap-config";
import { cn } from "@/lib/utils";

interface RevealTextProps {
  /** The text string to animate word-by-word */
  children: string;
  /** Additional CSS classes */
  className?: string;
  /** Delay before animation starts in seconds */
  delay?: number;
  /** Viewport threshold for ScrollTrigger (0-1, default 0.2) */
  threshold?: number;
}

/**
 * RevealText - Word-by-word scroll-triggered text reveal
 *
 * Splits text by spaces and wraps each word in an overflow-hidden span.
 * Animates each word from y:100% + opacity:0 to y:0% + opacity:1 with
 * 0.04s stagger between words. Uses ScrollTrigger with toggleActions
 * "play none none reverse" so the animation reverses when scrolling back.
 *
 * @example
 * ```tsx
 * <RevealText className="text-4xl font-display">
 *   Your files, intelligently organized
 * </RevealText>
 * ```
 */
export function RevealText({
  children,
  className,
  delay = 0,
  threshold = 0.2,
}: RevealTextProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const words = children.split(" ");

  useGSAP(
    () => {
      const container = containerRef.current;
      if (!container) return;

      const wordElements = container.querySelectorAll(".word");

      gsap.fromTo(
        wordElements,
        {
          y: "100%",
          opacity: 0,
        },
        {
          y: "0%",
          opacity: 1,
          duration: 1.0,
          stagger: 0.04,
          ease: "power3.out",
          delay,
          scrollTrigger: {
            trigger: container,
            start: `top ${100 - threshold * 100}%`,
            toggleActions: "play none none reverse",
          },
        }
      );
    },
    { scope: containerRef }
  );

  return (
    <div
      ref={containerRef}
      className={cn(
        "flex flex-wrap gap-x-[0.25em] overflow-hidden pb-[0.2em] -mb-[0.2em]",
        className
      )}
      aria-label={children}
    >
      {words.map((word, i) => (
        <span key={i} className="relative overflow-hidden inline-block">
          <span className="word inline-block relative translate-y-full opacity-0">
            {word}
          </span>
        </span>
      ))}
    </div>
  );
}

export default RevealText;
