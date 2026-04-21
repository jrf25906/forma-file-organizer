"use client";

import { ScrollReveal } from "@/components/animation/ScrollReveal";
import { DraftedPlate } from "@/components/ui/DraftedPlate";
import { MonoLabel } from "@/components/ui/MonoLabel";
import { ScribeLine } from "@/components/animation/ScribeLine";
import { FolderFigure } from "@/components/illustrations/AxonometricFigures";

const storyBullets = [
  {
    eyebrow: "Write the rule naturally",
    body: "Tell Forma what belongs together and where it should land. It reads more like a note to yourself than a settings screen.",
  },
  {
    eyebrow: "Pause before anything moves",
    body: "Preview the batch, scan the matches, and uncheck anything that feels off before the app does any work.",
  },
  {
    eyebrow: "Keep recovery close",
    body: "If a batch was wrong, undo the recent move from the same flow instead of rebuilding the folder by hand.",
  },
] as const;

const callouts = [
  { label: "§ 01", title: "Plain-language rule", path: "M10 70 C 30 56, 44 40, 60 30" },
  { label: "§ 02", title: "Preview first", path: "M90 60 C 80 40, 70 28, 60 30" },
  { label: "§ 03", title: "Undo batch", path: "M50 92 C 58 78, 60 56, 60 30" },
] as const;

export default function IllustratedStorySection() {
  return (
    <section className="grid-stronger relative z-10 overflow-hidden border-b border-[var(--rule-faint)] py-24 md:py-32">
      <div className="mx-auto grid w-full max-w-[1200px] gap-12 px-6 lg:grid-cols-[0.88fr,1.12fr] lg:items-center lg:gap-16">
        <ScrollReveal direction="up" distance={20}>
          <div className="max-w-[34rem]">
            <MonoLabel
              variant="fig"
              className="mb-3 flex items-center gap-2.5 before:block before:h-px before:w-7 before:bg-[var(--ink-draft)]"
            >
              FIG.&nbsp;03 · THE BATCH, DRAFTED
            </MonoLabel>
            <p className="eyebrow">A calmer first step</p>
            <h2 className="display-lg mt-5 text-[var(--ink-primary)]">
              Make sense of the mess without turning it into a project.
            </h2>
            <p className="prose-editorial mt-5">
              Write one rule in plain English, preview what it wants to do, and approve only the
              files that look right. Forma stays human-sized even when the folder is not.
            </p>

            <div className="mt-8 space-y-5">
              {storyBullets.map((bullet, index) => (
                <div
                  key={bullet.eyebrow}
                  className="flex gap-4 border-t border-[var(--rule-draft-faint)] pt-5 first:border-t-0 first:pt-0"
                >
                  <MonoLabel variant="section" className="pt-0.5 tabular-nums">
                    § 0{index + 1}
                  </MonoLabel>
                  <div>
                    <h3 className="font-display text-[1.125rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
                      {bullet.eyebrow}
                    </h3>
                    <p className="mt-2 text-[15px] leading-relaxed text-[var(--ink-secondary)]">
                      {bullet.body}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </ScrollReveal>

        <ScrollReveal direction="up" distance={24}>
          <DraftedPlate
            fig="FIG. 03A — FOLDER IN REVIEW"
            dimensionTop="— 120 files —"
            dimensionSide="§ BATCH"
            innerClassName="min-h-[480px] p-8"
          >
            <div className="relative mx-auto">
              {/* Centered folder figure */}
              <div className="relative mx-auto flex h-[260px] w-[320px] items-center justify-center">
                <FolderFigure className="h-[180px] w-[220px]" />
                {/* Three scribe-leader lines drawing to callout corners */}
                {callouts.map((c, i) => (
                  <ScribeLine
                    key={c.label}
                    path={c.path}
                    viewBox="0 0 100 100"
                    durationMs={520}
                    delayMs={220 + i * 180}
                    strokeDasharray="3 4"
                    strokeWidth={1}
                    className="absolute inset-0 h-full w-full"
                  />
                ))}
              </div>

              {/* Three callouts positioned under the figure */}
              <div className="mt-6 grid gap-4 sm:grid-cols-3">
                {callouts.map((c) => (
                  <div
                    key={c.label}
                    className="rounded-[0.5rem] border border-[var(--rule-draft-faint)] bg-[rgba(255,252,248,0.9)] px-4 py-3"
                  >
                    <MonoLabel variant="section" className="tabular-nums">
                      {c.label}
                    </MonoLabel>
                    <p className="mt-1 font-display text-[0.95rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
                      {c.title}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          </DraftedPlate>
        </ScrollReveal>
      </div>
    </section>
  );
}
