"use client";

import { useRef, useEffect, useState } from "react";
import { Check, Monitor, Shield, Clock, Undo2 } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaStagger, formaDuration } from "@/lib/animation";
import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";
import { MagneticButton } from "@/components/animation/MagneticButton";
import { AppleLogo } from "@/components/icons";

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

  const enableScrollAnimations = true;
  const sectionRef = useRef<HTMLElement>(null);
  const headlineRef = useRef<HTMLHeadingElement>(null);
  const subtextRef = useRef<HTMLParagraphElement>(null);
  const featuresRef = useRef<HTMLUListElement>(null);
  const ctaRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (!enableScrollAnimations) return;
      if (!sectionRef.current) return;

      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (prefersReducedMotion) {
        gsap.set(
          [headlineRef.current, subtextRef.current, ctaRef.current],
          { opacity: 1, y: 0 }
        );
        if (featuresRef.current?.children) {
          gsap.set(featuresRef.current.children, { opacity: 1, y: 0 });
        }
        return;
      }

      const tl = gsap.timeline({
        scrollTrigger: {
          trigger: sectionRef.current,
          start: "top 75%",
          toggleActions: "play none none none",
        },
      });

      tl.from(headlineRef.current, {
        opacity: 0,
        y: 40,
        duration: formaDuration.normal,
        ease: formaReveal,
      })
        .from(
          subtextRef.current,
          {
            opacity: 0,
            y: 30,
            duration: formaDuration.normal,
            ease: formaReveal,
          },
          "-=0.5"
        )
        .from(
          featuresRef.current?.children ?? [],
          {
            opacity: 0,
            y: 20,
            stagger: formaStagger.normal,
            duration: formaDuration.fast,
            ease: formaReveal,
          },
          "-=0.4"
        )
        .from(
          ctaRef.current,
          {
            opacity: 0,
            y: 20,
            scale: 0.97,
            duration: formaDuration.normal,
            ease: formaReveal,
          },
          "-=0.3"
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
      <div className="absolute inset-0 bg-[#f0f3f7] pointer-events-none" />
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[600px] rounded-full bg-forma-steel-blue/[0.08] blur-[150px]" />
      </div>

      <div className="site-container relative">
        <div className="glass-card-strong mx-auto max-w-xl rounded-3xl px-8 py-12 md:px-12 md:py-14 text-center">
          <p className="mb-4 text-[11px] font-medium tracking-[0.15em] uppercase text-forma-steel-blue/60">
            Pricing
          </p>
          <h2
            ref={headlineRef}
            className="font-display text-6xl md:text-7xl lg:text-[5.5rem] tracking-tight gradient-text"
          >
            $29. Once. Forever.
          </h2>

          <p
            ref={subtextRef}
            className="mt-5 text-base md:text-lg text-forma-obsidian/65 leading-relaxed max-w-md mx-auto"
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
              >
                <span className="mt-0.5 flex h-5 w-5 items-center justify-center rounded-full bg-forma-sage/15 flex-shrink-0">
                  <Check className="w-3 h-3 text-forma-sage" strokeWidth={3} />
                </span>
                <span className="text-[14px] leading-relaxed text-forma-obsidian/70">{feature.text}</span>
              </li>
            ))}
          </ul>

          <div ref={ctaRef} className="mt-12 flex flex-col items-center gap-4">
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

            <p className="text-[13px] text-forma-obsidian/45 mt-1">
              Requires macOS 14 (Sonoma) or later.
            </p>

            {!isMac && (
              <p className="text-[12px] text-forma-obsidian/40 mt-2">
                Open this page on your Mac to download.
              </p>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
