"use client";

import { useRef, useEffect, useState } from "react";
import { Check, Monitor, Shield, Clock, Undo2 } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaStagger, formaDuration } from "@/lib/animation";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";
import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";
import { MagneticButton } from "@/components/animation/MagneticButton";
import { CountUp } from "@/components/animation/CountUp";
import { AppleLogo } from "@/components/icons";
import { soundEngine } from "@/lib/sound/sound-engine";

const features = [
  {
    icon: Monitor,
    text: "Mac-native Swift \u2014 not another Electron wrapper",
  },
  {
    icon: Shield,
    text: "Privacy-first \u2014 your files never leave your Mac",
  },
  {
    icon: Undo2,
    text: "Full undo history \u2014 reverse any move, anytime",
  },
  {
    icon: Clock,
    text: "macOS 14+ \u2014 built for modern Mac",
  },
];

export default function PricingSection() {
  const [isMac, setIsMac] = useState(true);

  useEffect(() => {
    const platform = navigator.platform ?? "";
    const ua = navigator.userAgent ?? "";
    const mac = /Mac/.test(platform) || /Macintosh/.test(ua);
    setIsMac(mac);
  }, []);

  const sectionRef = useRef<HTMLElement>(null);
  const headlineRef = useRef<HTMLDivElement>(null);
  const subtextRef = useRef<HTMLParagraphElement>(null);
  const featuresRef = useRef<HTMLUListElement>(null);
  const ctaRef = useRef<HTMLDivElement>(null);
  const glowRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (!sectionRef.current) return;

      const reducedMotion = getReducedMotionValue();

      if (reducedMotion) {
        gsap.set(
          [headlineRef.current, subtextRef.current, ctaRef.current],
          { opacity: 1, y: 0, scale: 1, filter: "blur(0px)" }
        );
        if (featuresRef.current?.children) {
          gsap.set(featuresRef.current.children, { opacity: 1, y: 0 });
        }
        if (glowRef.current) {
          gsap.set(glowRef.current, { opacity: 0.12 });
        }
        return;
      }

      // Dramatic headline entrance: starts scaled up and blurred, resolves on scroll
      gsap.fromTo(
        headlineRef.current,
        { scale: 2, opacity: 0, filter: "blur(12px)" },
        {
          scale: 1,
          opacity: 1,
          filter: "blur(0px)",
          ease: "power2.out",
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 80%",
            end: "top 30%",
            scrub: 1,
            onEnter: () => soundEngine.play("reveal"),
          },
        }
      );

      // Subtext fades in with scroll scrub
      gsap.fromTo(
        subtextRef.current,
        { opacity: 0, y: 30 },
        {
          opacity: 1,
          y: 0,
          ease: formaReveal,
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 65%",
            end: "top 35%",
            scrub: 1,
          },
        }
      );

      // Feature checkmarks stagger in with dramatic timing
      gsap.fromTo(
        featuresRef.current?.children ?? [],
        { opacity: 0, y: 30 },
        {
          opacity: 1,
          y: 0,
          stagger: 0.15,
          ease: formaReveal,
          scrollTrigger: {
            trigger: featuresRef.current,
            start: "top 75%",
            end: "top 45%",
            scrub: 1,
          },
        }
      );

      // CTA button entrance
      gsap.fromTo(
        ctaRef.current,
        { opacity: 0, y: 20, scale: 0.97 },
        {
          opacity: 1,
          y: 0,
          scale: 1,
          ease: formaReveal,
          scrollTrigger: {
            trigger: ctaRef.current,
            start: "top 85%",
            end: "top 60%",
            scrub: 1,
          },
        }
      );

      // Glow orb intensifies as section enters view
      gsap.fromTo(
        glowRef.current,
        { opacity: 0.05 },
        {
          opacity: 0.12,
          ease: "power1.inOut",
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 80%",
            end: "top 20%",
            scrub: 1,
          },
        }
      );
    },
    { scope: sectionRef }
  );

  return (
    <section
      ref={sectionRef}
      id="pricing"
      className="scroll-mt-16 relative py-24 md:py-32 overflow-hidden"
    >
      {/* Distinct background */}
      <div className="absolute inset-0 bg-[var(--bg-secondary)] pointer-events-none" />
      <div className="absolute inset-0 pointer-events-none">
        <div
          ref={glowRef}
          className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[600px] rounded-full bg-forma-steel-blue blur-[150px]"
          style={{ opacity: 0.05 }}
        />
      </div>

      <div className="site-container relative">
        <div className="glass-card-strong mx-auto max-w-xl rounded-3xl px-8 py-12 md:px-12 md:py-14 text-center">
          <p className="mb-4 text-[11px] font-medium tracking-[0.15em] uppercase text-forma-steel-blue/70">
            Pricing
          </p>
          <div
            ref={headlineRef}
            className="font-display text-6xl md:text-7xl lg:text-[5.5rem] tracking-tight gradient-text"
            style={{ opacity: 0, scale: 2, filter: "blur(12px)" }}
          >
            <CountUp target={29} prefix="$" scrub className="font-display" />
            <span>. Once. Forever.</span>
          </div>

          <p
            ref={subtextRef}
            className="mt-5 text-base md:text-lg text-[var(--text-secondary)] leading-relaxed max-w-md mx-auto"
            style={{ opacity: 0 }}
          >
            No subscription. No account. No &lsquo;premium tiers.&rsquo; Pay
            once, own it forever.
          </p>

          <ul
            ref={featuresRef}
            className="mt-10 grid grid-cols-1 sm:grid-cols-2 gap-4 text-left max-w-lg mx-auto"
          >
            {features.map((feature) => (
              <li
                key={feature.text}
                className="flex items-start gap-3"
                style={{ opacity: 0 }}
              >
                <span className="mt-0.5 flex h-5 w-5 items-center justify-center rounded-full bg-forma-sage/15 flex-shrink-0">
                  <Check className="w-3 h-3 text-forma-sage" strokeWidth={3} />
                </span>
                <span className="text-[14px] leading-relaxed text-[var(--text-secondary)]">{feature.text}</span>
              </li>
            ))}
          </ul>

          <div ref={ctaRef} className="mt-12 flex flex-col items-center gap-4" style={{ opacity: 0 }}>
            <MagneticButton strength={0.25}>
              <a
                href={MAC_APP_STORE_URL}
                {...MAC_APP_STORE_LINK_PROPS}
                className="dark-button inline-flex items-center gap-3.5 rounded-xl py-4 px-8 transition-all duration-300 hover:-translate-y-px hover:shadow-xl active:translate-y-0 border shadow-lg"
              >
                <AppleLogo className="w-7 h-7 flex-shrink-0" />
                <div className="flex flex-col items-start leading-tight">
                  <span className="text-[10px] font-body opacity-60 tracking-wide uppercase">
                    Download on the
                  </span>
                  <span className="text-lg font-display -mt-0.5">
                    Mac App Store
                  </span>
                </div>
              </a>
            </MagneticButton>

            <p className="text-[13px] text-[var(--text-muted)] mt-1">
              Requires macOS 14 (Sonoma) or later.
            </p>

            {!isMac && (
              <p className="text-[12px] text-[var(--text-muted)] mt-2">
                Open this page on your Mac to download.
              </p>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
