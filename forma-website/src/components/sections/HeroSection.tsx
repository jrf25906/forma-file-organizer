"use client";

import { useRef, useState, useEffect } from "react";
import Image from "next/image";
import { gsap, useGSAP } from "@/lib/animation/gsap-config";
import { formaReveal, formaDuration, formaStagger } from "@/lib/animation/ease-curves";
import { ScrollReveal } from "@/components/animation/ScrollReveal";
import { RevealText } from "@/components/animation/RevealText";
import MacWindowFrame from "@/components/ui/MacWindowFrame";
import { useTheme } from "@/components/ThemeProvider";

// ═══════════════════════════════════════════════════════════════════════════
// APPLE LOGO SVG
// ═══════════════════════════════════════════════════════════════════════════

function AppleLogo({ className = "" }: { className?: string }) {
  return (
    <svg
      className={className}
      width="14"
      height="17"
      viewBox="0 0 14 17"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <path d="M13.3 13.16c-.31.71-.67 1.36-1.09 1.96-.57.81-1.04 1.37-1.4 1.68-.56.51-1.16.77-1.8.79-.46 0-1.02-.13-1.67-.4-.65-.26-1.25-.4-1.8-.4-.57 0-1.19.14-1.84.4-.66.27-1.19.41-1.59.43-.62.03-1.23-.24-1.84-.82-.39-.34-.88-.92-1.47-1.75C.27 14.3-.12 13.43-.12 12.5c0-1.06.23-1.97.69-2.73a4.02 4.02 0 0 1 3.37-2.02c.49 0 1.13.15 1.93.44.8.3 1.31.44 1.53.44.17 0 .73-.17 1.68-.51.9-.32 1.65-.45 2.27-.4 1.68.14 2.94.81 3.78 2.02-1.5.91-2.24 2.19-2.22 3.82.02 1.27.47 2.33 1.37 3.16.41.39.86.69 1.37.9-.11.32-.23.62-.35.93zM10.2.34c0 1-.36 1.93-1.09 2.8-.87 1.03-1.93 1.62-3.07 1.53a3.1 3.1 0 0 1-.02-.37c0-.96.42-1.98 1.16-2.82.37-.42.84-.77 1.42-1.06.57-.28 1.11-.43 1.62-.46.01.13.02.25.02.38h-.04z" />
    </svg>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// THEME-AWARE APP SCREENSHOT
// ═══════════════════════════════════════════════════════════════════════════

function AppScreenshot() {
  const { resolvedTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  // Prevent hydration mismatch by defaulting to light during SSR
  const isDark = mounted ? resolvedTheme === "dark" : false;

  return (
    <Image
      src={
        isDark
          ? "/screenshots/dark/forma-01-hero-main-window.png"
          : "/screenshots/light/forma-01-hero-main-window.png"
      }
      alt="Forma app main window showing file organization rules and preview"
      width={1280}
      height={800}
      className="w-full h-auto"
      priority
    />
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO SECTION
// ═══════════════════════════════════════════════════════════════════════════

export default function HeroSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const headlineRef = useRef<HTMLDivElement>(null);
  const subtextRef = useRef<HTMLParagraphElement>(null);
  const bodyRef = useRef<HTMLParagraphElement>(null);
  const ctaRef = useRef<HTMLDivElement>(null);
  const mockupRef = useRef<HTMLDivElement>(null);

  // Entrance animation for above-the-fold content
  useGSAP(
    () => {
      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (prefersReducedMotion) {
        gsap.set(
          [
            headlineRef.current,
            subtextRef.current,
            bodyRef.current,
            ctaRef.current,
            mockupRef.current,
          ],
          { opacity: 1, y: 0 }
        );
        return;
      }

      const tl = gsap.timeline({ delay: 0.3 });

      // Headline
      tl.fromTo(
        headlineRef.current,
        { opacity: 0, y: 40 },
        {
          opacity: 1,
          y: 0,
          duration: formaDuration.normal,
          ease: formaReveal,
        }
      );

      // Subtext
      tl.fromTo(
        subtextRef.current,
        { opacity: 0, y: 30 },
        {
          opacity: 1,
          y: 0,
          duration: formaDuration.normal,
          ease: formaReveal,
        },
        "-=0.55"
      );

      // Body
      tl.fromTo(
        bodyRef.current,
        { opacity: 0, y: 25 },
        {
          opacity: 1,
          y: 0,
          duration: formaDuration.normal,
          ease: formaReveal,
        },
        "-=0.5"
      );

      // CTAs
      tl.fromTo(
        ctaRef.current,
        { opacity: 0, y: 20 },
        {
          opacity: 1,
          y: 0,
          duration: formaDuration.fast,
          ease: formaReveal,
        },
        "-=0.4"
      );

      // App mockup
      tl.fromTo(
        mockupRef.current,
        { opacity: 0, y: 60, scale: 0.96 },
        {
          opacity: 1,
          y: 0,
          scale: 1,
          duration: formaDuration.slow,
          ease: formaReveal,
        },
        "-=0.3"
      );
    },
    { scope: sectionRef }
  );

  const handleSeeHowItWorks = (e: React.MouseEvent<HTMLAnchorElement>) => {
    e.preventDefault();
    const featuresSection = document.getElementById("features");
    if (featuresSection) {
      featuresSection.scrollIntoView({ behavior: "smooth" });
    }
  };

  return (
    <section
      ref={sectionRef}
      className="relative min-h-screen flex flex-col items-center justify-center py-24 px-6 overflow-hidden"
    >
      {/* Background gradient orbs */}
      <div
        className="absolute inset-0 pointer-events-none"
        aria-hidden="true"
      >
        <div
          className="absolute w-[700px] h-[700px] rounded-full blur-[140px] opacity-20"
          style={{
            background:
              "radial-gradient(circle, rgba(91, 124, 153, 0.4) 0%, transparent 70%)",
            left: "-10%",
            top: "10%",
          }}
        />
        <div
          className="absolute w-[500px] h-[500px] rounded-full blur-[120px] opacity-15"
          style={{
            background:
              "radial-gradient(circle, rgba(122, 157, 126, 0.35) 0%, transparent 70%)",
            right: "-5%",
            top: "30%",
          }}
        />
        <div
          className="absolute w-[400px] h-[400px] rounded-full blur-[100px] opacity-10"
          style={{
            background:
              "radial-gradient(circle, rgba(201, 126, 102, 0.3) 0%, transparent 70%)",
            left: "30%",
            bottom: "5%",
          }}
        />
      </div>

      <div className="relative max-w-4xl mx-auto text-center z-10">
        {/* ─────────────────────────────────────────────────────────────── */}
        {/* HEADLINE                                                       */}
        {/* ─────────────────────────────────────────────────────────────── */}
        <div ref={headlineRef} className="opacity-0">
          <RevealText
            className="text-4xl sm:text-5xl md:text-6xl lg:text-[3.75rem] font-display text-forma-bone leading-[1.08] tracking-tight justify-center headline-hero"
            delay={0.5}
          >
            A file organizer for people who gave up on file organizers.
          </RevealText>
        </div>

        {/* ─────────────────────────────────────────────────────────────── */}
        {/* SUBTEXT                                                        */}
        {/* ─────────────────────────────────────────────────────────────── */}
        <p
          ref={subtextRef}
          className="mt-6 text-lg md:text-xl text-forma-bone/60 max-w-2xl mx-auto leading-relaxed opacity-0"
        >
          Your desktop is a dumping ground. Your Downloads folder is worse.
          You&apos;ve tried to fix it before.
        </p>

        {/* ─────────────────────────────────────────────────────────────── */}
        {/* BODY                                                           */}
        {/* ─────────────────────────────────────────────────────────────── */}
        <p
          ref={bodyRef}
          className="mt-5 text-base md:text-lg text-forma-bone/70 max-w-2xl mx-auto leading-relaxed opacity-0"
        >
          You make rules. Forma follows them. Screenshots go here, PDFs go
          there. You preview what&apos;s about to happen, approve it, and
          it&apos;s done. If you don&apos;t like it, undo it. That&apos;s the
          whole thing.
        </p>

        {/* ─────────────────────────────────────────────────────────────── */}
        {/* CTAs                                                           */}
        {/* ─────────────────────────────────────────────────────────────── */}
        <div
          ref={ctaRef}
          className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4 opacity-0"
        >
          {/* Primary CTA - Download for Mac */}
          <a
            href="https://apps.apple.com/app/forma/id0000000000"
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary inline-flex items-center gap-2.5 px-8 py-3.5 text-white force-white-text text-base font-medium rounded-xl shadow-xl shadow-forma-steel-blue/20 hover:shadow-2xl hover:shadow-forma-steel-blue/30 transition-all duration-300"
          >
            <AppleLogo className="w-[14px] h-[17px]" />
            <span>Download for Mac</span>
          </a>

          {/* Secondary CTA - See how it works */}
          <a
            href="#features"
            onClick={handleSeeHowItWorks}
            className="btn-secondary inline-flex items-center gap-2 px-8 py-3.5 text-base font-medium rounded-xl transition-all duration-300"
          >
            See how it works
          </a>
        </div>
      </div>

      {/* ═══════════════════════════════════════════════════════════════════ */}
      {/* APP SCREENSHOT IN MAC WINDOW FRAME                                */}
      {/* ═══════════════════════════════════════════════════════════════════ */}
      <div
        ref={mockupRef}
        className="relative w-full max-w-5xl mx-auto mt-16 md:mt-20 z-10 opacity-0"
      >
        <div className="app-mockup-glow">
          <MacWindowFrame className="w-full">
            <AppScreenshot />
          </MacWindowFrame>
        </div>
      </div>
    </section>
  );
}
