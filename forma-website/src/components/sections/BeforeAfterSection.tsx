"use client";

import { useRef, useState, useEffect } from "react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";
import { TiltCard } from "@/components/animation/TiltCard";
import { RevealText } from "@/components/animation/RevealText";

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
// BEFORE / AFTER SECTION — DARK BAND
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
      className="relative py-24 md:py-32 bg-forma-obsidian overflow-hidden"
    >
      {/* Decorative orbs */}
      <div className="pointer-events-none absolute inset-0" aria-hidden="true">
        <div className="absolute -left-20 top-1/3 h-72 w-72 rounded-full bg-forma-warm-orange/10 blur-[100px]" />
        <div className="absolute -right-16 bottom-1/4 h-64 w-64 rounded-full bg-forma-sage/8 blur-[100px]" />
      </div>

      <div className="site-container relative">
        <h2
          ref={headlineRef}
          className="mb-12 text-center font-display text-3xl tracking-tight text-forma-bone md:mb-14 md:text-4xl lg:text-[2.75rem]"
        >
          <RevealText>Sound familiar?</RevealText>
        </h2>

        <div className="relative mx-auto grid max-w-3xl grid-cols-1 gap-5 md:grid-cols-2">
        {/* Arrow between cards on desktop */}
        <div className="hidden md:flex absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 z-10 h-10 w-10 items-center justify-center rounded-full bg-white/10 border border-white/15 shadow-md">
          <svg className="w-4 h-4 text-forma-bone/60" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" /></svg>
        </div>
        {/* BEFORE CARD */}
        <div ref={beforeCardRef}>
          <TiltCard enabled={!isTouchDevice} glare className="h-full">
            <div className="flex h-full flex-col rounded-2xl border border-forma-warm-orange/25 bg-forma-warm-orange/[0.08] p-6">
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
                    className="truncate rounded-lg bg-white/10 px-3 py-1.5 font-mono text-[12px] leading-relaxed text-forma-bone/70 border border-white/[0.06]"
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
          <TiltCard enabled={!isTouchDevice} glare className="h-full">
            <div className="flex h-full flex-col rounded-2xl border border-forma-sage/25 bg-forma-sage/[0.08] p-6">
              <span className="inline-flex items-center gap-2 text-[12px] font-semibold tracking-widest text-forma-sage uppercase mb-5">
                <span className="w-2 h-2 rounded-full bg-forma-sage/60" />
                After
              </span>

              <ul
                className="flex-1 space-y-3"
                aria-label="Organized folder structure"
              >
                {organizedFolders.map((folder) => (
                  <li key={folder.name} className="flex items-center gap-3 rounded-lg bg-white/10 px-4 py-3 border border-white/[0.06]">
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
                <svg className="w-3.5 h-3.5 text-forma-sage" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}><path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" /></svg>
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
