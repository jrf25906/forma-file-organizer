"use client";

import { useRef } from "react";
import { Eye, GitBranch, Type, Undo2 } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";

type Feature = {
  id: string;
  icon: typeof Type;
  title: string;
  description: string;
  accentText: string;
  accentBg: string;
};

const features: Feature[] = [
  {
    id: "natural-language",
    icon: Type,
    title: "Natural Language Rules",
    description:
      "Tell it what to do in plain English. No syntax to learn, no config files to edit. Just say where things should go.",
    accentText: "text-forma-steel-blue",
    accentBg: "bg-forma-steel-blue/12",
  },
  {
    id: "smart-connections",
    icon: GitBranch,
    title: "Smart Connections",
    description:
      "It sees patterns you'd miss. Related files are grouped automatically so your rules can work across entire categories.",
    accentText: "text-forma-sage",
    accentBg: "bg-forma-sage/12",
  },
  {
    id: "total-control",
    icon: Eye,
    title: "Total Control",
    description:
      "Preview everything before it happens. See exactly which files move where, toggle individual items, then approve the batch.",
    accentText: "text-forma-muted-blue",
    accentBg: "bg-forma-muted-blue/12",
  },
  {
    id: "full-undo",
    icon: Undo2,
    title: "Full Undo",
    description:
      "Reverse any move, any time. Every action is tracked in a timeline you can step through and roll back.",
    accentText: "text-forma-warm-orange",
    accentBg: "bg-forma-warm-orange/12",
  },
];

function RulePreview() {
  return (
    <div className="space-y-2.5">
      <div className="rounded-lg border border-black/[0.06] bg-white px-3.5 py-2.5 font-mono text-[12px] text-forma-obsidian/80">
        Move screenshots to <span className="text-forma-steel-blue">~/Screenshots</span>
      </div>
      <div className="flex items-center gap-2 text-[11px] text-forma-obsidian/50">
        <span className="h-px flex-1 bg-forma-obsidian/8" />
        <span>Moves matching files to target folder</span>
        <span className="h-px flex-1 bg-forma-obsidian/8" />
      </div>
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
          className="rounded-lg border border-black/[0.05] bg-white px-3 py-2"
        >
          <div className="mb-1 flex items-center gap-1.5">
            <span className={`h-1.5 w-1.5 rounded-full ${group.dotClass}`} />
            <span className={`text-[11px] font-medium ${group.textClass}`}>
              {group.name}
            </span>
          </div>
          <div className="flex flex-wrap gap-1">
            {group.files.map((file) => (
              <span
                key={file}
                className="rounded bg-black/[0.03] px-1.5 py-0.5 font-mono text-[10px] text-forma-obsidian/55"
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
    { name: "Screenshot 2024-01-15.png", from: "~/Desktop", to: "~/Screenshots" },
    { name: "Invoice_March.pdf", from: "~/Downloads", to: "~/Documents/PDFs" },
    { name: "notes.txt", from: "~/Desktop", to: "~/Documents" },
  ];

  return (
    <div className="space-y-1.5">
      {files.map((file) => (
        <div
          key={file.name}
          className="flex items-start gap-2 rounded-lg border border-black/[0.05] bg-white px-3 py-2"
        >
          <span className="mt-0.5 inline-flex h-3.5 w-3.5 items-center justify-center rounded bg-forma-muted-blue text-[8px] text-white flex-shrink-0">
            ✓
          </span>
          <div className="min-w-0 flex-1">
            <p className="truncate text-[11px] text-forma-obsidian/75">{file.name}</p>
            <p className="truncate text-[10px] text-forma-obsidian/45">
              {file.from} → <span className="text-forma-sage">{file.to}</span>
            </p>
          </div>
        </div>
      ))}
    </div>
  );
}

function UndoPreview() {
  const rows = [
    { file: "report.pdf", detail: "~/Documents · 2m ago" },
    { file: "hero.png", detail: "~/Screenshots · 5m ago" },
    { file: "backup.zip", detail: "~/Archive · 12m ago" },
  ];

  return (
    <div className="space-y-1.5">
      {rows.map((row) => (
        <div
          key={row.file}
          className="flex items-center justify-between rounded-lg border border-black/[0.05] bg-white px-3 py-2"
        >
          <div className="min-w-0 pr-3">
            <p className="truncate text-[11px] text-forma-obsidian/75">{row.file}</p>
            <p className="truncate text-[10px] text-forma-obsidian/45">{row.detail}</p>
          </div>
          <button
            type="button"
            className="flex-shrink-0 rounded-md bg-forma-warm-orange/8 px-2 py-1 text-[10px] font-medium text-forma-warm-orange/80"
          >
            Undo
          </button>
        </div>
      ))}
    </div>
  );
}

function PreviewForFeature({ id }: { id: string }) {
  if (id === "natural-language") return <RulePreview />;
  if (id === "smart-connections") return <ConnectionPreview />;
  if (id === "total-control") return <ControlPreview />;
  return <UndoPreview />;
}

export default function FeaturesSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const headlineRef = useRef<HTMLHeadingElement>(null);

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

      gsap.from(headlineRef.current, {
        opacity: 0,
        y: 40,
        duration: formaDuration.normal,
        ease: formaReveal,
        scrollTrigger: {
          trigger: sectionRef.current,
          start: "top 80%",
          toggleActions: "play none none none",
        },
      });
    },
    { scope: sectionRef }
  );

  return (
    <section
      ref={sectionRef}
      id="features"
      className="features-section relative scroll-mt-16 overflow-hidden bg-[#f4f6f8] py-24 md:py-32"
    >
      <div className="pointer-events-none absolute inset-0" aria-hidden="true">
        <div className="absolute inset-0 bg-[linear-gradient(180deg,rgba(255,255,255,0.65)_0%,rgba(244,246,248,1)_100%)]" />
      </div>

      <div className="site-container relative">
        <div className="mx-auto max-w-5xl">
          <div className="mb-14 text-center md:mb-16">
            <h2
              ref={headlineRef}
              className="font-display text-3xl tracking-tight text-forma-obsidian md:text-4xl lg:text-[2.75rem]"
            >
              How it actually works
            </h2>
            <p className="mx-auto mt-4 max-w-lg text-base leading-relaxed text-forma-obsidian/60 md:text-lg">
              Four things that make the difference between a tool you install
              and a tool you keep.
            </p>
          </div>

          <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
            {features.map((feature) => {
              const Icon = feature.icon;
              return (
                <article
                  key={feature.id}
                  className="flex flex-col rounded-2xl border border-black/[0.06] bg-white p-6 shadow-[0_2px_12px_rgba(0,0,0,0.04)] transition-shadow duration-300 hover:shadow-[0_8px_30px_rgba(0,0,0,0.07)]"
                >
                  <div className="flex items-center gap-3 mb-3">
                    <div
                      className={`inline-flex h-9 w-9 items-center justify-center rounded-lg ${feature.accentBg}`}
                    >
                      <Icon className={`h-[18px] w-[18px] ${feature.accentText}`} />
                    </div>
                    <h3 className="font-display text-xl tracking-tight text-forma-obsidian">
                      {feature.title}
                    </h3>
                  </div>
                  <p className="text-[14px] leading-relaxed text-forma-obsidian/60 mb-5">
                    {feature.description}
                  </p>

                  <div className="mt-auto rounded-xl border border-black/[0.05] bg-[#f8f9fb] p-4">
                    <PreviewForFeature id={feature.id} />
                  </div>
                </article>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}
