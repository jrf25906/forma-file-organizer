"use client";

import { useRef, useMemo, useEffect, useCallback, useState } from "react";
import { gsap } from "@/lib/animation/gsap-config";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";
import { FormaFileCard } from "@/components/ui/FormaFileCard";
import {
  beforeAfterFiles,
  folderGroups,
  categoryColors,
  cardTokens,
} from "@/lib/forma-design-tokens";

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

  // Chaos positions — wider spread for larger cards
  const chaosPositions = useMemo<Position[]>(() => {
    return beforeAfterFiles.map((_, i) => ({
      x: seededRandom(i * 3 + 1) * 400 - 200,
      y: seededRandom(i * 3 + 2) * 240 - 120,
      rotation: seededRandom(i * 3 + 3) * 14 - 7,
    }));
  }, []);

  // Organized positions — 3 rows grouped by folder
  // Full cards are 280px wide; container is 780px. Center-offset cards need
  // to stay within ±390px of center, so gap=295 with startX=-145 keeps them in bounds.
  const organizedPositions = useMemo<Position[]>(() => {
    const folderOrder = ["Screenshots/", "Documents/", "Videos/"];
    const rowStartX = -120;
    const rowGap = 295;
    const rowYBase = -72;
    const rowSpacing = 72;

    const positions: Position[] = [];
    const folderCounts: Record<string, number> = {};

    // Map file destinations to folder names
    const destToFolder: Record<string, string> = {
      Screenshots: "Screenshots/",
      Documents: "Documents/",
      Videos: "Videos/",
    };

    beforeAfterFiles.forEach((file) => {
      const folder = file.destination ? destToFolder[file.destination] || "Documents/" : "Documents/";
      const folderIndex = folderOrder.indexOf(folder);
      const countInFolder = folderCounts[folder] || 0;
      folderCounts[folder] = countInFolder + 1;

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
      // Show organized state immediately
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
    const labelsStartTime = beforeAfterFiles.length * 0.12 + 0.4;
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
      className="relative mx-auto w-full max-w-[780px] h-[380px] overflow-hidden"
      aria-label="File sorting animation"
      role="img"
    >
      {/* File cards */}
      {beforeAfterFiles.map((file, i) => (
        <div
          key={file.name}
          ref={setFileRef(i)}
          className="absolute"
          style={{ left: "50%", top: "50%", marginLeft: "-145px", marginTop: "-30px" }}
        >
          <FormaFileCard file={file} scale="full" />
        </div>
      ))}

      {/* Folder labels (fade in when organized) */}
      {folderGroups.map((folder, i) => {
        // Position labels to the left of the file cards
        // Container is 380px tall, center is 190px. Rows at y = -72, 0, +72 from center.
        const labelTop = 190 + (-72 + i * 72) - 10;
        const color = categoryColors[folder.category];
        return (
          <div
            key={folder.name}
            ref={setFolderLabelRef(i)}
            className="absolute flex items-center gap-2 opacity-0"
            style={{
              left: "28px",
              top: `${labelTop}px`,
            }}
          >
            <div
              className="w-5 h-5 rounded flex items-center justify-center"
              style={{ background: `${color}20` }}
            >
              <svg
                width="11"
                height="11"
                viewBox="0 0 24 24"
                fill={color}
                style={{ opacity: 0.7 }}
              >
                <path d="M2 6a2 2 0 0 1 2-2h5l2 2h9a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6Z" />
              </svg>
            </div>
            <div className="flex flex-col">
              <span
                className="text-[11px] font-semibold tracking-wide"
                style={{
                  color: "var(--text-primary)",
                  fontFamily: cardTokens.font,
                }}
              >
                {folder.name}
              </span>
              <span
                className="text-[10px]"
                style={{ color: "var(--text-muted)" }}
              >
                {folder.fileCount} {folder.fileCount === 1 ? "file" : "files"}
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
