import { ScrollReveal } from "@/components/animation/ScrollReveal";

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
          <span className="rounded-md bg-[rgba(74,107,136,0.12)] px-2.5 py-1 text-[12px] font-medium text-forma-steel-blue">
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
            style={{ backgroundColor: `rgba(74,107,136,${opacity})` }}
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
              row.undone
                ? "bg-[rgba(107,143,113,0.12)] text-forma-sage"
                : "bg-[rgba(184,107,82,0.15)] text-forma-warm-orange"
            }`}
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
      className={`group overflow-hidden rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] transition-shadow duration-300 hover:shadow-[0_8px_30px_rgba(0,0,0,0.06)] ${className ?? ""}`}
    >
      {scene}
      <div className="border-t border-[var(--border-subtle)] px-6 py-5">
        <h3 className="text-[16px] font-semibold text-[var(--text-primary)]">
          {title}
        </h3>
        <p className="mt-2 text-[14px] leading-relaxed text-[var(--text-secondary)]">
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
      aria-labelledby="features-heading"
      className="relative z-10 border-b border-[var(--border-subtle)] bg-transparent py-20 md:py-28"
    >
      <div className="site-container">
        {/* Section header */}
        <div className="mx-auto max-w-3xl text-center">
          <p className="text-[12px] font-semibold uppercase tracking-[0.12em] text-forma-steel-blue">
            What makes it different
          </p>
          <h2
            id="features-heading"
            className="mx-auto mt-5 max-w-2xl text-[1.875rem] font-semibold leading-[1.15] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem] md:leading-[1.1]"
          >
            Automation you can actually see.
          </h2>
          <p className="mx-auto mt-5 max-w-lg text-base leading-relaxed text-[var(--text-secondary)] md:text-[1.125rem]">
            Most file organizers run in the background and hope for the best.
            Forma shows you what it&apos;s about to do.
          </p>
        </div>

        {/* Bento grid — 2×2 asymmetric */}
        <div className="mx-auto mt-14 max-w-5xl">
          <ScrollReveal direction="up" distance={24} stagger={0.08}>
            <div className="grid gap-4 md:grid-cols-5">
              {/* Row 1: Natural Language (wider) + Auto-grouping */}
              <BentoCard
                className="md:col-span-3"
                scene={<NaturalLanguageScene />}
                title="Natural language rules"
                description="Describe what you want in words, not code. No regex, no scripts &mdash; just conditions and destinations."
              />
              <BentoCard
                className="md:col-span-2"
                scene={<AutoGroupingScene />}
                title="Auto-grouping"
                description="One rule catches 200 similar files. Not 200 rules for 200 files."
              />

              {/* Row 2: Preview + Undo (wider) */}
              <BentoCard
                className="md:col-span-2"
                scene={<PreviewScene />}
                title="Preview before action"
                description="See every file that matched before anything moves. Uncheck the ones you&rsquo;re not sure about."
              />
              <BentoCard
                className="md:col-span-3"
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
