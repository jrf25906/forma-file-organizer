"use client";

import { useRef, useEffect, useCallback, type ReactNode, type ComponentType } from "react";
import type { LucideIcon } from "lucide-react";
import { useScrollSceneProgress } from "@/components/animation/ScrollScene";
import { gsap } from "@/lib/animation/gsap-config";
import { formaReveal, formaDuration } from "@/lib/animation/ease-curves";
import MacWindowFrame from "@/components/ui/MacWindowFrame";

/* ------------------------------------------------------------------ */
/*  Types                                                              */
/* ------------------------------------------------------------------ */

export type ShowcaseFeature = {
  id: string;
  icon: LucideIcon;
  title: string;
  description: string;
  accentText: string;
  accentBg: string;
  preview: ReactNode;
  /** Animated demo component that receives scroll-driven progress (0-1). */
  animatedDemo?: ComponentType<{ progress: number }>;
};

interface FeatureShowcaseProps {
  features: ShowcaseFeature[];
}

/* ------------------------------------------------------------------ */
/*  Progress -> active feature mapping                                 */
/* ------------------------------------------------------------------ */

/** Segment boundaries for each feature (start, end). */
const FEATURE_SEGMENTS: [number, number][] = [
  [0.05, 0.275],
  [0.275, 0.50],
  [0.50, 0.725],
  [0.725, 0.97],
];

/** Maps scroll progress (0-1) to a feature index (0-3). */
function getActiveFeature(progress: number): number {
  if (progress < 0.275) return 0;
  if (progress < 0.50) return 1;
  if (progress < 0.725) return 2;
  return 3;
}

/** Computes 0-1 sub-progress for a specific feature index. */
function getFeatureProgress(progress: number, index: number): number {
  const [start, end] = FEATURE_SEGMENTS[index];
  if (progress <= start) return 0;
  if (progress >= end) return 1;
  return (progress - start) / (end - start);
}

/* ------------------------------------------------------------------ */
/*  FeatureShowcase                                                    */
/* ------------------------------------------------------------------ */

export function FeatureShowcase({ features }: FeatureShowcaseProps) {
  const progress = useScrollSceneProgress();
  const activeIndex = getActiveFeature(progress);

  /* Per-feature sub-progress values (0-1 within each feature's segment) */
  const featureProgressValues = FEATURE_SEGMENTS.map((_, i) =>
    getFeatureProgress(progress, i)
  );

  /* Refs for animated elements */
  const textPanelsRef = useRef<(HTMLDivElement | null)[]>([]);
  const demoPanelsRef = useRef<(HTMLDivElement | null)[]>([]);
  const dotsRef = useRef<(HTMLButtonElement | null)[]>([]);
  const prevIndexRef = useRef(0);

  /* Ref setters (stable callbacks) */
  const setTextRef = useCallback(
    (el: HTMLDivElement | null, i: number) => {
      textPanelsRef.current[i] = el;
    },
    []
  );
  const setDemoRef = useCallback(
    (el: HTMLDivElement | null, i: number) => {
      demoPanelsRef.current[i] = el;
    },
    []
  );
  const setDotRef = useCallback(
    (el: HTMLButtonElement | null, i: number) => {
      dotsRef.current[i] = el;
    },
    []
  );

  /* ---- Initial state: hide all except first ---- */
  useEffect(() => {
    features.forEach((_, i) => {
      const textEl = textPanelsRef.current[i];
      const demoEl = demoPanelsRef.current[i];
      if (textEl) {
        gsap.set(textEl, {
          opacity: i === 0 ? 1 : 0,
          y: i === 0 ? 0 : 24,
          position: "absolute",
          top: 0,
          left: 0,
          width: "100%",
        });
      }
      if (demoEl) {
        gsap.set(demoEl, {
          opacity: i === 0 ? 1 : 0,
          scale: i === 0 ? 1 : 0.96,
          position: "absolute",
          top: 0,
          left: 0,
          width: "100%",
        });
      }
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [features.length]);

  /* ---- Crossfade when activeIndex changes ---- */
  useEffect(() => {
    const prev = prevIndexRef.current;
    if (prev === activeIndex) return;

    const dur = formaDuration.fast;
    const ease = formaReveal;

    /* Text crossfade */
    const oldText = textPanelsRef.current[prev];
    const newText = textPanelsRef.current[activeIndex];
    if (oldText) {
      gsap.to(oldText, { opacity: 0, y: -16, duration: dur * 0.6, ease });
    }
    if (newText) {
      gsap.set(newText, { y: 24 });
      gsap.to(newText, { opacity: 1, y: 0, duration: dur, ease, delay: dur * 0.15 });
    }

    /* Demo crossfade */
    const oldDemo = demoPanelsRef.current[prev];
    const newDemo = demoPanelsRef.current[activeIndex];
    if (oldDemo) {
      gsap.to(oldDemo, { opacity: 0, scale: 0.96, duration: dur * 0.6, ease });
    }
    if (newDemo) {
      gsap.set(newDemo, { scale: 0.96 });
      gsap.to(newDemo, { opacity: 1, scale: 1, duration: dur, ease, delay: dur * 0.1 });
    }

    /* Progress dots */
    dotsRef.current.forEach((dot, i) => {
      if (!dot) return;
      gsap.to(dot, {
        scale: i === activeIndex ? 1.5 : 1,
        opacity: i === activeIndex ? 1 : 0.35,
        duration: 0.25,
        ease,
      });
    });

    prevIndexRef.current = activeIndex;
  }, [activeIndex]);

  /* ---- Intro/outro opacity based on raw progress ---- */
  const sectionOpacity =
    progress < 0.03
      ? progress / 0.03
      : progress > 0.95
        ? (1 - progress) / 0.05
        : 1;

  return (
    <div
      className="flex h-screen w-full items-center justify-center px-6 lg:px-12"
      style={{ opacity: Math.max(0, Math.min(1, sectionOpacity)) }}
    >
      <div className="flex w-full max-w-6xl items-center gap-10 lg:gap-16">
        {/* ---- Progress dots (left edge) ---- */}
        <div className="hidden flex-col items-center gap-3 md:flex" aria-label="Feature progress">
          {features.map((f, i) => (
            <button
              key={f.id}
              ref={(el) => setDotRef(el, i)}
              type="button"
              tabIndex={-1}
              aria-label={f.title}
              className="h-2 w-2 rounded-full bg-white/50 transition-colors"
              style={{
                opacity: i === 0 ? 1 : 0.35,
                transform: i === 0 ? "scale(1.5)" : "scale(1)",
              }}
            />
          ))}
        </div>

        {/* ---- Left panel: text (40%) ---- */}
        <div className="relative w-[40%] shrink-0">
          {/* Reserve height so absolute-positioned children don't collapse */}
          <div className="invisible" aria-hidden="true">
            <FeatureTextBlock feature={features[0]} />
          </div>

          {features.map((feature, i) => (
            <div
              key={feature.id}
              ref={(el) => setTextRef(el, i)}
              aria-hidden={i !== activeIndex}
            >
              <FeatureTextBlock feature={feature} />
            </div>
          ))}
        </div>

        {/* ---- Right panel: demo (60%) ---- */}
        <div className="relative min-w-0 flex-1">
          {/* Reserve height */}
          <div className="invisible" aria-hidden="true">
            <DemoFrame>
              <FeatureDemoContent
                feature={features[0]}
                progress={featureProgressValues[0]}
              />
            </DemoFrame>
          </div>

          {features.map((feature, i) => (
            <div
              key={feature.id}
              ref={(el) => setDemoRef(el, i)}
              aria-hidden={i !== activeIndex}
            >
              <DemoFrame>
                <FeatureDemoContent
                  feature={feature}
                  progress={featureProgressValues[i]}
                />
              </DemoFrame>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*  Sub-components                                                     */
/* ------------------------------------------------------------------ */

function FeatureTextBlock({ feature }: { feature: ShowcaseFeature }) {
  const Icon = feature.icon;
  return (
    <div className="space-y-4">
      <div className={`inline-flex h-11 w-11 items-center justify-center rounded-xl ${feature.accentBg}`}>
        <Icon className={`h-5 w-5 ${feature.accentText}`} />
      </div>
      <h3 className="font-display text-2xl tracking-tight text-[var(--text-primary)] lg:text-3xl">
        {feature.title}
      </h3>
      <p className="text-[15px] leading-relaxed text-[var(--text-secondary)] lg:text-base">
        {feature.description}
      </p>
    </div>
  );
}

/** Renders the animated demo if available, otherwise falls back to the static preview. */
function FeatureDemoContent({
  feature,
  progress,
}: {
  feature: ShowcaseFeature;
  progress: number;
}) {
  if (feature.animatedDemo) {
    const AnimDemo = feature.animatedDemo;
    return <AnimDemo progress={progress} />;
  }
  return <>{feature.preview}</>;
}

function DemoFrame({ children }: { children: ReactNode }) {
  return (
    <MacWindowFrame title="Forma">
      <div className="p-5 lg:p-6">{children}</div>
    </MacWindowFrame>
  );
}

export default FeatureShowcase;
