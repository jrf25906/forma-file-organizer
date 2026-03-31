"use client";

import { useRef, useState } from "react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";
import { CountUp } from "@/components/animation/CountUp";
import { AppleLogo } from "@/components/icons";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";
import { FormaShellCard } from "@/components/ui/forma-shell-card";
import { formaShellCtaVariants } from "@/components/ui/forma-shell-cta";
import { cn } from "@/lib/utils";

export default function PricingSection() {
  const [isMac] = useState(() => {
    if (typeof navigator === "undefined") return true;
    const platform = navigator.platform ?? "";
    const ua = navigator.userAgent ?? "";
    return /Mac/.test(platform) || /Macintosh/.test(ua);
  });

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

      const triggerTop = sectionRef.current.getBoundingClientRect().top;
      if (triggerTop <= window.innerHeight * 0.8) {
        gsap.set(cardRef.current, { opacity: 1, y: 0 });
        return;
      }

      // Simple fade-up entrance for the entire card
      gsap.fromTo(
        cardRef.current,
        { opacity: 0.88, y: 24 },
        {
          opacity: 1,
          y: 0,
          immediateRender: false,
          duration: formaDuration.normal,
          ease: formaReveal,
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 80%",
            toggleActions: "play none none none",
            invalidateOnRefresh: true,
            onRefresh: (self) => {
              if (self.progress > 0) {
                gsap.set(cardRef.current, { opacity: 1, y: 0 });
              }
            },
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
      className="scroll-mt-16 relative overflow-hidden py-10 md:py-20"
    >
      {/* Distinct background */}
      <div className="absolute inset-0 bg-[var(--bg-secondary)] pointer-events-none" />

      <div className="site-container relative">
        <div ref={cardRef} className="mx-auto max-w-xl">
          <FormaShellCard className="px-6 py-8 text-center sm:px-7 md:px-12 md:py-14">
            <p className="mb-3 text-[11px] font-medium tracking-[0.15em] uppercase text-forma-steel-blue">
              Pricing
            </p>
            <div className="font-display text-6xl md:text-7xl lg:text-[5.5rem] tracking-tight text-[var(--text-primary)]">
              <CountUp target={29} prefix="$" className="font-display" />
              <span>. Once. Forever.</span>
            </div>

            <p className="mt-4 text-base md:text-lg text-[var(--text-secondary)] leading-relaxed max-w-md mx-auto">
              No subscription. No account. No &lsquo;premium tiers.&rsquo; Pay
              once, own it forever.
            </p>

            <ul className="mx-auto mt-6 max-w-md space-y-3.5 text-left">
              {[
                "One payment, yours forever — no subscription tricks",
                "Works offline, no account required",
                "Fast and lightweight — built natively for macOS 15+",
              ].map((item) => (
                <li
                  key={item}
                  className="flex items-start gap-3 text-[14px] leading-relaxed text-[var(--text-secondary)]"
                >
                  <svg
                    className="mt-0.5 h-4 w-4 shrink-0 text-forma-sage"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={2.5}
                    aria-hidden="true"
                    focusable="false"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M5 13l4 4L19 7"
                    />
                  </svg>
                  <span>{item}</span>
                </li>
              ))}
            </ul>

            <div className="mt-8 flex flex-col items-center gap-4">
              <TrackedAppStoreLink
                location="pricing_primary"
                className={cn(
                  formaShellCtaVariants({ variant: "primary" }),
                  "h-auto min-h-14 px-8 py-4 text-[16px] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forma-steel-blue focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--shell-surface)]"
                )}
              >
                <AppleLogo className="h-7 w-7 flex-shrink-0" />
                <div className="flex flex-col items-start leading-tight">
                  <span className="text-[10px] font-body uppercase tracking-wide opacity-60">
                    Download on the
                  </span>
                  <span className="font-display -mt-0.5 text-lg">
                    Mac App Store
                  </span>
                </div>
              </TrackedAppStoreLink>

              <p className="mt-1 text-[13px] text-[var(--text-muted)]">
                Requires macOS 15 or later.
              </p>

              {!isMac && (
                <p className="mt-2 text-[12px] text-[var(--text-muted)]">
                  Open this page on your Mac to download.
                </p>
              )}
            </div>
          </FormaShellCard>
        </div>
      </div>
    </section>
  );
}
