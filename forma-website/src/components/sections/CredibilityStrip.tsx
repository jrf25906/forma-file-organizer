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
  const sectionRef = useRef<HTMLElement>(null);
  const badgesRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
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
      className="relative py-12 md:py-16 px-6 overflow-hidden"
      aria-label="Why trust Forma"
    >
      <div className="relative max-w-4xl mx-auto">
        <div
          ref={badgesRef}
          className="flex flex-col sm:flex-row items-center justify-center gap-4 sm:gap-5 md:gap-6"
        >
          {badges.map(({ icon: Icon, label, description }) => (
            <div
              key={label}
              data-badge
              className="group relative flex items-center gap-3.5 rounded-2xl bg-white/5 border border-forma-bone/10 px-5 py-4 backdrop-blur-sm transition-colors duration-300 hover:bg-white/[0.08] hover:border-forma-bone/15"
            >
              {/* Icon circle */}
              <div className="flex items-center justify-center w-10 h-10 rounded-xl bg-forma-steel-blue/10 border border-forma-steel-blue/15 transition-transform duration-300 group-hover:scale-105">
                <Icon
                  className="w-5 h-5 text-forma-steel-blue"
                  strokeWidth={1.75}
                />
              </div>

              {/* Text */}
              <div className="flex flex-col">
                <span className="text-sm font-display font-medium text-forma-bone tracking-tight">
                  {label}
                </span>
                <span className="text-xs text-forma-bone/60 leading-snug mt-0.5">
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
