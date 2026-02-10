"use client";

import { useRef, useMemo, useEffect, useCallback, useState } from "react";
import { gsap } from "@/lib/animation/gsap-config";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";

// ===================================================================
// FILE DATA
// ===================================================================

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

// ===================================================================
// POSITION TYPES
// ===================================================================

interface Position {
  x: number;
  y: number;
  rotation: number;
}

// ===================================================================
// DETERMINISTIC PSEUDO-RANDOM
// ===================================================================

function seededRandom(seed: number): number {
  const x = Math.sin(seed * 9301 + 49297) * 49297;
  return x - Math.floor(x);
}

// ===================================================================
// COMPONENT
// ===================================================================

export default function FileSortAnimation() {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const fileRefs = useRef<(HTMLDivElement | null)[]>([]);
  const folderLabelRefs = useRef<(HTMLDivElement | null)[]>([]);
  const badgeRef = useRef<HTMLDivElement | null>(null);
  const hasTriggered = useRef(false);
  const [triggered, setTriggered] = useState(false);

  // Chaos positions (scattered within container)
  const chaosPositions = useMemo<Position[]>(() => {
    return files.map((_, i) => ({
      x: seededRandom(i * 3 + 1) * 300 - 150,
      y: seededRandom(i * 3 + 2) * 180 - 90,
      rotation: seededRandom(i * 3 + 3) * 14 - 7,
    }));
  }, []);

  // Organized positions (3 rows, grouped by folder)
  const organizedPositions = useMemo<Position[]>(() => {
    const folderOrder = ["Screenshots/", "Documents/", "Videos/"];
    const rowStartX = -30;
    const rowGap = 160;
    const rowYBase = -55;
    const rowSpacing = 55;

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

  // Ref setter callbacks
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

  // Set initial chaos positions on mount
  useEffect(() => {
    const reducedMotion = getReducedMotionValue();

    if (reducedMotion) {
      // Show organized state immediately for reduced motion
      fileRefs.current.forEach((el, i) => {
        if (!el) return;
        const organized = organizedPositions[i];
        gsap.set(el, { x: organized.x, y: organized.y, rotation: 0 });
      });
      folderLabelRefs.current.forEach((el) => {
        if (!el) return;
        gsap.set(el, { opacity: 1, y: 0 });
      });
      if (badgeRef.current) {
        gsap.set(badgeRef.current, { opacity: 1, y: 0 });
      }
      return;
    }

    // Set initial chaos positions
    fileRefs.current.forEach((el, i) => {
      if (!el) return;
      const chaos = chaosPositions[i];
      gsap.set(el, { x: chaos.x, y: chaos.y, rotation: chaos.rotation });
    });
  }, [chaosPositions, organizedPositions]);

  // Intersection observer: trigger animation once when visible
  useEffect(() => {
    if (!containerRef.current || hasTriggered.current) return;
    if (getReducedMotionValue()) return;

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting && !hasTriggered.current) {
            hasTriggered.current = true;
            setTriggered(true);
            observer.disconnect();
          }
        }
      },
      { threshold: 0.3 }
    );

    observer.observe(containerRef.current);
    return () => observer.disconnect();
  }, []);

  // Run the sort animation when triggered
  useEffect(() => {
    if (!triggered) return;

    const tl = gsap.timeline({ defaults: { ease: "power2.inOut" } });

    // Animate each file from chaos to organized with stagger
    fileRefs.current.forEach((el, i) => {
      if (!el) return;
      const organized = organizedPositions[i];
      const staggerDelay = i * 0.12;

      tl.to(
        el,
        {
          x: organized.x,
          y: organized.y,
          rotation: 0,
          duration: 0.8,
          ease: "power2.inOut",
        },
        staggerDelay
      );

    });

    // Fade in folder labels after files settle
    const labelsStartTime = files.length * 0.12 + 0.4;
    folderLabelRefs.current.forEach((el, i) => {
      if (!el) return;
      tl.to(
        el,
        { opacity: 1, y: 0, duration: 0.4, ease: "power2.out" },
        labelsStartTime + i * 0.1
      );
    });

    // Fade in badge last
    if (badgeRef.current) {
      tl.to(
        badgeRef.current,
        { opacity: 1, y: 0, duration: 0.4, ease: "power2.out" },
        labelsStartTime + 0.3
      );
    }

    return () => {
      tl.kill();
    };
  }, [triggered, organizedPositions]);

  return (
    <div
      ref={containerRef}
      className="relative mx-auto w-full max-w-[780px] h-[300px] overflow-hidden"
      aria-label="File sorting animation"
      role="img"
    >
      {/* File cards */}
      {files.map((file, i) => (
        <div
          key={file.name}
          ref={setFileRef(i)}
          className="file-sort-card absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 rounded-lg border border-white/[0.08] bg-white/[0.04] backdrop-blur-sm px-3 py-2 shadow-lg will-change-transform"
        >
          <div className="flex items-center gap-2 pointer-events-none select-none">
            <span
              className={`w-2 h-2 shrink-0 rounded-full ${typeColors[file.type]}`}
              aria-hidden="true"
            />
            <span className="font-mono text-[11px] text-[var(--text-secondary)] truncate max-w-[130px]">
              {file.name}
            </span>
          </div>
        </div>
      ))}

      {/* Folder labels (fade in when organized) */}
      {folderLabels.map((folder, i) => {
        // Position labels to the left of the file cards
        // Container is 300px tall, center is 150px. Cards at y = -55, 0, +55 from center.
        const labelTop = 150 + (-55 + i * 55) - 10;
        return (
          <div
            key={folder.name}
            ref={setFolderLabelRef(i)}
            className="absolute flex items-center gap-2 opacity-0"
            style={{
              left: "40px",
              top: `${labelTop}px`,
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

      {/* "Organized in seconds" badge */}
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
