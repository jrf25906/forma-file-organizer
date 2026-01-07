"use client";

import { useRef, useEffect, useCallback } from "react";
import { trackEvent, type AnalyticsEventData } from "@/lib/analytics";

// ═══════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════

export interface ScrollMilestone {
  /** Threshold value (0-1) at which to fire */
  threshold: number;
  /** Label for the milestone (e.g., "25%", "halfway") */
  label: string;
}

export interface UseScrollAnalyticsOptions {
  /** Name of the section being tracked */
  sectionName: string;
  /** Custom milestones (defaults to 25%, 50%, 75%, 100%) */
  milestones?: ScrollMilestone[];
  /** Additional data to include with each event */
  additionalData?: AnalyticsEventData;
  /** Whether to track narrative beats/sections */
  trackBeats?: boolean;
  /** Optional callback when a milestone is reached */
  onMilestone?: (milestone: ScrollMilestone, progress: number) => void;
}

export interface ScrollAnalyticsReturn {
  /** Reset tracking (e.g., when component unmounts and remounts) */
  reset: () => void;
  /** Get list of milestones that have been fired */
  getFiredMilestones: () => number[];
}

// ═══════════════════════════════════════════════════════════════════════════
// DEFAULT MILESTONES
// ═══════════════════════════════════════════════════════════════════════════

const DEFAULT_MILESTONES: ScrollMilestone[] = [
  { threshold: 0.25, label: "25%" },
  { threshold: 0.5, label: "50%" },
  { threshold: 0.75, label: "75%" },
  { threshold: 1.0, label: "100%" },
];

// ═══════════════════════════════════════════════════════════════════════════
// HOOK
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Track scroll depth analytics for a section.
 *
 * Fires events when scroll progress crosses defined milestones.
 * Events are only fired once per milestone per session (won't re-fire on scroll up/down).
 *
 * @param progress - Current scroll progress (0-1)
 * @param options - Configuration options
 * @returns Object with reset function and fired milestones getter
 *
 * @example
 * ```tsx
 * function HeroSection() {
 *   const [scrollProgress, setScrollProgress] = useState(0);
 *
 *   useScrollAnalytics(scrollProgress, {
 *     sectionName: 'hero',
 *     onMilestone: (milestone) => console.log(`Reached ${milestone.label}`)
 *   });
 *
 *   return <section>...</section>;
 * }
 * ```
 */
export function useScrollAnalytics(
  progress: number,
  options: UseScrollAnalyticsOptions
): ScrollAnalyticsReturn {
  const {
    sectionName,
    milestones = DEFAULT_MILESTONES,
    additionalData = {},
    onMilestone,
  } = options;

  // Track which milestones have been fired (persists across re-renders)
  const firedMilestonesRef = useRef<Set<number>>(new Set());

  // Track milestones
  useEffect(() => {
    milestones.forEach((milestone) => {
      if (
        progress >= milestone.threshold &&
        !firedMilestonesRef.current.has(milestone.threshold)
      ) {
        // Mark as fired
        firedMilestonesRef.current.add(milestone.threshold);

        // Fire analytics event
        trackEvent("hero_scroll_milestone", {
          section: sectionName,
          milestone: milestone.threshold * 100,
          milestone_label: milestone.label,
          actual_progress: Math.round(progress * 100),
          ...additionalData,
        });

        // Call optional callback
        onMilestone?.(milestone, progress);
      }
    });
  }, [progress, milestones, sectionName, additionalData, onMilestone]);

  // Reset function - clears fired milestones
  const reset = useCallback(() => {
    firedMilestonesRef.current.clear();
  }, []);

  // Get fired milestones
  const getFiredMilestones = useCallback(() => {
    return Array.from(firedMilestonesRef.current).sort((a, b) => a - b);
  }, []);

  return { reset, getFiredMilestones };
}

// ═══════════════════════════════════════════════════════════════════════════
// BEAT TRACKING HOOK
// ═══════════════════════════════════════════════════════════════════════════

export interface NarrativeBeat {
  id: string;
  progress: [number, number]; // [start, end]
}

export interface UseBeatAnalyticsOptions {
  /** Name of the section containing the beats */
  sectionName: string;
  /** Array of narrative beats to track */
  beats: NarrativeBeat[];
  /** Additional data to include with each event */
  additionalData?: AnalyticsEventData;
  /** Optional callback when a beat is entered */
  onBeatEnter?: (beat: NarrativeBeat, beatIndex: number) => void;
}

/**
 * Track which narrative beats/sections users view.
 *
 * Fires an event when a user enters each beat for the first time.
 *
 * @param progress - Current scroll progress (0-1)
 * @param options - Configuration options
 *
 * @example
 * ```tsx
 * const BEATS = [
 *   { id: 'intro', progress: [0, 0.25] },
 *   { id: 'feature', progress: [0.25, 0.5] },
 * ];
 *
 * useBeatAnalytics(scrollProgress, {
 *   sectionName: 'hero',
 *   beats: BEATS,
 * });
 * ```
 */
export function useBeatAnalytics(
  progress: number,
  options: UseBeatAnalyticsOptions
): void {
  const { sectionName, beats, additionalData = {}, onBeatEnter } = options;

  // Track which beats have been viewed
  const viewedBeatsRef = useRef<Set<string>>(new Set());

  useEffect(() => {
    beats.forEach((beat, index) => {
      const [start, end] = beat.progress;
      const isInBeat = progress >= start && progress < end;

      if (isInBeat && !viewedBeatsRef.current.has(beat.id)) {
        // Mark as viewed
        viewedBeatsRef.current.add(beat.id);

        // Fire analytics event
        trackEvent("hero_beat_viewed", {
          section: sectionName,
          beat_id: beat.id,
          beat_index: index,
          beat_start: start * 100,
          beat_end: end * 100,
          ...additionalData,
        });

        // Call optional callback
        onBeatEnter?.(beat, index);
      }
    });
  }, [progress, beats, sectionName, additionalData, onBeatEnter]);
}

// ═══════════════════════════════════════════════════════════════════════════
// CTA VISIBILITY TRACKING
// ═══════════════════════════════════════════════════════════════════════════

export interface UseCtaVisibilityOptions {
  /** When the CTA becomes visible (progress threshold) */
  visibilityThreshold: number;
  /** Name of the CTA being tracked */
  ctaName: string;
  /** Section containing the CTA */
  sectionName: string;
  /** Additional data to include */
  additionalData?: AnalyticsEventData;
}

/**
 * Track when a CTA becomes visible during scroll.
 *
 * Fires once when the scroll progress crosses the visibility threshold.
 *
 * @param progress - Current scroll progress (0-1)
 * @param options - Configuration options
 */
export function useCtaVisibilityAnalytics(
  progress: number,
  options: UseCtaVisibilityOptions
): void {
  const { visibilityThreshold, ctaName, sectionName, additionalData = {} } = options;

  const hasFiredRef = useRef(false);

  useEffect(() => {
    if (progress >= visibilityThreshold && !hasFiredRef.current) {
      hasFiredRef.current = true;

      trackEvent("hero_cta_visible", {
        section: sectionName,
        cta_name: ctaName,
        scroll_depth: Math.round(progress * 100),
        ...additionalData,
      });
    }
  }, [progress, visibilityThreshold, ctaName, sectionName, additionalData]);
}
