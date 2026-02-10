"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { ScrollScene, useScrollSceneProgress } from "@/components/animation/ScrollScene";
import { ScrollReveal } from "@/components/animation/ScrollReveal";
import FileSortAnimation from "@/components/sections/FileSortAnimation";

// ═══════════════════════════════════════════════════════════════════════════
// DATA (preserved from original)
// ═══════════════════════════════════════════════════════════════════════════

const chaosFiles = [
  "Screenshot 2024-01-15 at 3.42.17 PM.png",
  "IMG_4829.HEIC",
  "Document (3).pdf",
  "Screen Recording 2024-02-01 at 10.15.23 AM.mov",
  "final_FINAL_v2_actual_final.docx",
  "Untitled.txt",
];

const organizedFolders = [
  { name: "Screenshots/", count: "3 files", icon: "\uD83D\uDDBC\uFE0F" },
  { name: "Documents/", count: "2 files", icon: "\uD83D\uDCC4" },
  { name: "Videos/", count: "1 file", icon: "\uD83C\uDFAC" },
];

// ═══════════════════════════════════════════════════════════════════════════
// DESKTOP INNER CONTENT
// Reads scroll scene progress for the crossfade heading and animation.
// ═══════════════════════════════════════════════════════════════════════════

function DesktopContent() {
  const progress = useScrollSceneProgress();

  // Heading crossfade:
  // progress < 0.3  => "Sound familiar?" fully visible
  // 0.3 - 0.5       => crossfade transition
  // progress > 0.5  => "Problem solved." fully visible
  const headingTransition = Math.max(0, Math.min(1, (progress - 0.3) / 0.2));

  return (
    <div className="relative min-h-screen flex items-center bg-[var(--bg-primary)] overflow-hidden">
      {/* Decorative orbs */}
      <div className="pointer-events-none absolute inset-0" aria-hidden="true">
        <div className="absolute -left-20 top-1/3 h-72 w-72 rounded-full bg-forma-warm-orange/10 blur-[100px]" />
        <div className="absolute -right-16 bottom-1/4 h-64 w-64 rounded-full bg-forma-sage/8 blur-[100px]" />
      </div>

      <div className="site-container relative w-full py-24 md:py-32">
        {/* Crossfading heading */}
        <div className="relative mb-12 md:mb-14" style={{ height: "1.3em" }}>
          <h2
            className="absolute inset-0 text-center font-display text-3xl tracking-tight text-forma-bone md:text-4xl lg:text-[2.75rem]"
            style={{ opacity: 1 - headingTransition, transition: "none" }}
            aria-hidden={headingTransition > 0.5}
          >
            Sound familiar?
          </h2>
          <h2
            className="absolute inset-0 text-center font-display text-3xl tracking-tight text-forma-bone md:text-4xl lg:text-[2.75rem]"
            style={{ opacity: headingTransition, transition: "none" }}
            aria-hidden={headingTransition <= 0.5}
          >
            Problem solved.
          </h2>
          {/* Accessible heading for screen readers */}
          <span className="sr-only">
            {headingTransition > 0.5 ? "Problem solved." : "Sound familiar?"}
          </span>
        </div>

        {/* File sort animation */}
        <FileSortAnimation />
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// MOBILE FALLBACK
// Static before/after cards with ScrollReveal, no pinning.
// ═══════════════════════════════════════════════════════════════════════════

function MobileFallback() {
  return (
    <div className="relative py-20 bg-[var(--bg-primary)] overflow-hidden">
      {/* Decorative orbs */}
      <div className="pointer-events-none absolute inset-0" aria-hidden="true">
        <div className="absolute -left-20 top-1/3 h-72 w-72 rounded-full bg-forma-warm-orange/10 blur-[100px]" />
        <div className="absolute -right-16 bottom-1/4 h-64 w-64 rounded-full bg-forma-sage/8 blur-[100px]" />
      </div>

      <div className="site-container relative">
        <ScrollReveal direction="up" distance={30}>
          <h2 className="mb-10 text-center font-display text-3xl tracking-tight text-forma-bone">
            Sound familiar?
          </h2>
        </ScrollReveal>

        <div className="mx-auto grid max-w-md grid-cols-1 gap-5">
          {/* BEFORE CARD */}
          <ScrollReveal direction="up" distance={40} delay={100}>
            <div className="flex flex-col rounded-2xl border border-forma-warm-orange/25 bg-forma-warm-orange/[0.08] p-6">
              <span className="inline-flex items-center gap-2 text-[12px] font-semibold tracking-widest text-forma-warm-orange uppercase mb-5">
                <span className="w-2 h-2 rounded-full bg-forma-warm-orange/60" />
                Before
              </span>

              <ul className="flex-1 space-y-2.5" aria-label="Messy file listing">
                {chaosFiles.map((file) => (
                  <li
                    key={file}
                    className="truncate rounded-lg bg-white/10 px-3 py-1.5 font-mono text-[12px] leading-relaxed text-forma-bone/70 border border-white/[0.06]"
                  >
                    {file}
                  </li>
                ))}
              </ul>
            </div>
          </ScrollReveal>

          {/* Arrow between cards */}
          <div className="flex justify-center">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-white/10 border border-white/15 shadow-md">
              <svg
                className="w-4 h-4 text-forma-bone/60 rotate-90"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={2}
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M13 7l5 5m0 0l-5 5m5-5H6"
                />
              </svg>
            </div>
          </div>

          {/* AFTER CARD */}
          <ScrollReveal direction="up" distance={40} delay={200}>
            <div className="flex flex-col rounded-2xl border border-forma-sage/25 bg-forma-sage/[0.08] p-6">
              <span className="inline-flex items-center gap-2 text-[12px] font-semibold tracking-widest text-forma-sage uppercase mb-5">
                <span className="w-2 h-2 rounded-full bg-forma-sage/60" />
                After
              </span>

              <ul className="flex-1 space-y-3" aria-label="Organized folder structure">
                {organizedFolders.map((folder) => (
                  <li
                    key={folder.name}
                    className="flex items-center gap-3 rounded-lg bg-white/10 px-4 py-3 border border-white/[0.06]"
                  >
                    <span className="text-lg">{folder.icon}</span>
                    <div className="flex flex-col">
                      <span className="font-mono text-[13px] font-medium tracking-wide text-forma-bone/85">
                        {folder.name}
                      </span>
                      <span className="text-[11px] text-forma-bone/45">
                        {folder.count}
                      </span>
                    </div>
                  </li>
                ))}
              </ul>

              <div className="mt-auto pt-4 flex items-center gap-2 rounded-lg bg-forma-sage/15 px-3 py-2">
                <svg
                  className="w-3.5 h-3.5 text-forma-sage"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={2.5}
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M5 13l4 4L19 7"
                  />
                </svg>
                <span className="text-[11px] font-medium text-forma-sage">
                  Organized in seconds
                </span>
              </div>
            </div>
          </ScrollReveal>
        </div>

        <ScrollReveal direction="up" distance={20} delay={400}>
          <h2 className="mt-10 text-center font-display text-3xl tracking-tight text-forma-bone">
            Problem solved.
          </h2>
        </ScrollReveal>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// BEFORE / AFTER SECTION — RESPONSIVE WRAPPER
// Desktop: ScrollScene with pinned FileSortAnimation
// Mobile: Static before/after cards with ScrollReveal
// ═══════════════════════════════════════════════════════════════════════════

export default function BeforeAfterSection() {
  const [isDesktop, setIsDesktop] = useState(false);
  const resizeTimerRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  const checkViewport = useCallback(() => {
    setIsDesktop(window.innerWidth >= 768);
  }, []);

  useEffect(() => {
    checkViewport();
    const handleResize = () => {
      clearTimeout(resizeTimerRef.current);
      resizeTimerRef.current = setTimeout(checkViewport, 150);
    };
    window.addEventListener("resize", handleResize);
    return () => {
      window.removeEventListener("resize", handleResize);
      clearTimeout(resizeTimerRef.current);
    };
  }, [checkViewport]);

  if (!isDesktop) {
    return (
      <section id="before-after" aria-label="Before and after file organization">
        <MobileFallback />
      </section>
    );
  }

  return (
    <section id="before-after" aria-label="Before and after file organization">
      <ScrollScene id="before-after-scene" scrubLength={2} pin>
        <DesktopContent />
      </ScrollScene>
    </section>
  );
}
