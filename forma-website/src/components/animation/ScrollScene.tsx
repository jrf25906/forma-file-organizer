"use client";

import { useRef, createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { gsap, ScrollTrigger, useGSAP } from "@/lib/animation/gsap-config";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";

const ScrollProgressContext = createContext<number>(0);

export function useScrollSceneProgress() {
  return useContext(ScrollProgressContext);
}

interface ScrollSceneProps {
  children: ReactNode;
  /** Viewport heights to scrub over (default: 3) */
  scrubLength?: number;
  /** Pin the scene during scrub (default: true) */
  pin?: boolean;
  /** Unique ScrollTrigger ID */
  id: string;
  /** Callback with progress 0-1 */
  onProgress?: (progress: number) => void;
  /** Bypass for mobile/reduced-motion */
  disabled?: boolean;
  /** Additional CSS classes */
  className?: string;
}

export function ScrollScene({
  children,
  scrubLength = 3,
  pin = true,
  id,
  onProgress,
  disabled = false,
  className,
}: ScrollSceneProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const lastUpdateRef = useRef(0);
  const [progress, setProgress] = useState(0);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    setIsMobile(window.innerWidth < 768);
    const handleResize = () => setIsMobile(window.innerWidth < 768);
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  const isDisabled = disabled || isMobile || getReducedMotionValue();

  useGSAP(
    () => {
      if (isDisabled || !containerRef.current) return;

      const trigger = ScrollTrigger.create({
        trigger: containerRef.current,
        start: "top top",
        end: () => `+=${scrubLength * window.innerHeight}`,
        pin: pin,
        scrub: 1,
        id: id,
        onUpdate: (self) => {
          const now = performance.now();
          if (now - lastUpdateRef.current > 33) {
            setProgress(self.progress);
            lastUpdateRef.current = now;
          }
          onProgress?.(self.progress);
        },
        invalidateOnRefresh: true,
      });

      return () => {
        trigger.kill();
      };
    },
    { scope: containerRef, dependencies: [isDisabled, scrubLength, pin, id] }
  );

  if (isDisabled) {
    return (
      <ScrollProgressContext.Provider value={1}>
        <div className={className}>{children}</div>
      </ScrollProgressContext.Provider>
    );
  }

  return (
    <ScrollProgressContext.Provider value={progress}>
      <div ref={containerRef} className={className} style={{ willChange: "transform", width: "100%" }}>
        {children}
      </div>
    </ScrollProgressContext.Provider>
  );
}

export default ScrollScene;
