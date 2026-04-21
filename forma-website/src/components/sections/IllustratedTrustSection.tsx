"use client";

import Image from "next/image";
import Link from "next/link";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";
import { ScrollReveal } from "@/components/animation/ScrollReveal";
import { DraftedPlate } from "@/components/ui/DraftedPlate";
import { MonoLabel } from "@/components/ui/MonoLabel";
import { formaShellCtaVariants } from "@/components/ui/forma-shell-cta";
import { cn } from "@/lib/utils";
import { SUPPORT_EMAIL } from "@/lib/site";

const trustRows = [
  {
    mark: "§ 01",
    title: "Mac App Store purchase.",
    body: "Checkout, updates, and billing stay inside a storefront Mac users already understand. No account to create.",
  },
  {
    mark: "§ 02",
    title: "Folder-by-folder access.",
    body: "Forma asks for access one directory at a time, never all at once. Revocable in System Settings.",
  },
  {
    mark: "§ 03",
    title: "Preview before the move; undo the recent batch.",
    body: "Every match and destination is staged before anything runs. If a batch was wrong, reverse it without rebuilding the folder.",
  },
] as const;

export default function IllustratedTrustSection() {
  return (
    <section
      aria-labelledby="trust-heading"
      className="grid-stronger relative z-10 overflow-hidden border-b border-[var(--rule-faint)] py-24 md:py-32"
    >
      <div className="mx-auto grid w-full max-w-[1200px] gap-12 px-6 lg:grid-cols-[0.92fr,1.08fr] lg:items-start lg:gap-16">
        <ScrollReveal direction="up" distance={20}>
          <div className="max-w-[34rem]">
            <MonoLabel
              variant="fig"
              className="mb-3 flex items-center gap-2.5 before:block before:h-px before:w-7 before:bg-[var(--ink-draft)]"
            >
              FIG.&nbsp;06 · TRUST SHEET
            </MonoLabel>
            <p className="eyebrow">Before you pay</p>
            <h2 id="trust-heading" className="display-lg mt-5 text-[var(--ink-primary)]">
              Bought through Apple. Controlled by you.
            </h2>
            <p className="prose-editorial mt-5">
              The trust story should read quickly: buy it through the Mac App Store, choose the
              folders yourself, preview every move, and undo the recent batch if something was wrong.
            </p>

            <p className="mt-6 text-[14px] leading-relaxed text-[var(--ink-secondary)]">
              Need more confidence first?{" "}
              <Link
                href="/blog"
                className="font-medium text-forma-steel-blue underline underline-offset-4 decoration-forma-steel-blue/30 transition-[text-decoration-color,color] duration-200 hover:decoration-forma-steel-blue/60"
              >
                Read the guide flow
              </Link>{" "}
              or{" "}
              <TrackedMailtoLink
                email={SUPPORT_EMAIL}
                location="homepage_trust_bridge"
                className="font-medium text-forma-steel-blue underline underline-offset-4 decoration-forma-steel-blue/30 transition-[text-decoration-color,color] duration-200 hover:decoration-forma-steel-blue/60"
              >
                ask a question
              </TrackedMailtoLink>
              .
            </p>
          </div>
        </ScrollReveal>

        <ScrollReveal direction="up" distance={24}>
          <DraftedPlate
            fig="FIG. 06 — TRUST SHEET"
            dimensionSide="§ TRUST"
            innerClassName="p-6 md:p-8"
          >
            <div className="space-y-5">
              {trustRows.map((row) => (
                <div
                  key={row.mark}
                  className="grid grid-cols-[54px_1fr] items-baseline gap-3 border-b border-[var(--rule-draft-faint)] pb-4 last:border-b-0 last:pb-0"
                >
                  <MonoLabel variant="section" className="pt-0.5 tabular-nums">
                    {row.mark}
                  </MonoLabel>
                  <div>
                    <h3 className="font-display text-[1.05rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
                      {row.title}
                    </h3>
                    <p className="mt-1.5 text-[14px] leading-relaxed text-[var(--ink-secondary)]">
                      {row.body}
                    </p>
                  </div>
                </div>
              ))}
            </div>

            {/* Sub-figure — preview-queue screenshot with its own FIG label */}
            <div className="mt-7 rounded-[0.5rem] border border-[var(--rule-draft-faint)] bg-[rgba(255,252,248,0.92)] p-3">
              <div className="mb-2 flex items-center justify-between">
                <MonoLabel variant="fig">FIG. 06A — PREVIEW QUEUE</MonoLabel>
                <MonoLabel variant="dim">— staged, not executed —</MonoLabel>
              </div>
              <Image
                src="/screenshots/story/forma-paper-03-preview.png"
                alt="Forma preview queue showing file moves before approval"
                width={1312}
                height={900}
                className="h-auto w-full rounded-[0.4rem] outline outline-1 -outline-offset-1 outline-black/10"
              />
            </div>

            <div className="mt-6">
              <TrackedAppStoreLink
                location="post_proof_primary"
                className={cn(formaShellCtaVariants({ variant: "primary" }), "h-11 px-5 text-[14px]")}
              >
                View on the Mac App Store
              </TrackedAppStoreLink>
            </div>
          </DraftedPlate>
        </ScrollReveal>
      </div>
    </section>
  );
}
