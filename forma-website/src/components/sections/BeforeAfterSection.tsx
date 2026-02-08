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
      className="relative py-24 md:py-32"
    >
      <div className="site-container relative">
        <h2
          ref={headlineRef}
          className="mb-12 text-center font-display text-3xl tracking-tight text-forma-obsidian md:mb-14 md:text-4xl lg:text-[2.75rem]"
        >
          Sound familiar?
        </h2>

        <div className="relative mx-auto grid max-w-3xl grid-cols-1 gap-5 md:grid-cols-2">
        {/* BEFORE CARD */}
        <div ref={beforeCardRef}>
          <TiltCard enabled={!isTouchDevice} className="h-full">
            <div className="flex h-full flex-col rounded-2xl border border-black/[0.06] bg-white p-5 md:p-6">
              <span className="inline-flex items-center gap-1.5 text-[11px] font-medium tracking-widest text-forma-warm-orange/70 uppercase mb-5">
                <span className="w-1.5 h-1.5 rounded-full bg-forma-warm-orange/50" />
                Before
              </span>

              <ul
                className="flex-1 space-y-2"
                aria-label="Messy file listing"
              >
                {chaosFiles.map((file) => (
                  <li
                    key={file}
                    className="truncate font-mono text-[12px] leading-relaxed text-forma-obsidian/55"
                  >
                    {file}
                  </li>
                ))}
              </ul>
            </div>
          </TiltCard>
        </div>

        {/* AFTER CARD */}
        <div ref={afterCardRef}>
          <TiltCard enabled={!isTouchDevice} className="h-full">
            <div className="flex h-full flex-col rounded-2xl border border-black/[0.06] bg-white p-5 md:p-6">
              <span className="inline-flex items-center gap-1.5 text-[11px] font-medium tracking-widest text-forma-sage/80 uppercase mb-5">
                <span className="w-1.5 h-1.5 rounded-full bg-forma-sage/60" />
                After
              </span>

              <ul
                className="flex-1 space-y-2.5"
                aria-label="Organized folder structure"
              >
                {organizedFolders.map((folder) => (
                  <li key={folder.name} className="flex items-baseline gap-2">
                    <span className="font-mono text-[13px] tracking-wide text-forma-obsidian/80">
                      {folder.name}
                    </span>
                    <span className="text-[11px] text-forma-obsidian/40">
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
