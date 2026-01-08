"use client";

import { useState } from "react";
import { Folder, FileText, Image, Code, Monitor, Clock, Shield, Sparkles } from "lucide-react";

// GSAP-powered animation components
import { ScrollReveal } from "@/components/animation/ScrollReveal";
import { MagneticButton } from "@/components/animation/MagneticButton";
import { HoverScale } from "@/components/animation/HoverScale";
import { TiltCard } from "@/components/animation/TiltCard";
import { LottieAnimation } from "@/components/animation";

// GSAP-powered hero
import ProductHero from "@/components/hero/ProductHero";

// Animated tech credibility section
import { TechCredibilityStrip } from "@/components/credibility";

import { RevealText } from "@/components/animation/RevealText";
import { Footer } from "@/components/Footer";
import AuroraBackground from "@/components/ui/AuroraBackground";
import { Button } from "@/components/ui/Button";

// ═══════════════════════════════════════════════════════════════════════════
// CHAPTER COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

function ChapterMarker({ number, title }: { number: string; title: string }) {
  return (
    <ScrollReveal direction="left" distance={30} duration={0.7}>
      <div className="flex items-center gap-4">
        <span className="font-mono text-xs text-forma-steel-blue tracking-widest">
          {number}
        </span>
        <div className="w-12 h-px bg-forma-steel-blue/30" />
        <span className="font-mono text-xs text-forma-obsidian/40 uppercase tracking-widest">
          {title}
        </span>
      </div>
    </ScrollReveal>
  );
}

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
          className="forma-logo-dot"
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


// TechCredibilityStrip is now imported from @/components/credibility

// ═══════════════════════════════════════════════════════════════════════════
// INTERACTIVE CAPABILITY DEMO COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

function NaturalLanguageDemo({ accent, useLottie = false }: { accent: string; useLottie?: boolean }) {
  // Start in result state - users trigger interactions via hover
  const [showResult, setShowResult] = useState(true);

  return (
    <div
      className="relative p-6 rounded-2xl cursor-pointer transition-all duration-500"
      style={{
        background: `linear-gradient(135deg, ${accent}12 0%, ${accent}05 100%)`,
        border: `1px solid ${accent}25`,
      }}
      onMouseEnter={() => setShowResult(true)}
      onMouseLeave={() => setShowResult(false)}
    >
      {/* Command input */}
      <div className="flex items-center gap-3 mb-4">
        <div className="w-2 h-2 rounded-full animate-pulse" style={{ background: accent }} />
        <span className="font-mono text-sm text-forma-obsidian/85">Natural language rule:</span>
      </div>

      <div
        className="font-mono text-base p-3 rounded-lg bg-white/60 mb-4 transition-all duration-300"
        style={{ color: accent }}
      >
        &quot;Move screenshots older than a week to Archive&quot;
      </div>

      {/* Animated file preview - Lottie version or CSS fallback */}
      <div className="relative h-16 overflow-hidden">
        {useLottie ? (
          <LottieAnimation
            animationPath="natural-language-demo.json"
            playOnHover
            loop={false}
            className="absolute inset-0"
            ariaLabel="Files moving to Archive folder animation"
          />
        ) : (
          <>
            <div className={`flex gap-3 transition-all duration-700 ${showResult ? '-translate-x-20 opacity-0' : ''}`}>
              <div className="flex items-center gap-2 px-3 py-2 bg-white/80 rounded-lg shadow-sm">
                <Image className="w-4 h-4" style={{ color: accent }} />
                <span className="text-xs text-forma-obsidian/85">Screenshot_Dec_14.png</span>
              </div>
              <div className="flex items-center gap-2 px-3 py-2 bg-white/80 rounded-lg shadow-sm">
                <Image className="w-4 h-4" style={{ color: accent }} />
                <span className="text-xs text-forma-obsidian/85">Screenshot_Dec_08.png</span>
              </div>
            </div>

            {/* Destination folder appears */}
            <div className={`absolute inset-0 flex items-center transition-all duration-500 ${showResult ? 'opacity-100 translate-x-0' : 'opacity-0 translate-x-8'}`}>
              <div className="flex items-center gap-2 px-4 py-3 bg-white/90 rounded-lg shadow-md border" style={{ borderColor: `${accent}30` }}>
                <Folder className="w-5 h-5" style={{ color: accent }} />
                <span className="text-sm font-medium text-forma-obsidian">Archive</span>
                <span className="text-xs text-forma-obsidian/45 ml-2">+2 files</span>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function ConnectionsDemo({ accent, useLottie = false }: { accent: string; useLottie?: boolean }) {
  // Start in connected state - users trigger interactions via hover
  const [showConnected, setShowConnected] = useState(true);

  const files = [
    { name: "Acme_brief_FINAL.pdf", type: FileText },
    { name: "logo_exploration_v4.fig", type: Image },
    { name: "brand_colors.json", type: Code },
  ];

  return (
    <div
      className="relative p-6 rounded-2xl cursor-pointer transition-all duration-500"
      style={{
        background: `linear-gradient(135deg, ${accent}12 0%, ${accent}05 100%)`,
        border: `1px solid ${accent}25`,
      }}
      onMouseEnter={() => setShowConnected(true)}
      onMouseLeave={() => setShowConnected(false)}
    >
      <div className="flex items-center gap-3 mb-4">
        <Sparkles className="w-4 h-4" style={{ color: accent }} />
        <span className="font-mono text-sm text-forma-obsidian/85">Project detected:</span>
        <span className="font-mono text-sm font-medium" style={{ color: accent }}>Acme Rebrand</span>
      </div>

      {/* Files that connect - Lottie version or CSS fallback */}
      <div className="relative">
        {useLottie ? (
          <div className="h-32">
            <LottieAnimation
              animationPath="connections-demo.json"
              playOnHover
              loop={false}
              className="absolute inset-0"
              ariaLabel="Files connecting to project animation"
            />
          </div>
        ) : (
          <>
            <div className={`flex flex-col gap-2 transition-all duration-500 ${showConnected ? 'gap-0' : ''}`}>
              {files.map((file, i) => {
                const Icon = file.type;
                return (
                  <div
                    key={i}
                    className={`flex items-center gap-2 px-3 py-2 bg-white/80 rounded-lg shadow-sm transition-all duration-500`}
                    style={{
                      transitionDelay: `${i * 50}ms`,
                      transform: showConnected ? `translateY(${i * -8}px)` : 'none',
                    }}
                  >
                    <Icon className="w-4 h-4" style={{ color: accent }} />
                    <span className="text-xs text-forma-obsidian/85">{file.name}</span>
                  </div>
                );
              })}
            </div>

            {/* Connection lines */}
            <div
              className={`absolute -right-2 top-1/2 -translate-y-1/2 transition-opacity duration-500 ${showConnected ? 'opacity-100' : 'opacity-0'}`}
            >
              <div className="w-8 h-16 border-r-2 border-t-2 border-b-2 rounded-r-lg" style={{ borderColor: `${accent}40` }} />
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function ControlDemo({ accent }: { accent: string }) {
  // Start with all items approved to show the result state
  const [approved, setApproved] = useState<number[]>([0, 1, 2]);

  const pendingFiles = [
    { name: "Q4_report_final_v2.pdf", dest: "Documents/Reports" },
    { name: "team_photo_Dec.jpg", dest: "Photos/2024" },
    { name: "meeting_notes_12-18.md", dest: "Notes/Meetings" },
  ];

  return (
    <div
      className="relative p-6 rounded-2xl transition-all duration-500"
      style={{
        background: `linear-gradient(135deg, ${accent}12 0%, ${accent}05 100%)`,
        border: `1px solid ${accent}25`,
      }}
    >
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <Shield className="w-4 h-4" style={{ color: accent }} />
          <span className="font-mono text-sm text-forma-obsidian/85">Review pending:</span>
        </div>
        <span className="text-xs font-mono" style={{ color: accent }}>{approved.length}/3 approved</span>
      </div>

      <div className="space-y-2">
        {pendingFiles.map((file, i) => (
          <button
            key={i}
            onClick={() => setApproved(prev => prev.includes(i) ? prev.filter(x => x !== i) : [...prev, i])}
            className={`w-full flex items-center justify-between px-3 py-2 rounded-lg transition-all duration-300 ${approved.includes(i)
              ? 'bg-white/90 shadow-md'
              : 'bg-white/50 hover:bg-white/70'
              }`}
            style={{ borderLeft: approved.includes(i) ? `3px solid ${accent}` : '3px solid transparent' }}
          >
            <div className="flex items-center gap-2">
              <div className={`w-4 h-4 rounded border-2 flex items-center justify-center transition-all duration-200`}
                style={{ borderColor: accent, background: approved.includes(i) ? accent : 'transparent' }}
              >
                {approved.includes(i) && <span className="text-white text-xs">✓</span>}
              </div>
              <span className="text-xs text-forma-obsidian/85">{file.name}</span>
            </div>
            <span className="text-xs text-forma-obsidian/45">→ {file.dest}</span>
          </button>
        ))}
      </div>

      <span className="absolute bottom-3 right-3 text-[10px] font-mono text-forma-obsidian/30">
        tap to approve
      </span>
    </div>
  );
}

function UndoDemo({ accent }: { accent: string }) {
  // Static history state - users can interact by clicking undo/redo
  const [history, setHistory] = useState([
    { action: "Moved client_assets/ → Projects/Acme", time: "2m ago", undone: false },
    { action: "Renamed: invoice_*.pdf → 2024-Invoice-*.pdf", time: "5m ago", undone: false },
    { action: "Archived 12 screenshots from Desktop", time: "8m ago", undone: false },
  ]);

  const handleUndo = (index: number) => {
    setHistory(prev => prev.map((item, i) =>
      i === index ? { ...item, undone: !item.undone } : item
    ));
  };

  return (
    <div
      className="relative p-6 rounded-2xl transition-all duration-500"
      style={{
        background: `linear-gradient(135deg, ${accent}12 0%, ${accent}05 100%)`,
        border: `1px solid ${accent}25`,
      }}
    >
      <div className="flex items-center gap-3 mb-4">
        <Clock className="w-4 h-4" style={{ color: accent }} />
        <span className="font-mono text-sm text-forma-obsidian/85">Activity history</span>
      </div>

      <div className="space-y-2">
        {history.map((item, i) => (
          <div
            key={i}
            className={`flex items-center justify-between px-3 py-2 rounded-lg transition-all duration-300 ${item.undone ? 'bg-white/40 opacity-50' : 'bg-white/70'
              }`}
          >
            <div className="flex-1">
              <span className={`text-xs ${item.undone ? 'line-through text-forma-obsidian/40' : 'text-forma-obsidian/85'}`}>
                {item.action}
              </span>
              <span className="text-[10px] text-forma-obsidian/30 ml-2">{item.time}</span>
            </div>
            <button
              onClick={() => handleUndo(i)}
              className="text-xs font-mono px-2 py-1 rounded transition-colors hover:bg-white/50"
              style={{ color: accent }}
            >
              {item.undone ? 'redo' : 'undo'}
            </button>
          </div>
        ))}
      </div>

      <span className="absolute bottom-3 right-3 text-[10px] font-mono text-forma-obsidian/30">
        tap to undo
      </span>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// CAPABILITIES SECTION
// ═══════════════════════════════════════════════════════════════════════════

function ActThree() {
  // This section is the skip link target - first content after hero
  const capabilities = [
    {
      title: "Talk to it like a human",
      description:
        "Forget learning another interface. Just say \"Move screenshots older than a week to Archive\" and it's done. No folders-within-folders. No tagging systems. No manual drag-and-drop forever.",
      accent: "#5B7C99",
      Demo: NaturalLanguageDemo,
    },
    {
      title: "It gets context. Finally.",
      description:
        "Other tools sort by file type. Forma sees the actual relationship. Client brief, logo explorations, and color palette belong together — not scattered across Documents, Downloads, and Desktop.",
      accent: "#7A9D7E",
      Demo: ConnectionsDemo,
    },
    {
      title: "You approve. It executes.",
      description:
        "No black-box automation anxiety. See exactly what will move and where before it happens. One tap to approve, or fine-tune until it's perfect.",
      accent: "#6B8CA8",
      Demo: ControlDemo,
    },
    {
      title: "Undo everything. Always.",
      description:
        "Made a mistake? Regret that rule? One click restores everything exactly where it was. No more digging through Trash or recreating folder structures.",
      accent: "#C97E66",
      Demo: UndoDemo,
    },
  ];

  return (
    <section
      id="features"
      tabIndex={-1}
      className="relative py-12 md:py-16 px-6 outline-none focus:ring-2 focus:ring-forma-steel-blue focus:ring-offset-4 scroll-mt-20"
      aria-label="Features section"
    >
      {/* Background gradient orbs */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none" aria-hidden="true">
        <div
          className="absolute w-[600px] h-[600px] rounded-full blur-[120px] opacity-20"
          style={{
            background: "radial-gradient(circle, #5B7C99 0%, transparent 70%)",
            left: "-10%",
            top: "20%",
          }}
        />
        <div
          className="absolute w-[500px] h-[500px] rounded-full blur-[100px] opacity-15"
          style={{
            background: "radial-gradient(circle, #7A9D7E 0%, transparent 70%)",
            right: "-5%",
            top: "60%",
          }}
        />
      </div>

      <div className="relative max-w-6xl mx-auto">
        <ChapterMarker number="01" title="How It Works" />

        <ScrollReveal direction="up" distance={40}>
          <div className="mt-8 md:mt-10 max-w-3xl">
            <RevealText className="text-4xl md:text-5xl lg:text-6xl font-display text-forma-obsidian leading-[1.1]" delay={0.2}>
              File organization that actually works.
            </RevealText>
          </div>
          <p className="mt-6 text-lg md:text-xl text-forma-obsidian/85 max-w-2xl">
            You've tried folders. You've tried tags. You've tried "I'll organize it later." Here's what's different.
          </p>
        </ScrollReveal>

        {/* Capabilities - truly asymmetric layout */}
        <div className="mt-10 md:mt-14 space-y-12 md:space-y-16">
          {capabilities.map((cap, i) => {
            const Demo = cap.Demo;
            const isOdd = i % 2 === 1;
            // Vary the grid placement more dramatically
            // Features 3 & 4 use a tighter 2-column grid on desktop
            const gridConfig = i === 0
              ? "lg:grid-cols-2 gap-10"
              : i === 1
                ? "lg:grid-cols-12 gap-8"
                : i === 2
                  ? "lg:grid-cols-2 gap-10"
                  : "lg:grid-cols-2 gap-10";

            return (
              <div key={i} className={`grid ${gridConfig} items-center py-8 md:py-12`}>
                {/* Text content */}
                <div
                  className={`${i === 1 ? "lg:col-span-5 lg:col-start-8" : ""
                    } ${isOdd ? "lg:order-2" : ""}`}
                >
                  <ScrollReveal delay={i * 100} direction={isOdd ? "right" : "left"}>
                    <div className="flex items-center gap-3 mb-4">
                      <div
                        className="w-1 h-8 rounded-full"
                        style={{ background: cap.accent }}
                      />
                    </div>
                    <h3 className="text-2xl md:text-3xl font-display text-forma-obsidian mb-3">
                      {cap.title}
                    </h3>
                    <p className="text-base md:text-lg text-forma-obsidian/85 leading-relaxed">
                      {cap.description}
                    </p>
                  </ScrollReveal>
                </div>

                {/* Interactive demo */}
                <div
                  className={`${i === 1 ? "lg:col-span-6 lg:col-start-1" : ""
                    } ${isOdd ? "lg:order-1" : ""}`}
                >
                  <ScrollReveal
                    delay={i * 100 + 200}
                    direction={isOdd ? "left" : "right"}
                  >
                    <TiltCard maxRotation={8} scale={1.02} glare>
                      <Demo accent={cap.accent} />
                    </TiltCard>
                  </ScrollReveal>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// ACT IV: BEFORE/AFTER WORKFLOW COMPARISON
// Show the contrast, not platitudes
// ═══════════════════════════════════════════════════════════════════════════

// Scattered chaos icons for the "Before" state - reinforces visual disorder
function ScatteredChaosIcons({ useLottie = false }: { useLottie?: boolean }) {
  const icons = [
    { Icon: FileText, x: 82, y: 10, rotate: -15, scale: 1 },
    { Icon: Image, x: 70, y: 28, rotate: 12, scale: 0.9 },
    { Icon: Code, x: 88, y: 48, rotate: -8, scale: 0.85 },
    { Icon: FileText, x: 75, y: 68, rotate: 18, scale: 0.95 },
    { Icon: Image, x: 85, y: 85, rotate: -12, scale: 0.8 },
  ];

  // Lottie version - shows animated chaos if available
  if (useLottie) {
    return (
      <div className="absolute inset-0 overflow-hidden pointer-events-none" aria-hidden="true">
        <LottieAnimation
          animationPath="scattered-chaos.json"
          loop
          className="absolute inset-0 opacity-25"
          ariaLabel="Scattered chaotic files animation"
        />
      </div>
    );
  }

  // CSS fallback version
  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none" aria-hidden="true">
      {icons.map((item, i) => {
        const IconComponent = item.Icon;
        return (
          <div
            key={i}
            className="absolute chaos-icon"
            style={{
              left: `${item.x}%`,
              top: `${item.y}%`,
              transform: `rotate(${item.rotate}deg) scale(${item.scale})`,
              opacity: 0.25,
              animation: `chaos-drift ${2 + i * 0.3}s ease-in-out infinite`,
              animationDelay: `${i * 0.2}s`,
            }}
          >
            <IconComponent className="w-4 h-4 text-forma-warm-orange/70" strokeWidth={1.5} />
          </div>
        );
      })}
    </div>
  );
}

// Organized folder structure for the "After" state - reinforces visual order
function OrganizedFolderCluster({ useLottie = false }: { useLottie?: boolean }) {
  const folders = [
    { label: "Documents", delay: 0 },
    { label: "Images", delay: 0.1 },
    { label: "Projects", delay: 0.2 },
  ];

  // Lottie version - shows animated organization if available
  if (useLottie) {
    return (
      <div className="absolute right-3 top-6 bottom-6 w-20 overflow-hidden pointer-events-none" aria-hidden="true">
        <LottieAnimation
          animationPath="organized-folders.json"
          playOnView
          loop={false}
          className="absolute inset-0 opacity-35"
          ariaLabel="Organized folder structure animation"
        />
      </div>
    );
  }

  // CSS fallback version
  return (
    <div className="absolute right-3 top-6 bottom-6 w-20 overflow-hidden pointer-events-none" aria-hidden="true">
      <div className="relative h-full flex flex-col justify-center gap-2.5">
        {folders.map((folder, i) => (
          <div
            key={i}
            className="organized-folder flex items-center gap-1.5"
            style={{
              opacity: 0.35,
              animation: `settle-in 0.6s ease-out forwards`,
              animationDelay: `${folder.delay + 0.3}s`,
            }}
          >
            <Folder className="w-3 h-3 text-forma-sage" strokeWidth={1.5} />
            <span className="text-[8px] font-mono text-forma-sage/90 tracking-tight">{folder.label}</span>
          </div>
        ))}
        {/* Subtle connecting line showing hierarchy */}
        <div
          className="absolute left-[5px] top-[28%] bottom-[28%] w-px"
          style={{
            background: 'linear-gradient(to bottom, transparent 0%, rgba(122, 157, 126, 0.2) 20%, rgba(122, 157, 126, 0.2) 80%, transparent 100%)',
          }}
        />
      </div>
    </div>
  );
}

function ActFour() {
  const [beforeHovered, setBeforeHovered] = useState(false);
  const [afterHovered, setAfterHovered] = useState(false);

  return (
    <section id="how-it-works" className="relative py-12 md:py-16 px-6 scroll-mt-20">
      <div className="max-w-6xl mx-auto">
        <ScrollReveal direction="up" distance={30}>
          <div className="text-center mb-10 md:mb-12">
            <span className="font-mono text-xs text-forma-steel-blue/80 tracking-widest uppercase">The difference</span>
            <h2 className="mt-4 text-3xl md:text-4xl font-display text-forma-obsidian">
              Your workflow, <span className="italic text-forma-steel-blue">transformed</span>
            </h2>
          </div>
        </ScrollReveal>

        <div className="grid md:grid-cols-2 gap-6 md:gap-8 pt-4">
          {/* BEFORE - Chaotic, stressed, uncomfortable */}
          <ScrollReveal delay={100} direction="left" distance={40}>
            <TiltCard maxRotation={6} scale={1.01}>
            <div
              className={`before-card relative p-6 md:p-8 rounded-2xl transition-all duration-500 ${beforeHovered ? 'before-card-hovered' : ''
                }`}
              style={{
                background: 'linear-gradient(135deg, rgba(201, 126, 102, 0.08) 0%, rgba(201, 126, 102, 0.03) 50%, rgba(26, 26, 26, 0.02) 100%)',
                border: '1px solid rgba(201, 126, 102, 0.18)',
              }}
              onMouseEnter={() => setBeforeHovered(true)}
              onMouseLeave={() => setBeforeHovered(false)}
            >
              {/* Scattered file icons in background */}
              <ScatteredChaosIcons />

              {/* Warm/stressed color overlay - subtle red/orange undertone */}
              <div
                className="absolute inset-0 pointer-events-none"
                style={{
                  background: 'radial-gradient(ellipse at 85% 15%, rgba(201, 126, 102, 0.12) 0%, transparent 50%)',
                  opacity: beforeHovered ? 0.5 : 0.35,
                  transition: 'opacity 0.4s ease',
                }}
              />

              <span
                className="absolute -top-3 left-6 px-3 py-1 bg-forma-bone text-xs font-mono uppercase tracking-wider rounded-sm"
                style={{
                  color: 'rgba(201, 126, 102, 0.75)',
                  border: '1px solid rgba(201, 126, 102, 0.2)',
                }}
              >
                Before
              </span>

              <div className="relative space-y-4 mt-2">
                <div className="flex items-start gap-3">
                  <span className="text-forma-warm-orange/60 text-lg font-light select-none">×</span>
                  <p className="text-forma-obsidian/55">Spend 15 minutes hunting for that one screenshot</p>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-forma-warm-orange/60 text-lg font-light select-none">×</span>
                  <p className="text-forma-obsidian/55">
                    Desktop covered in{' '}
                    <code
                      className="text-xs px-1.5 py-0.5 rounded border"
                      style={{
                        backgroundColor: 'rgba(201, 126, 102, 0.08)',
                        color: 'rgba(201, 126, 102, 0.8)',
                        borderColor: 'rgba(201, 126, 102, 0.15)',
                      }}
                    >
                      Untitled.txt
                    </code>{' '}
                    files
                  </p>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-forma-warm-orange/60 text-lg font-light select-none">×</span>
                  <p className="text-forma-obsidian/55">That sinking feeling when you can&apos;t find the final_FINAL_v3.pdf</p>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-forma-warm-orange/60 text-lg font-light select-none">×</span>
                  <p className="text-forma-obsidian/55">Weekend afternoon spent &ldquo;getting organized&rdquo; (again)</p>
                </div>
              </div>
            </div>
            </TiltCard>
          </ScrollReveal>

          {/* AFTER - Calm, serene, organized */}
          <ScrollReveal delay={200} direction="right" distance={40}>
            <TiltCard maxRotation={6} scale={1.01}>
            <div
              className={`after-card relative p-6 md:p-8 rounded-2xl transition-all duration-500 ${afterHovered ? 'after-card-hovered' : ''
                }`}
              style={{
                background: 'linear-gradient(135deg, rgba(122, 157, 126, 0.12) 0%, rgba(91, 124, 153, 0.08) 50%, rgba(122, 157, 126, 0.06) 100%)',
                border: '1px solid rgba(122, 157, 126, 0.25)',
              }}
              onMouseEnter={() => setAfterHovered(true)}
              onMouseLeave={() => setAfterHovered(false)}
            >
              {/* Organized folder cluster in background */}
              <OrganizedFolderCluster />

              {/* Serene color overlay - cool blue/green tint */}
              <div
                className="absolute inset-0 pointer-events-none"
                style={{
                  background: 'radial-gradient(ellipse at 15% 85%, rgba(91, 124, 153, 0.1) 0%, transparent 50%), radial-gradient(ellipse at 85% 15%, rgba(122, 157, 126, 0.08) 0%, transparent 40%)',
                  opacity: afterHovered ? 0.6 : 0.4,
                  transition: 'opacity 0.4s ease',
                }}
              />

              <span
                className="absolute -top-3 left-6 px-3 py-1 bg-forma-bone text-xs font-mono uppercase tracking-wider rounded-sm"
                style={{
                  color: 'rgba(122, 157, 126, 0.9)',
                  border: '1px solid rgba(122, 157, 126, 0.25)',
                }}
              >
                After
              </span>

              <div className="relative space-y-4 mt-2">
                <div className="flex items-start gap-3">
                  <span className="text-forma-sage text-lg select-none">✓</span>
                  <p className="text-forma-obsidian/85">Every file exactly where you&apos;d expect it</p>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-forma-sage text-lg select-none">✓</span>
                  <p className="text-forma-obsidian/85">Desktop stays clean. Permanently.</p>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-forma-sage text-lg select-none">✓</span>
                  <p className="text-forma-obsidian/85">Find anything in under 3 seconds</p>
                </div>
                <div className="flex items-start gap-3">
                  <span className="text-forma-sage text-lg select-none">✓</span>
                  <p className="text-forma-obsidian/85">Organization happens automatically, in the background</p>
                </div>
              </div>
            </div>
            </TiltCard>
          </ScrollReveal>
        </div>
      </div>
    </section>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// ANIMATED CTA BUTTON - Files flow into folder on hover
// ═══════════════════════════════════════════════════════════════════════════

function AnimatedCTAButton({ onClick, useLottie = false }: { onClick?: () => void; useLottie?: boolean }) {
  const [isHovered, setIsHovered] = useState(false);

  return (
    <MagneticButton strength={0.2} className="relative group">
      <button
        onClick={onClick}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
        className="relative z-10 flex items-center gap-3 px-8 py-4 bg-forma-obsidian text-forma-bone rounded-full font-medium text-lg overflow-hidden transition-all duration-300 hover:shadow-2xl hover:shadow-forma-obsidian/20"
      >
        <span className="relative z-10">Start organizing</span>

        {/* Lottie Version */}
        {useLottie ? (
          <div className="w-6 h-6">
            <LottieAnimation
              animationPath="cta-files-to-folder.json"
              playOnHover
              loop={false}
              className="w-full h-full"
              ariaLabel="Files moving to folder icon"
            />
          </div>
        ) : (
          /* CSS Fallback Version */
          <div className="relative w-6 h-6 flex items-center justify-center">
            {/* Static folder that opens on hover */}
            <Folder
              className={`w-5 h-5 transition-all duration-300 ${isHovered ? 'scale-110' : 'scale-100'}`}
              strokeWidth={2}
            />

            {/* Small filing animation on hover */}
            <div className={`absolute inset-0 pointer-events-none ${isHovered ? 'opacity-100' : 'opacity-0'}`}>
              <div className="absolute top-0 right-0 w-2 h-2 bg-forma-bone rounded-[1px] animate-[file-drop_0.6s_ease-in-out_infinite]" />
            </div>
          </div>
        )}
      </button>

      {/* Button Glow */}
      <div className="absolute inset-0 rounded-full bg-forma-obsidian/0 group-hover:bg-forma-obsidian/5 transition-colors duration-300 -z-10" />
    </MagneticButton>
  );
}


// ═══════════════════════════════════════════════════════════════════════════
// BETA SIGNUP MODAL
// ═══════════════════════════════════════════════════════════════════════════

function BetaSignupModal({
  isOpen,
  onClose,
}: {
  isOpen: boolean;
  onClose: () => void;
}) {
  const [email, setEmail] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email) return;

    setIsSubmitting(true);

    // Simulate API call - replace with actual endpoint
    await new Promise((resolve) => setTimeout(resolve, 1000));

    setIsSubmitting(false);
    setIsSuccess(true);

    // Reset after showing success
    setTimeout(() => {
      onClose();
      setIsSuccess(false);
      setEmail("");
    }, 2000);
  };

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center p-4"
      onClick={onClose}
    >
      {/* Backdrop */}
      <div className="absolute inset-0 bg-forma-obsidian/60 backdrop-blur-sm" />

      {/* Modal */}
      <div
        className="relative w-full max-w-md bg-forma-bone rounded-2xl shadow-2xl p-8 animate-in fade-in zoom-in-95 duration-300"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 w-8 h-8 flex items-center justify-center text-forma-obsidian/40 hover:text-forma-obsidian transition-colors rounded-full hover:bg-forma-obsidian/5"
        >
          <span className="sr-only">Close</span>
          <svg
            className="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>

        {isSuccess ? (
          <div className="text-center py-8">
            <div className="relative w-16 h-16 mx-auto mb-4 rounded-full bg-forma-sage/20 flex items-center justify-center overflow-hidden">
              {/* Lottie animation overlay - renders on top when animation exists */}
              <div className="absolute inset-0 flex items-center justify-center z-10">
                <LottieAnimation
                  animationPath="success-checkmark.json"
                  autoplay
                  loop={false}
                  className="w-12 h-12"
                  ariaLabel="Success checkmark animation"
                />
              </div>
              {/* SVG fallback - always rendered but may be covered by Lottie */}
              <svg
                className="w-8 h-8 text-forma-sage"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M5 13l4 4L19 7"
                />
              </svg>
            </div>
            <h3 className="text-xl font-display text-forma-obsidian mb-2">
              You&apos;re on the list!
            </h3>
            <p className="text-forma-obsidian/85 text-sm">
              We&apos;ll send your beta invite within 24 hours.
            </p>
          </div>
        ) : (
          <>
            <div className="text-center mb-6">
              <GridLogo size={40} className="mx-auto mb-4" />
              <h3 className="text-2xl font-display text-forma-obsidian mb-2">
                Join the Beta
              </h3>
              <p className="text-forma-obsidian/85 text-sm">
                Get early access to Forma and help shape the future of file organization.
              </p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label htmlFor="email" className="sr-only">
                  Email address
                </label>
                <input
                  type="email"
                  id="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  required
                  className="w-full px-4 py-3 rounded-xl border border-forma-obsidian/10 bg-white/50 text-forma-obsidian placeholder:text-forma-obsidian/40 focus:outline-none focus:ring-2 focus:ring-forma-steel-blue/50 focus:border-transparent transition-all"
                />
              </div>

              <Button
                type="submit"
                disabled={isSubmitting}
                className="w-full"
                size="md"
              >
                {isSubmitting ? (
                  <>
                    <svg
                      className="animate-spin w-4 h-4 mr-2"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        className="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        strokeWidth="4"
                      />
                      <path
                        className="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      />
                    </svg>
                    Joining...
                  </>
                ) : (
                  "Get Early Access"
                )}
              </Button>
            </form>

            <p className="mt-4 text-center text-xs text-forma-obsidian/40">
              Free during beta. No credit card required.
            </p>
          </>
        )}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// ACT V: THE INVITATION (Restructured with better narrative flow)
// ═══════════════════════════════════════════════════════════════════════════

function ActFive() {
  const [isModalOpen, setIsModalOpen] = useState(false);

  return (
    <section id="pricing" className="relative py-12 md:py-16 px-6 scroll-mt-20">
      {/* Subtle gradient background */}
      <div className="absolute inset-0 pointer-events-none">
        <div
          className="absolute inset-0"
          style={{
            background: `linear-gradient(180deg, transparent 0%, rgba(91, 124, 153, 0.04) 50%, transparent 100%)`,
          }}
        />
      </div>

      <div className="relative max-w-6xl mx-auto">
        {/* Header with logo */}
        <ScrollReveal direction="up" distance={20}>
          <div className="text-center mb-6">
            <GridLogo size={48} className="mx-auto" />
          </div>
        </ScrollReveal>

        <ScrollReveal delay={100} direction="up" distance={30}>
          <div className="flex flex-col items-center">
            <RevealText className="text-center text-3xl md:text-4xl lg:text-5xl font-display text-forma-obsidian leading-[1.15] justify-center" delay={0.1}>
              Join the beta. Give your files form.
            </RevealText>
          </div>
        </ScrollReveal>

        {/* Beta status - honest placeholder */}
        <ScrollReveal delay={200} direction="up" distance={25}>
          <div className="mt-8 max-w-lg mx-auto text-center">
            <p className="text-forma-obsidian/60 text-base leading-relaxed">
              Currently in beta with early testers. We&apos;ll share their stories soon.
            </p>
          </div>
        </ScrollReveal>

        {/* Capability framing */}
        <ScrollReveal delay={300} direction="up" distance={30}>
          <div className="mt-8 py-5 px-6 rounded-2xl bg-white/40 border border-forma-obsidian/5 backdrop-blur-sm">
            <div className="flex flex-wrap items-center justify-center gap-8 md:gap-16">
              <HoverScale scale={1.05}>
                <div className="text-center">
                  <p className="text-2xl md:text-3xl font-display text-forma-obsidian">100,000+</p>
                  <p className="text-xs text-forma-obsidian/45 font-mono uppercase tracking-wider mt-1">
                    Files handled
                  </p>
                </div>
              </HoverScale>
              <div className="w-px h-12 bg-forma-obsidian/10 hidden md:block" />
              <HoverScale scale={1.05}>
                <div className="text-center">
                  <p className="text-2xl md:text-3xl font-display text-forma-obsidian">Milliseconds</p>
                  <p className="text-xs text-forma-obsidian/45 font-mono uppercase tracking-wider mt-1">
                    Not minutes
                  </p>
                </div>
              </HoverScale>
              <div className="w-px h-12 bg-forma-obsidian/10 hidden md:block" />
              <HoverScale scale={1.05}>
                <div className="text-center">
                  <p className="text-2xl md:text-3xl font-display text-forma-obsidian">Zero</p>
                  <p className="text-xs text-forma-obsidian/45 font-mono uppercase tracking-wider mt-1">
                    Files lost. Ever.
                  </p>
                </div>
              </HoverScale>
            </div>
          </div>
        </ScrollReveal>

        {/* CTA Section with friction reduction */}
        <ScrollReveal delay={400} direction="up" distance={25}>
          <div className="mt-8 text-center">
            {/* Social proof near CTA */}
            <p className="mb-4 text-sm text-forma-obsidian/50 flex items-center justify-center gap-2">
              <span className="inline-flex -space-x-2">
                {[1, 2, 3, 4].map((i) => (
                  <span
                    key={i}
                    className="w-6 h-6 rounded-full bg-gradient-to-br from-forma-steel-blue/30 to-forma-sage/30 border-2 border-forma-bone"
                  />
                ))}
              </span>
              <span>Join 847 early adopters</span>
            </p>

            {/* Main CTA Button */}
            <AnimatedCTAButton onClick={() => setIsModalOpen(true)} />

            {/* Friction reduction text */}
            <p className="mt-4 text-sm text-forma-obsidian/45">
              Free during beta. No credit card required.
            </p>
          </div>
        </ScrollReveal>

        {/* System requirements & trust badges */}
        <ScrollReveal delay={500} direction="up" distance={20}>
          <div className="mt-6 flex flex-wrap items-center justify-center gap-6 text-sm text-forma-obsidian/45">
            <span className="flex items-center gap-2">
              <Monitor className="w-4 h-4" />
              macOS 14+
            </span>
            <span className="flex items-center gap-2">
              <Shield className="w-4 h-4" />
              Privacy-first
            </span>
            <span className="flex items-center gap-2">
              <Clock className="w-4 h-4" />
              2-min setup
            </span>
          </div>
        </ScrollReveal>
      </div>

      {/* Beta signup modal */}
      <BetaSignupModal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} />
    </section>
  );
}



// ═══════════════════════════════════════════════════════════════════════════
// MAIN PAGE
// ═══════════════════════════════════════════════════════════════════════════

export default function Home() {
  return (
    <div className="relative min-h-screen">
      <main className="relative z-10 mb-[220px] shadow-2xl overflow-hidden">
        {/* Aurora is inside main so it shows while footer stays hidden */}
        <AuroraBackground />
        <ProductHero />
        <TechCredibilityStrip />
        <ActThree />
        <ActFour />
        <ActFive />
      </main>
      <Footer />
    </div>
  );
}
