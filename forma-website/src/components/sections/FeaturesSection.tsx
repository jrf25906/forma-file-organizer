"use client";

import { useRef, useEffect, useState, forwardRef, type ComponentType } from "react";
import { Eye, GitBranch, Type, Undo2 } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";
import { ScrollReveal } from "@/components/animation/ScrollReveal";
import { ScrollScene, useScrollSceneProgress } from "@/components/animation/ScrollScene";
import { FeatureShowcase, type ShowcaseFeature } from "@/components/features/FeatureShowcase";
import { AnimatedRuleDemo } from "@/components/features/AnimatedRuleDemo";
import { AnimatedConnectionDemo } from "@/components/features/AnimatedConnectionDemo";
import { AnimatedPreviewDemo } from "@/components/features/AnimatedPreviewDemo";
import { AnimatedUndoDemo } from "@/components/features/AnimatedUndoDemo";

/* ------------------------------------------------------------------ */
/*  Feature data                                                       */
/* ------------------------------------------------------------------ */

type FeatureMeta = {
  id: string;
  icon: typeof Type;
  title: string;
  description: string;
  accentText: string;
  accentBg: string;
  accentBorder: string;
};

const features: FeatureMeta[] = [
  {
    id: "natural-language",
    icon: Type,
    title: "If you can say it, you can automate it.",
    description:
      "Rules that read like sentences. No regex. No scripts. No config files — just conditions and destinations.",
    accentText: "text-forma-steel-blue",
    accentBg: "bg-forma-steel-blue/12",
    accentBorder: "bg-forma-steel-blue/50",
  },
  {
    id: "auto-grouping",
    icon: GitBranch,
    title: "200 screenshots. One rule.",
    description:
      "Forma groups similar files so one rule handles all of them — instead of writing 200 rules.",
    accentText: "text-forma-sage",
    accentBg: "bg-forma-sage/12",
    accentBorder: "bg-forma-sage/50",
  },
  {
    id: "total-control",
    icon: Eye,
    title: "Nothing moves until you say so.",
    description:
      "See exactly what will happen before it happens. Toggle individual files on or off, then approve the batch.",
    accentText: "text-forma-muted-blue",
    accentBg: "bg-forma-muted-blue/12",
    accentBorder: "bg-forma-muted-blue/50",
  },
  {
    id: "full-undo",
    icon: Undo2,
    title: "Undo everything. Always.",
    description:
      "Reverse any move, any time. Every action is tracked in a timeline you can step through and roll back.",
    accentText: "text-forma-warm-orange",
    accentBg: "bg-forma-warm-orange/12",
    accentBorder: "bg-forma-warm-orange/50",
  },
];

/* ------------------------------------------------------------------ */
/*  Preview components (static fallbacks for mobile)                   */
/* ------------------------------------------------------------------ */

function RulePreview() {
  const rules = [
    { text: "Move screenshots to", target: "~/Screenshots", status: "Active" },
    { text: "Rename invoices by", target: "date", status: "Active" },
    { text: "Sort code files into", target: "~/Projects", status: "3 matched" },
  ];

  return (
    <div className="space-y-2">
      {rules.map((rule) => (
        <div
          key={rule.text}
          className="flex items-center justify-between rounded-lg border border-[var(--border-medium)] bg-[var(--surface-glass)] px-3.5 py-2.5"
        >
          <span className="font-mono text-[11px] text-[var(--text-secondary)]">
            {rule.text}{" "}
            <span className="text-forma-steel-blue">{rule.target}</span>
          </span>
          <span className="rounded-full bg-forma-sage/12 px-2 py-0.5 text-[9px] font-medium text-forma-sage">
            {rule.status}
          </span>
        </div>
      ))}
    </div>
  );
}

function ConnectionPreview() {
  const groups = [
    {
      name: "Images",
      textClass: "text-forma-steel-blue",
      dotClass: "bg-forma-steel-blue",
      files: ["hero.png", "banner.jpg", "icon.svg"],
    },
    {
      name: "Documents",
      textClass: "text-forma-sage",
      dotClass: "bg-forma-sage",
      files: ["report.pdf", "notes.md", "readme.txt"],
    },
    {
      name: "Code",
      textClass: "text-forma-warm-orange",
      dotClass: "bg-forma-warm-orange",
      files: ["app.tsx", "styles.css", "utils.ts"],
    },
  ];

  return (
    <div className="space-y-2">
      {groups.map((group) => (
        <div
          key={group.name}
          className="rounded-lg border border-[var(--border-medium)] bg-[var(--surface-glass)] px-3 py-2"
        >
          <div className="mb-1 flex items-center gap-1.5">
            <span className={`h-1.5 w-1.5 rounded-full ${group.dotClass}`} />
            <span className={`text-[11px] font-medium ${group.textClass}`}>
              {group.name} ({group.files.length})
            </span>
          </div>
          <div className="flex flex-wrap gap-1">
            {group.files.map((file) => (
              <span
                key={file}
                className="rounded bg-[var(--surface-glass-hover)] px-1.5 py-0.5 font-mono text-[10px] text-[var(--text-muted)]"
              >
                {file}
              </span>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function ControlPreview() {
  const files = [
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
  ];

  return (
    <div className="space-y-1.5">
      {files.map((file) => (
        <div
          key={file.name}
          className={`flex items-start gap-2 rounded-lg border border-[var(--border-medium)] bg-[var(--surface-glass)] px-3 py-2${
            !file.checked ? " opacity-60" : ""
          }`}
        >
          <span
            className={`mt-0.5 inline-flex h-3.5 w-3.5 flex-shrink-0 items-center justify-center rounded text-[8px] ${
              file.checked
                ? "bg-forma-muted-blue text-white"
                : "border border-forma-muted-blue/40 bg-transparent text-transparent"
            }`}
          >
            {"\u2713"}
          </span>
          <div className="min-w-0 flex-1">
            <p className="truncate text-[11px] text-[var(--text-secondary)]">
              {file.name}
            </p>
            <p className="truncate text-[10px] text-[var(--text-muted)]">
              {file.from} {"\u2192"}{" "}
              <span className="text-forma-sage">{file.to}</span>
            </p>
          </div>
        </div>
      ))}
    </div>
  );
}

function UndoPreview() {
  const rows = [
    { file: "report.pdf", detail: "~/Documents \u00b7 2m ago", undone: false },
    { file: "hero.png", detail: "~/Screenshots \u00b7 5m ago", undone: false },
    { file: "backup.zip", detail: "~/Archive \u00b7 12m ago", undone: true },
  ];

  return (
    <div className="space-y-1.5">
      {rows.map((row) => (
        <div
          key={row.file}
          className="flex items-center justify-between rounded-lg border border-[var(--border-medium)] bg-[var(--surface-glass)] px-3 py-2"
        >
          <div className="min-w-0 pr-3">
            <p
              className={`truncate text-[11px] text-[var(--text-secondary)]${
                row.undone ? " line-through" : ""
              }`}
            >
              {row.file}
            </p>
            <p className="truncate text-[10px] text-[var(--text-muted)]">
              {row.detail}
            </p>
          </div>
          <button
            type="button"
            className={`flex-shrink-0 rounded-md px-2 py-1 text-[10px] font-medium ${
              row.undone
                ? "bg-forma-sage/12 text-forma-sage"
                : "bg-forma-warm-orange/15 text-forma-warm-orange"
            }`}
          >
            {row.undone ? "Done" : "Undo"}
          </button>
        </div>
      ))}
    </div>
  );
}

function PreviewForFeature({ id }: { id: string }) {
  if (id === "natural-language") return <RulePreview />;
  if (id === "auto-grouping") return <ConnectionPreview />;
  if (id === "total-control") return <ControlPreview />;
  return <UndoPreview />;
}

/* ------------------------------------------------------------------ */
/*  Build showcase data from feature meta + preview components         */
/* ------------------------------------------------------------------ */

/** Map feature ID to its animated demo component. */
const animatedDemoMap: Record<string, ComponentType<{ progress: number }>> = {
  "natural-language": AnimatedRuleDemo,
  "auto-grouping": AnimatedConnectionDemo,
  "total-control": AnimatedPreviewDemo,
  "full-undo": AnimatedUndoDemo,
};

const showcaseFeatures: ShowcaseFeature[] = features.map((f) => ({
  id: f.id,
  icon: f.icon,
  title: f.title,
  description: f.description,
  accentText: f.accentText,
  accentBg: f.accentBg,
  preview: <PreviewForFeature id={f.id} />,
  animatedDemo: animatedDemoMap[f.id],
}));

/* ------------------------------------------------------------------ */
/*  Desktop: pinned scroll showcase                                    */
/* ------------------------------------------------------------------ */

function DesktopFeatures() {
  const headlineRef = useRef<HTMLDivElement>(null);

  return (
    <ScrollScene id="features-showcase" scrubLength={3} pin={true}>
      <div className="relative h-screen w-full">
        {/* Section header - sits inside the pinned scene and fades based on progress */}
        <SectionHeader ref={headlineRef} />

        {/* The showcase fills the viewport */}
        <FeatureShowcase features={showcaseFeatures} />
      </div>
    </ScrollScene>
  );
}

/* ------------------------------------------------------------------ */
/*  Section header (used by both desktop and mobile)                   */
/* ------------------------------------------------------------------ */

const SectionHeader = forwardRef<HTMLDivElement>(function SectionHeader(_, ref) {
  const progress = useScrollSceneProgress();

  /* On desktop the header is inside the ScrollScene and should only
     show during the intro portion of the scroll (progress 0-0.06).
     On mobile (progress is always 1 because ScrollScene is disabled),
     we render it separately so this component is not used there. */
  const headerOpacity =
    progress < 0.02
      ? progress / 0.02
      : progress < 0.05
        ? 1
        : progress < 0.08
          ? 1 - (progress - 0.05) / 0.03
          : 0;

  const headerTranslateY = progress > 0.05 ? -20 * ((progress - 0.05) / 0.03) : 0;

  return (
    <div
      ref={ref}
      className="pointer-events-none absolute inset-x-0 top-0 z-10 flex h-screen items-center justify-center"
      style={{
        opacity: Math.max(0, Math.min(1, headerOpacity)),
        transform: `translateY(${headerTranslateY}px)`,
      }}
    >
      <div className="text-center">
        <p className="mb-4 text-[11px] font-medium uppercase tracking-[0.15em] text-forma-steel-blue">
          Features
        </p>
        <h2
          id="how-it-works"
          className="font-display text-3xl tracking-tight text-[var(--text-primary)] md:text-4xl lg:text-[2.75rem]"
        >
          How it actually works
        </h2>
        <p className="mx-auto mt-4 max-w-lg text-base leading-relaxed text-[var(--text-secondary)] md:text-lg">
          Most organizers move first and explain later. Forma shows you
          everything upfront — then lets you decide.
        </p>
      </div>
    </div>
  );
});

/* ------------------------------------------------------------------ */
/*  Mobile: stacked card grid (no pinning)                             */
/* ------------------------------------------------------------------ */

function MobileFeatures() {
  const headlineRef = useRef<HTMLHeadingElement>(null);
  const sectionRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (!sectionRef.current || !headlineRef.current) return;

      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (prefersReducedMotion) {
        gsap.set(headlineRef.current, { opacity: 1, y: 0 });
        return;
      }

      const triggerTop = sectionRef.current.getBoundingClientRect().top;
      if (triggerTop <= window.innerHeight * 0.8) {
        gsap.set(headlineRef.current, { opacity: 1, y: 0 });
        return;
      }

      gsap.from(headlineRef.current, {
        opacity: 0,
        y: 40,
        duration: formaDuration.normal,
        ease: formaReveal,
        scrollTrigger: {
          trigger: sectionRef.current,
          start: "top 80%",
          toggleActions: "play none none none",
          invalidateOnRefresh: true,
          onRefresh: (self) => {
            if (self.progress > 0) {
              gsap.set(headlineRef.current, { opacity: 1, y: 0 });
            }
          },
        },
      });
    },
    { scope: sectionRef }
  );

  return (
    <div ref={sectionRef}>
      <div className="mx-auto max-w-5xl">
        <div className="mb-7 text-center md:mb-14">
          <p className="mb-4 text-[11px] font-medium uppercase tracking-[0.15em] text-forma-steel-blue">
            Features
          </p>
          <h2
            id="how-it-works"
            ref={headlineRef}
            className="font-display text-3xl tracking-tight text-[var(--text-primary)] md:text-4xl lg:text-[2.75rem]"
          >
            How it actually works
          </h2>
          <p className="mx-auto mt-4 max-w-lg text-base leading-relaxed text-[var(--text-secondary)] md:text-lg">
            Most organizers move first and explain later. Forma shows you
            everything upfront — then lets you decide.
          </p>
        </div>

        <ScrollReveal stagger={0.12} threshold={85}>
          <div className="grid grid-cols-1 gap-4">
            {features.map((feature) => {
              const Icon = feature.icon;
              return (
                <article
                  key={feature.id}
                  className="flex flex-col overflow-hidden rounded-2xl bg-[var(--bg-secondary)] border border-[var(--border-subtle)]"
                >
                  <div className={`h-1.5 w-full ${feature.accentBorder}`} />
                  <div className="flex flex-1 flex-col p-5 sm:p-6">
                    <div className="mb-3 flex items-center gap-3">
                      <div
                        className={`inline-flex h-9 w-9 items-center justify-center rounded-lg ${feature.accentBg}`}
                      >
                        <Icon
                          className={`h-[18px] w-[18px] ${feature.accentText}`}
                        />
                      </div>
                      <h3 className="font-display text-xl tracking-tight text-[var(--text-primary)]">
                        {feature.title}
                      </h3>
                    </div>
                    <p className="mb-4 text-[14px] leading-relaxed text-[var(--text-secondary)]">
                      {feature.description}
                    </p>

                    <div className="demo-area mt-auto rounded-xl border border-[var(--border-medium)] bg-[var(--surface-glass)] p-4">
                      <PreviewForFeature id={feature.id} />
                    </div>
                  </div>
                </article>
              );
            })}
          </div>
        </ScrollReveal>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*  Exported FeaturesSection                                           */
/* ------------------------------------------------------------------ */

export default function FeaturesSection() {
  // Render mobile by default during SSR, then resolve viewport after mount.
  const [isMobile, setIsMobile] = useState(true);
  const [hasMounted, setHasMounted] = useState(false);

  useEffect(() => {
    const handleResize = () => setIsMobile(window.innerWidth < 768);
    window.addEventListener("resize", handleResize);

    const viewportFrame = window.requestAnimationFrame(handleResize);
    const mountedFrame = window.requestAnimationFrame(() => setHasMounted(true));

    return () => {
      window.removeEventListener("resize", handleResize);
      window.cancelAnimationFrame(viewportFrame);
      window.cancelAnimationFrame(mountedFrame);
    };
  }, []);

  return (
    <section
      id="features"
      className="features-section relative scroll-mt-16 overflow-hidden bg-transparent"
    >
      <div className="site-container relative">
        {/* Before mount, render mobile layout to avoid layout shift */}
        {!hasMounted ? (
          <div className="py-12 md:py-32">
            <MobileFeatures />
          </div>
        ) : isMobile ? (
          <div className="py-10 sm:py-12">
            <MobileFeatures />
          </div>
        ) : (
          <DesktopFeatures />
        )}
      </div>
    </section>
  );
}
