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
  { name: "Screenshots/", count: "3 files", icon: "\uD83D\uDDBC\uFE0F" },
  { name: "Documents/", count: "2 files", icon: "\uD83D\uDCC4" },
  { name: "Videos/", count: "1 file", icon: "\uD83C\uDFAC" },
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
            <div className="flex h-full flex-col rounded-2xl border border-forma-warm-orange/15 bg-forma-warm-orange/[0.03] p-6">
              <span className="inline-flex items-center gap-2 text-[12px] font-semibold tracking-widest text-forma-warm-orange uppercase mb-5">
                <span className="w-2 h-2 rounded-full bg-forma-warm-orange/60" />
                Before
              </span>

              <ul
                className="flex-1 space-y-2.5"
                aria-label="Messy file listing"
              >
                {chaosFiles.map((file) => (
                  <li
                    key={file}
                    className="truncate rounded-lg bg-white/80 px-3 py-1.5 font-mono text-[12px] leading-relaxed text-forma-obsidian/60 border border-black/[0.04]"
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
            <div className="flex h-full flex-col rounded-2xl border border-forma-sage/15 bg-forma-sage/[0.04] p-6">
              <span className="inline-flex items-center gap-2 text-[12px] font-semibold tracking-widest text-forma-sage uppercase mb-5">
                <span className="w-2 h-2 rounded-full bg-forma-sage/60" />
                After
              </span>

              <ul
                className="flex-1 space-y-3"
                aria-label="Organized folder structure"
              >
                {organizedFolders.map((folder) => (
                  <li key={folder.name} className="flex items-center gap-3 rounded-lg bg-white/80 px-4 py-3 border border-black/[0.04]">
                    <span className="text-lg">{folder.icon}</span>
                    <div className="flex flex-col">
                      <span className="font-mono text-[13px] font-medium tracking-wide text-forma-obsidian/85">
                        {folder.name}
                      </span>
                      <span className="text-[11px] text-forma-obsidian/45">
                        {folder.count}
                      </span>
                    </div>
                  </li>
                ))}
              </ul>

              <div className="mt-4 flex items-center gap-2 rounded-lg bg-forma-sage/10 px-3 py-2">
                <span className="text-[11px] font-medium text-forma-sage">Organized in seconds</span>
              </div>
            </div>
          </TiltCard>
        </div>
        </div>
      </div>
    </section>
  );
}
