"use client";

import { useEffect, useState, useRef } from "react";
import { MoveRight } from "lucide-react";
import { useMousePosition } from "@/hooks/useScrollAnimation";

// ═══════════════════════════════════════════════════════════════════════════
// SCROLLYTELLING OPTION A: THE TRANSFORMATION HERO
// A scroll-driven narrative from chaos to order
// ═══════════════════════════════════════════════════════════════════════════

interface FloatingFile {
  id: number;
  // Chaos positions (random)
  chaosX: number;
  chaosY: number;
  chaosRotation: number;
  // Ordered positions (grid)
  orderX: number;
  orderY: number;
  // Shared
  scale: number;
  type: "image" | "document" | "folder" | "code" | "video";
  color: string;
  delay: number;
}

const FILE_COLORS = {
  image: "#5B7C99",
  document: "#7A9D7E",
  folder: "#C97E66",
  code: "#6B8CA8",
  video: "#8BA688",
};

const FILE_ICONS: Record<string, string> = {
  image: "IMG",
  document: "DOC",
  folder: "📁",
  code: "</>",
  video: "▶",
};

function generateFiles(count: number): FloatingFile[] {
  const types: FloatingFile["type"][] = ["image", "document", "folder", "code", "video"];
  const cols = 6;

  return Array.from({ length: count }, (_, i) => {
    const type = types[Math.floor(Math.random() * types.length)];
    const gridCol = i % cols;
    const gridRow = Math.floor(i / cols);

    return {
      id: i,
      // Chaos: scattered randomly
      chaosX: 10 + Math.random() * 80,
      chaosY: 10 + Math.random() * 80,
      chaosRotation: (Math.random() - 0.5) * 60,
      // Order: neat grid
      orderX: 22 + gridCol * 10,
      orderY: 30 + gridRow * 14,
      scale: 0.7 + Math.random() * 0.4,
      type,
      color: FILE_COLORS[type],
      delay: Math.random() * 0.5,
    };
  });
}

function GridLogo({ className = "", size = 48, opacity = 1 }: { className?: string; size?: number; opacity?: number }) {
  const cellSize = size / 3.5;
  const gap = size / 14;

  return (
    <div
      className={`grid grid-cols-3 ${className}`}
      style={{ gap: `${gap}px`, width: size, height: size, opacity }}
    >
      {[1, 1, 1, 0.7, 0.7, 0.7, 0.4, 0.4, 0.4].map((cellOpacity, i) => (
        <div
          key={i}
          className="bg-forma-obsidian rounded-[2px]"
          style={{
            width: cellSize,
            height: cellSize,
            opacity: cellOpacity,
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

export default function ScrollytellingOptionA() {
  const [files, setFiles] = useState<FloatingFile[]>([]);
  const [scrollProgress, setScrollProgress] = useState(0);
  const containerRef = useRef<HTMLDivElement>(null);
  const mouse = useMousePosition();

  useEffect(() => {
    setFiles(generateFiles(24));
  }, []);

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

  // Determine which "beat" we're in based on scroll progress
  const beat = scrollProgress < 0.25 ? 1 : scrollProgress < 0.5 ? 2 : scrollProgress < 0.75 ? 3 : 4;

  // Interpolation factor for file positions (0 = chaos, 1 = order)
  const orderFactor = Math.max(0, (scrollProgress - 0.5) * 2);

  // Text visibility
  const showChaosText = scrollProgress > 0.1 && scrollProgress < 0.4;
  const showRecognitionText = scrollProgress > 0.3 && scrollProgress < 0.6;
  const showTransformText = scrollProgress > 0.55 && scrollProgress < 0.85;
  const showFinalText = scrollProgress > 0.8;

  return (
    <main ref={containerRef} className="relative bg-forma-bone min-h-[500vh]">
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

      {/* Beat indicators */}
      <div className="fixed left-6 top-1/2 -translate-y-1/2 z-40 flex flex-col gap-2">
        {[1, 2, 3, 4].map((b) => (
          <div
            key={b}
            className={`w-2 h-2 rounded-full transition-all duration-300 ${
              beat >= b ? "bg-forma-steel-blue scale-100" : "bg-forma-obsidian/20 scale-75"
            }`}
          />
        ))}
      </div>

      {/* Sticky viewport */}
      <div className="sticky top-0 h-screen flex items-center justify-center overflow-hidden">

        {/* Floating files layer */}
        <div className="absolute inset-0">
          {files.map((file) => {
            // Interpolate between chaos and order positions
            const x = file.chaosX + (file.orderX - file.chaosX) * orderFactor;
            const y = file.chaosY + (file.orderY - file.chaosY) * orderFactor;
            const rotation = file.chaosRotation * (1 - orderFactor);
            const opacity = 0.3 + orderFactor * 0.5;

            return (
              <div
                key={file.id}
                className="absolute transition-all duration-700 ease-out"
                style={{
                  left: `${x}%`,
                  top: `${y}%`,
                  transform: `
                    translate(-50%, -50%)
                    rotate(${rotation}deg)
                    scale(${file.scale})
                    translateX(${mouse.x * 8 * (1 - orderFactor)}px)
                    translateY(${mouse.y * 8 * (1 - orderFactor)}px)
                  `,
                  opacity,
                  transitionDelay: `${file.delay * 0.3}s`,
                }}
              >
                <div
                  className="relative w-14 h-18 rounded-lg shadow-lg backdrop-blur-sm flex flex-col items-center justify-center"
                  style={{
                    background: `linear-gradient(135deg, ${file.color}22 0%, ${file.color}11 100%)`,
                    border: `1px solid ${file.color}33`,
                  }}
                >
                  <span className="text-xs font-mono font-bold" style={{ color: file.color }}>
                    {FILE_ICONS[file.type]}
                  </span>
                  <div className="mt-1.5 space-y-0.5 w-6">
                    <div className="h-0.5 rounded-full" style={{ background: `${file.color}44`, width: "100%" }} />
                    <div className="h-0.5 rounded-full" style={{ background: `${file.color}33`, width: "70%" }} />
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {/* Center content layer */}
        <div className="relative z-10 text-center px-6 max-w-4xl mx-auto">

          {/* Beat 1: Chaos title */}
          <div
            className={`absolute inset-0 flex flex-col items-center justify-center transition-all duration-700 ${
              showChaosText ? "opacity-100" : "opacity-0 pointer-events-none"
            }`}
          >
            <span className="font-mono text-xs text-forma-obsidian/40 tracking-widest mb-4">
              EVERY CREATIVE KNOWS THIS FEELING
            </span>
            <h2 className="text-5xl md:text-7xl font-display text-forma-obsidian">
              The chaos.
            </h2>
          </div>

          {/* Beat 2: Recognition */}
          <div
            className={`absolute inset-0 flex flex-col items-center justify-center transition-all duration-700 ${
              showRecognitionText ? "opacity-100" : "opacity-0 pointer-events-none"
            }`}
          >
            <h2 className="text-4xl md:text-6xl font-display text-forma-obsidian leading-tight">
              Your files deserve
              <br />
              <span className="text-forma-steel-blue italic">better.</span>
            </h2>
          </div>

          {/* Beat 3: Transformation */}
          <div
            className={`absolute inset-0 flex flex-col items-center justify-center transition-all duration-700 ${
              showTransformText ? "opacity-100" : "opacity-0 pointer-events-none"
            }`}
          >
            <GridLogo size={80} className="mx-auto mb-8" opacity={orderFactor} />
            <h2 className="text-4xl md:text-6xl font-display text-forma-obsidian">
              Watch them find
              <br />
              <span className="text-forma-sage italic">their place.</span>
            </h2>
          </div>

          {/* Beat 4: Order achieved */}
          <div
            className={`absolute inset-0 flex flex-col items-center justify-center transition-all duration-700 ${
              showFinalText ? "opacity-100" : "opacity-0 pointer-events-none"
            }`}
          >
            <GridLogo size={64} className="mx-auto mb-6" />
            <h1 className="text-5xl md:text-8xl font-display text-forma-obsidian mb-4">
              Forma
            </h1>
            <p className="text-xl text-forma-obsidian/50 mb-8 max-w-md">
              Intelligent file organization that brings order to your digital life.
            </p>
            <a
              href="#"
              className="inline-flex items-center gap-2 px-8 py-4 bg-[#1A1A1A] text-[#FAFAF8] rounded-full font-display text-lg hover:gap-4 transition-all duration-300"
            >
              Join the Beta
              <MoveRight className="w-5 h-5" />
            </a>
          </div>
        </div>

        {/* Scroll prompt (only at very beginning) */}
        <div
          className={`absolute bottom-12 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2 transition-opacity duration-500 ${
            scrollProgress < 0.05 ? "opacity-100" : "opacity-0"
          }`}
        >
          <span className="font-mono text-xs text-forma-obsidian/40 tracking-widest">
            SCROLL TO BEGIN
          </span>
          <div className="w-px h-8 bg-forma-obsidian/20 animate-pulse" />
        </div>
      </div>
    </main>
  );
}
