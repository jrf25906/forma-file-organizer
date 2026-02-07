"use client";

import { useRef, useState, useEffect, useCallback } from "react";
import { Type, GitBranch, Eye, Undo2 } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";

// ═══════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════

interface FeatureConfig {
  id: string;
  icon: typeof Type;
  title: string;
  description: string;
  accentColor: string;
  accentBg: string;
  demo: React.FC<{ active: boolean }>;
}

// ═══════════════════════════════════════════════════════════════════════════
// INTERACTION STATE HOOK
//
// Desktop (pointer: fine)  -- demos activate on hover (mouseenter/leave).
// Touch  (pointer: coarse) -- demos auto-activate when scrolled into view
//                             via IntersectionObserver, and toggle on tap.
// ═══════════════════════════════════════════════════════════════════════════

function useInteractionState(ref: React.RefObject<HTMLDivElement | null>) {
  const [active, setActive] = useState(false);
  const [isTouch, setIsTouch] = useState(false);
  const tappedRef = useRef(false);

  // Detect pointer type
  useEffect(() => {
    if (typeof window === "undefined" || !window.matchMedia) return;
    const mq = window.matchMedia("(pointer: coarse)");
    setIsTouch(mq.matches);

    const handleChange = (e: MediaQueryListEvent) => setIsTouch(e.matches);
    mq.addEventListener("change", handleChange);
    return () => mq.removeEventListener("change", handleChange);
  }, []);

  // Desktop: hover handlers
  const onMouseEnter = useCallback(() => {
    if (!isTouch) setActive(true);
  }, [isTouch]);

  const onMouseLeave = useCallback(() => {
    if (!isTouch) setActive(false);
  }, [isTouch]);

  // Touch: tap to toggle
  const onTap = useCallback(() => {
    if (isTouch) {
      tappedRef.current = !tappedRef.current;
      setActive(tappedRef.current);
    }
  }, [isTouch]);

  // Touch: auto-activate when scrolled into view
  useEffect(() => {
    if (!isTouch || !ref.current) return;

    const el = ref.current;
    const observer = new IntersectionObserver(
      ([entry]) => {
        // Only auto-activate if user has not manually tapped
        if (!tappedRef.current) {
          setActive(entry.isIntersecting);
        }
      },
      { threshold: 0.5 }
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, [isTouch, ref]);

  return { active, isTouch, onMouseEnter, onMouseLeave, onTap };
}

// ═══════════════════════════════════════════════════════════════════════════
// DEMO 1 -- NATURAL LANGUAGE RULES
// Animated typing of rule strings into a styled input.
// ═══════════════════════════════════════════════════════════════════════════

const RULE_EXAMPLES = [
  "Move screenshots to ~/Screenshots",
  "PDFs from Downloads -> ~/Documents/PDFs",
  "Old files over 90 days -> ~/Archive",
  "Sort invoices by date into ~/Finances",
];

function NaturalLanguageDemo({ active }: { active: boolean }) {
  const [displayText, setDisplayText] = useState("");
  const [ruleIndex, setRuleIndex] = useState(0);
  const [charIndex, setCharIndex] = useState(0);
  const [isDeleting, setIsDeleting] = useState(false);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  useEffect(() => {
    if (!active) {
      setDisplayText("");
      setCharIndex(0);
      setIsDeleting(false);
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
      return;
    }

    const currentRule = RULE_EXAMPLES[ruleIndex];

    if (!isDeleting) {
      if (charIndex < currentRule.length) {
        timeoutRef.current = setTimeout(() => {
          setDisplayText(currentRule.slice(0, charIndex + 1));
          setCharIndex((c) => c + 1);
        }, 45 + Math.random() * 35);
      } else {
        timeoutRef.current = setTimeout(() => setIsDeleting(true), 2200);
      }
    } else {
      if (charIndex > 0) {
        timeoutRef.current = setTimeout(() => {
          setDisplayText(currentRule.slice(0, charIndex - 1));
          setCharIndex((c) => c - 1);
        }, 22);
      } else {
        setIsDeleting(false);
        setRuleIndex((i) => (i + 1) % RULE_EXAMPLES.length);
      }
    }

    return () => {
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
    };
  }, [active, charIndex, isDeleting, ruleIndex]);

  // Derive a simple parsed target from the current text
  const parsedTarget =
    displayText.split(" to ")[1] ||
    displayText.split(" -> ")[1] ||
    displayText.split(" into ")[1] ||
    null;

  return (
    <div className="space-y-3">
      {/* Faux terminal input */}
      <div className="rounded-lg border border-white/10 bg-white/[0.04] px-4 py-3 font-mono text-sm">
        <span className="text-forma-steel-blue/50 select-none">$ </span>
        <span className="text-forma-bone/90">{displayText}</span>
        <span
          className={`inline-block w-[2px] h-4 ml-0.5 align-text-bottom bg-forma-steel-blue ${
            active ? "animate-blink" : "opacity-0"
          }`}
        />
      </div>

      {/* Parsed rule preview */}
      <div
        className={`rounded-lg border border-white/[0.06] bg-white/[0.02] px-4 py-2.5 transition-all duration-500 ${
          parsedTarget ? "opacity-100 translate-y-0" : "opacity-0 translate-y-1"
        }`}
      >
        <div className="flex items-center gap-2 text-xs text-forma-bone/40 mb-1.5">
          <div className="w-1.5 h-1.5 rounded-full bg-forma-sage animate-pulse" />
          Rule parsed
        </div>
        <div className="flex flex-wrap items-center gap-1.5 text-xs">
          <span className="rounded bg-forma-steel-blue/15 px-1.5 py-0.5 text-forma-steel-blue">
            action
          </span>
          <span className="text-forma-bone/60">move</span>
          <span className="text-forma-bone/20">|</span>
          <span className="rounded bg-forma-sage/15 px-1.5 py-0.5 text-forma-sage">
            target
          </span>
          <span className="text-forma-bone/60 truncate max-w-[120px]">
            {parsedTarget || "\u2026"}
          </span>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// DEMO 2 -- SMART CONNECTIONS
// Colored dots/tags grouped by file type with connecting lines.
// ═══════════════════════════════════════════════════════════════════════════

const FILE_GROUPS = [
  {
    label: "Images",
    dotColor: "bg-forma-steel-blue",
    textColor: "text-forma-steel-blue",
    borderColor: "border-forma-steel-blue/30",
    files: ["hero.png", "banner.jpg", "icon.svg"],
  },
  {
    label: "Documents",
    dotColor: "bg-forma-sage",
    textColor: "text-forma-sage",
    borderColor: "border-forma-sage/30",
    files: ["report.pdf", "notes.md", "readme.txt"],
  },
  {
    label: "Code",
    dotColor: "bg-forma-warm-orange",
    textColor: "text-forma-warm-orange",
    borderColor: "border-forma-warm-orange/30",
    files: ["app.tsx", "styles.css", "utils.ts"],
  },
];

function SmartConnectionsDemo({ active }: { active: boolean }) {
  return (
    <div className="space-y-2.5">
      {FILE_GROUPS.map((group, groupIdx) => (
        <div
          key={group.label}
          className={`flex items-start gap-3 rounded-lg border border-white/[0.06] bg-white/[0.02] px-3 py-2.5 transition-all duration-500 ${
            active ? "opacity-100 translate-x-0" : "opacity-40 translate-x-2"
          }`}
          style={{
            transitionDelay: active ? `${groupIdx * 100}ms` : "0ms",
          }}
        >
          {/* Group dot + connecting line */}
          <div className="flex flex-col items-center gap-1 pt-0.5">
            <div
              className={`w-2.5 h-2.5 rounded-full ${group.dotColor} transition-transform duration-300 ${
                active ? "scale-100" : "scale-50"
              }`}
              style={{
                transitionDelay: active ? `${groupIdx * 100 + 150}ms` : "0ms",
              }}
            />
            <div
              className={`w-px flex-1 ${group.dotColor} opacity-20 transition-opacity duration-300`}
            />
          </div>

          <div className="flex-1 min-w-0">
            <div className={`text-[11px] font-medium ${group.textColor} mb-1`}>
              {group.label}
            </div>
            <div className="flex flex-wrap gap-1.5">
              {group.files.map((file, fileIdx) => (
                <span
                  key={file}
                  className={`inline-flex items-center rounded border px-1.5 py-0.5 text-[10px] font-mono text-forma-bone/60 ${group.borderColor} bg-white/[0.03] transition-all duration-300 ${
                    active ? "opacity-100 scale-100" : "opacity-0 scale-90"
                  }`}
                  style={{
                    transitionDelay: active
                      ? `${groupIdx * 100 + fileIdx * 60 + 200}ms`
                      : "0ms",
                  }}
                >
                  {file}
                </span>
              ))}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// DEMO 3 -- TOTAL CONTROL (PREVIEW)
// Checkbox list showing files about to be moved with source/dest paths.
// ═══════════════════════════════════════════════════════════════════════════

const PREVIEW_FILES = [
  {
    name: "Screenshot 2024-01-15.png",
    from: "~/Desktop",
    to: "~/Screenshots",
    checked: true,
  },
  {
    name: "Invoice_March.pdf",
    from: "~/Downloads",
    to: "~/Documents/PDFs",
    checked: true,
  },
  {
    name: "notes.txt",
    from: "~/Desktop",
    to: "~/Documents",
    checked: false,
  },
  {
    name: "photo_backup.zip",
    from: "~/Downloads",
    to: "~/Archive",
    checked: true,
  },
];

function TotalControlDemo({ active }: { active: boolean }) {
  const [checks, setChecks] = useState(PREVIEW_FILES.map((f) => f.checked));

  const toggleCheck = (idx: number) => {
    setChecks((prev) => {
      const next = [...prev];
      next[idx] = !next[idx];
      return next;
    });
  };

  return (
    <div className="space-y-1">
      {/* Header bar */}
      <div className="flex items-center justify-between px-2 pb-1.5 border-b border-white/[0.06]">
        <span className="text-[10px] text-forma-bone/40 uppercase tracking-wider">
          Preview
        </span>
        <span className="text-[10px] text-forma-bone/30">
          {checks.filter(Boolean).length}/{checks.length} selected
        </span>
      </div>

      {/* File rows */}
      {PREVIEW_FILES.map((file, idx) => (
        <button
          key={file.name}
          onClick={() => toggleCheck(idx)}
          className={`w-full flex items-center gap-2.5 rounded px-2 py-1.5 text-left transition-all duration-300 hover:bg-white/[0.04] ${
            active ? "opacity-100 translate-y-0" : "opacity-0 translate-y-1"
          }`}
          style={{ transitionDelay: active ? `${idx * 80}ms` : "0ms" }}
        >
          {/* Checkbox */}
          <div
            className={`w-3.5 h-3.5 rounded-[3px] border flex-shrink-0 flex items-center justify-center transition-all duration-200 ${
              checks[idx]
                ? "bg-forma-steel-blue border-forma-steel-blue"
                : "border-white/20 bg-transparent"
            }`}
          >
            {checks[idx] && (
              <svg width="8" height="8" viewBox="0 0 8 8" fill="none">
                <path
                  d="M1.5 4L3.2 5.8L6.5 2.2"
                  stroke="white"
                  strokeWidth="1.2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            )}
          </div>

          {/* File info */}
          <div className="flex-1 min-w-0">
            <div className="text-[11px] text-forma-bone/80 truncate">
              {file.name}
            </div>
            <div className="flex items-center gap-1 text-[9px] text-forma-bone/35 mt-0.5">
              <span className="truncate max-w-[70px]">{file.from}</span>
              <span className="text-forma-sage">&rarr;</span>
              <span className="truncate max-w-[70px] text-forma-sage/80">
                {file.to}
              </span>
            </div>
          </div>
        </button>
      ))}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// DEMO 4 -- FULL UNDO
// Timeline of recent moves with reversible undo buttons.
// ═══════════════════════════════════════════════════════════════════════════

const UNDO_ACTIONS = [
  { file: "report.pdf", action: "Moved to ~/Documents", time: "2m ago" },
  { file: "hero.png", action: "Moved to ~/Screenshots", time: "5m ago" },
  { file: "backup.zip", action: "Moved to ~/Archive", time: "12m ago" },
];

function FullUndoDemo({ active }: { active: boolean }) {
  const [undone, setUndone] = useState<Set<number>>(new Set());
  const [animating, setAnimating] = useState<number | null>(null);

  const handleUndo = (idx: number) => {
    if (undone.has(idx) || animating !== null) return;
    setAnimating(idx);
    setTimeout(() => {
      setUndone((prev) => new Set(prev).add(idx));
      setAnimating(null);
    }, 400);
  };

  // Reset when demo deactivates
  useEffect(() => {
    if (!active) {
      setUndone(new Set());
      setAnimating(null);
    }
  }, [active]);

  return (
    <div className="space-y-1.5">
      {/* Header */}
      <div className="flex items-center gap-2 px-2 pb-1.5 border-b border-white/[0.06]">
        <div className="w-1.5 h-1.5 rounded-full bg-forma-sage animate-pulse" />
        <span className="text-[10px] text-forma-bone/40 uppercase tracking-wider">
          Recent Activity
        </span>
      </div>

      {/* Timeline items */}
      {UNDO_ACTIONS.map((item, idx) => {
        const isUndone = undone.has(idx);
        const isAnimating = animating === idx;

        return (
          <div
            key={idx}
            className={`flex items-center gap-2.5 rounded px-2 py-2 transition-all duration-400 ${
              active ? "opacity-100 translate-x-0" : "opacity-0 translate-x-3"
            } ${isUndone ? "opacity-50" : ""}`}
            style={{ transitionDelay: active ? `${idx * 100}ms` : "0ms" }}
          >
            {/* Timeline dot + connector */}
            <div className="flex flex-col items-center self-stretch">
              <div
                className={`w-2 h-2 rounded-full flex-shrink-0 transition-colors duration-300 ${
                  isUndone ? "bg-forma-bone/20" : "bg-forma-steel-blue"
                }`}
              />
              {idx < UNDO_ACTIONS.length - 1 && (
                <div className="w-px flex-1 bg-white/[0.06] mt-1" />
              )}
            </div>

            {/* Info */}
            <div className="flex-1 min-w-0">
              <div
                className={`text-[11px] transition-all duration-300 ${
                  isUndone
                    ? "text-forma-bone/30 line-through"
                    : "text-forma-bone/80"
                }`}
              >
                {item.file}
              </div>
              <div className="text-[9px] text-forma-bone/35 mt-0.5">
                {isUndone ? "Reversed" : item.action} &middot; {item.time}
              </div>
            </div>

            {/* Undo button */}
            <button
              onClick={() => handleUndo(idx)}
              disabled={isUndone}
              className={`flex items-center gap-1 rounded px-2 py-1 text-[10px] transition-all duration-300 ${
                isUndone
                  ? "text-forma-bone/20 cursor-default"
                  : "text-forma-warm-orange hover:bg-forma-warm-orange/10 cursor-pointer"
              } ${isAnimating ? "animate-forma-settle" : ""}`}
            >
              <Undo2 className="w-3 h-3" />
              {isUndone ? "Done" : "Undo"}
            </button>
          </div>
        );
      })}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// FEATURE DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════

const FEATURES: FeatureConfig[] = [
  {
    id: "natural-language",
    icon: Type,
    title: "Natural Language Rules",
    description:
      "Tell it what to do in plain English. No syntax to learn, no config files to edit. Just say where things should go.",
    accentColor: "text-forma-steel-blue",
    accentBg: "bg-forma-steel-blue/10",
    demo: NaturalLanguageDemo,
  },
  {
    id: "smart-connections",
    icon: GitBranch,
    title: "Smart Connections",
    description:
      "It sees patterns you\u2019d miss. Related files are grouped automatically so your rules can work across entire categories.",
    accentColor: "text-forma-sage",
    accentBg: "bg-forma-sage/10",
    demo: SmartConnectionsDemo,
  },
  {
    id: "total-control",
    icon: Eye,
    title: "Total Control",
    description:
      "Preview everything before it happens. See exactly which files move where, toggle individual items, then approve the batch.",
    accentColor: "text-forma-steel-blue",
    accentBg: "bg-forma-steel-blue/10",
    demo: TotalControlDemo,
  },
  {
    id: "full-undo",
    icon: Undo2,
    title: "Full Undo",
    description:
      "Reverse any move, any time. Every action is tracked in a timeline you can step through and roll back.",
    accentColor: "text-forma-warm-orange",
    accentBg: "bg-forma-warm-orange/10",
    demo: FullUndoDemo,
  },
];

// ═══════════════════════════════════════════════════════════════════════════
// FEATURE CARD
// ═══════════════════════════════════════════════════════════════════════════

function FeatureCard({ feature }: { feature: FeatureConfig }) {
  const cardRef = useRef<HTMLDivElement>(null);
  const { active, isTouch, onMouseEnter, onMouseLeave, onTap } =
    useInteractionState(cardRef);

  const Icon = feature.icon;
  const Demo = feature.demo;

  return (
    <div
      ref={cardRef}
      className="feature-card glass-card rounded-2xl p-6 md:p-8 transition-all duration-300 hover:border-white/15"
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
      onClick={onTap}
    >
      <div className="flex flex-col md:flex-row gap-6 md:gap-8">
        {/* Left side -- icon, title, description */}
        <div className="flex-1 min-w-0">
          <div
            className={`inline-flex items-center justify-center w-10 h-10 rounded-xl ${feature.accentBg} mb-4`}
          >
            <Icon className={`w-5 h-5 ${feature.accentColor}`} />
          </div>

          <h3 className="font-display text-xl md:text-2xl text-forma-bone tracking-tight mb-2">
            {feature.title}
          </h3>

          <p className="text-sm md:text-base text-forma-bone/60 leading-relaxed">
            {feature.description}
          </p>

          {/* Hover hint -- desktop only */}
          <div
            className={`mt-4 text-[11px] text-forma-bone/25 transition-opacity duration-300 hidden md:block ${
              active ? "opacity-0" : "opacity-100"
            }`}
          >
            Hover to interact
          </div>

          {/* Tap hint -- touch only */}
          {isTouch && (
            <div className="mt-3 text-[11px] text-forma-bone/25 md:hidden">
              Tap to interact
            </div>
          )}
        </div>

        {/* Right side -- interactive demo */}
        <div className="md:w-[280px] lg:w-[320px] flex-shrink-0">
          <div
            className={`rounded-xl border border-white/[0.06] bg-white/[0.02] p-4 transition-all duration-300 ${
              active
                ? "border-white/10 bg-white/[0.04] shadow-lg shadow-black/10"
                : ""
            }`}
          >
            <Demo active={active} />
          </div>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// FEATURES SECTION
// ═══════════════════════════════════════════════════════════════════════════

export default function FeaturesSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const headlineRef = useRef<HTMLHeadingElement>(null);
  const subtextRef = useRef<HTMLParagraphElement>(null);
  const cardsRef = useRef<HTMLDivElement>(null);

  // ScrollTrigger entrance animations
  useGSAP(
    () => {
      if (!sectionRef.current) return;

      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (prefersReducedMotion) {
        gsap.set([headlineRef.current, subtextRef.current], {
          opacity: 1,
          y: 0,
        });
        gsap.set(".feature-card", { opacity: 1, y: 0 });
        return;
      }

      // Header entrance
      const headerTl = gsap.timeline({
        scrollTrigger: {
          trigger: sectionRef.current,
          start: "top 78%",
          toggleActions: "play none none reverse",
        },
      });

      headerTl
        .from(headlineRef.current, {
          opacity: 0,
          y: 40,
          duration: formaDuration.normal,
          ease: formaReveal,
        })
        .from(
          subtextRef.current,
          {
            opacity: 0,
            y: 30,
            duration: formaDuration.normal,
            ease: formaReveal,
          },
          "-=0.5"
        );

      // Each feature card has its own ScrollTrigger
      const cards = cardsRef.current?.querySelectorAll(".feature-card");
      if (cards) {
        cards.forEach((card) => {
          gsap.from(card, {
            opacity: 0,
            y: 50,
            duration: formaDuration.normal,
            ease: formaReveal,
            scrollTrigger: {
              trigger: card,
              start: "top 85%",
              toggleActions: "play none none reverse",
            },
          });
        });
      }
    },
    { scope: sectionRef }
  );

  return (
    <section
      ref={sectionRef}
      id="features"
      className="scroll-mt-20 relative py-24 md:py-32 px-6 overflow-hidden"
    >
      {/* Background gradients */}
      <div className="absolute inset-0 pointer-events-none" aria-hidden="true">
        <div className="absolute inset-0 bg-gradient-to-b from-transparent via-forma-steel-blue/[0.03] to-transparent" />
        <div className="absolute top-1/3 left-0 w-[500px] h-[500px] rounded-full bg-forma-sage/[0.04] blur-[140px]" />
        <div className="absolute bottom-1/4 right-0 w-[400px] h-[400px] rounded-full bg-forma-steel-blue/[0.04] blur-[120px]" />
      </div>

      <div className="relative max-w-5xl mx-auto">
        {/* Section header */}
        <div className="text-center mb-16 md:mb-20">
          <h2
            ref={headlineRef}
            className="font-display text-3xl md:text-4xl lg:text-5xl text-forma-bone tracking-tight"
          >
            How it actually works
          </h2>
          <p
            ref={subtextRef}
            className="mt-5 text-lg md:text-xl text-forma-bone/60 max-w-2xl mx-auto leading-relaxed"
          >
            Four things that make the difference between a tool you install and a
            tool you keep.
          </p>
        </div>

        {/* Feature cards */}
        <div ref={cardsRef} className="space-y-6 md:space-y-8">
          {FEATURES.map((feature) => (
            <FeatureCard key={feature.id} feature={feature} />
          ))}
        </div>
      </div>
    </section>
  );
}
