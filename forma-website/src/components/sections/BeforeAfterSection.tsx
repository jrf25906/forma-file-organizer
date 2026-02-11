"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { ScrollReveal } from "@/components/animation/ScrollReveal";
import FileSortAnimation from "@/components/sections/FileSortAnimation";

// ===================================================================
// DATA (preserved from original)
// ===================================================================

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

// ===================================================================
// DESKTOP CONTENT
// Shows "Sound familiar?" heading, the FileSortAnimation (self-triggered),
// and "Problem solved." heading below.
// ===================================================================

function DesktopContent() {
  return (
    <div className="relative overflow-hidden bg-[var(--bg-primary)] pt-6 pb-10 md:pt-10 md:pb-14">
      <div className="site-container relative w-full">
        <ScrollReveal direction="up" distance={30}>
          <h2 className="mb-10 md:mb-12 text-center font-display text-3xl tracking-tight text-[var(--text-primary)] md:text-4xl lg:text-[2.75rem]">
            Sound familiar?
          </h2>
        </ScrollReveal>

        {/* File sort animation triggers itself via intersection observer */}
        <FileSortAnimation />

        <ScrollReveal direction="up" distance={20}>
          <h2 className="mt-10 md:mt-14 text-center font-display text-3xl tracking-tight text-[var(--text-primary)] md:text-4xl lg:text-[2.75rem]">
            Problem solved.
          </h2>
        </ScrollReveal>
      </div>
    </div>
  );
}

// ===================================================================
// MOBILE FALLBACK
// Static before/after cards with ScrollReveal, no pinning.
// ===================================================================

function MobileFallback() {
  return (
    <div className="relative overflow-hidden bg-[var(--bg-primary)] py-10 sm:py-12">
      <div className="site-container relative">
        <ScrollReveal direction="up" distance={30}>
          <h2 className="mb-6 text-center font-display text-3xl tracking-tight text-[var(--text-primary)]">
            Sound familiar?
          </h2>
        </ScrollReveal>

        <div className="mx-auto grid max-w-md grid-cols-1 gap-4">
          {/* BEFORE CARD */}
          <ScrollReveal direction="up" distance={40} delay={100}>
            <div className="flex flex-col rounded-2xl border border-forma-warm-orange/25 bg-forma-warm-orange/[0.08] p-5">
              <span className="mb-4 inline-flex items-center gap-2 text-[12px] font-semibold tracking-widest text-forma-warm-orange uppercase">
                <span className="w-2 h-2 rounded-full bg-forma-warm-orange/60" />
                Before
              </span>

              <ul className="flex-1 space-y-2.5" aria-label="Messy file listing">
                {chaosFiles.map((file) => (
                  <li
                    key={file}
                    className="truncate rounded-lg border border-[var(--border-subtle)] bg-[var(--surface-glass-hover)] px-3 py-1.5 font-mono text-[12px] leading-relaxed text-[var(--text-secondary)]"
                  >
                    {file}
                  </li>
                ))}
              </ul>
            </div>
          </ScrollReveal>

          {/* Arrow between cards */}
          <div className="flex justify-center">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-[var(--surface-glass-hover)] border border-[var(--border-strong)] shadow-md">
              <svg
                className="h-4 w-4 rotate-90 text-[var(--text-muted)]"
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
            <div className="flex flex-col rounded-2xl border border-forma-sage/25 bg-forma-sage/[0.08] p-5">
              <span className="mb-4 inline-flex items-center gap-2 text-[12px] font-semibold tracking-widest text-forma-sage uppercase">
                <span className="w-2 h-2 rounded-full bg-forma-sage/60" />
                After
              </span>

              <ul className="flex-1 space-y-3" aria-label="Organized folder structure">
                {organizedFolders.map((folder) => (
                  <li
                    key={folder.name}
                    className="flex items-center gap-3 rounded-lg bg-[var(--surface-glass-hover)] px-4 py-3 border border-[var(--border-subtle)]"
                  >
                    <span className="text-lg">{folder.icon}</span>
                    <div className="flex flex-col">
                      <span className="font-mono text-[13px] font-medium tracking-wide text-[var(--text-primary)]">
                        {folder.name}
                      </span>
                      <span className="text-[11px] text-[var(--text-muted)]">
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
          <h2 className="mt-6 text-center font-display text-3xl tracking-tight text-[var(--text-primary)]">
            Problem solved.
          </h2>
        </ScrollReveal>
      </div>
    </div>
  );
}

// ===================================================================
// BEFORE / AFTER SECTION -- RESPONSIVE WRAPPER
// Desktop: Normal scrolling with intersection-triggered FileSortAnimation
// Mobile: Static before/after cards with ScrollReveal
// ===================================================================

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
      <DesktopContent />
    </section>
  );
}
