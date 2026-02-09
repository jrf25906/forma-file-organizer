"use client";

import { useRef } from "react";
import Image from "next/image";
import MacWindowFrame from "@/components/ui/MacWindowFrame";
import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";
import { MagneticButton } from "@/components/animation/MagneticButton";
import { gsap, useGSAP } from "@/lib/animation";
import { AppleLogo } from "@/components/icons";

function AppScreenshot() {
  return (
    <Image
      src="/screenshots/light/forma-01-hero-main-window.png"
      alt="Forma app main window showing file organization rules and preview"
      width={1280}
      height={800}
      className="w-full h-auto"
      sizes="(max-width: 768px) 100vw, 980px"
      priority
    />
  );
}

export default function HeroSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const headlineRef = useRef<HTMLHeadingElement>(null);
  const subtitleRef = useRef<HTMLParagraphElement>(null);
  const ctaRef = useRef<HTMLDivElement>(null);
  const metaRef = useRef<HTMLParagraphElement>(null);

  // Simple mount animation for above-fold content (no ScrollTrigger)
  useGSAP(
    () => {
      if (!sectionRef.current) return;

      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (prefersReducedMotion) {
        gsap.set([headlineRef.current, subtitleRef.current, ctaRef.current, metaRef.current], {
          opacity: 1,
          y: 0,
        });
        return;
      }

      // Staggered entrance on mount
      const tl = gsap.timeline({ delay: 0.1 });

      tl.fromTo(
        headlineRef.current,
        { opacity: 0, y: 30 },
        { opacity: 1, y: 0, duration: 0.8, ease: "power3.out" }
      )
        .fromTo(
          subtitleRef.current,
          { opacity: 0, y: 20 },
          { opacity: 1, y: 0, duration: 0.6, ease: "power3.out" },
          "-=0.4"
        )
        .fromTo(
          ctaRef.current,
          { opacity: 0, y: 20 },
          { opacity: 1, y: 0, duration: 0.6, ease: "power3.out" },
          "-=0.3"
        )
        .fromTo(
          metaRef.current,
          { opacity: 0 },
          { opacity: 1, duration: 0.4, ease: "power2.out" },
          "-=0.2"
        );
    },
    { scope: sectionRef }
  );

  return (
    <section ref={sectionRef} className="relative pt-16 pb-16 md:pt-20 md:pb-20">

      <div className="site-container relative">
        <div className="mx-auto max-w-[820px] text-center">
          <h1
            ref={headlineRef}
            className="mx-auto max-w-[720px] font-display text-[2.75rem] leading-[1.08] tracking-[-0.025em] text-forma-obsidian text-balance sm:text-[3.5rem] lg:text-[4.25rem] opacity-0"
          >
            A file organizer for people who gave up on file organizers.
          </h1>

          <p
            ref={subtitleRef}
            className="mx-auto mt-6 max-w-[580px] text-lg leading-relaxed text-forma-obsidian/60 md:text-[1.2rem] opacity-0"
          >
            You make rules. Forma follows them. Preview what happens,
            approve it, undo anything.
          </p>

          <div ref={ctaRef} className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row opacity-0">
            <MagneticButton strength={0.25}>
              <a
                href={MAC_APP_STORE_URL}
                {...MAC_APP_STORE_LINK_PROPS}
                className="inline-flex items-center gap-2.5 rounded-xl bg-forma-obsidian px-8 py-3.5 text-[16px] font-semibold text-forma-bone shadow-lg shadow-black/10 transition-all duration-300 hover:bg-forma-obsidian/90 hover:-translate-y-px hover:shadow-xl hover:shadow-black/15 active:translate-y-0"
              >
                <AppleLogo className="h-[15px] w-[12px]" />
                <span>Download for Mac</span>
              </a>
            </MagneticButton>

            <MagneticButton strength={0.2}>
              <a
                href="#features"
                className="inline-flex items-center gap-2 rounded-xl border border-black/[0.12] px-8 py-3.5 text-[16px] font-medium text-forma-obsidian/70 transition-colors hover:text-forma-obsidian hover:border-black/[0.22]"
              >
                See how it works
              </a>
            </MagneticButton>
          </div>

          <p
            ref={metaRef}
            className="mt-5 border-t border-black/[0.04] pt-3 text-[13px] text-forma-obsidian/50 inline-block opacity-0"
          >
            $29 once. macOS 14+. No subscription.
          </p>
        </div>

        <div className="relative mx-auto mt-14 max-w-[980px] md:mt-16">
          {/* Decorative orbs behind screenshot */}
          <div className="pointer-events-none absolute inset-0" aria-hidden="true">
            <div className="absolute -left-20 top-1/4 h-72 w-72 rounded-full bg-forma-steel-blue/20 blur-[80px] animate-float" />
            <div className="absolute -right-16 top-1/3 h-64 w-64 rounded-full bg-forma-sage/15 blur-[80px] animate-float-slower" />
          </div>

          <div className="app-mockup-glow rounded-2xl border border-black/[0.08] bg-white/80 p-1.5 shadow-[0_0_0_1px_rgba(0,0,0,0.03),0_2px_4px_rgba(0,0,0,0.04),0_12px_32px_rgba(0,0,0,0.08),0_32px_80px_rgba(0,0,0,0.12)] backdrop-blur-sm md:rounded-[20px] md:p-2">
            <MacWindowFrame className="w-full">
              <AppScreenshot />
            </MacWindowFrame>
          </div>
        </div>
      </div>
    </section>
  );
}
