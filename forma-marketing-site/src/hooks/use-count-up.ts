"use client";

import { useRef, useEffect, useState, useCallback } from "react";
import { gsap, ScrollTrigger } from "@/lib/animation/gsap-config";

interface UseCountUpOptions {
  /** Target value to count up to */
  end: number;
  /** Starting value (default: 0) */
  start?: number;
  /** Animation duration in seconds (default: 2) */
  duration?: number;
  /** Decimal places to show (default: 0) */
  decimals?: number;
  /** Easing function (default: "power2.out") */
  ease?: string;
  /** Delay before animation starts in seconds (default: 0) */
  delay?: number;
  /** Suffix to append (e.g., "+", "%") */
  suffix?: string;
  /** Prefix to prepend (e.g., "$") */
  prefix?: string;
  /** Format number with commas (default: true) */
  useCommas?: boolean;
  /** ScrollTrigger start position (default: "top 80%") */
  triggerStart?: string;
  /** Only animate once (default: true) */
  once?: boolean;
}

/**
 * useCountUp Hook
 *
 * A GSAP-powered count-up animation hook that triggers on scroll.
 * Numbers animate from start to end value when element enters viewport.
 *
 * @example
 * ```tsx
 * function StatCard() {
 *   const { ref, value } = useCountUp({
 *     end: 847000,
 *     duration: 2.5,
 *     suffix: "+",
 *     useCommas: true,
 *   });
 *
 *   return <span ref={ref}>{value}</span>;
 * }
 * ```
 */
export function useCountUp<T extends HTMLElement = HTMLSpanElement>(
  options: UseCountUpOptions
) {
  const {
    end,
    start = 0,
    duration = 2,
    decimals = 0,
    ease = "power2.out",
    delay = 0,
    suffix = "",
    prefix = "",
    useCommas = true,
    triggerStart = "top 80%",
    once = true,
  } = options;

  const ref = useRef<T>(null);
  const [displayValue, setDisplayValue] = useState(start);
  const hasAnimatedRef = useRef(false);
  const tweenRef = useRef<gsap.core.Tween | null>(null);

  // Format number with commas
  const formatNumber = useCallback(
    (num: number): string => {
      const fixed = num.toFixed(decimals);
      if (!useCommas) return `${prefix}${fixed}${suffix}`;

      const parts = fixed.split(".");
      parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
      return `${prefix}${parts.join(".")}${suffix}`;
    },
    [decimals, useCommas, prefix, suffix]
  );

  const formattedValue = formatNumber(displayValue);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;

    // Check for reduced motion preference
    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;

    if (prefersReducedMotion) {
      setDisplayValue(end);
      return;
    }

    // Create object for GSAP to tween
    const counter = { value: start };

    const trigger = ScrollTrigger.create({
      trigger: element,
      start: triggerStart,
      once: once,
      onEnter: () => {
        if (once && hasAnimatedRef.current) return;
        hasAnimatedRef.current = true;

        tweenRef.current = gsap.to(counter, {
          value: end,
          duration,
          delay,
          ease,
          onUpdate: () => {
            setDisplayValue(counter.value);
          },
        });
      },
      onEnterBack: () => {
        if (once) return;
        // Reset and replay if not once
        counter.value = start;
        setDisplayValue(start);

        tweenRef.current = gsap.to(counter, {
          value: end,
          duration,
          delay,
          ease,
          onUpdate: () => {
            setDisplayValue(counter.value);
          },
        });
      },
    });

    return () => {
      trigger.kill();
      if (tweenRef.current) {
        tweenRef.current.kill();
      }
    };
  }, [end, start, duration, decimals, ease, delay, triggerStart, once]);

  return {
    ref,
    value: formattedValue,
    rawValue: displayValue,
  };
}

export default useCountUp;
