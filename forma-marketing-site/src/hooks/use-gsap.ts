"use client";

import { useRef, useEffect, useCallback } from "react";
import { gsap, ScrollTrigger } from "@/lib/animation/gsap-config";
import { formaReveal, formaDuration } from "@/lib/animation/ease-curves";

// ============================================================================
// Types
// ============================================================================

interface ScrollTriggerConfig {
  /** The element or selector to trigger on */
  trigger?: string | Element | null;
  /** Start position (e.g., "top center", "top 80%") */
  start?: string | number;
  /** End position (e.g., "bottom center", "+=500") */
  end?: string | number;
  /** Whether to pin the trigger element */
  pin?: boolean | string | Element;
  /** Add markers for debugging */
  markers?: boolean;
  /** Scrub animation to scroll position (true or number for smoothing) */
  scrub?: boolean | number;
  /** Toggle actions: onEnter, onLeave, onEnterBack, onLeaveBack */
  toggleActions?: string;
  /** Toggle a class on the trigger element */
  toggleClass?: string | { targets: string; className: string };
  /** Callback when element enters viewport */
  onEnter?: (self: ScrollTrigger) => void;
  /** Callback when element leaves viewport */
  onLeave?: (self: ScrollTrigger) => void;
  /** Callback when element enters viewport from below */
  onEnterBack?: (self: ScrollTrigger) => void;
  /** Callback when element leaves viewport going up */
  onLeaveBack?: (self: ScrollTrigger) => void;
  /** Callback on scroll progress update */
  onUpdate?: (self: ScrollTrigger) => void;
  /** Callback when ScrollTrigger refreshes */
  onRefresh?: (self: ScrollTrigger) => void;
}

interface UseTimelineOptions {
  /** Whether to pause the timeline initially */
  paused?: boolean;
  /** Default duration for all tweens */
  defaults?: gsap.TweenVars;
  /** Whether the timeline should repeat */
  repeat?: number;
  /** Delay between repeats */
  repeatDelay?: number;
  /** Whether to yoyo (reverse) on repeat */
  yoyo?: boolean;
  /** Callback when timeline completes */
  onComplete?: () => void;
  /** Callback on timeline update */
  onUpdate?: () => void;
}

// ============================================================================
// useScrollTrigger
// ============================================================================

/**
 * Creates a ScrollTrigger instance with automatic cleanup.
 * Returns a ref to attach to the trigger element and the ScrollTrigger instance.
 *
 * @example
 * ```tsx
 * function AnimatedSection() {
 *   const { ref, scrollTrigger } = useScrollTrigger({
 *     start: "top 80%",
 *     onEnter: () => console.log("Entered!"),
 *   });
 *
 *   return <section ref={ref}>Content</section>;
 * }
 * ```
 */
export function useScrollTrigger<T extends HTMLElement = HTMLDivElement>(
  config: ScrollTriggerConfig = {}
) {
  const ref = useRef<T>(null);
  const scrollTriggerRef = useRef<ScrollTrigger | null>(null);
  const contextRef = useRef<gsap.Context | null>(null);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;

    // Create GSAP context for proper cleanup
    contextRef.current = gsap.context(() => {
      scrollTriggerRef.current = ScrollTrigger.create({
        trigger: config.trigger || element,
        start: config.start ?? "top 80%",
        end: config.end ?? "bottom 20%",
        pin: config.pin,
        markers: config.markers,
        scrub: config.scrub,
        toggleActions: config.toggleActions ?? "play none none reverse",
        toggleClass: config.toggleClass,
        onEnter: config.onEnter,
        onLeave: config.onLeave,
        onEnterBack: config.onEnterBack,
        onLeaveBack: config.onLeaveBack,
        onUpdate: config.onUpdate,
        onRefresh: config.onRefresh,
      });
    });

    return () => {
      if (scrollTriggerRef.current) {
        scrollTriggerRef.current.kill();
        scrollTriggerRef.current = null;
      }
      if (contextRef.current) {
        contextRef.current.revert();
        contextRef.current = null;
      }
    };
  }, [
    config.trigger,
    config.start,
    config.end,
    config.pin,
    config.markers,
    config.scrub,
    config.toggleActions,
    config.toggleClass,
    config.onEnter,
    config.onLeave,
    config.onEnterBack,
    config.onLeaveBack,
    config.onUpdate,
    config.onRefresh,
  ]);

  return {
    ref,
    scrollTrigger: scrollTriggerRef.current,
  };
}

// ============================================================================
// useTimeline
// ============================================================================

/**
 * Creates and manages a GSAP timeline with automatic cleanup.
 * Returns the timeline instance and control methods.
 *
 * @example
 * ```tsx
 * function AnimatedComponent() {
 *   const { timeline, play, pause, reverse, restart } = useTimeline({
 *     paused: true,
 *     defaults: { duration: 0.5, ease: "power2.out" },
 *   });
 *
 *   useEffect(() => {
 *     if (timeline) {
 *       timeline
 *         .to(".box", { x: 100 })
 *         .to(".box", { rotation: 360 });
 *     }
 *   }, [timeline]);
 *
 *   return <button onClick={play}>Play Animation</button>;
 * }
 * ```
 */
export function useTimeline(options: UseTimelineOptions = {}) {
  const timelineRef = useRef<gsap.core.Timeline | null>(null);
  const contextRef = useRef<gsap.Context | null>(null);

  // Initialize timeline
  useEffect(() => {
    contextRef.current = gsap.context(() => {
      timelineRef.current = gsap.timeline({
        paused: options.paused ?? false,
        defaults: options.defaults ?? {
          duration: formaDuration.normal,
          ease: formaReveal,
        },
        repeat: options.repeat,
        repeatDelay: options.repeatDelay,
        yoyo: options.yoyo,
        onComplete: options.onComplete,
        onUpdate: options.onUpdate,
      });
    });

    return () => {
      if (timelineRef.current) {
        timelineRef.current.kill();
        timelineRef.current = null;
      }
      if (contextRef.current) {
        contextRef.current.revert();
        contextRef.current = null;
      }
    };
  }, [
    options.paused,
    options.defaults,
    options.repeat,
    options.repeatDelay,
    options.yoyo,
    options.onComplete,
    options.onUpdate,
  ]);

  // Control methods
  const play = useCallback(() => {
    timelineRef.current?.play();
  }, []);

  const pause = useCallback(() => {
    timelineRef.current?.pause();
  }, []);

  const reverse = useCallback(() => {
    timelineRef.current?.reverse();
  }, []);

  const restart = useCallback(() => {
    timelineRef.current?.restart();
  }, []);

  const seek = useCallback((position: number | string) => {
    timelineRef.current?.seek(position);
  }, []);

  const progress = useCallback((value?: number) => {
    if (value !== undefined) {
      timelineRef.current?.progress(value);
    }
    return timelineRef.current?.progress() ?? 0;
  }, []);

  const clear = useCallback(() => {
    timelineRef.current?.clear();
  }, []);

  return {
    timeline: timelineRef.current,
    play,
    pause,
    reverse,
    restart,
    seek,
    progress,
    clear,
  };
}

// ============================================================================
// useGSAPContext
// ============================================================================

/**
 * Creates a GSAP context scoped to a container element.
 * All animations within the context are automatically cleaned up on unmount.
 *
 * @example
 * ```tsx
 * function AnimatedContainer() {
 *   const { ref, context } = useGSAPContext();
 *
 *   useEffect(() => {
 *     if (context) {
 *       context.add(() => {
 *         gsap.to(".item", { opacity: 1, stagger: 0.1 });
 *       });
 *     }
 *   }, [context]);
 *
 *   return (
 *     <div ref={ref}>
 *       <div className="item">Item 1</div>
 *       <div className="item">Item 2</div>
 *     </div>
 *   );
 * }
 * ```
 */
export function useGSAPContext<T extends HTMLElement = HTMLDivElement>() {
  const ref = useRef<T>(null);
  const contextRef = useRef<gsap.Context | null>(null);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;

    contextRef.current = gsap.context(() => {}, element);

    return () => {
      if (contextRef.current) {
        contextRef.current.revert();
        contextRef.current = null;
      }
    };
  }, []);

  return {
    ref,
    context: contextRef.current,
  };
}

// ============================================================================
// useScrollAnimation (GSAP version)
// ============================================================================

interface UseGSAPScrollAnimationOptions {
  /** Animation properties */
  from?: gsap.TweenVars;
  to?: gsap.TweenVars;
  /** ScrollTrigger options */
  trigger?: ScrollTriggerConfig;
}

/**
 * Combines ScrollTrigger with a tween for scroll-triggered animations.
 * Provides a simple API for common scroll animation patterns.
 *
 * @example
 * ```tsx
 * function FadeInSection() {
 *   const ref = useGSAPScrollAnimation({
 *     from: { opacity: 0, y: 50 },
 *     to: { opacity: 1, y: 0 },
 *     trigger: { start: "top 80%" },
 *   });
 *
 *   return <section ref={ref}>Fades in on scroll</section>;
 * }
 * ```
 */
export function useGSAPScrollAnimation<T extends HTMLElement = HTMLDivElement>(
  options: UseGSAPScrollAnimationOptions = {}
) {
  const ref = useRef<T>(null);
  const contextRef = useRef<gsap.Context | null>(null);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;

    contextRef.current = gsap.context(() => {
      const { from, to, trigger } = options;

      // Set initial state if "from" is provided
      if (from) {
        gsap.set(element, from);
      }

      // Create the animation
      if (to) {
        gsap.to(element, {
          ...to,
          scrollTrigger: {
            trigger: trigger?.trigger || element,
            start: trigger?.start ?? "top 80%",
            end: trigger?.end ?? "bottom 20%",
            toggleActions: trigger?.toggleActions ?? "play none none reverse",
            markers: trigger?.markers,
            scrub: trigger?.scrub,
            onEnter: trigger?.onEnter,
            onLeave: trigger?.onLeave,
            onEnterBack: trigger?.onEnterBack,
            onLeaveBack: trigger?.onLeaveBack,
          },
        });
      }
    });

    return () => {
      if (contextRef.current) {
        contextRef.current.revert();
        contextRef.current = null;
      }
    };
  }, [options]);

  return ref;
}

// ============================================================================
// Exports
// ============================================================================

export { gsap, ScrollTrigger };
