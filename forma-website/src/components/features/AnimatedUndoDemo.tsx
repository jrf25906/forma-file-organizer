"use client";

import { useMemo } from "react";

/* ------------------------------------------------------------------ */
/*  Data                                                               */
/* ------------------------------------------------------------------ */

const timelineRows = [
  { file: "report.pdf",  dest: "~/Documents",   time: "2m ago" },
  { file: "hero.png",    dest: "~/Screenshots",  time: "5m ago" },
  { file: "backup.zip",  dest: "~/Archive",      time: "12m ago" },
];

/* ------------------------------------------------------------------ */
/*  Helpers                                                            */
/* ------------------------------------------------------------------ */

function subProgress(progress: number, start: number, end: number): number {
  if (progress <= start) return 0;
  if (progress >= end) return 1;
  return (progress - start) / (end - start);
}

function easeOut(t: number): number {
  return 1 - Math.pow(1 - t, 3);
}

/* ------------------------------------------------------------------ */
/*  AnimatedUndoDemo                                                   */
/* ------------------------------------------------------------------ */

interface AnimatedUndoDemoProps {
  progress: number;
}

export function AnimatedUndoDemo({ progress }: AnimatedUndoDemoProps) {
  const computed = useMemo(() => {
    /* Phase 1 (0.0 - 0.3): Timeline rows appear, staggered */
    const row0 = easeOut(subProgress(progress, 0.0, 0.12));
    const row1 = easeOut(subProgress(progress, 0.08, 0.2));
    const row2 = easeOut(subProgress(progress, 0.16, 0.3));
    const rowOpacities = [row0, row1, row2];

    /* Phase 2 (0.3 - 0.55): Undo button on middle row highlights */
    const undoHighlightP = subProgress(progress, 0.3, 0.45);
    const undoPressP = subProgress(progress, 0.42, 0.55);
    const undoBtnScale =
      undoHighlightP > 0 && undoHighlightP < 1
        ? 1 + 0.1 * Math.sin(undoHighlightP * Math.PI)
        : undoPressP > 0 && undoPressP < 1
          ? 1 - 0.05 * Math.sin(undoPressP * Math.PI)
          : 1;
    const undoBtnGlow = undoHighlightP > 0 && undoHighlightP < 1;

    /* Phase 3 (0.55 - 0.8): Row shifts, file name highlights, "Undone" badge */
    const slideBack = easeOut(subProgress(progress, 0.55, 0.72));
    const nameHighlight = subProgress(progress, 0.58, 0.72);
    const nameHighlightOpacity =
      nameHighlight > 0 && nameHighlight < 1
        ? Math.sin(nameHighlight * Math.PI) * 0.4
        : 0;

    /* Phase 4 (0.8 - 1.0): Badge transitions from "Undone" to "Restored" */
    const restoredP = easeOut(subProgress(progress, 0.8, 1.0));

    /* State of the middle row */
    const isUndoing = progress >= 0.45 && progress < 0.72;
    const isUndone = progress >= 0.72;
    const isRestored = progress >= 0.85;

    return {
      rowOpacities,
      undoBtnScale,
      undoBtnGlow,
      slideBack,
      nameHighlightOpacity,
      restoredP,
      isUndoing,
      isUndone,
      isRestored,
    };
  }, [progress]);

  return (
    <div className="space-y-1.5">
      {timelineRows.map((row, i) => {
        const isMiddle = i === 1;
        const rowOpacity = computed.rowOpacities[i];
        const translateX = isMiddle ? -4 * computed.slideBack : 0;

        return (
          <div
            key={row.file}
            className="flex items-center justify-between rounded-lg border border-white/[0.08] bg-white/[0.04] px-3 py-2"
            style={{
              opacity: rowOpacity,
              transform: `translateX(${translateX}px) translateY(${8 * (1 - rowOpacity)}px)`,
            }}
          >
            <div className="min-w-0 pr-3">
              <div className="relative">
                <p
                  className={`truncate text-[11px] text-[var(--text-secondary)] ${
                    isMiddle && computed.isUndone ? "line-through" : ""
                  }`}
                >
                  {row.file}
                </p>
                {/* Name highlight flash */}
                {isMiddle && computed.nameHighlightOpacity > 0 && (
                  <div
                    className="pointer-events-none absolute inset-0 rounded bg-forma-warm-orange/20"
                    style={{ opacity: computed.nameHighlightOpacity }}
                  />
                )}
              </div>
              <p className="truncate text-[10px] text-[var(--text-muted)]">
                {row.dest} {"\u00b7"} {row.time}
              </p>
            </div>

            {/* Action button / badge area */}
            {isMiddle ? (
              <div className="flex flex-shrink-0 items-center gap-1.5">
                {computed.isRestored ? (
                  <span
                    className="rounded-md bg-forma-sage/12 px-2 py-1 text-[10px] font-medium text-forma-sage"
                    style={{
                      opacity: computed.restoredP,
                      transform: `scale(${0.85 + 0.15 * computed.restoredP})`,
                    }}
                  >
                    Restored
                  </span>
                ) : computed.isUndone ? (
                  <span className="rounded-md bg-forma-warm-orange/10 px-2 py-1 text-[10px] font-medium text-forma-warm-orange/60">
                    Undone
                  </span>
                ) : (
                  <button
                    type="button"
                    className={`rounded-md px-2 py-1 text-[10px] font-medium ${
                      computed.undoBtnGlow
                        ? "bg-forma-warm-orange/25 text-forma-warm-orange shadow-[0_0_8px_rgba(193,126,74,0.3)]"
                        : "bg-forma-warm-orange/15 text-forma-warm-orange"
                    }`}
                    style={{
                      transform: `scale(${computed.undoBtnScale})`,
                    }}
                  >
                    Undo
                  </button>
                )}
              </div>
            ) : (
              <button
                type="button"
                className="flex-shrink-0 rounded-md bg-forma-warm-orange/15 px-2 py-1 text-[10px] font-medium text-forma-warm-orange"
              >
                Undo
              </button>
            )}
          </div>
        );
      })}
    </div>
  );
}

export default AnimatedUndoDemo;
