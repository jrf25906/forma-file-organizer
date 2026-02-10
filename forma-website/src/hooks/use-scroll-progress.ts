"use client";

import { useRef, useState, useEffect } from "react";
import { gsap, ScrollTrigger } from "@/lib/animation/gsap-config";

interface UseScrollProgressOptions {
  start?: string;
  end?: string;
  scrub?: boolean | number;
}

export function useScrollProgress<T extends HTMLElement>(
  options: UseScrollProgressOptions = {}
) {
  const ref = useRef<T>(null);
  const [progress, setProgress] = useState(0);
  const { start = "top bottom", end = "bottom top", scrub = true } = options;

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const trigger = ScrollTrigger.create({
      trigger: el,
      start,
      end,
      scrub: scrub === true ? 1 : scrub === false ? undefined : scrub,
      onUpdate: (self) => {
        setProgress(self.progress);
      },
    });

    return () => trigger.kill();
  }, [start, end, scrub]);

  return { ref, progress };
}

export default useScrollProgress;
