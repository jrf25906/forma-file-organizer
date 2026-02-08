"use client";

import { useRef } from "react";
import { Check, Monitor, Shield, Clock, Undo2 } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaStagger, formaDuration } from "@/lib/animation";
import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";

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

function AppleLogo({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 814 1000"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76.5 0-103.7 40.8-165.9 40.8s-105.6-57.8-155.5-127.4c-58.3-81.5-105.3-208.1-105.3-329 0-193.9 126.1-296.8 250.1-296.8 65.9 0 120.9 43.4 162.3 43.4 39.5 0 101.1-46 176.6-46 28.5 0 130.9 2.6 198.3 99.2zm-234-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8.6 15.6 1.3 18.2 2.6.6 6.4 1.3 10.2 1.3 45.4 0 103.5-30.4 139.5-71.4z" />
    </svg>
  );
}

export default function PricingSection() {
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
        <div className="mx-auto max-w-xl text-center">
          <h2
            ref={headlineRef}
            className="font-display text-4xl md:text-5xl lg:text-[3.25rem] text-forma-obsidian tracking-tight"
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
            <a
              href={MAC_APP_STORE_URL}
              {...MAC_APP_STORE_LINK_PROPS}
              className="dark-button inline-flex items-center gap-4 rounded-2xl py-4 px-8 transition-all duration-300 hover:-translate-y-px hover:shadow-xl active:translate-y-0 border shadow-lg"
            >
              <AppleLogo className="w-6 h-6 flex-shrink-0" />
              <div className="flex flex-col items-start leading-tight">
                <span className="text-[10px] font-body text-white/60 tracking-wide uppercase">
                  Download on the
                </span>
                <span className="text-lg font-display -mt-0.5">
                  Mac App Store
                </span>
              </div>
            </a>

            <p className="text-[13px] text-forma-obsidian/45 mt-1">
              Requires macOS 14 (Sonoma) or later.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
