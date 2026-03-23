"use client";

import { useRef, type ReactNode } from "react";
import { gsap, useGSAP } from "@/lib/animation/gsap-config";
import { formaReveal, formaDuration } from "@/lib/animation/ease-curves";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";

interface HeroEntranceProps {
  children: ReactNode;
  className?: string;
}

/**
 * HeroEntrance — orchestrates a staggered mount animation for the hero section.
 *
 * Direct children are animated in sequence using a GSAP timeline.
 * Tag each child with data-hero="eyebrow|headline|subtext|cta|window"
 * to control the animation order and style. Untagged children get a
 * default fade-up.
 *
 * Respects prefers-reduced-motion by showing everything instantly.
 */
export default function HeroEntrance({ children, className }: HeroEntranceProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const container = containerRef.current;
      if (!container) return;

      if (getReducedMotionValue()) {
        container.querySelectorAll("[data-hero]").forEach((el) => {
          gsap.set(el, { opacity: 1, y: 0, scale: 1 });
        });
        return;
      }

      const eyebrow = container.querySelector('[data-hero="eyebrow"]');
      const headline = container.querySelector('[data-hero="headline"]');
      const subtext = container.querySelector('[data-hero="subtext"]');
      const cta = container.querySelector('[data-hero="cta"]');
      const window = container.querySelector('[data-hero="window"]');

      // Set initial hidden states
      const allEls = [eyebrow, headline, subtext, cta, window].filter(Boolean);
      gsap.set(allEls, { opacity: 0 });
      if (eyebrow) gsap.set(eyebrow, { y: 10 });
      if (headline) gsap.set(headline, { y: 16 });
      if (subtext) gsap.set(subtext, { y: 12 });
      if (cta) gsap.set(cta, { y: 10, scale: 0.97 });
      if (window) gsap.set(window, { y: 16, scale: 0.99 });

      // Orchestrated timeline — total sequence under 900ms
      const tl = gsap.timeline({ delay: 0.05 });

      if (eyebrow) {
        tl.to(eyebrow, {
          opacity: 1,
          y: 0,
          duration: formaDuration.fast,
          ease: formaReveal,
        });
      }

      if (headline) {
        tl.to(
          headline,
          {
            opacity: 1,
            y: 0,
            duration: 0.5,
            ease: formaReveal,
          },
          "-=0.22"
        );
      }

      if (subtext) {
        tl.to(
          subtext,
          {
            opacity: 1,
            y: 0,
            duration: 0.4,
            ease: formaReveal,
          },
          "-=0.3"
        );
      }

      if (cta) {
        tl.to(
          cta,
          {
            opacity: 1,
            y: 0,
            scale: 1,
            duration: 0.35,
            ease: formaReveal,
          },
          "-=0.2"
        );
      }

      if (window) {
        tl.to(
          window,
          {
            opacity: 1,
            y: 0,
            scale: 1,
            duration: 0.6,
            ease: formaReveal,
          },
          "-=0.3"
        );
      }
    },
    { scope: containerRef }
  );

  return (
    <div ref={containerRef} className={className}>
      {children}
    </div>
  );
}
