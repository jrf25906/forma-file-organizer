"use client";

import { useRef, useEffect, useState } from "react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";
import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";
import { CountUp } from "@/components/animation/CountUp";
import { AppleLogo } from "@/components/icons";

export default function PricingSection() {
  const [isMac, setIsMac] = useState(true);

  useEffect(() => {
    const platform = navigator.platform ?? "";
    const ua = navigator.userAgent ?? "";
    const mac = /Mac/.test(platform) || /Macintosh/.test(ua);
    setIsMac(mac);
  }, []);

  const sectionRef = useRef<HTMLElement>(null);
  const cardRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (!sectionRef.current || !cardRef.current) return;

      const reducedMotion = getReducedMotionValue();

      if (reducedMotion) {
        gsap.set(cardRef.current, { opacity: 1, y: 0 });
        return;
      }

      // Simple fade-up entrance for the entire card
      gsap.fromTo(
        cardRef.current,
        { opacity: 0, y: 40 },
        {
          opacity: 1,
          y: 0,
          duration: formaDuration.normal,
          ease: formaReveal,
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 80%",
            toggleActions: "play none none none",
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
      className="scroll-mt-16 relative py-16 md:py-24 overflow-hidden"
    >
      {/* Distinct background */}
      <div className="absolute inset-0 bg-[var(--bg-secondary)] pointer-events-none" />

      <div className="site-container relative">
        <div
          ref={cardRef}
          className="mx-auto max-w-xl bg-[#161618] border border-white/[0.10] rounded-2xl px-8 py-12 md:px-12 md:py-14 text-center"
          style={{ opacity: 0 }}
        >
          <p className="mb-4 text-[11px] font-medium tracking-[0.15em] uppercase text-forma-steel-blue/70">
            Pricing
          </p>
          <div className="font-display text-6xl md:text-7xl lg:text-[5.5rem] tracking-tight text-[var(--text-primary)]">
            <CountUp target={29} prefix="$" className="font-display" />
            <span>. Once. Forever.</span>
          </div>

          <p className="mt-5 text-base md:text-lg text-[var(--text-secondary)] leading-relaxed max-w-md mx-auto">
            No subscription. No account. No &lsquo;premium tiers.&rsquo; Pay
            once, own it forever.
          </p>

          <ul className="mt-10 space-y-3.5 text-left max-w-md mx-auto">
            {[
              "One payment, yours forever — no subscription tricks",
              "Works offline, no account required",
              "Not another Electron wrapper — native Swift on macOS 14+",
            ].map((item) => (
              <li key={item} className="flex items-start gap-3 text-[14px] leading-relaxed text-[var(--text-secondary)]">
                <svg className="w-4 h-4 mt-0.5 shrink-0 text-forma-sage" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
                <span>{item}</span>
              </li>
            ))}
          </ul>

          <div className="mt-12 flex flex-col items-center gap-4">
            <a
              href={MAC_APP_STORE_URL}
              {...MAC_APP_STORE_LINK_PROPS}
              className="inline-flex items-center gap-3.5 rounded-xl py-4 px-8 bg-[#F0F0F2] text-[#0A0A0B] border border-white/20 shadow-lg shadow-black/30 transition-all duration-300 hover:bg-[#E0E0E2] hover:-translate-y-px hover:shadow-xl hover:shadow-black/40 active:translate-y-0"
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
