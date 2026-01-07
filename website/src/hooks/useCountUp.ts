"use client";

import { useEffect, useState } from "react";
import { useInView } from "framer-motion";
import { useRef } from "react";

interface UseCountUpOptions {
  end: number;
  duration?: number;
  decimals?: number;
  delay?: number;
  easing?: (t: number) => number;
}

// Easing function for smooth deceleration
const easeOutQuart = (t: number): number => 1 - Math.pow(1 - t, 4);

export function useCountUp({
  end,
  duration = 1500,
  decimals = 1,
  delay = 0,
  easing = easeOutQuart,
}: UseCountUpOptions) {
  const [count, setCount] = useState(0);
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: "-50px" });
  const hasAnimated = useRef(false);

  useEffect(() => {
    if (!isInView || hasAnimated.current) return;
    hasAnimated.current = true;

    const startTime = performance.now() + delay;
    let animationFrame: number;

    const animate = (currentTime: number) => {
      const elapsed = currentTime - startTime;

      if (elapsed < 0) {
        animationFrame = requestAnimationFrame(animate);
        return;
      }

      const progress = Math.min(elapsed / duration, 1);
      const easedProgress = easing(progress);
      const currentCount = easedProgress * end;

      setCount(currentCount);

      if (progress < 1) {
        animationFrame = requestAnimationFrame(animate);
      }
    };

    animationFrame = requestAnimationFrame(animate);

    return () => cancelAnimationFrame(animationFrame);
  }, [isInView, end, duration, delay, easing]);

  const formattedCount = count.toFixed(decimals);

  return { count, formattedCount, ref, isInView };
}
