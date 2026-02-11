"use client";

import { useRef } from "react";
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

  const setDisplayValue = (value: number) => {
    if (!ref.current) return;
    ref.current.textContent = `${prefix}${Math.round(value)}${suffix}`;
  };

  useGSAP(
    () => {
      if (!ref.current) return;

      if (getReducedMotionValue()) {
        setDisplayValue(target);
        return;
      }

      const triggerTop = ref.current.getBoundingClientRect().top;
      const startThreshold = window.innerHeight * (scrub ? 0.8 : 0.85);
      if (triggerTop <= startThreshold) {
        counterRef.current.value = target;
        setDisplayValue(target);
        return;
      }

      // Start at 0 when animated counting is possible.
      setDisplayValue(0);

      const config: gsap.TweenVars = {
        value: target,
        duration,
        ease: "power2.out",
        onUpdate: () => {
          setDisplayValue(counterRef.current.value);
        },
      };

      const syncIfAlreadyPastTrigger = (progress: number) => {
        // If users deep-link below pricing, ensure count does not stay at 0.
        if (progress > 0) {
          counterRef.current.value = target;
          setDisplayValue(target);
        }
      };

      if (scrub) {
        gsap.to(counterRef.current, {
          ...config,
          scrollTrigger: {
            trigger: ref.current,
            start: "top 80%",
            end: "top 30%",
            scrub: 1,
            onRefresh: (self) => syncIfAlreadyPastTrigger(self.progress),
          },
        });
      } else {
        gsap.to(counterRef.current, {
          ...config,
          scrollTrigger: {
            trigger: ref.current,
            start: "top 85%",
            toggleActions: "play none none none",
            onRefresh: (self) => syncIfAlreadyPastTrigger(self.progress),
          },
        });
      }
    },
    { scope: ref, dependencies: [target, prefix, suffix, duration, scrub] }
  );

  return (
    <span ref={ref} className={className}>
      {prefix}{target}{suffix}
    </span>
  );
}

export default CountUp;
