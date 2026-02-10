"use client";

import { useRef, useMemo, useEffect, useCallback } from "react";
import { gsap } from "@/lib/animation/gsap-config";
import { useScrollSceneProgress } from "@/components/animation/ScrollScene";

// ═══════════════════════════════════════════════════════════════════════════
// FILE DATA
// ═══════════════════════════════════════════════════════════════════════════

type FileType = "screenshot" | "document" | "video";

interface FileItem {
  name: string;
  type: FileType;
  folder: string;
}

const files: FileItem[] = [
  { name: "Screenshot 2024-01-15 at 3.42.17 PM.png", type: "screenshot", folder: "Screenshots/" },
  { name: "IMG_4829.HEIC", type: "screenshot", folder: "Screenshots/" },
  { name: "Document (3).pdf", type: "document", folder: "Documents/" },
  { name: "Screen Recording 2024-02-01 at 10.15.23 AM.mov", type: "video", folder: "Videos/" },
  { name: "final_FINAL_v2_actual_final.docx", type: "document", folder: "Documents/" },
  { name: "Untitled.txt", type: "screenshot", folder: "Screenshots/" },
];

const folderLabels = [
  { name: "Screenshots/", count: "3 files", icon: "\uD83D\uDDBC\uFE0F" },
  { name: "Documents/", count: "2 files", icon: "\uD83D\uDCC4" },
  { name: "Videos/", count: "1 file", icon: "\uD83C\uDFAC" },
];

const typeColors: Record<FileType, string> = {
  screenshot: "bg-forma-steel-blue",
  document: "bg-forma-sage",
  video: "bg-forma-warm-orange",
};

// ═══════════════════════════════════════════════════════════════════════════
// POSITION TYPES
// ═══════════════════════════════════════════════════════════════════════════

interface Position {
  x: number;
  y: number;
  rotation: number;
}

// ═══════════════════════════════════════════════════════════════════════════
// DETERMINISTIC PSEUDO-RANDOM
// We use a seeded approach so chaos positions are stable across renders
// but still look random.
// ═══════════════════════════════════════════════════════════════════════════

function seededRandom(seed: number): number {
  const x = Math.sin(seed * 9301 + 49297) * 49297;
  return x - Math.floor(x);
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPONENT
// ═══════════════════════════════════════════════════════════════════════════

export default function FileSortAnimation() {
  const progress = useScrollSceneProgress();
  const fileRefs = useRef<(HTMLDivElement | null)[]>([]);
  const folderLabelRefs = useRef<(HTMLDivElement | null)[]>([]);
  const badgeRef = useRef<HTMLDivElement | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);

  // ── Chaos positions (scattered within container) ──────────────────────
  const chaosPositions = useMemo<Position[]>(() => {
    return files.map((_, i) => ({
      x: seededRandom(i * 3 + 1) * 340 - 170,
      y: seededRandom(i * 3 + 2) * 240 - 120,
      rotation: seededRandom(i * 3 + 3) * 14 - 7,
    }));
  }, []);

  // ── Organized positions (3 rows, grouped by folder) ───────────────────
  const organizedPositions = useMemo<Position[]>(() => {
    const folderOrder = ["Screenshots/", "Documents/", "Videos/"];
    // Card width ~220px + 12px gap. Container is 600px wide, labels take ~120px left.
    // Files start at x = -120 (left area) and stack right.
    const rowStartX = -100;
    const rowGap = 220;
    const rowYBase = -100; // top row
    const rowSpacing = 70;

    const positions: Position[] = [];
    const folderCounts: Record<string, number> = {};

    files.forEach((file) => {
      const folderIndex = folderOrder.indexOf(file.folder);
      const countInFolder = folderCounts[file.folder] || 0;
      folderCounts[file.folder] = countInFolder + 1;

      positions.push({
        x: rowStartX + countInFolder * rowGap,
        y: rowYBase + folderIndex * rowSpacing,
        rotation: 0,
      });
    });

    return positions;
  }, []);

  // ── Ref setter callback ───────────────────────────────────────────────
  const setFileRef = useCallback(
    (index: number) => (el: HTMLDivElement | null) => {
      fileRefs.current[index] = el;
    },
    []
  );

  const setFolderLabelRef = useCallback(
    (index: number) => (el: HTMLDivElement | null) => {
      folderLabelRefs.current[index] = el;
    },
    []
  );

  // ── Animate on progress ───────────────────────────────────────────────
  useEffect(() => {
    // Sort progress: 0 when chaotic, 1 when organized
    // Maps progress 0.3-0.8 to sortProgress 0-1
    const sortProgress = Math.max(0, Math.min(1, (progress - 0.3) / 0.5));

    // Ease the sort progress for a more natural feel
    const easedSort = sortProgress < 0.5
      ? 2 * sortProgress * sortProgress
      : 1 - Math.pow(-2 * sortProgress + 2, 2) / 2;

    // Chaos drift intensity: full at 0, fades out as sorting begins
    const driftIntensity = Math.max(0, 1 - sortProgress * 2);

    fileRefs.current.forEach((el, i) => {
      if (!el) return;

      const chaos = chaosPositions[i];
      const organized = organizedPositions[i];

      // Stagger: offset each file slightly so they don't all move in lockstep
      const staggerOffset = i * 0.06;
      const fileSort = Math.max(0, Math.min(1, (sortProgress - staggerOffset) / (1 - staggerOffset * files.length * 0.5)));
      const easedFileSort = fileSort < 0.5
        ? 2 * fileSort * fileSort
        : 1 - Math.pow(-2 * fileSort + 2, 2) / 2;

      const x = chaos.x + (organized.x - chaos.x) * easedFileSort;
      const y = chaos.y + (organized.y - chaos.y) * easedFileSort;
      const rotation = chaos.rotation * (1 - easedFileSort);

      gsap.set(el, { x, y, rotation });

      // Drift animation: controlled via CSS custom property
      el.style.setProperty("--drift-intensity", String(driftIntensity));
    });

    // Folder labels: fade in at progress > 0.75
    const labelOpacity = Math.max(0, Math.min(1, (progress - 0.75) / 0.15));
    folderLabelRefs.current.forEach((el) => {
      if (!el) return;
      gsap.set(el, { opacity: labelOpacity, y: (1 - labelOpacity) * 8 });
    });

    // Badge: fade in at progress > 0.85
    if (badgeRef.current) {
      const badgeOpacity = Math.max(0, Math.min(1, (progress - 0.85) / 0.1));
      gsap.set(badgeRef.current, { opacity: badgeOpacity, y: (1 - badgeOpacity) * 10 });
    }
  }, [progress, chaosPositions, organizedPositions]);

  return (
    <div
      ref={containerRef}
      className="relative mx-auto w-full max-w-[640px] h-[400px]"
      aria-label="File sorting animation"
      role="img"
    >
      {/* ── File cards ─────────────────────────────────────────────────── */}
      {files.map((file, i) => (
        <div
          key={file.name}
          ref={setFileRef(i)}
          className="file-sort-card absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 rounded-lg border border-white/[0.08] bg-white/[0.04] backdrop-blur-sm px-3 py-2 shadow-lg will-change-transform"
          style={{
            // Drift animation uses CSS custom property for intensity
            animation: "file-chaos-drift 3s ease-in-out infinite",
            animationDelay: `${i * -0.5}s`,
            // Each card gets a unique drift direction via CSS custom prop
            ["--chaos-dx" as string]: `${seededRandom(i * 7 + 10) * 6 - 3}px`,
            ["--chaos-dy" as string]: `${seededRandom(i * 7 + 20) * 4 - 2}px`,
            ["--chaos-dr" as string]: `${seededRandom(i * 7 + 30) * 3 - 1.5}deg`,
            ["--drift-intensity" as string]: "1",
          }}
        >
          <div className="flex items-center gap-2 pointer-events-none select-none">
            <span
              className={`w-2 h-2 shrink-0 rounded-full ${typeColors[file.type]}`}
              aria-hidden="true"
            />
            <span className="font-mono text-[11px] text-[var(--text-secondary)] truncate max-w-[180px]">
              {file.name}
            </span>
          </div>
        </div>
      ))}

      {/* ── Folder labels (fade in when organized) ─────────────────────── */}
      {folderLabels.map((folder, i) => {
        // Position labels to the left of the organized rows
        const labelY = -100 + i * 70;
        return (
          <div
            key={folder.name}
            ref={setFolderLabelRef(i)}
            className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 flex items-center gap-2 opacity-0 will-change-transform"
            style={{
              transform: `translate(calc(-50% - 260px), calc(-50% + ${labelY}px))`,
            }}
          >
            <span className="text-sm" aria-hidden="true">{folder.icon}</span>
            <div className="flex flex-col">
              <span className="font-mono text-[11px] font-medium text-[var(--text-primary)] tracking-wide">
                {folder.name}
              </span>
              <span className="text-[10px] text-[var(--text-muted)]">
                {folder.count}
              </span>
            </div>
          </div>
        );
      })}

      {/* ── "Organized in seconds" badge ───────────────────────────────── */}
      <div
        ref={badgeRef}
        className="absolute left-1/2 -translate-x-1/2 bottom-4 flex items-center gap-2 rounded-lg bg-forma-sage/15 border border-forma-sage/20 px-3.5 py-2 opacity-0 will-change-transform"
      >
        <svg
          className="w-3.5 h-3.5 text-forma-sage"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2.5}
        >
          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
        </svg>
        <span className="text-[11px] font-medium text-forma-sage whitespace-nowrap">
          Organized in seconds
        </span>
      </div>
    </div>
  );
}
