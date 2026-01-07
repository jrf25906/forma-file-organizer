"use client";

import { useEffect, useState, useRef } from "react";
import { MoveRight, Folder, Image, FileText, Code, Film } from "lucide-react";

// ═══════════════════════════════════════════════════════════════════════════
// SCROLLYTELLING: SIMPLIFIED
// Fewer elements, cleaner focus, more breathing room
// ═══════════════════════════════════════════════════════════════════════════

interface DesktopFile {
  id: string;
  type: "folder" | "image" | "document" | "code" | "video";
  chaosX: number;
  chaosY: number;
  chaosRotation: number;
  organizedX: number;
  organizedY: number;
  color: string;
  depth: number;
}

const FILE_ICONS = {
  folder: Folder,
  image: Image,
  document: FileText,
  code: Code,
  video: Film,
};

const FILE_COLORS = {
  folder: "#C97E66",
  image: "#5B7C99",
  document: "#7A9D7E",
  code: "#6B8CA8",
  video: "#8BA688",
};

// SIMPLIFIED: Only 8 files + 2 folders
const DESKTOP_FILES: DesktopFile[] = [
  // Images - scattered at edges
  { id: "1", type: "image", chaosX: 8, chaosY: 20, chaosRotation: -8, organizedX: 72, organizedY: 35, color: FILE_COLORS.image, depth: 0.7 },
  { id: "2", type: "image", chaosX: 88, chaosY: 25, chaosRotation: 12, organizedX: 72, organizedY: 50, color: FILE_COLORS.image, depth: 0.4 },

  // Documents - left side
  { id: "3", type: "document", chaosX: 12, chaosY: 70, chaosRotation: 6, organizedX: 28, organizedY: 35, color: FILE_COLORS.document, depth: 0.5 },
  { id: "4", type: "document", chaosX: 6, chaosY: 45, chaosRotation: -10, organizedX: 28, organizedY: 50, color: FILE_COLORS.document, depth: 0.8 },

  // Code files - right side
  { id: "5", type: "code", chaosX: 92, chaosY: 60, chaosRotation: 5, organizedX: 72, organizedY: 65, color: FILE_COLORS.code, depth: 0.6 },
  { id: "6", type: "code", chaosX: 85, chaosY: 80, chaosRotation: -12, organizedX: 28, organizedY: 65, color: FILE_COLORS.code, depth: 0.3 },

  // Video - corner
  { id: "7", type: "video", chaosX: 10, chaosY: 88, chaosRotation: 15, organizedX: 28, organizedY: 80, color: FILE_COLORS.video, depth: 0.5 },

  // Extra document
  { id: "8", type: "document", chaosX: 90, chaosY: 12, chaosRotation: -5, organizedX: 72, organizedY: 80, color: FILE_COLORS.document, depth: 0.9 },

  // SIMPLIFIED: Only 2 folders
  { id: "f1", type: "folder", chaosX: -15, chaosY: 22, chaosRotation: 0, organizedX: 28, organizedY: 22, color: FILE_COLORS.folder, depth: 1 },
  { id: "f2", type: "folder", chaosX: 115, chaosY: 22, chaosRotation: 0, organizedX: 72, organizedY: 22, color: FILE_COLORS.folder, depth: 1 },
];

const NARRATIVE_BEATS = [
  {
    progress: [0, 0.22],
    subtitle: "YOUR DESKTOP, PROBABLY",
    title: "Sound familiar?",
    description: "Files everywhere. That document you swore you saved somewhere logical.",
  },
  {
    progress: [0.22, 0.48],
    subtitle: "INTELLIGENT ANALYSIS",
    title: "Forma sees the patterns",
    description: "Understanding context, not just file types.",
  },
  {
    progress: [0.48, 0.78],
    subtitle: "ONE CLICK",
    title: "Watch them find their place",
    description: null,
  },
  {
    progress: [0.78, 1],
    subtitle: "READY?",
    title: "This could be you",
    description: null,
  },
];

function useMousePosition() {
  const [position, setPosition] = useState({ x: 0, y: 0 });

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      const x = (e.clientX / window.innerWidth - 0.5) * 2;
      const y = (e.clientY / window.innerHeight - 0.5) * 2;
      setPosition({ x, y });
    };

    window.addEventListener("mousemove", handleMouseMove, { passive: true });
    return () => window.removeEventListener("mousemove", handleMouseMove);
  }, []);

  return position;
}

function GridLogo({ size = 48 }: { size?: number }) {
  const cellSize = size / 3.5;
  const gap = size / 14;

  return (
    <div
      className="grid grid-cols-3"
      style={{ gap: `${gap}px`, width: size, height: size }}
    >
      {[1, 1, 1, 0.7, 0.7, 0.7, 0.4, 0.4, 0.4].map((opacity, i) => (
        <div
          key={i}
          className="bg-forma-obsidian transition-opacity duration-500"
          style={{
            width: cellSize,
            height: cellSize,
            opacity,
            borderRadius: size > 40 ? "4px" : "2px",
            transitionDelay: `${i * 40}ms`,
          }}
        />
      ))}
    </div>
  );
}

function GrainOverlay() {
  return (
    <div
      className="fixed inset-0 pointer-events-none z-50 opacity-[0.02]"
      style={{
        backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.8' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E")`,
      }}
    />
  );
}

function FileIcon({
  file,
  progress,
  isScanning,
  mouseX,
  mouseY
}: {
  file: DesktopFile;
  progress: number;
  isScanning: boolean;
  mouseX: number;
  mouseY: number;
}) {
  const Icon = FILE_ICONS[file.type];
  const isFolder = file.type === "folder";

  // Folders appear after 40%
  const folderVisibility = isFolder ? Math.max(0, Math.min(1, (progress - 0.4) * 4)) : 1;

  // Files organize after 48%
  const organizeFactor = Math.max(0, Math.min(1, (progress - 0.48) * 3));

  // Interpolate positions
  const x = file.chaosX + (file.organizedX - file.chaosX) * organizeFactor;
  const y = file.chaosY + (file.organizedY - file.chaosY) * organizeFactor;
  const rotation = file.chaosRotation * (1 - organizeFactor);

  // Parallax (only during chaos)
  const parallaxStrength = 12 * file.depth * (1 - organizeFactor);
  const parallaxX = mouseX * parallaxStrength;
  const parallaxY = mouseY * parallaxStrength;

  // Opacity
  const opacity = isFolder
    ? folderVisibility
    : 0.5 + file.depth * 0.3 + organizeFactor * 0.2;

  // Scale
  const scale = isFolder ? 1.1 : 0.9 + file.depth * 0.15;

  const isBeingScanned = isScanning && !isFolder;

  return (
    <div
      className="absolute transition-all ease-out"
      style={{
        left: `${x}%`,
        top: `${y}%`,
        transform: `
          translate(-50%, -50%)
          translate(${parallaxX}px, ${parallaxY}px)
          rotate(${rotation}deg)
          scale(${scale})
        `,
        opacity,
        zIndex: isFolder ? 5 : 10,
        transitionDuration: "700ms",
      }}
    >
      <div
        className={`p-3 rounded-xl transition-all duration-500 ${
          isBeingScanned
            ? "ring-2 ring-forma-steel-blue/50 bg-white/80"
            : isFolder
              ? "bg-white/90 shadow-lg"
              : "bg-white/60 shadow-md"
        }`}
        style={{
          border: isFolder ? `2px solid ${file.color}40` : `1px solid ${file.color}25`,
        }}
      >
        <Icon
          className={isFolder ? "w-10 h-10" : "w-7 h-7"}
          style={{ color: file.color }}
          strokeWidth={1.5}
        />

        {isBeingScanned && (
          <div className="absolute -top-1 -right-1 w-2 h-2 bg-forma-steel-blue rounded-full animate-pulse" />
        )}
      </div>

      {/* NO file labels - cleaner look */}
    </div>
  );
}

function NarrativeText({ progress }: { progress: number }) {
  const currentBeat = NARRATIVE_BEATS.find(
    (beat) => progress >= beat.progress[0] && progress < beat.progress[1]
  ) || NARRATIVE_BEATS[NARRATIVE_BEATS.length - 1];

  const isLastBeat = currentBeat === NARRATIVE_BEATS[NARRATIVE_BEATS.length - 1];
  const showLogo = progress > 0.7;

  return (
    <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-20">
      {/* Subtle backdrop - MORE TRANSPARENT */}
      <div
        className="absolute inset-x-0 top-1/2 -translate-y-1/2 h-[280px] md:h-[320px]"
        style={{
          background: `radial-gradient(ellipse 500px 250px at center, rgba(250,250,248,0.75) 0%, rgba(250,250,248,0.3) 60%, transparent 100%)`,
        }}
      />

      <div className="relative text-center px-6 max-w-xl pointer-events-auto">
        {/* Logo - ABOVE narrative, only on final beats */}
        <div
          className={`mb-8 flex justify-center transition-all duration-700 ${
            showLogo ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"
          }`}
        >
          <GridLogo size={isLastBeat ? 64 : 48} />
        </div>

        {/* Subtitle */}
        <span className="block font-mono text-[11px] tracking-[0.2em] text-forma-steel-blue/80 mb-3">
          {currentBeat.subtitle}
        </span>

        {/* Title - SMALLER */}
        <h2
          className={`font-display text-forma-obsidian leading-[1.1] ${
            isLastBeat ? "text-4xl md:text-6xl" : "text-3xl md:text-5xl"
          }`}
        >
          {currentBeat.title.includes("their place") ? (
            <>
              Watch them find<br />
              <span className="text-forma-sage italic">their place</span>
            </>
          ) : currentBeat.title.includes("patterns") ? (
            <>
              Forma sees<br />
              <span className="text-forma-steel-blue italic">the patterns</span>
            </>
          ) : isLastBeat ? (
            <>
              This could be<br />
              <span className="italic">you</span>
            </>
          ) : (
            currentBeat.title
          )}
        </h2>

        {/* Description - SHORTER */}
        {currentBeat.description && (
          <p className="mt-4 text-base md:text-lg text-forma-obsidian/50 leading-relaxed max-w-md mx-auto">
            {currentBeat.description}
          </p>
        )}

        {/* CTA */}
        {isLastBeat && (
          <div className="mt-10 space-y-3">
            <a
              href="#"
              className="inline-flex items-center gap-2 px-8 py-4 bg-forma-obsidian text-forma-bone rounded-full font-display text-base hover:gap-4 hover:shadow-xl transition-all duration-300"
            >
              Join the Beta
              <MoveRight className="w-4 h-4" />
            </a>
            <p className="text-xs text-forma-obsidian/35">
              Free during beta • macOS 14+
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

export default function ScrollytellingSimplified() {
  const [scrollProgress, setScrollProgress] = useState(0);
  const containerRef = useRef<HTMLDivElement>(null);
  const mouse = useMousePosition();

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

  const isScanning = scrollProgress > 0.22 && scrollProgress < 0.48;

  return (
    <main ref={containerRef} className="relative min-h-[400vh] bg-forma-bone">
      <GrainOverlay />

      {/* Navigation */}
      <div className="fixed top-6 left-6 z-40">
        <a href="/" className="text-forma-obsidian/30 hover:text-forma-obsidian text-sm font-mono transition-colors">
          ← Back
        </a>
      </div>

      {/* Progress */}
      <div className="fixed top-6 right-6 z-40 flex items-center gap-3">
        <span className="text-[10px] font-mono text-forma-obsidian/30">
          {Math.round(scrollProgress * 100)}%
        </span>
        <div className="w-16 h-0.5 bg-forma-obsidian/10 rounded-full overflow-hidden">
          <div
            className="h-full bg-forma-steel-blue/60 transition-all duration-150"
            style={{ width: `${scrollProgress * 100}%` }}
          />
        </div>
      </div>

      {/* Beat indicators - SMALLER */}
      <div className="fixed left-6 top-1/2 -translate-y-1/2 z-40 flex flex-col gap-2">
        {NARRATIVE_BEATS.map((beat, i) => {
          const isCurrent = scrollProgress >= beat.progress[0] && scrollProgress < beat.progress[1];
          const isPast = scrollProgress >= beat.progress[1];
          return (
            <div
              key={i}
              className={`transition-all duration-300 rounded-full ${
                isCurrent
                  ? "w-2 h-2 bg-forma-steel-blue"
                  : isPast
                    ? "w-1.5 h-1.5 bg-forma-obsidian/25"
                    : "w-1.5 h-1.5 bg-forma-obsidian/10"
              }`}
            />
          );
        })}
      </div>

      {/* Sticky viewport */}
      <div className="sticky top-0 h-screen overflow-hidden">
        {/* Desktop container - SUBTLE */}
        <div
          className="absolute inset-8 md:inset-12 lg:inset-16 rounded-2xl overflow-hidden"
          style={{
            background: "linear-gradient(145deg, rgba(255,255,255,0.25) 0%, rgba(255,255,255,0.1) 100%)",
            boxShadow: "0 20px 60px -20px rgba(0,0,0,0.08), inset 0 1px 0 rgba(255,255,255,0.5)",
          }}
        >
          {/* Window chrome - MINIMAL */}
          <div className="absolute top-0 left-0 right-0 h-8 flex items-center px-3 gap-1.5 bg-white/40">
            <div className="w-2.5 h-2.5 rounded-full bg-forma-obsidian/10" />
            <div className="w-2.5 h-2.5 rounded-full bg-forma-obsidian/10" />
            <div className="w-2.5 h-2.5 rounded-full bg-forma-obsidian/10" />
          </div>

          {/* Files */}
          <div className="absolute inset-0 top-8">
            {DESKTOP_FILES.map((file) => (
              <FileIcon
                key={file.id}
                file={file}
                progress={scrollProgress}
                isScanning={isScanning}
                mouseX={mouse.x}
                mouseY={mouse.y}
              />
            ))}
          </div>
        </div>

        {/* Narrative */}
        <NarrativeText progress={scrollProgress} />

        {/* Scroll prompt */}
        <div
          className={`fixed bottom-8 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2 transition-all duration-500 z-40 ${
            scrollProgress < 0.02 ? "opacity-100" : "opacity-0 pointer-events-none"
          }`}
        >
          <span className="font-mono text-[10px] text-forma-obsidian/30 tracking-[0.15em]">
            SCROLL
          </span>
          <div className="w-px h-8 bg-gradient-to-b from-forma-obsidian/20 to-transparent" />
        </div>
      </div>
    </main>
  );
}
