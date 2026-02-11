"use client";

import { useMemo } from "react";

/* ------------------------------------------------------------------ */
/*  Data                                                               */
/* ------------------------------------------------------------------ */

const RULE_1_TEXT = 'Move screenshots to ~/Screenshots';
const RULE_2_TEXT = 'Sort code files into ~/Projects';

/* ------------------------------------------------------------------ */
/*  Helpers                                                            */
/* ------------------------------------------------------------------ */

/** Clamp a sub-range of progress to 0-1. */
function subProgress(progress: number, start: number, end: number): number {
  if (progress <= start) return 0;
  if (progress >= end) return 1;
  return (progress - start) / (end - start);
}

/** Smooth ease-out curve for CSS-driven animations. */
function easeOut(t: number): number {
  return 1 - Math.pow(1 - t, 3);
}

/* ------------------------------------------------------------------ */
/*  AnimatedRuleDemo                                                   */
/* ------------------------------------------------------------------ */

interface AnimatedRuleDemoProps {
  progress: number;
}

export function AnimatedRuleDemo({ progress }: AnimatedRuleDemoProps) {
  const computed = useMemo(() => {
    /* Phase 1 (0.0 - 0.3): First rule types */
    const typing1 = subProgress(progress, 0.0, 0.3);
    const chars1 = Math.floor(typing1 * RULE_1_TEXT.length);
    const visible1 = RULE_1_TEXT.slice(0, chars1);

    /* Phase 2 (0.3 - 0.6): First rule card materializes */
    const card1Raw = subProgress(progress, 0.3, 0.5);
    const card1 = easeOut(card1Raw);
    const card1Opacity = card1;
    const card1Y = 12 * (1 - card1);

    /* Phase 3 (0.6 - 0.85): Second rule types */
    const typing2 = subProgress(progress, 0.6, 0.85);
    const chars2 = Math.floor(typing2 * RULE_2_TEXT.length);
    const visible2 = RULE_2_TEXT.slice(0, chars2);
    const input2Opacity = progress >= 0.58 ? Math.min(1, subProgress(progress, 0.58, 0.62)) : 0;

    /* Second card materializes near end of typing */
    const card2Raw = subProgress(progress, 0.78, 0.92);
    const card2 = easeOut(card2Raw);
    const card2Opacity = card2;
    const card2Y = 12 * (1 - card2);

    /* Phase 4 (0.85 - 1.0): Match count badges */
    const badge1Raw = subProgress(progress, 0.85, 0.93);
    const badge1 = easeOut(badge1Raw);
    const badge2Raw = subProgress(progress, 0.9, 1.0);
    const badge2 = easeOut(badge2Raw);

    /* Cursor blink visibility - only show while typing is in progress */
    const showCursor1 = progress < 0.32;
    const showCursor2 = progress >= 0.58 && progress < 0.87;

    return {
      visible1,
      showCursor1,
      card1Opacity,
      card1Y,
      visible2,
      input2Opacity,
      showCursor2,
      card2Opacity,
      card2Y,
      badge1Opacity: badge1,
      badge1Scale: 0.8 + 0.2 * badge1,
      badge2Opacity: badge2,
      badge2Scale: 0.8 + 0.2 * badge2,
    };
  }, [progress]);

  return (
    <div className="space-y-3">
      {/* First input area */}
      <div className="rounded-lg border border-[var(--demo-row-border)] bg-[var(--demo-row-bg-strong)] px-3 py-2.5">
        <span className="font-mono text-[11px] text-[var(--text-secondary)]">
          {computed.visible1}
          {computed.showCursor1 && (
            <span className="animate-pulse text-forma-steel-blue">|</span>
          )}
        </span>
        {!computed.visible1 && !computed.showCursor1 && (
          <span className="text-[11px] text-[var(--demo-placeholder)]">&nbsp;</span>
        )}
      </div>

      {/* First rule card */}
      <div
        style={{
          opacity: computed.card1Opacity,
          transform: `translateY(${computed.card1Y}px)`,
        }}
      >
        <div className="flex items-center justify-between rounded-lg border border-[var(--demo-row-border)] bg-[var(--demo-row-bg)] px-3 py-2">
          <span className="font-mono text-[11px] text-[var(--text-secondary)]">
            Move screenshots to{" "}
            <span className="text-forma-steel-blue">~/Screenshots</span>
          </span>
          <div className="flex items-center gap-1.5">
            <span
              style={{
                opacity: computed.badge1Opacity,
                transform: `scale(${computed.badge1Scale})`,
              }}
              className="rounded-full bg-forma-steel-blue/15 px-2 py-0.5 text-[9px] font-medium text-forma-steel-blue"
            >
              12 matched
            </span>
            <span className="rounded-full bg-forma-sage/15 px-2 py-0.5 text-[9px] font-medium text-forma-sage">
              Active
            </span>
          </div>
        </div>
      </div>

      {/* Second input area */}
      <div
        className="rounded-lg border border-[var(--demo-row-border)] bg-[var(--demo-row-bg-strong)] px-3 py-2.5"
        style={{ opacity: computed.input2Opacity }}
      >
        <span className="font-mono text-[11px] text-[var(--text-secondary)]">
          {computed.visible2}
          {computed.showCursor2 && (
            <span className="animate-pulse text-forma-steel-blue">|</span>
          )}
        </span>
        {!computed.visible2 && !computed.showCursor2 && (
          <span className="text-[11px] text-[var(--demo-placeholder)]">&nbsp;</span>
        )}
      </div>

      {/* Second rule card */}
      <div
        style={{
          opacity: computed.card2Opacity,
          transform: `translateY(${computed.card2Y}px)`,
        }}
      >
        <div className="flex items-center justify-between rounded-lg border border-[var(--demo-row-border)] bg-[var(--demo-row-bg)] px-3 py-2">
          <span className="font-mono text-[11px] text-[var(--text-secondary)]">
            Sort code files into{" "}
            <span className="text-forma-steel-blue">~/Projects</span>
          </span>
          <div className="flex items-center gap-1.5">
            <span
              style={{
                opacity: computed.badge2Opacity,
                transform: `scale(${computed.badge2Scale})`,
              }}
              className="rounded-full bg-forma-steel-blue/15 px-2 py-0.5 text-[9px] font-medium text-forma-steel-blue"
            >
              8 matched
            </span>
            <span className="rounded-full bg-forma-sage/15 px-2 py-0.5 text-[9px] font-medium text-forma-sage">
              Active
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

export default AnimatedRuleDemo;
