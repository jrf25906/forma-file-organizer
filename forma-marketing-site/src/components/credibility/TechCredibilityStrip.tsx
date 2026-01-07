"use client";

import { useRef, useEffect } from "react";
import { gsap, ScrollTrigger } from "@/lib/animation/gsap-config";
import { useReducedMotion } from "@/hooks/use-reduced-motion";
import { AnimatedCredentialBadge } from "./AnimatedCredentialBadge";
import { MonitorNativeIcon, ShieldPrivateIcon, BoltInstantIcon } from "./icons";

/**
 * TechCredibilityStrip - Premium animated tech credentials
 *
 * Three credentials that scroll-reveal with choreographed DrawSVG animations:
 * 1. Mac-Native (Not Electron)
 * 2. Private (Stays Local)
 * 3. Instant (Zero Delay)
 *
 * Features:
 * - Staggered entrance animations
 * - DrawSVG icons that "draw themselves"
 * - SplitText character wave on hover
 * - Hint text reveals on interaction
 */
export function TechCredibilityStrip() {
  const containerRef = useRef<HTMLDivElement>(null);
  const badgesRef = useRef<HTMLDivElement>(null);
  const reducedMotion = useReducedMotion();

  const credentials = [
    {
      Icon: MonitorNativeIcon,
      label: "Mac-Native",
      hint: "Not another Electron app",
      color: "#5B7C99", // forma-steel-blue
    },
    {
      Icon: ShieldPrivateIcon,
      label: "Private",
      hint: "Your files never leave your Mac",
      color: "#7A9D7E", // forma-sage
    },
    {
      Icon: BoltInstantIcon,
      label: "Instant",
      hint: "Zero startup delay",
      color: "#C97E66", // forma-warm-orange (but softer)
    },
  ];

  // Staggered container entrance
  useEffect(() => {
    const container = containerRef.current;
    const badges = badgesRef.current;
    if (!container || !badges || reducedMotion) return;

    // Get all badge wrappers
    const badgeElements = badges.querySelectorAll("[data-badge]");

    // Initial state - slightly faded and offset
    gsap.set(badgeElements, {
      opacity: 0,
      y: 20,
    });

    // Create scroll-triggered staggered entrance
    const tl = gsap.timeline({
      scrollTrigger: {
        trigger: container,
        start: "top 85%",
        toggleActions: "play none none none",
      },
    });

    tl.to(badgeElements, {
      opacity: 1,
      y: 0,
      duration: 0.6,
      stagger: 0.12,
      ease: "power2.out",
    });

    return () => {
      tl.kill();
    };
  }, [reducedMotion]);

  return (
    <section
      ref={containerRef}
      className="relative py-8 md:py-10 px-6 overflow-hidden"
      aria-label="Technical credentials"
    >
      {/* Subtle animated grid background */}
      <div className="absolute inset-0 pointer-events-none opacity-[0.03]">
        <div
          className="absolute inset-0"
          style={{
            backgroundImage: `linear-gradient(to right, currentColor 1px, transparent 1px), linear-gradient(to bottom, currentColor 1px, transparent 1px)`,
            backgroundSize: '40px 40px',
            maskImage: 'radial-gradient(circle at center, black 40%, transparent 80%)'
          }}
        />
      </div>

      {/* Radial glows */}
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          background: `
            radial-gradient(ellipse 80% 50% at 20% 50%, rgba(91, 124, 153, 0.08) 0%, transparent 60%),
            radial-gradient(ellipse 60% 40% at 80% 50%, rgba(122, 157, 126, 0.06) 0%, transparent 60%)
          `,
        }}
      />

      <div className="relative max-w-6xl mx-auto">
        {/* Badges container - larger gaps for prominent badges */}
        <div
          ref={badgesRef}
          className="flex flex-col sm:flex-row items-center justify-center gap-6 sm:gap-8 md:gap-10"
        >
          {credentials.map((cred, index) => (
            <div key={cred.label} data-badge className="relative">
              <AnimatedCredentialBadge
                Icon={cred.Icon}
                label={cred.label}
                hint={cred.hint}
                iconColor={cred.color}
                staggerDelay={index * 0.15}
              />
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export default TechCredibilityStrip;
