"use client";

import { useRef, useEffect, useCallback, Suspense } from "react";
import dynamic from "next/dynamic";
import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";
import { MagneticButton } from "@/components/animation/MagneticButton";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration, formaStagger } from "@/lib/animation/ease-curves";
import { ScrollScene, useScrollSceneProgress } from "@/components/animation/ScrollScene";
import { TextReveal } from "@/components/animation/TextReveal";
import { AppleLogo } from "@/components/icons";
import { useWebGLAvailable } from "@/hooks/use-webgl-available";
import { FileParticleSceneFallback } from "@/components/three/FileParticleSceneFallback";

const FileParticleScene = dynamic(
  () => import("@/components/three/FileParticleScene"),
  { ssr: false },
);

// ---------------------------------------------------------------------------
// Utility: clamp and remap helpers for progress-based animation math
// ---------------------------------------------------------------------------
function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}

/** Maps progress within [start, end] to [0, 1], clamped */
function remap(progress: number, start: number, end: number) {
  return clamp((progress - start) / (end - start), 0, 1);
}

// ---------------------------------------------------------------------------
// HeroContent - reads scroll progress from ScrollScene context and drives
// three animation beats via gsap.set for maximum smoothness.
// ---------------------------------------------------------------------------
function HeroContent() {
  const progress = useScrollSceneProgress();
  const webGLAvailable = useWebGLAvailable();

  // Refs for scroll-driven transforms
  const textBlockRef = useRef<HTMLDivElement>(null);
  const subtitleRef = useRef<HTMLParagraphElement>(null);
  const ctaRef = useRef<HTMLDivElement>(null);
  const metaRef = useRef<HTMLParagraphElement>(null);
  const showcaseRef = useRef<HTMLDivElement>(null);
  const orb1Ref = useRef<HTMLDivElement>(null);
  const orb2Ref = useRef<HTMLDivElement>(null);

  // Refs for mount animation targets (headline is handled by TextReveal)
  const mountSubtitleRef = useRef<HTMLParagraphElement>(null);
  const mountCtaRef = useRef<HTMLDivElement>(null);
  const mountMetaRef = useRef<HTMLParagraphElement>(null);

  // Mount animation: staggered entrance for above-fold content (runs once)
  useGSAP(
    () => {
      if (!mountSubtitleRef.current) return;

      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (prefersReducedMotion) {
        gsap.set(
          [mountSubtitleRef.current, mountCtaRef.current, mountMetaRef.current],
          { opacity: 1, y: 0 }
        );
        return;
      }

      // TextReveal handles headline animation independently.
      // We animate subtitle, CTA, and meta with a stagger timed after the
      // headline reveal (TextReveal uses ~0.6s total for word stagger).
      const tl = gsap.timeline({ delay: 0.55 });

      tl.fromTo(
        mountSubtitleRef.current,
        { opacity: 0, y: 20 },
        { opacity: 1, y: 0, duration: formaDuration.normal, ease: formaReveal },
      )
        .fromTo(
          mountCtaRef.current,
          { opacity: 0, y: 20 },
          { opacity: 1, y: 0, duration: formaDuration.normal, ease: formaReveal },
          `-=${formaDuration.normal * 0.5}`
        )
        .fromTo(
          mountMetaRef.current,
          { opacity: 0 },
          { opacity: 1, duration: formaDuration.fast, ease: formaReveal },
          `-=${formaDuration.fast * 0.6}`
        );
    },
    { dependencies: [] }
  );

  // Scroll-driven animation: reacts to progress 0-1 from ScrollScene
  useEffect(() => {
    if (
      !textBlockRef.current ||
      !showcaseRef.current ||
      !orb1Ref.current ||
      !orb2Ref.current
    ) {
      return;
    }

    // -----------------------------------------------------------------------
    // Beat 1 (progress 0.0 - 0.3): Hero text fully visible, showcase at rest
    // Beat 2 (progress 0.3 - 0.7): Text exits up/fades, showcase scales up
    // Beat 3 (progress 0.7 - 1.0): Showcase settles, prepares for unpin
    // -----------------------------------------------------------------------

    // --- Text block: fade out and translate up during Beat 2 ---
    const textFadeStart = 0.2;
    const textFadeEnd = 0.45;
    const textFadeProgress = remap(progress, textFadeStart, textFadeEnd);
    const textOpacity = 1 - textFadeProgress;
    const textY = -textFadeProgress * 120; // translate up 120px max

    gsap.set(textBlockRef.current, {
      opacity: textOpacity,
      y: textY,
      pointerEvents: textOpacity < 0.1 ? "none" : "auto",
    });

    // --- Showcase: scale from resting to center stage, then settle ---
    const showcaseGrowStart = 0.2;
    const showcaseGrowEnd = 0.65;
    const showcaseSettleStart = 0.8;
    const showcaseSettleEnd = 1.0;

    const growProgress = remap(progress, showcaseGrowStart, showcaseGrowEnd);
    const settleProgress = remap(progress, showcaseSettleStart, showcaseSettleEnd);

    // Scale: 0.85 -> 1.0 during grow, then 1.0 -> 0.92 during settle
    const growScale = 0.85 + growProgress * 0.15;
    const settleScale = 1.0 - settleProgress * 0.08;
    const showcaseScale = progress < showcaseSettleStart ? growScale : settleScale;

    // Translate showcase upward as text exits to take center stage
    const showcaseY = -growProgress * 60;

    // Opacity: slight fade during settle to ease into next section
    const showcaseOpacity = 1 - settleProgress * 0.3;

    gsap.set(showcaseRef.current, {
      scale: showcaseScale,
      y: showcaseY,
      opacity: showcaseOpacity,
    });

    // --- Orbs: parallax intensifies with progress ---
    const orbDrift = progress * 40;
    const orbScale = 1 + progress * 0.25;

    gsap.set(orb1Ref.current, {
      x: -orbDrift * 0.6,
      y: -orbDrift * 0.8,
      scale: orbScale,
      opacity: 0.2 + progress * 0.15,
    });

    gsap.set(orb2Ref.current, {
      x: orbDrift * 0.5,
      y: -orbDrift * 0.4,
      scale: orbScale * 0.95,
      opacity: 0.15 + progress * 0.2,
    });
  }, [progress]);

  // Assign refs to both the mount animation target and the scroll-driven
  // target. The mount animation refs handle initial opacity:0 -> 1. The
  // textBlockRef wraps everything for the scroll-driven fade-out.
  const setSubtitleRefs = useCallback((el: HTMLParagraphElement | null) => {
    (subtitleRef as React.MutableRefObject<HTMLParagraphElement | null>).current = el;
    (mountSubtitleRef as React.MutableRefObject<HTMLParagraphElement | null>).current = el;
  }, []);

  const setCtaRefs = useCallback((el: HTMLDivElement | null) => {
    (ctaRef as React.MutableRefObject<HTMLDivElement | null>).current = el;
    (mountCtaRef as React.MutableRefObject<HTMLDivElement | null>).current = el;
  }, []);

  const setMetaRefs = useCallback((el: HTMLParagraphElement | null) => {
    (metaRef as React.MutableRefObject<HTMLParagraphElement | null>).current = el;
    (mountMetaRef as React.MutableRefObject<HTMLParagraphElement | null>).current = el;
  }, []);

  return (
    <section className="relative min-h-screen flex flex-col justify-start pt-16 pb-16 md:pt-20 md:pb-20 overflow-hidden">
      <div className="site-container relative">
        {/* Text block - wrapped for scroll-driven fade/translate */}
        <div ref={textBlockRef} className="mx-auto max-w-[820px] text-center will-change-[transform,opacity]">
          <TextReveal
            as="h1"
            type="words"
            stagger={formaStagger.fast}
            className="mx-auto max-w-[720px] font-display text-[2.75rem] leading-[1.08] tracking-[-0.025em] text-[var(--text-primary)] text-balance sm:text-[3.5rem] lg:text-[4.25rem]"
          >
            A file organizer for people who gave up on file organizers.
          </TextReveal>

          <p
            ref={setSubtitleRefs}
            className="mx-auto mt-6 max-w-[580px] text-lg leading-relaxed text-[var(--text-secondary)] md:text-[1.2rem] opacity-0"
          >
            You make rules. Forma follows them. Preview what happens,
            approve it, undo anything.
          </p>

          <div
            ref={setCtaRefs}
            className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row opacity-0"
          >
            <MagneticButton strength={0.25}>
              <a
                href={MAC_APP_STORE_URL}
                {...MAC_APP_STORE_LINK_PROPS}
                className="inline-flex items-center gap-2.5 rounded-xl bg-[#F0F0F2] px-8 py-3.5 text-[16px] font-semibold text-[#0A0A0B] shadow-lg shadow-black/30 transition-all duration-300 hover:bg-[#E0E0E2] hover:-translate-y-px hover:shadow-xl hover:shadow-black/40 active:translate-y-0"
              >
                <AppleLogo className="h-[15px] w-[12px]" />
                <span>Download for Mac</span>
              </a>
            </MagneticButton>

            <MagneticButton strength={0.2}>
              <a
                href="#features"
                className="inline-flex items-center gap-2 rounded-xl border border-white/[0.12] px-8 py-3.5 text-[16px] font-medium text-[var(--text-secondary)] transition-colors hover:text-[var(--text-primary)] hover:border-white/[0.22]"
              >
                See how it works
              </a>
            </MagneticButton>
          </div>

          <p
            ref={setMetaRefs}
            className="mt-5 border-t border-white/[0.06] pt-3 text-[13px] text-[var(--text-muted)] inline-block opacity-0"
          >
            $29 once. macOS 14+. No subscription.
          </p>
        </div>

        {/* Product showcase - 3D scene scales to center stage on scroll */}
        <div
          ref={showcaseRef}
          className="relative mx-auto mt-14 max-w-[980px] md:mt-16 will-change-[transform,opacity]"
          style={{ transformOrigin: "center top" }}
        >
          {/* Decorative orbs */}
          <div className="pointer-events-none absolute inset-0" aria-hidden="true">
            <div
              ref={orb1Ref}
              className="absolute -left-20 top-1/4 h-72 w-72 rounded-full bg-forma-steel-blue/20 blur-[80px] animate-float will-change-transform"
            />
            <div
              ref={orb2Ref}
              className="absolute -right-16 top-1/3 h-64 w-64 rounded-full bg-forma-sage/15 blur-[80px] animate-float-slower will-change-transform"
            />
          </div>

          {/* 3D Scene or 2D Fallback */}
          <div className="relative aspect-[16/10] w-full overflow-hidden rounded-2xl border border-white/[0.08] bg-white/[0.02]">
            {webGLAvailable ? (
              <Suspense fallback={<FileParticleSceneFallback progress={progress} />}>
                <FileParticleScene progress={progress} />
              </Suspense>
            ) : (
              <FileParticleSceneFallback progress={progress} />
            )}
          </div>

          {/* Screen reader alt text */}
          <span className="sr-only">
            Animated visualization: scattered files organizing themselves into neat folders
          </span>
        </div>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// HeroSection - wraps content in ScrollScene for pinned scroll-scrub
// ---------------------------------------------------------------------------
export default function HeroSection() {
  return (
    <ScrollScene id="hero-scene" scrubLength={3} pin={true}>
      <HeroContent />
    </ScrollScene>
  );
}
