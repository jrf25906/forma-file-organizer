"use client";

import { useRef, useMemo } from "react";
import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration, formaStagger } from "@/lib/animation/ease-curves";
import { ScrollScene, useScrollSceneProgress } from "@/components/animation/ScrollScene";
import { TextReveal } from "@/components/animation/TextReveal";
import { AppleLogo } from "@/components/icons";
import { FormaFileCard } from "@/components/ui/FormaFileCard";
import { heroFiles, categoryColors } from "@/lib/forma-design-tokens";
import type { FileCategory } from "@/lib/forma-design-tokens";

// ---------------------------------------------------------------------------
// Folder grouping for organized grid labels
// ---------------------------------------------------------------------------
const folderGroups: { label: string; category: FileCategory }[] = [
  { label: "Images",    category: "images" },
  { label: "Documents", category: "documents" },
  { label: "Videos",    category: "videos" },
  { label: "Audio",     category: "audio" },
];

// Map each hero file to its folder group index
function folderIndexFor(category: FileCategory): number {
  return folderGroups.findIndex((g) => g.category === category);
}

function seededRandom(seed: number) {
  const x = Math.sin(seed * 9301 + 49297) * 233280;
  return x - Math.floor(x);
}

// ---------------------------------------------------------------------------
// FileSortShowcase - CSS transition driven by a single "sorted" boolean
// ---------------------------------------------------------------------------
function FileSortShowcase({ sorted }: { sorted: boolean }) {
  // Chaos spread: 300×200 (wider than before to accommodate larger cards)
  const chaosPositions = useMemo(
    () =>
      heroFiles.map((_, i) => ({
        x: Math.round((seededRandom(i * 3 + 1) - 0.5) * 300 * 100) / 100,
        y: Math.round((seededRandom(i * 3 + 2) - 0.5) * 200 * 100) / 100,
        rotation: Math.round((seededRandom(i * 3 + 3) - 0.5) * 14 * 100) / 100,
      })),
    [],
  );

  // Organized grid — compact cards are 200px min-width.
  // Container is ~800px (center ±400). Keep cards within visible bounds.
  const organizedPositions = useMemo(() => {
    const counts = [0, 0, 0, 0];
    return heroFiles.map((file) => {
      const fi = folderIndexFor(file.category);
      const col = counts[fi]++;
      return {
        x: -110 + col * 215,
        y: -85 + fi * 56,
        rotation: 0,
      };
    });
  }, []);

  return (
    <div
      className="relative w-full h-[340px] md:h-[400px]"
      aria-hidden="true"
    >
      {/* Folder labels - appear when sorted */}
      {folderGroups.map((group, i) => (
        <span
          key={group.label}
          className="absolute text-[10px] font-semibold uppercase tracking-wider transition-opacity duration-500"
          style={{
            left: "50%",
            top: "50%",
            transform: `translate3d(${-310}px, ${-85 + i * 56 - 16}px, 0)`,
            opacity: sorted ? 0.5 : 0,
            color: categoryColors[group.category],
            fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif",
          }}
        >
          {group.label}
        </span>
      ))}

      {heroFiles.map((file, i) => {
        const chaos = chaosPositions[i];
        const org = organizedPositions[i];
        const pos = sorted ? org : chaos;
        const delay = i * 40; // stagger in ms

        return (
          <div
            key={i}
            className="absolute"
            style={{
              left: "50%",
              top: "50%",
              transform: `translate3d(${pos.x}px, ${pos.y}px, 0) rotate(${pos.rotation}deg)`,
              marginLeft: "-105px",
              marginTop: "-24px",
              transition: `transform 700ms cubic-bezier(0.16, 1, 0.3, 1) ${delay}ms`,
            }}
          >
            <FormaFileCard file={file} scale="compact" />
          </div>
        );
      })}
    </div>
  );
}

// ---------------------------------------------------------------------------
// HeroContent - reads scroll progress from ScrollScene context
// ---------------------------------------------------------------------------
function HeroContent() {
  const progress = useScrollSceneProgress();

  // Refs for mount animation targets
  const subtitleRef = useRef<HTMLParagraphElement>(null);
  const ctaRef = useRef<HTMLDivElement>(null);
  const metaRef = useRef<HTMLParagraphElement>(null);

  // Mount animation: staggered entrance for above-fold content (runs once)
  useGSAP(
    () => {
      if (!subtitleRef.current) return;

      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (prefersReducedMotion) {
        gsap.set(
          [subtitleRef.current, ctaRef.current, metaRef.current],
          { opacity: 1, y: 0 }
        );
        return;
      }

      // TextReveal handles headline animation independently.
      // Animate subtitle, CTA, and meta with a stagger timed after headline.
      const tl = gsap.timeline({ delay: 0.55 });

      tl.fromTo(
        subtitleRef.current,
        { opacity: 0, y: 20 },
        { opacity: 1, y: 0, duration: formaDuration.normal, ease: formaReveal },
      )
        .fromTo(
          ctaRef.current,
          { opacity: 0, y: 20 },
          { opacity: 1, y: 0, duration: formaDuration.normal, ease: formaReveal },
          `-=${formaDuration.normal * 0.5}`
        )
        .fromTo(
          metaRef.current,
          { opacity: 0 },
          { opacity: 1, duration: formaDuration.fast, ease: formaReveal },
          `-=${formaDuration.fast * 0.6}`
        );
    },
    { dependencies: [] }
  );

  // The showcase sorts when scroll progress passes 0.35
  const sorted = progress > 0.35;

  return (
    <section className="relative min-h-screen flex flex-col justify-start pt-16 pb-10 md:pt-20 md:pb-14 overflow-hidden">
      <div className="site-container relative">
        {/* Text block */}
        <div className="mx-auto max-w-[820px] text-center">
          <TextReveal
            as="h1"
            type="words"
            stagger={formaStagger.fast}
            className="mx-auto max-w-[720px] font-display text-[2.75rem] leading-[1.08] tracking-[-0.025em] text-[var(--text-primary)] text-balance sm:text-[3.5rem] lg:text-[4.25rem]"
          >
            A file organizer for people who gave up on file organizers.
          </TextReveal>

          <p
            ref={subtitleRef}
            className="mx-auto mt-6 max-w-[580px] text-lg leading-relaxed text-[var(--text-secondary)] md:text-[1.2rem] opacity-0"
          >
            You make rules. Forma follows them. Preview what happens,
            approve it, undo anything.
          </p>

          <div
            ref={ctaRef}
            className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row opacity-0"
          >
            <a
              href={MAC_APP_STORE_URL}
              {...MAC_APP_STORE_LINK_PROPS}
              className="inline-flex items-center gap-2.5 rounded-xl bg-[var(--cta-bg)] px-8 py-3.5 text-[16px] font-semibold text-[var(--cta-text)] shadow-lg shadow-[var(--shadow-color)] transition-all duration-300 hover:bg-[var(--cta-bg-hover)] hover:-translate-y-px hover:shadow-xl active:translate-y-0"
            >
              <AppleLogo className="h-[15px] w-[12px]" />
              <span>Download for Mac</span>
            </a>

            <a
              href="#features"
              className="inline-flex items-center gap-2 rounded-xl border border-[var(--border-medium)] px-8 py-3.5 text-[16px] font-medium text-[var(--text-secondary)] transition-colors hover:text-[var(--text-primary)] hover:border-[var(--border-strong)]"
            >
              See how it works
            </a>
          </div>

          <p
            ref={metaRef}
            className="mt-5 border-t border-[var(--border-subtle)] pt-3 text-[13px] text-[var(--text-muted)] inline-block opacity-0"
          >
            $29 once. macOS 14+. No subscription.
          </p>
        </div>

        {/* Product showcase - 2D file sort visualization */}
        <div
          className="relative mx-auto mt-14 max-w-[800px] md:mt-16"
        >
          <div className="relative w-full overflow-hidden rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)]">
            <FileSortShowcase sorted={sorted} />
          </div>

          <span className="sr-only">
            Animated visualization: scattered files organizing themselves into neat folders
          </span>
        </div>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// HeroSection - wraps content in ScrollScene with reduced scrub length
// ---------------------------------------------------------------------------
export default function HeroSection() {
  return (
    <ScrollScene id="hero-scene" scrubLength={1.5} pin={true}>
      <HeroContent />
    </ScrollScene>
  );
}
