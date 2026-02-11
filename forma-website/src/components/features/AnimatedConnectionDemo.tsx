"use client";

import { useMemo } from "react";

/* ------------------------------------------------------------------ */
/*  Data                                                               */
/* ------------------------------------------------------------------ */

type FileNode = {
  name: string;
  group: "images" | "documents" | "code";
  /** Scattered position (relative %, within the demo area). */
  scattered: { x: number; y: number };
  /** Grouped position. */
  grouped: { x: number; y: number };
};

const files: FileNode[] = [
  /* Images */
  { name: "hero.png",   group: "images",    scattered: { x: 68, y: 6 },  grouped: { x: 12, y: 22 } },
  { name: "banner.jpg", group: "images",    scattered: { x: 8,  y: 42 }, grouped: { x: 12, y: 38 } },
  { name: "icon.svg",   group: "images",    scattered: { x: 52, y: 70 }, grouped: { x: 12, y: 54 } },
  /* Documents */
  { name: "report.pdf", group: "documents", scattered: { x: 30, y: 12 }, grouped: { x: 50, y: 22 } },
  { name: "notes.md",   group: "documents", scattered: { x: 78, y: 52 }, grouped: { x: 50, y: 38 } },
  { name: "readme.txt", group: "documents", scattered: { x: 14, y: 72 }, grouped: { x: 50, y: 54 } },
  /* Code */
  { name: "app.tsx",    group: "code",      scattered: { x: 46, y: 36 }, grouped: { x: 84, y: 22 } },
  { name: "styles.css", group: "code",      scattered: { x: 82, y: 26 }, grouped: { x: 84, y: 38 } },
  { name: "utils.ts",   group: "code",      scattered: { x: 36, y: 82 }, grouped: { x: 84, y: 54 } },
];

const groupColors: Record<string, { text: string; bg: string; dot: string; line: string }> = {
  images:    { text: "text-forma-steel-blue",  bg: "bg-forma-steel-blue/12", dot: "bg-forma-steel-blue", line: "rgba(91,124,153,0.35)" },
  documents: { text: "text-forma-sage",        bg: "bg-forma-sage/12",       dot: "bg-forma-sage",       line: "rgba(122,157,126,0.35)" },
  code:      { text: "text-forma-warm-orange", bg: "bg-forma-warm-orange/12",dot: "bg-forma-warm-orange",line: "rgba(193,126,74,0.35)" },
};

/** Pairs within each group for connection lines. */
const connectionPairs: [number, number][] = [
  [0, 1], [1, 2], // images
  [3, 4], [4, 5], // documents
  [6, 7], [7, 8], // code
];

const groupLabels = [
  { key: "images",    label: "Images",    x: 12, y: 10 },
  { key: "documents", label: "Documents", x: 50, y: 10 },
  { key: "code",      label: "Code",      x: 84, y: 10 },
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

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

/* ------------------------------------------------------------------ */
/*  AnimatedConnectionDemo                                             */
/* ------------------------------------------------------------------ */

interface AnimatedConnectionDemoProps {
  progress: number;
}

export function AnimatedConnectionDemo({ progress }: AnimatedConnectionDemoProps) {
  const computed = useMemo(() => {
    /* Phase 1 (0.0 - 0.25): Files fade in at scattered positions */
    const fadeIn = easeOut(subProgress(progress, 0.0, 0.25));

    /* Phase 2 (0.25 - 0.6): Lines draw between related files */
    const lineDraw = subProgress(progress, 0.25, 0.6);

    /* Phase 3 (0.6 - 0.85): Files cluster into groups */
    const cluster = easeOut(subProgress(progress, 0.6, 0.85));

    /* Phase 4 (0.85 - 1.0): Group labels + counts */
    const labels = easeOut(subProgress(progress, 0.85, 1.0));

    /* Per-file positions */
    const filePositions = files.map((f, i) => {
      /* Stagger fade-in per file */
      const staggerDelay = i * 0.08;
      const fileOpacity = Math.min(1, easeOut(subProgress(progress, staggerDelay * 0.2, 0.15 + staggerDelay * 0.2)));

      const x = lerp(f.scattered.x, f.grouped.x, cluster);
      const y = lerp(f.scattered.y, f.grouped.y, cluster);

      return { ...f, x, y, opacity: fileOpacity };
    });

    return { fadeIn, lineDraw, cluster, labels, filePositions };
  }, [progress]);

  return (
    <div className="relative" style={{ height: 200 }}>
      {/* SVG layer for connection lines */}
      <svg
        className="pointer-events-none absolute inset-0 h-full w-full"
        viewBox="0 0 100 100"
        preserveAspectRatio="none"
        style={{ opacity: computed.fadeIn }}
      >
        {connectionPairs.map(([a, b], i) => {
          const fa = computed.filePositions[a];
          const fb = computed.filePositions[b];
          const group = files[a].group;
          const color = groupColors[group].line;

          /* Line dash animation: total length roughly sqrt((dx)^2+(dy)^2) */
          const dx = fb.x - fa.x;
          const dy = fb.y - fa.y;
          const len = Math.sqrt(dx * dx + dy * dy);

          /* Stagger each line slightly */
          const lineStart = 0.25 + i * 0.04;
          const lineEnd = lineStart + 0.25;
          const lineP = easeOut(subProgress(progress, lineStart, lineEnd));
          const offset = len * (1 - lineP);

          return (
            <line
              key={`${a}-${b}`}
              x1={fa.x}
              y1={fa.y}
              x2={fb.x}
              y2={fb.y}
              stroke={color}
              strokeWidth={0.5}
              strokeDasharray={len}
              strokeDashoffset={offset}
              strokeLinecap="round"
            />
          );
        })}
      </svg>

      {/* File chip nodes */}
      {computed.filePositions.map((f) => {
        const colors = groupColors[f.group];
        return (
          <div
            key={f.name}
            className={`absolute rounded px-1.5 py-0.5 font-mono text-[10px] ${colors.bg} ${colors.text}`}
            style={{
              left: `${f.x}%`,
              top: `${f.y}%`,
              transform: "translate(-50%, -50%)",
              opacity: f.opacity,
              transition: "none",
            }}
          >
            {f.name}
          </div>
        );
      })}

      {/* Group labels */}
      {groupLabels.map((g) => {
        const colors = groupColors[g.key];
        const count = files.filter((f) => f.group === g.key).length;
        return (
          <div
            key={g.key}
            className="absolute flex items-center gap-1.5"
            style={{
              left: `${g.x}%`,
              top: `${g.y}%`,
              transform: "translate(-50%, -50%)",
              opacity: computed.labels,
            }}
          >
            <span className={`h-1.5 w-1.5 rounded-full ${colors.dot}`} />
            <span className={`text-[11px] font-medium ${colors.text}`}>
              {g.label}
            </span>
            <span
              className="rounded-full bg-[var(--demo-muted-chip-bg)] px-1.5 py-0.5 text-[9px] text-[var(--text-muted)]"
              style={{
                opacity: computed.labels,
                transform: `scale(${0.8 + 0.2 * computed.labels})`,
              }}
            >
              {count} files
            </span>
          </div>
        );
      })}
    </div>
  );
}

export default AnimatedConnectionDemo;
