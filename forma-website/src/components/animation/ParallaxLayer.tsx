"use client";

import { useRef, type ReactNode } from "react";
import { useGSAP } from "@/lib/animation/gsap-config";
import { gsap } from "@/lib/animation/gsap-config";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";

interface ParallaxLayerProps {
  children: ReactNode;
  /** Speed multiplier: -1 (opposite) to 1 (same direction). 0 = no parallax */
  speed?: number;
  className?: string;
}

export function ParallaxLayer({ children, speed = 0.3, className }: ParallaxLayerProps) {
  const ref = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (!ref.current || getReducedMotionValue()) return;

      // Reduce parallax intensity on mobile
      const isMobile = window.innerWidth < 768;
      const effectiveSpeed = isMobile ? speed * 0.5 : speed;

      if (effectiveSpeed === 0) return;

      gsap.to(ref.current, {
        y: () => effectiveSpeed * -200,
        ease: "none",
        scrollTrigger: {
          trigger: ref.current,
          start: "top bottom",
          end: "bottom top",
          scrub: 1,
          invalidateOnRefresh: true,
        },
      });
    },
    { scope: ref, dependencies: [speed] }
  );

  return (
    <div ref={ref} className={className}>
      {children}
    </div>
  );
}

export default ParallaxLayer;
