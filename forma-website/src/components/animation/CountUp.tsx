"use client";

import { useRef, useState, useEffect } from "react";
import { gsap, useGSAP } from "@/lib/animation/gsap-config";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";

interface CountUpProps {
  /** Target number to count to */
  target: number;
  /** Prefix (e.g. "$") */
  prefix?: string;
  /** Suffix (e.g. "%") */
  suffix?: string;
  /** Animation duration in seconds */
  duration?: number;
  /** Whether to scrub with scroll */
  scrub?: boolean;
  className?: string;
}

export function CountUp({
  target,
  prefix = "",
  suffix = "",
  duration = 1.5,
  scrub = false,
  className,
}: CountUpProps) {
  const ref = useRef<HTMLSpanElement>(null);
  const counterRef = useRef({ value: 0 });

  useGSAP(
    () => {
      if (!ref.current) return;

      if (getReducedMotionValue()) {
        ref.current.textContent = `${prefix}${target}${suffix}`;
        return;
      }

      const config: gsap.TweenVars = {
        value: target,
        duration,
        ease: "power2.out",
        onUpdate: () => {
          if (ref.current) {
            ref.current.textContent = `${prefix}${Math.round(counterRef.current.value)}${suffix}`;
          }
        },
      };

      if (scrub) {
        gsap.to(counterRef.current, {
          ...config,
          scrollTrigger: {
            trigger: ref.current,
            start: "top 80%",
            end: "top 30%",
            scrub: 1,
          },
        });
      } else {
        gsap.to(counterRef.current, {
          ...config,
          scrollTrigger: {
            trigger: ref.current,
            start: "top 85%",
            toggleActions: "play none none none",
          },
        });
      }
    },
    { scope: ref }
  );

  return (
    <span ref={ref} className={className}>
      {prefix}0{suffix}
    </span>
  );
}

export default CountUp;
