"use client";

import { useMemo } from "react";

/* ------------------------------------------------------------------ */
/*  Data                                                               */
/* ------------------------------------------------------------------ */

const fileRows = [
  {
    name: "Screenshot 2024-01-15.png",
    from: "~/Desktop",
    to: "~/Screenshots",
  },
  {
    name: "Invoice_March.pdf",
    from: "~/Downloads",
    to: "~/Documents/PDFs",
  },
  {
    name: "notes.txt",
    from: "~/Desktop",
    to: "~/Documents",
  },
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
/*  AnimatedPreviewDemo                                                */
/* ------------------------------------------------------------------ */

interface AnimatedPreviewDemoProps {
  progress: number;
}

export function AnimatedPreviewDemo({ progress }: AnimatedPreviewDemoProps) {
  const computed = useMemo(() => {
    /* Phase 1 (0.0 - 0.3): File list appears, all checked initially */
    const listAppear = easeOut(subProgress(progress, 0.0, 0.2));

    /* Phase 2 (0.3 - 0.5): Third checkbox unchecks (user deselects) */
    const uncheckP = subProgress(progress, 0.3, 0.45);
    const thirdChecked = uncheckP < 0.5;

    /* Checkbox scale animation for the toggle */
    const toggleScale =
      uncheckP > 0 && uncheckP < 1
        ? 1 + 0.15 * Math.sin(uncheckP * Math.PI)
        : 1;

    /* Phase 3 (0.5 - 0.75): Button press animation */
    const btnAppearP = subProgress(progress, 0.45, 0.52);
    const btnPressP = subProgress(progress, 0.55, 0.65);
    const isMoving = progress >= 0.6 && progress < 0.78;
    const btnScale =
      btnPressP > 0 && btnPressP < 1
        ? 1 - 0.05 * Math.sin(btnPressP * Math.PI)
        : 1;

    /* Phase 4 (0.75 - 1.0): Files show "Moved" badges staggered */
    const moved0 = easeOut(subProgress(progress, 0.75, 0.85));
    const moved1 = easeOut(subProgress(progress, 0.8, 0.9));
    /* Third file was unchecked, so it shows "Skipped" */
    const moved2 = easeOut(subProgress(progress, 0.85, 0.95));

    /* Are we past the complete point? */
    const allDone = progress >= 0.95;

    return {
      listAppear,
      thirdChecked,
      toggleScale,
      btnAppearP: easeOut(btnAppearP),
      btnScale,
      isMoving,
      allDone,
      movedBadges: [moved0, moved1, moved2],
    };
  }, [progress]);

  const checkboxClasses = (checked: boolean, scaleOverride?: number) => {
    const scale = scaleOverride ?? 1;
    return {
      className: `mt-0.5 inline-flex h-3.5 w-3.5 flex-shrink-0 items-center justify-center rounded text-[8px] transition-colors ${
        checked
          ? "bg-forma-muted-blue text-white"
          : "border border-forma-muted-blue/40 bg-transparent text-transparent"
      }`,
      style: { transform: `scale(${scale})` },
    };
  };

  return (
    <div className="space-y-2" style={{ opacity: computed.listAppear }}>
      {/* File rows */}
      {fileRows.map((file, i) => {
        const isThird = i === 2;
        const checked = isThird ? computed.thirdChecked : true;
        const cbScale = isThird ? computed.toggleScale : 1;
        const badge = computed.movedBadges[i];
        const isMoved = badge > 0 && !isThird;
        const isSkipped = badge > 0 && isThird;

        return (
          <div
            key={file.name}
            className={`flex items-start gap-2 rounded-lg border border-white/[0.08] bg-white/[0.04] px-3 py-2 ${
              !checked ? "opacity-60" : ""
            }`}
            style={{
              opacity: computed.listAppear * (isThird && !checked ? 0.6 : 1),
            }}
          >
            <span {...checkboxClasses(checked, cbScale)}>
              {checked ? (isMoved ? "\u2713" : "\u2713") : "\u2713"}
            </span>
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <p
                  className={`truncate text-[11px] text-[var(--text-secondary)] ${
                    isMoved ? "line-through opacity-60" : ""
                  }`}
                >
                  {file.name}
                </p>
                {/* Moved / Skipped badge */}
                {(isMoved || isSkipped) && (
                  <span
                    className={`flex-shrink-0 rounded-full px-1.5 py-0.5 text-[8px] font-medium ${
                      isMoved
                        ? "bg-forma-sage/15 text-forma-sage"
                        : "bg-white/[0.08] text-[var(--text-muted)]"
                    }`}
                    style={{
                      opacity: badge,
                      transform: `scale(${0.8 + 0.2 * badge})`,
                    }}
                  >
                    {isMoved ? "Moved" : "Skipped"}
                  </span>
                )}
              </div>
              <p className="truncate text-[10px] text-[var(--text-muted)]">
                {file.from} {"\u2192"}{" "}
                <span className="text-forma-sage">{file.to}</span>
              </p>
            </div>
          </div>
        );
      })}

      {/* Approve / Moving button */}
      <div
        className="flex justify-end pt-1"
        style={{ opacity: computed.btnAppearP }}
      >
        <div
          className={`inline-flex items-center gap-1.5 rounded-lg px-4 py-1.5 text-[11px] font-medium ${
            computed.allDone
              ? "bg-forma-sage/20 text-forma-sage"
              : computed.isMoving
                ? "bg-forma-muted-blue/20 text-forma-muted-blue"
                : "bg-forma-muted-blue/20 text-forma-muted-blue"
          }`}
          style={{ transform: `scale(${computed.btnScale})` }}
        >
          {computed.allDone ? (
            <>
              <span className="text-forma-sage">{"\u2713"}</span> Done
            </>
          ) : computed.isMoving ? (
            <>
              <span className="inline-block h-2.5 w-2.5 animate-spin rounded-full border border-forma-muted-blue/40 border-t-forma-muted-blue" />
              Moving...
            </>
          ) : (
            "Approve 2 files"
          )}
        </div>
      </div>
    </div>
  );
}

export default AnimatedPreviewDemo;
