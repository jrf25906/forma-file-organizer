"use client";

import {
  createContext,
  useContext,
  useEffect,
  useRef,
  type ReactNode,
} from "react";
import Lenis from "lenis";
import { gsap, ScrollTrigger } from "./gsap-config";

// ---------------------------------------------------------------------------
// Context
// ---------------------------------------------------------------------------

type LenisContextValue = Lenis | null;

const LenisContext = createContext<LenisContextValue>(null);

/**
 * Hook to access the Lenis smooth scroll instance.
 * Returns null if called outside of LenisGSAPProvider or before initialization.
 */
export function useLenisScroll(): LenisContextValue {
  return useContext(LenisContext);
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

interface LenisGSAPProviderProps {
  children: ReactNode;
  /**
   * Lenis configuration options
   * @see https://github.com/darkroomengineering/lenis#options
   */
  options?: ConstructorParameters<typeof Lenis>[0];
}

/**
 * Provider that creates a Lenis instance for smooth scrolling and connects it
 * to GSAP ScrollTrigger for synchronized scroll-driven animations.
 *
 * - Uses gsap.ticker for the RAF loop (more efficient than separate rAF)
 * - Disables lagSmoothing for smoother animations
 * - Updates ScrollTrigger on each Lenis scroll event
 * - Properly cleans up on unmount
 */
export function LenisGSAPProvider({
  children,
  options,
}: LenisGSAPProviderProps) {
  const lenisRef = useRef<Lenis | null>(null);

  useEffect(() => {
    // Create Lenis instance with sensible defaults
    const lenis = new Lenis({
      lerp: 0.1,
      duration: 1.2,
      smoothWheel: true,
      wheelMultiplier: 1,
      touchMultiplier: 2,
      infinite: false,
      ...options,
    });

    lenisRef.current = lenis;

    // Connect Lenis scroll updates to ScrollTrigger
    // This ensures ScrollTrigger knows the current scroll position from Lenis
    lenis.on("scroll", ScrollTrigger.update);

    // Disable lag smoothing for smoother scroll-driven animations
    // This prevents GSAP from trying to "catch up" which can cause jank
    gsap.ticker.lagSmoothing(0);

    // Use GSAP's ticker for the animation frame loop
    // This is more efficient than a separate requestAnimationFrame
    // and ensures Lenis and GSAP are perfectly synchronized
    const tickerCallback = (time: number) => {
      // GSAP ticker time is in seconds, Lenis expects milliseconds
      lenis.raf(time * 1000);
    };

    gsap.ticker.add(tickerCallback);

    // Tell ScrollTrigger to use Lenis's wrapper and content elements
    // This is important for accurate scroll calculations
    ScrollTrigger.defaults({
      scroller: lenis.options.wrapper === window ? undefined : lenis.options.wrapper,
    });

    // Refresh ScrollTrigger after Lenis is initialized
    // Small delay to ensure DOM is ready
    const refreshTimeout = setTimeout(() => {
      ScrollTrigger.refresh();
    }, 100);

    // Cleanup function
    return () => {
      clearTimeout(refreshTimeout);
      gsap.ticker.remove(tickerCallback);
      lenis.off("scroll", ScrollTrigger.update);
      lenis.destroy();
      lenisRef.current = null;
    };
  }, [options]);

  return (
    <LenisContext.Provider value={lenisRef.current}>
      {children}
    </LenisContext.Provider>
  );
}

// ---------------------------------------------------------------------------
// Utility: Scroll To
// ---------------------------------------------------------------------------

/**
 * Programmatically scroll to a target using Lenis.
 * Can be used outside of React components.
 *
 * @example
 * ```ts
 * // Scroll to element
 * scrollTo('#section-2');
 *
 * // Scroll to top
 * scrollTo(0);
 *
 * // Scroll with options
 * scrollTo('#contact', { offset: -100, duration: 2 });
 * ```
 */
export function scrollTo(
  target: string | number | HTMLElement,
  options?: {
    offset?: number;
    duration?: number;
    immediate?: boolean;
    lock?: boolean;
    onComplete?: () => void;
  }
) {
  // Access lenis from the global window object if available
  // This is a fallback for usage outside React components
  const lenis = (window as unknown as { lenis?: Lenis }).lenis;
  if (lenis) {
    lenis.scrollTo(target, options);
  } else {
    // Fallback to native scroll if Lenis isn't available
    if (typeof target === "number") {
      window.scrollTo({ top: target, behavior: "smooth" });
    } else if (typeof target === "string") {
      const element = document.querySelector(target);
      element?.scrollIntoView({ behavior: "smooth" });
    } else if (target instanceof HTMLElement) {
      target.scrollIntoView({ behavior: "smooth" });
    }
  }
}

// ---------------------------------------------------------------------------
// Re-exports
// ---------------------------------------------------------------------------

export { Lenis };
