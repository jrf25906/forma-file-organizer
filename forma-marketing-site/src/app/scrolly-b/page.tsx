"use client";

import { useEffect, useState, useRef } from "react";
import { MoveRight, Folder, Image, FileText, Code, Film, Music, Archive } from "lucide-react";

// ═══════════════════════════════════════════════════════════════════════════
// SCROLLYTELLING OPTION B: THE DESKTOP JOURNEY
// A sticky desktop mockup that transforms as you scroll
// ═══════════════════════════════════════════════════════════════════════════

interface DesktopFile {
  id: string;
  name: string;
  type: "folder" | "image" | "document" | "code" | "video" | "music" | "archive";
  // Chaos position (messy desktop)
  chaosX: number;
  chaosY: number;
  // Organized position (sorted into folders)
  organizedX: number;
  organizedY: number;
  organizedFolder?: string;
  color: string;
}

const FILE_ICONS = {
  folder: Folder,
  image: Image,
  document: FileText,
  code: Code,
  video: Film,
  music: Music,
  archive: Archive,
};

const FILE_COLORS = {
  folder: "#C97E66",
  image: "#5B7C99",
  document: "#7A9D7E",
  code: "#6B8CA8",
  video: "#8BA688",
  music: "#9B7CB5",
  archive: "#8B8B8B",
};

// Realistic messy desktop files
const DESKTOP_FILES: DesktopFile[] = [
  // Images scattered
  { id: "1", name: "IMG_4291.png", type: "image", chaosX: 15, chaosY: 12, organizedX: 70, organizedY: 25, organizedFolder: "Photos", color: FILE_COLORS.image },
  { id: "2", name: "screenshot_final.png", type: "image", chaosX: 78, chaosY: 8, organizedX: 70, organizedY: 35, organizedFolder: "Photos", color: FILE_COLORS.image },
  { id: "3", name: "profile_pic_v2.jpg", type: "image", chaosX: 45, chaosY: 65, organizedX: 70, organizedY: 45, organizedFolder: "Photos", color: FILE_COLORS.image },

  // Documents scattered
  { id: "4", name: "proposal_FINAL.docx", type: "document", chaosX: 8, chaosY: 45, organizedX: 25, organizedY: 25, organizedFolder: "Documents", color: FILE_COLORS.document },
  { id: "5", name: "notes_meeting.txt", type: "document", chaosX: 62, chaosY: 72, organizedX: 25, organizedY: 35, organizedFolder: "Documents", color: FILE_COLORS.document },
  { id: "6", name: "budget_2024.xlsx", type: "document", chaosX: 35, chaosY: 28, organizedX: 25, organizedY: 45, organizedFolder: "Documents", color: FILE_COLORS.document },

  // Code files
  { id: "7", name: "index.tsx", type: "code", chaosX: 88, chaosY: 35, organizedX: 47, organizedY: 25, organizedFolder: "Projects", color: FILE_COLORS.code },
  { id: "8", name: "styles.css", type: "code", chaosX: 22, chaosY: 78, organizedX: 47, organizedY: 35, organizedFolder: "Projects", color: FILE_COLORS.code },
  { id: "9", name: "config.json", type: "code", chaosX: 55, chaosY: 18, organizedX: 47, organizedY: 45, organizedFolder: "Projects", color: FILE_COLORS.code },

  // Videos
  { id: "10", name: "demo_recording.mp4", type: "video", chaosX: 72, chaosY: 55, organizedX: 70, organizedY: 55, organizedFolder: "Videos", color: FILE_COLORS.video },
  { id: "11", name: "tutorial_draft.mov", type: "video", chaosX: 12, chaosY: 62, organizedX: 70, organizedY: 65, organizedFolder: "Videos", color: FILE_COLORS.video },

  // Random clutter
  { id: "12", name: "Untitled.txt", type: "document", chaosX: 42, chaosY: 42, organizedX: 25, organizedY: 55, organizedFolder: "Documents", color: FILE_COLORS.document },
  { id: "13", name: "backup.zip", type: "archive", chaosX: 85, chaosY: 78, organizedX: 47, organizedY: 55, organizedFolder: "Archives", color: FILE_COLORS.archive },

  // Destination folders (appear during organization)
  { id: "f1", name: "Documents", type: "folder", chaosX: -20, chaosY: 20, organizedX: 25, organizedY: 15, color: FILE_COLORS.folder },
  { id: "f2", name: "Projects", type: "folder", chaosX: -20, chaosY: 40, organizedX: 47, organizedY: 15, color: FILE_COLORS.folder },
  { id: "f3", name: "Photos", type: "folder", chaosX: 120, chaosY: 20, organizedX: 70, organizedY: 15, color: FILE_COLORS.folder },
];

const NARRATIVE_BEATS = [
  {
    title: "Sound familiar?",
    subtitle: "Your desktop, probably",
    description: "Files everywhere. Screenshots from last month. That document you swore you saved somewhere logical.",
  },
  {
    title: "Forma sees the patterns",
    subtitle: "Analyzing your files",
    description: "Understanding context, not just file types. That screenshot belongs with the project it documents.",
  },
  {
    title: "One click. Total clarity.",
    subtitle: "Intelligent organization",
    description: "Files flow to where they belong. No manual sorting. No lost work. Just order.",
  },
  {
    title: "This could be you.",
    subtitle: "Ready?",
    description: null,
  },
];

function GridLogo({ className = "", size = 48 }: { className?: string; size?: number }) {
  const cellSize = size / 3.5;
  const gap = size / 14;

  return (
    <div
      className={`grid grid-cols-3 ${className}`}
      style={{ gap: `${gap}px`, width: size, height: size }}
    >
      {[1, 1, 1, 0.7, 0.7, 0.7, 0.4, 0.4, 0.4].map((opacity, i) => (
        <div
          key={i}
          className="bg-forma-obsidian rounded-[2px]"
          style={{
            width: cellSize,
            height: cellSize,
            opacity,
            borderRadius: size > 40 ? "4px" : "2px",
          }}
        />
      ))}
    </div>
  );
}

function GrainOverlay() {
  return (
    <div
      className="fixed inset-0 pointer-events-none z-50 opacity-[0.03]"
      style={{
        backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.8' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E")`,
      }}
    />
  );
}

function DesktopMockup({ progress }: { progress: number }) {
  // Phase 1 (0-0.3): Chaos
  // Phase 2 (0.3-0.6): Analysis/scanning effect
  // Phase 3 (0.6-1.0): Organization

  const organizeFactor = Math.max(0, (progress - 0.5) * 2);
  const showFolders = progress > 0.4;
  const showScanEffect = progress > 0.25 && progress < 0.6;

  return (
    <div className="relative w-full max-w-3xl aspect-[16/10] rounded-xl overflow-hidden shadow-2xl border border-forma-obsidian/10">
      {/* Desktop background */}
      <div
        className="absolute inset-0 transition-all duration-1000"
        style={{
          background: progress > 0.7
            ? "linear-gradient(135deg, #E8EAE6 0%, #D4D8D0 100%)"
            : "linear-gradient(135deg, #F5F5F3 0%, #EAEAE8 100%)",
        }}
      />

      {/* Scan overlay effect */}
      {showScanEffect && (
        <div
          className="absolute inset-0 pointer-events-none z-20"
          style={{
            background: `linear-gradient(180deg,
              transparent 0%,
              rgba(91, 124, 153, 0.1) ${((progress - 0.25) / 0.35) * 100}%,
              transparent ${((progress - 0.25) / 0.35) * 100 + 5}%
            )`,
          }}
        />
      )}

      {/* Desktop files */}
      {DESKTOP_FILES.map((file) => {
        const Icon = FILE_ICONS[file.type];
        const isFolder = file.type === "folder";

        // Folders slide in from off-screen
        const folderVisibility = isFolder ? (showFolders ? 1 : 0) : 1;

        // Files interpolate between chaos and organized positions
        const x = file.chaosX + (file.organizedX - file.chaosX) * organizeFactor;
        const y = file.chaosY + (file.organizedY - file.chaosY) * organizeFactor;

        // Slight chaos rotation that disappears when organized
        const rotation = isFolder ? 0 : (Math.sin(parseInt(file.id) * 1.5) * 8) * (1 - organizeFactor);

        // Highlight effect during scanning
        const isBeingScanned = showScanEffect && !isFolder;

        return (
          <div
            key={file.id}
            className="absolute flex flex-col items-center transition-all duration-700 ease-out"
            style={{
              left: `${x}%`,
              top: `${y}%`,
              transform: `translate(-50%, -50%) rotate(${rotation}deg)`,
              opacity: folderVisibility,
              zIndex: isFolder ? 5 : 10,
            }}
          >
            {/* File icon container */}
            <div
              className={`relative p-2 rounded-lg transition-all duration-300 ${
                isBeingScanned ? "ring-2 ring-forma-steel-blue/50 bg-forma-steel-blue/5" : ""
              }`}
            >
              <Icon
                className="w-8 h-8 md:w-10 md:h-10 transition-colors duration-300"
                style={{ color: file.color }}
                strokeWidth={1.5}
              />

              {/* Scanning dot */}
              {isBeingScanned && (
                <div className="absolute -top-1 -right-1 w-2 h-2 bg-forma-steel-blue rounded-full animate-pulse" />
              )}
            </div>

            {/* File name */}
            <span
              className={`mt-1 text-[10px] md:text-xs font-mono truncate max-w-[80px] md:max-w-[100px] transition-all duration-300 ${
                isFolder ? "font-semibold text-forma-obsidian" : "text-forma-obsidian/70"
              }`}
            >
              {file.name}
            </span>
          </div>
        );
      })}

      {/* Window chrome */}
      <div className="absolute top-0 left-0 right-0 h-6 bg-forma-obsidian/5 flex items-center px-2 gap-1.5">
        <div className="w-2.5 h-2.5 rounded-full bg-red-400/70" />
        <div className="w-2.5 h-2.5 rounded-full bg-yellow-400/70" />
        <div className="w-2.5 h-2.5 rounded-full bg-green-400/70" />
      </div>
    </div>
  );
}

export default function ScrollytellingOptionB() {
  const [scrollProgress, setScrollProgress] = useState(0);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleScroll = () => {
      if (!containerRef.current) return;

      const rect = containerRef.current.getBoundingClientRect();
      const scrollableHeight = containerRef.current.scrollHeight - window.innerHeight;
      const scrolled = -rect.top;
      const progress = Math.max(0, Math.min(1, scrolled / scrollableHeight));

      setScrollProgress(progress);
    };

    window.addEventListener("scroll", handleScroll, { passive: true });
    handleScroll();
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  // Determine current narrative beat
  const beatIndex = Math.min(3, Math.floor(scrollProgress * 4));
  const currentBeat = NARRATIVE_BEATS[beatIndex];
  const isLastBeat = beatIndex === 3;

  return (
    <main ref={containerRef} className="relative bg-forma-bone min-h-[400vh]">
      <GrainOverlay />

      {/* Navigation hint */}
      <div className="fixed top-6 left-6 z-40">
        <a href="/" className="text-forma-obsidian/40 hover:text-forma-obsidian text-sm font-mono">
          ← Back to main
        </a>
      </div>

      {/* Progress indicator */}
      <div className="fixed top-6 right-6 z-40 flex items-center gap-3">
        <span className="text-xs font-mono text-forma-obsidian/40">
          {Math.round(scrollProgress * 100)}%
        </span>
        <div className="w-24 h-1 bg-forma-obsidian/10 rounded-full overflow-hidden">
          <div
            className="h-full bg-forma-steel-blue transition-all duration-100"
            style={{ width: `${scrollProgress * 100}%` }}
          />
        </div>
      </div>

      {/* Sticky viewport */}
      <div className="sticky top-0 h-screen flex items-center justify-center overflow-hidden px-6">
        <div className="flex flex-col lg:flex-row items-center gap-8 lg:gap-16 max-w-6xl mx-auto">

          {/* Desktop mockup - left side */}
          <div className="flex-1 w-full max-w-xl lg:max-w-none">
            <DesktopMockup progress={scrollProgress} />
          </div>

          {/* Narrative text - right side */}
          <div className="flex-1 text-center lg:text-left max-w-md">
            {/* Beat indicator */}
            <div className="flex items-center gap-2 mb-4 justify-center lg:justify-start">
              {NARRATIVE_BEATS.map((_, i) => (
                <div
                  key={i}
                  className={`w-8 h-1 rounded-full transition-all duration-300 ${
                    i <= beatIndex ? "bg-forma-steel-blue" : "bg-forma-obsidian/10"
                  }`}
                />
              ))}
            </div>

            {/* Subtitle */}
            <span className="font-mono text-xs text-forma-steel-blue tracking-widest uppercase">
              {currentBeat.subtitle}
            </span>

            {/* Title */}
            <h2 className="mt-2 text-3xl md:text-4xl lg:text-5xl font-display text-forma-obsidian leading-tight">
              {currentBeat.title}
            </h2>

            {/* Description */}
            {currentBeat.description && (
              <p className="mt-4 text-lg text-forma-obsidian/60 leading-relaxed">
                {currentBeat.description}
              </p>
            )}

            {/* CTA on final beat */}
            {isLastBeat && (
              <div className="mt-8 space-y-4">
                <a
                  href="#"
                  className="inline-flex items-center gap-2 px-8 py-4 bg-[#1A1A1A] text-[#FAFAF8] rounded-full font-display text-lg hover:gap-4 transition-all duration-300"
                >
                  Join the Beta
                  <MoveRight className="w-5 h-5" />
                </a>
                <p className="text-sm text-forma-obsidian/40">
                  Free during beta • macOS 14+ • No account required
                </p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Scroll prompt */}
      <div
        className={`fixed bottom-8 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2 transition-opacity duration-500 z-40 ${
          scrollProgress < 0.05 ? "opacity-100" : "opacity-0 pointer-events-none"
        }`}
      >
        <span className="font-mono text-xs text-forma-obsidian/40 tracking-widest">
          SCROLL TO EXPLORE
        </span>
        <div className="w-px h-8 bg-forma-obsidian/20 animate-pulse" />
      </div>
    </main>
  );
}
