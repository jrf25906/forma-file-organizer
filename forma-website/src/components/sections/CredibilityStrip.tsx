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
      className="relative py-10 md:py-14"
      aria-label="Why trust Forma"
    >
      <div className="site-container relative">
        <div
          ref={badgesRef}
          className="mx-auto flex max-w-3xl flex-col items-center justify-center gap-5 sm:flex-row sm:gap-6 md:gap-8"
        >
          {badges.map(({ icon: Icon, label, description }) => (
            <div
              key={label}
              data-badge
              className="flex items-center gap-3.5 rounded-xl border border-black/[0.06] bg-white/80 px-5 py-3.5 shadow-sm"
            >
              <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-forma-steel-blue/10 flex-shrink-0">
                <Icon
                  className="w-[18px] h-[18px] text-forma-steel-blue"
                  strokeWidth={1.75}
                />
              </div>
              <div className="flex flex-col">
                <span className="text-[14px] font-semibold text-forma-obsidian tracking-tight whitespace-nowrap">
                  {label}
                </span>
                <span className="text-[12px] text-forma-obsidian/55 leading-snug">
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
