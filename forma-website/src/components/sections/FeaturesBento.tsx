import { ScrollReveal } from "@/components/animation/ScrollReveal";
import { FormaShellSectionHeading } from "@/components/ui/forma-shell-section-heading";

/* ═══════════════════════════════════════════════════════════════════════════
   SCENE: NATURAL LANGUAGE RULES — rule rows with keywords + destination pills
   ═══════════════════════════════════════════════════════════════════════════ */

const ruleRows = [
  { prefix: "If it\u2019s a", keyword: "screenshot", dest: "~/Screenshots", opacity: 1 },
  { prefix: "If it\u2019s a", keyword: "PDF", dest: "~/Documents", opacity: 1 },
  { prefix: "If older than", keyword: "30 days", dest: "~/Archive", opacity: 0.5 },
];

function NaturalLanguageScene() {
  return (
    <div className="flex h-[200px] flex-col items-center justify-center gap-2.5 rounded-t-2xl bg-[var(--bg-tertiary)] px-6">
      {ruleRows.map((rule) => (
        <div
          key={rule.dest}
          className="flex w-full max-w-[380px] items-center gap-3 rounded-[10px] bg-[var(--bg-primary)] px-[18px] py-3.5"
          style={{ opacity: rule.opacity }}
        >
          <span className="text-[13px] text-[var(--text-secondary)]">
            {rule.prefix}{" "}
            <span className="font-medium text-forma-warm-orange">{rule.keyword}</span>
            , move to
          </span>
          <span
            className="rounded-md px-2.5 py-1 text-[12px] font-medium text-forma-steel-blue"
            style={{
              backgroundColor:
                "color-mix(in srgb, var(--forma-steel-blue) 12%, transparent)",
            }}
          >
            {rule.dest}
          </span>
        </div>
      ))}
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   SCENE: AUTO-GROUPING — file tile grid with match counter
   ═══════════════════════════════════════════════════════════════════════════ */

function AutoGroupingScene() {
  const tiles = [0.15, 0.12, 0.10, 0.08, 0.15, 0.10, 0.06, 0.06];
  return (
    <div className="flex h-[200px] flex-col items-center justify-center gap-3.5 rounded-t-2xl bg-[var(--bg-tertiary)]">
      <div className="flex items-center gap-2">
        <span className="h-2.5 w-2.5 rounded-full bg-forma-steel-blue" />
        <span className="text-[12px] font-medium text-forma-steel-blue">Images (47)</span>
      </div>
      <div className="flex max-w-[240px] flex-wrap justify-center gap-1.5">
        {tiles.map((opacity, i) => (
          <div
            key={i}
            className="h-9 w-9 rounded-md"
            style={{
              backgroundColor: `color-mix(in srgb, var(--forma-steel-blue) ${Math.round(opacity * 100)}%, transparent)`,
            }}
          />
        ))}
      </div>
      <span className="text-[11px] text-[var(--text-muted)]">+39 more matched</span>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   SCENE: PREVIEW — checklist with checkmarks and one unchecked
   ═══════════════════════════════════════════════════════════════════════════ */

const previewFiles = [
  { name: "Screenshot_2024-01.png", dest: "~/Screenshots", checked: true },
  { name: "Invoice_March.pdf", dest: "~/Documents", checked: true },
  { name: "notes.txt", dest: "~/Documents", checked: false },
  { name: "hero_banner.png", dest: "~/Screenshots", checked: true },
];

function PreviewScene() {
  return (
    <div className="flex h-[200px] flex-col items-stretch justify-center gap-2 rounded-t-2xl bg-[var(--bg-tertiary)] px-5">
      {previewFiles.map((file) => (
        <div
          key={file.name}
          className="flex items-center gap-2.5 rounded-lg bg-[var(--bg-primary)] px-3.5 py-2.5"
          style={{ opacity: file.checked ? 1 : 0.55 }}
        >
          <div
            className={`flex h-4 w-4 flex-shrink-0 items-center justify-center rounded ${
              file.checked
                ? "bg-forma-sage text-white"
                : "border-[1.5px] border-[var(--text-muted)]"
            }`}
          >
            {file.checked && (
              <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                <polyline points="20 6 9 17 4 12" />
              </svg>
            )}
          </div>
          <span className="text-[12px] text-[var(--text-secondary)]">{file.name}</span>
          <span className="ml-auto text-[11px] text-[var(--text-muted)]">{file.dest}</span>
        </div>
      ))}
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   SCENE: UNDO HISTORY — timeline with undo buttons
   ═══════════════════════════════════════════════════════════════════════════ */

const undoRows = [
  { file: "report.pdf", dest: "~/Documents", time: "2m ago", undone: false },
  { file: "hero.png", dest: "~/Screenshots", time: "5m ago", undone: false },
  { file: "backup.zip", dest: "~/Archive", time: "12m ago", undone: true },
];

function UndoScene() {
  return (
    <div className="flex h-[200px] flex-col items-center justify-center gap-1.5 rounded-t-2xl bg-[var(--bg-tertiary)] px-8">
      {undoRows.map((row) => (
        <div
          key={row.file}
          className="flex w-full max-w-[400px] items-center gap-3 rounded-lg bg-[var(--bg-primary)] px-3.5 py-2.5"
          style={{ opacity: row.undone ? 0.6 : 1 }}
        >
          <span
            className={`h-1.5 w-1.5 flex-shrink-0 rounded-full ${
              row.undone ? "bg-[var(--text-muted)]" : "bg-forma-sage"
            }`}
          />
          <span
            className={`flex-1 text-[12px] ${
              row.undone
                ? "text-[var(--text-muted)] line-through"
                : "text-[var(--text-secondary)]"
            }`}
          >
            {row.file} &rarr; {row.dest}
          </span>
          <span className="text-[11px] text-[var(--text-muted)]">{row.time}</span>
          <span
            className={`rounded-[5px] px-2.5 py-0.5 text-[11px] font-medium ${
              row.undone ? "text-forma-sage" : "text-forma-warm-orange"
            }`}
            style={{
              backgroundColor: row.undone
                ? "color-mix(in srgb, var(--forma-sage) 12%, transparent)"
                : "color-mix(in srgb, var(--forma-warm-orange) 15%, transparent)",
            }}
          >
            {row.undone ? "Undone" : "Undo"}
          </span>
        </div>
      ))}
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   BENTO CARD WRAPPER
   ═══════════════════════════════════════════════════════════════════════════ */

function BentoCard({
  scene,
  title,
  description,
  className,
}: {
  scene: React.ReactNode;
  title: string;
  description: string;
  className?: string;
}) {
  return (
    <article
      className={`group overflow-hidden rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] shadow-[var(--shell-shadow-soft)] transition-shadow duration-300 hover:shadow-[var(--shell-shadow-strong)] ${className ?? ""}`}
    >
      {scene}
      <div className="border-t border-[var(--rule-faint)] px-6 py-5">
        <h3 className="font-display text-[1.125rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
          {title}
        </h3>
        <p className="mt-2 text-[14px] leading-relaxed text-[var(--ink-secondary)]">
          {description}
        </p>
      </div>
    </article>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   EXPORTED SECTION
   ═══════════════════════════════════════════════════════════════════════════ */

export default function FeaturesBento() {
  return (
    <section
      className="relative z-10 border-b border-[var(--rule-faint)] py-24 md:py-32"
    >
      <div className="mx-auto w-full max-w-[1200px] px-6">
        <FormaShellSectionHeading
          eyebrow="What makes it different"
          title="Automation you can actually see."
          description="Most file organizers run in the background and hope for the best. Forma shows you what it's about to do."
          size="xl"
          className="max-w-3xl"
        />

        {/* Bento grid — 2×2 asymmetric */}
        <div className="mt-16">
          <ScrollReveal direction="up" distance={24} stagger={0.08}>
            <div className="grid gap-6 md:grid-cols-12">
              {/* Row 1: Natural Language (wider) + Auto-grouping */}
              <BentoCard
                className="md:col-span-7"
                scene={<NaturalLanguageScene />}
                title="Natural language rules"
                description="Describe what you want in words, not code. No regex, no scripts &mdash; just conditions and destinations."
              />
              <BentoCard
                className="md:col-span-5"
                scene={<AutoGroupingScene />}
                title="Auto-grouping"
                description="One rule catches 200 similar files. Not 200 rules for 200 files."
              />

              {/* Row 2: Preview + Undo (wider) */}
              <BentoCard
                className="md:col-span-5"
                scene={<PreviewScene />}
                title="Preview before action"
                description="See every file that matched before anything moves. Uncheck the ones you&rsquo;re not sure about."
              />
              <BentoCard
                className="md:col-span-7"
                scene={<UndoScene />}
                title="Undo recent batches"
                description="If a batch was wrong, reverse it in Forma without moving everything back by hand."
              />
            </div>
          </ScrollReveal>
        </div>
      </div>
    </section>
  );
}
