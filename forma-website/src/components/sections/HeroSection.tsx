"use client";

import { useRef, useMemo } from "react";
import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration, formaStagger } from "@/lib/animation/ease-curves";
import { ScrollScene, useScrollSceneProgress } from "@/components/animation/ScrollScene";
import { TextReveal } from "@/components/animation/TextReveal";
import { AppleLogo } from "@/components/icons";

// ---------------------------------------------------------------------------
// File card data for the 2D sort visualization
// ---------------------------------------------------------------------------
const files = [
  { name: "Screenshot 2024-01-15.png", type: "image", folder: 0 },
  { name: "IMG_4829.HEIC", type: "image", folder: 0 },
  { name: "Document (3).pdf", type: "document", folder: 1 },
  { name: "final_v2_FINAL.docx", type: "document", folder: 1 },
  { name: "app.tsx", type: "code", folder: 2 },
  { name: "styles.css", type: "code", folder: 2 },
  { name: "recording.mov", type: "video", folder: 3 },
  { name: "tutorial.mp4", type: "video", folder: 3 },
];

const typeColors: Record<string, string> = {
  image: "bg-[#C17E4A]",
  document: "bg-[#5B7C99]",
  code: "bg-[#7A9D7E]",
  video: "bg-[#6A8FAA]",
};

const folderLabels = ["Images", "Documents", "Code", "Videos"];

const folderLabelColors: Record<number, string> = {
  0: "text-[#C17E4A]",
  1: "text-[#5B7C99]",
  2: "text-[#7A9D7E]",
  3: "text-[#6A8FAA]",
};

function seededRandom(seed: number) {
  const x = Math.sin(seed * 9301 + 49297) * 233280;
  return x - Math.floor(x);
}

// ---------------------------------------------------------------------------
// FileSortShowcase - lightweight 2D visualization of files organizing
// Uses CSS transitions driven by a single "sorted" boolean from scroll progress
// ---------------------------------------------------------------------------
function FileSortShowcase({ sorted }: { sorted: boolean }) {
  const chaosPositions = useMemo(
    () =>
      files.map((_, i) => ({
        x: Math.round((seededRandom(i * 3 + 1) - 0.5) * 240 * 100) / 100,
        y: Math.round((seededRandom(i * 3 + 2) - 0.5) * 160 * 100) / 100,
        rotation: Math.round((seededRandom(i * 3 + 3) - 0.5) * 14 * 100) / 100,
      })),
    [],
  );

  // Organized positions: files grouped into rows by folder
  const organizedPositions = useMemo(() => {
    const counts = [0, 0, 0, 0];
    return files.map((file) => {
      const col = counts[file.folder]++;
      return {
        x: -80 + col * 170,
        y: -80 + file.folder * 56,
        rotation: 0,
      };
    });
  }, []);

  return (
    <div
      className="relative w-full h-[300px] md:h-[360px]"
      aria-hidden="true"
    >
      {/* Folder labels - appear when sorted */}
      {folderLabels.map((label, i) => (
        <span
          key={label}
          className={`absolute left-1/2 top-1/2 font-mono text-[10px] uppercase tracking-wider ${folderLabelColors[i]} transition-opacity duration-500`}
          style={{
            transform: `translate(calc(-50% + ${-170}px), calc(-50% + ${-80 + i * 56 - 16}px))`,
            opacity: sorted ? 0.5 : 0,
          }}
        >
          {label}
        </span>
      ))}

      {files.map((file, i) => {
        const chaos = chaosPositions[i];
        const org = organizedPositions[i];
        const pos = sorted ? org : chaos;
        const delay = i * 40; // stagger in ms

        return (
          <div
            key={i}
            className="absolute left-1/2 top-1/2 rounded-lg border border-white/[0.08] bg-[var(--bg-secondary)] px-3 py-2 shadow-lg shadow-black/20"
            style={{
              transform: `translate(calc(-50% + ${pos.x}px), calc(-50% + ${pos.y}px)) rotate(${pos.rotation}deg)`,
              transition: `transform 700ms cubic-bezier(0.16, 1, 0.3, 1) ${delay}ms`,
            }}
          >
            <div className="flex items-center gap-2">
              <span
                className={`w-2 h-2 rounded-full ${typeColors[file.type]} shrink-0`}
              />
              <span className="font-mono text-[11px] text-[var(--text-secondary)] whitespace-nowrap">
                {file.name.length > 20
                  ? file.name.slice(0, 20) + "..."
                  : file.name}
              </span>
            </div>
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
              className="inline-flex items-center gap-2.5 rounded-xl bg-[#F0F0F2] px-8 py-3.5 text-[16px] font-semibold text-[#0A0A0B] shadow-lg shadow-black/30 transition-all duration-300 hover:bg-[#E0E0E2] hover:-translate-y-px hover:shadow-xl hover:shadow-black/40 active:translate-y-0"
            >
              <AppleLogo className="h-[15px] w-[12px]" />
              <span>Download for Mac</span>
            </a>

            <a
              href="#features"
              className="inline-flex items-center gap-2 rounded-xl border border-white/[0.12] px-8 py-3.5 text-[16px] font-medium text-[var(--text-secondary)] transition-colors hover:text-[var(--text-primary)] hover:border-white/[0.22]"
            >
              See how it works
            </a>
          </div>

          <p
            ref={metaRef}
            className="mt-5 border-t border-white/[0.06] pt-3 text-[13px] text-[var(--text-muted)] inline-block opacity-0"
          >
            $29 once. macOS 14+. No subscription.
          </p>
        </div>

        {/* Product showcase - 2D file sort visualization */}
        <div
          className="relative mx-auto mt-14 max-w-[800px] md:mt-16"
        >
          <div className="relative w-full overflow-hidden rounded-2xl border border-white/[0.06] bg-[var(--bg-secondary)]">
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
