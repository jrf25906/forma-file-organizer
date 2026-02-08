"use client";

import { useRef, useState, useEffect } from "react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";
import { TiltCard } from "@/components/animation/TiltCard";

// ═══════════════════════════════════════════════════════════════════════════
// DATA
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
  { name: "Screenshots/", count: "3 files" },
  { name: "Documents/", count: "2 files" },
  { name: "Videos/", count: "1 file" },
];

// ═══════════════════════════════════════════════════════════════════════════
// BEFORE / AFTER SECTION
// ═══════════════════════════════════════════════════════════════════════════

export default function BeforeAfterSection() {
  const enableScrollAnimations = true;
  const sectionRef = useRef<HTMLElement>(null);
  const headlineRef = useRef<HTMLHeadingElement>(null);
  const beforeCardRef = useRef<HTMLDivElement>(null);
  const afterCardRef = useRef<HTMLDivElement>(null);
  const [isTouchDevice, setIsTouchDevice] = useState(false);

  // Detect touch / coarse-pointer devices to disable tilt
  useEffect(() => {
    if (typeof window === "undefined" || !window.matchMedia) return;
    const mq = window.matchMedia("(pointer: coarse)");

    setIsTouchDevice(mq.matches);

    const handler = (e: MediaQueryListEvent) => setIsTouchDevice(e.matches);
    mq.addEventListener("change", handler);
    return () => mq.removeEventListener("change", handler);
  }, []);

  // ScrollTrigger stagger: before card from left, after card from right
  useGSAP(
    () => {
      if (!enableScrollAnimations) return;
      if (!sectionRef.current) return;

      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (prefersReducedMotion) {
        gsap.set(
          [headlineRef.current, beforeCardRef.current, afterCardRef.current],
          { opacity: 1, x: 0, y: 0 }
        );
        return;
      }

      const tl = gsap.timeline({
        scrollTrigger: {
          trigger: sectionRef.current,
          start: "top 75%",
          toggleActions: "play none none none",
        },
      });

      // Headline fades up
      tl.from(headlineRef.current, {
        opacity: 0,
        y: 40,
        duration: formaDuration.normal,
        ease: formaReveal,
      });

      // Before card slides in from left
      tl.from(
        beforeCardRef.current,
        {
          opacity: 0,
          x: -60,
          duration: formaDuration.normal,
          ease: formaReveal,
        },
        "-=0.5"
      );

      // After card slides in from right (staggered overlap)
      tl.from(
        afterCardRef.current,
        {
          opacity: 0,
          x: 60,
          duration: formaDuration.normal,
          ease: formaReveal,
        },
        "-=0.7"
      );
    },
    { scope: sectionRef }
  );

  return (
    <section
      ref={sectionRef}
      className="relative py-24 md:py-32 overflow-hidden"
    >
      <div className="site-container relative">
        {/* Section heading */}
        <h2
          ref={headlineRef}
          className="mb-16 text-center font-display text-3xl tracking-tight text-forma-obsidian md:text-4xl lg:text-5xl"
        >
          Sound familiar?
        </h2>

        {/* Card grid */}
        <div className="relative mx-auto grid max-w-5xl grid-cols-1 gap-8 md:grid-cols-2">
        {/* ─────────────────────────────────────────────────────────── */}
        {/* BEFORE CARD                                                */}
        {/* ─────────────────────────────────────────────────────────── */}
        <div ref={beforeCardRef}>
          <TiltCard enabled={!isTouchDevice} className="h-full">
            <div className="flex h-full flex-col rounded-2xl border border-black/[0.08] bg-white p-6 md:p-8">
              {/* Warm chaos glow */}
              <div
                className="absolute inset-0 rounded-2xl pointer-events-none"
                aria-hidden="true"
                style={{
                  background:
                    "radial-gradient(ellipse at 30% 20%, rgba(201, 126, 102, 0.1) 0%, transparent 60%)",
                }}
              />

              {/* Card label */}
              <span className="relative inline-flex items-center gap-2 text-sm font-display tracking-wide text-forma-warm-orange/60 uppercase mb-6">
                <span className="w-2 h-2 rounded-full bg-forma-warm-orange/50" />
                Before
              </span>

              {/* Chaotic file list */}
              <ul
                className="relative flex-1 space-y-2.5"
                aria-label="Messy file listing"
              >
                {chaosFiles.map((file) => (
                  <li
                    key={file}
                    className="truncate font-mono text-sm leading-relaxed text-forma-obsidian/65"
                  >
                    {file}
                  </li>
                ))}
              </ul>
            </div>
          </TiltCard>
        </div>

        {/* ─────────────────────────────────────────────────────────── */}
        {/* AFTER CARD                                                 */}
        {/* ─────────────────────────────────────────────────────────── */}
        <div ref={afterCardRef}>
          <TiltCard enabled={!isTouchDevice} className="h-full">
            <div className="flex h-full flex-col rounded-2xl border border-black/[0.08] bg-white p-6 md:p-8">
              {/* Calm sage glow */}
              <div
                className="absolute inset-0 rounded-2xl pointer-events-none"
                aria-hidden="true"
                style={{
                  background:
                    "radial-gradient(ellipse at 70% 80%, rgba(122, 157, 126, 0.1) 0%, transparent 60%)",
                }}
              />

              {/* Card label */}
              <span className="relative inline-flex items-center gap-2 text-sm font-display tracking-wide text-forma-sage uppercase mb-6">
                <span className="w-2 h-2 rounded-full bg-forma-sage/60" />
                After
              </span>

              {/* Organized folder list */}
              <ul
                className="relative flex-1 space-y-3"
                aria-label="Organized folder structure"
              >
                {organizedFolders.map((folder) => (
                  <li key={folder.name} className="flex items-baseline gap-3">
                    <span className="font-mono text-sm tracking-wide text-forma-obsidian">
                      {folder.name}
                    </span>
                    <span className="text-xs text-forma-obsidian/65">
                      {folder.count}
                    </span>
                  </li>
                ))}
              </ul>

            </div>
          </TiltCard>
        </div>
        </div>
      </div>
    </section>
  );
}
