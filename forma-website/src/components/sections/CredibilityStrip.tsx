"use client";

import { useRef } from "react";
import { Monitor, Shield, Undo2 } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration, formaStagger } from "@/lib/animation";

// ═══════════════════════════════════════════════════════════════════════════
// BADGE DATA
// ═══════════════════════════════════════════════════════════════════════════

const badges = [
  {
    icon: Monitor,
    label: "Mac-Native",
    description: "Built with Swift for macOS",
  },
  {
    icon: Shield,
    label: "Privacy-First",
    description: "Your files never leave your Mac",
  },
  {
    icon: Undo2,
    label: "Always Reversible",
    description: "Undo any move, anytime",
  },
] as const;

// ═══════════════════════════════════════════════════════════════════════════
// CREDIBILITY STRIP
// ═══════════════════════════════════════════════════════════════════════════

export default function CredibilityStrip() {
  const enableScrollAnimations = true;
  const sectionRef = useRef<HTMLElement>(null);
  const badgesRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (!enableScrollAnimations) return;

      const section = sectionRef.current;
      const container = badgesRef.current;
      if (!section || !container) return;

      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      const badgeElements = container.querySelectorAll("[data-badge]");

      if (prefersReducedMotion) {
        gsap.set(badgeElements, { opacity: 1, y: 0 });
        return;
      }

      // Initial hidden state
      gsap.set(badgeElements, {
        opacity: 0,
        y: 24,
      });

      // Scroll-triggered staggered reveal
      const tl = gsap.timeline({
        scrollTrigger: {
          trigger: section,
          start: "top 85%",
          toggleActions: "play none none none",
        },
      });

      tl.to(badgeElements, {
        opacity: 1,
        y: 0,
        duration: formaDuration.fast,
        stagger: formaStagger.normal,
        ease: formaReveal,
      });

      return () => {
        tl.kill();
      };
    },
    { scope: sectionRef }
  );

  return (
    <section
      ref={sectionRef}
      id="credibility"
      className="relative py-8 md:py-12"
      aria-label="Why trust Forma"
    >
      <div className="site-container relative">
        <div
          ref={badgesRef}
          className="mx-auto flex max-w-3xl flex-col items-center justify-center gap-6 sm:flex-row sm:gap-10 md:gap-14"
        >
          {badges.map(({ icon: Icon, label, description }) => (
            <div
              key={label}
              data-badge
              className="flex items-center gap-3"
            >
              <Icon
                className="w-4 h-4 text-forma-obsidian/40 flex-shrink-0"
                strokeWidth={1.75}
              />
              <div className="flex flex-col">
                <span className="text-[13px] font-medium text-forma-obsidian/80 tracking-tight whitespace-nowrap">
                  {label}
                </span>
                <span className="text-[11px] text-forma-obsidian/50 leading-snug">
                  {description}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
