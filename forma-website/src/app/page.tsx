import Link from "next/link";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import dynamic from "next/dynamic";
import { ScrollReveal } from "@/components/animation/ScrollReveal";
import { HEADER_SHELL_LAYOUT } from "@/lib/header-shell-layout";
import { HeroCanvasBackground } from "@/components/effects/HeroCanvasBackground";
import { formaShellCtaVariants } from "@/components/ui/forma-shell-cta";
import { cn } from "@/lib/utils";
const FAQSection = dynamic(() => import("@/components/sections/FAQSection"));
const FormaBeforeAfter = dynamic(() => import("@/components/sections/FormaBeforeAfter"));
const UseCasesBento = dynamic(() => import("@/components/sections/UseCasesBento"));
const IllustratedStorySection = dynamic(() => import("@/components/sections/IllustratedStorySection"));
const IllustratedTrustSection = dynamic(() => import("@/components/sections/IllustratedTrustSection"));
import FormaHeroWindow from "@/components/sections/FormaHeroWindow";
import HeroEntrance from "@/components/animation/HeroEntrance";
import { MonoLabel } from "@/components/ui/MonoLabel";
import { DraftedPlate } from "@/components/ui/DraftedPlate";
import {
  FolderFigure,
  RuleCardFigure,
  PreviewQueueFigure,
  UndoStackFigure,
} from "@/components/illustrations/AxonometricFigures";
import { formatFolioRevision } from "@/lib/folio";
import { faqs } from "@/lib/faq";
import { SITE_NAME, SITE_URL, SUPPORT_EMAIL, WEBSITE_LAST_UPDATED_ISO } from "@/lib/site";

/* ═══════════════════════════════════════════════════════════════════════════
   CONTENT DATA
   ═══════════════════════════════════════════════════════════════════════════ */

const workflowSteps = [
  {
    number: "§ 01",
    label: "WRITE\u00b7RULE",
    title: "Describe the rule.",
    body: "\u2018PDFs with invoice in the name go to Finances.\u2019 That\u2019s a real rule. No twelve-tab settings panel.",
    Glyph: RuleCardFigure,
  },
  {
    number: "§ 02",
    label: "LOCAL\u00b7PREVIEW",
    title: "Preview the batch.",
    body: "See every file that matched, where it\u2019s going, and why. Uncheck anything that shouldn\u2019t move. Nothing happens until you say so.",
    Glyph: PreviewQueueFigure,
  },
  {
    number: "§ 03",
    label: "UNDO\u00b7BUILT\u00b7IN",
    title: "Undo the batch.",
    body: "If something was wrong, reverse the recent batch in Forma without moving everything back by hand.",
    Glyph: UndoStackFigure,
  },
] as const;

const closingChecklist = [
  "Start with one folder, not your whole Mac.",
  "Write one plain-language rule.",
  "Review the batch, then approve only what belongs.",
] as const;


/* ═══════════════════════════════════════════════════════════════════════════
   PAGE
   ═══════════════════════════════════════════════════════════════════════════ */

export default function Home() {
  const jsonLdGraph = [
    {
      "@context": "https://schema.org",
      "@type": "SoftwareApplication",
      name: SITE_NAME,
      applicationCategory: "ProductivityApplication",
      operatingSystem: "macOS 15+",
      offers: {
        "@type": "Offer",
        price: "29",
        priceCurrency: "USD",
        description: "One-time purchase. No subscription.",
        url: `${SITE_URL}/#pricing`,
      },
      description:
        "A file organizer for people who gave up on file organizers. Write rules in plain English, preview every move, and undo recent batches when something was wrong. Built for ADHD brains and anyone overwhelmed by file clutter. $29 for Mac.",
      featureList: [
        "Plain-language rules",
        "Preview every move before approval",
        "Recent batch undo",
        "Local-only privacy",
      ],
      url: SITE_URL,
    },
    {
      "@context": "https://schema.org",
      "@type": "Organization",
      name: SITE_NAME,
      url: SITE_URL,
      sameAs: [],
    },
    {
      "@context": "https://schema.org",
      "@type": "WebSite",
      name: SITE_NAME,
      url: SITE_URL,
      inLanguage: "en-US",
      dateModified: WEBSITE_LAST_UPDATED_ISO,
    },
    {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      mainEntity: faqs.map((faqEntry) => ({
        "@type": "Question",
        name: faqEntry.question,
        acceptedAnswer: {
          "@type": "Answer",
          text: faqEntry.answer,
        },
      })),
    },
  ];

  const jsonLdString = JSON.stringify({ "@context": "https://schema.org", "@graph": jsonLdGraph }).replace(/<\//g, "<\\/");

  const folioRev = formatFolioRevision(WEBSITE_LAST_UPDATED_ISO);

  return (
    <>
      {/* Structured data — generated from trusted site constants, safe to inline */}
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: jsonLdString }} />

      <main id="main-content" className="relative overflow-hidden w-full h-full">
        
        {/* ─── HERO ─────────────────────────────────────────────────────── */}
        <section
          id="top"
          data-hero-layout={HEADER_SHELL_LAYOUT.heroLayout}
          data-hero-clearance={HEADER_SHELL_LAYOUT.heroClearanceContract}
          className="relative overflow-hidden border-b border-[var(--rule-faint)]"
        >
          <HeroCanvasBackground />

          {/* Drafting folio bar */}
          <div className="relative z-10 border-b border-[var(--rule-draft-faint)] bg-[rgba(255,253,248,0.66)] backdrop-blur-[2px]">
            <div className="site-container flex items-center justify-between py-2.5">
              <MonoLabel variant="dim">Forma · Homepage · Hero</MonoLabel>
              <MonoLabel variant="dim" className="text-right">
                Sheet&nbsp;01 / 07 · Scale&nbsp;1:1 · Rev&nbsp;{folioRev}
              </MonoLabel>
            </div>
          </div>

          <HeroEntrance
            className={`site-container relative z-10 ${HEADER_SHELL_LAYOUT.heroClearanceClassName}`}
          >
            <div className="grid items-center gap-10 lg:grid-cols-[5fr_6fr] lg:items-center lg:gap-14">
              {/* Left: copy */}
              <div className="min-w-0">
                <MonoLabel
                  variant="fig"
                  className="mb-3 flex items-center gap-2.5 before:block before:h-px before:w-7 before:bg-[var(--ink-draft)]"
                >
                  FIG.&nbsp;01 · WHAT FORMA IS
                </MonoLabel>
                <p data-hero="eyebrow" className="eyebrow">
                  For the perpetually messy
                </p>
                <h1 data-hero="headline" className="display-xl mt-6 text-[var(--ink-primary)]">
                  A file organizer for people who gave up on file organizers.
                </h1>
                <p data-hero="subtext" className="prose-editorial mt-6 max-w-[48ch]">
                  Your files are already out of control. Tell Forma where they should go &mdash; in plain English, not regex.
                  Preview the batch. Undo the recent batch if something was wrong.
                </p>

                <div data-hero="cta" className="mt-10">
                  <TrackedAppStoreLink
                    location="hero_primary"
                    className={cn(
                      formaShellCtaVariants({ variant: "primary" }),
                      "h-12 px-6 text-[15px]"
                    )}
                  >
                    Get Forma for Mac
                  </TrackedAppStoreLink>
                  <p className="mt-3 text-[13px] text-[var(--ink-faint)]">
                    $29 once. No subscription. No account. Just a Mac app.
                  </p>
                </div>
              </div>

              {/* Right: live app replica inside a drafting plate */}
              <div data-hero="window" className="relative min-w-0">
                <DraftedPlate
                  fig="FIG. 02 — PREVIEW QUEUE · STAGED, NOT EXECUTED"
                  dimensionTop="— max 1200 —"
                  dimensionSide="§ 01"
                  innerClassName="p-3 md:p-4"
                  className="bg-transparent"
                >
                  <FormaHeroWindow />
                </DraftedPlate>
                <FolderFigure
                  aria-hidden
                  className="pointer-events-none absolute -bottom-6 -left-6 h-[72px] w-[90px]"
                />
              </div>
            </div>

            {/* Bottom drafting footer */}
            <div className="mt-12 border-t border-[var(--rule-draft-faint)] pt-3">
              <div className="flex flex-wrap items-center justify-between gap-4">
                <MonoLabel variant="dim">§ 01 · Plain-language rules</MonoLabel>
                <MonoLabel variant="dim">§ 02 · Preview first · § 03 · Undo batch</MonoLabel>
                <MonoLabel variant="dim">Forma · Mac App Store</MonoLabel>
              </div>
            </div>
          </HeroEntrance>
        </section>

        {/* ─── ILLUSTRATED STORY ───────────────────────────────────────── */}
        <IllustratedStorySection />

        {/* ─── HOW FORMA WORKS (3 steps) ────────────────────────────────── */}
        <section
          id="how-it-works"
          aria-labelledby="how-it-works-heading"
          className="relative z-10 scroll-mt-16 border-b border-[var(--rule-faint)] py-24 md:py-32"
        >
          <div className="mx-auto w-full max-w-[1200px] px-6">
            <div className="md:grid md:grid-cols-[1fr_2fr] md:gap-18 md:items-start">
              {/* Left: section intro */}
              <div className="mb-12 md:mb-0 md:sticky md:top-28 md:border-r md:border-[var(--rule-draft-faint)] md:pr-10">
                <p className="eyebrow">How Forma works</p>
                <h2 id="how-it-works-heading" className="display-lg mt-5 text-[var(--ink-primary)]">
                  Three steps. No manual.
                </h2>
              </div>

              {/* Right: steps */}
              <ScrollReveal direction="up" distance={24} stagger={0.1} className="grid gap-10 md:gap-12">
                {workflowSteps.map((step) => (
                  <div
                    key={step.number}
                    className="grid grid-cols-[1fr_96px] items-start gap-6 border-t border-[var(--rule-draft-faint)] pt-8 first:border-t-0 first:pt-0"
                  >
                    <div>
                      <div className="flex items-baseline gap-3">
                        <MonoLabel variant="section" className="text-[1.25rem] tracking-[0.08em]">
                          {step.number}
                        </MonoLabel>
                        <p className="text-[12px] font-semibold uppercase tracking-[0.12em] text-[var(--ink-draft)]">
                          {step.label}
                        </p>
                      </div>
                      <h3 className="mt-5 font-display text-[1.375rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)] md:text-[1.65rem]">
                        {step.title}
                      </h3>
                      <p className="mt-3 max-w-[34rem] text-[15px] leading-relaxed text-[var(--ink-secondary)] md:text-[1.03rem]">
                        {step.body}
                      </p>
                    </div>
                    <step.Glyph className="mt-2 hidden h-20 w-24 md:block" />
                  </div>
                ))}
              </ScrollReveal>
            </div>
          </div>
        </section>

        {/* ─── BEFORE & AFTER ───────────────────────────────────────────── */}
        <section aria-labelledby="before-after-heading" className="relative z-10 border-y border-[var(--rule-faint)] bg-[var(--canvas-bone)] py-24 md:py-32">
          <div className="mx-auto w-full max-w-[1200px] px-6">
            <ScrollReveal direction="up" distance={24}>
              <div className="max-w-2xl">
                <MonoLabel
                  variant="fig"
                  className="mb-3 flex items-center gap-2.5 before:block before:h-px before:w-7 before:bg-[var(--ink-draft)]"
                >
                  FIG.&nbsp;04 · BEFORE &amp; AFTER
                </MonoLabel>
                <p className="eyebrow">Before and after</p>
                <h2 id="before-after-heading" className="display-lg mt-5 text-[var(--ink-primary)]">
                  One rule. Hundreds of files. Zero guilt.
                </h2>
                <p className="prose-editorial mt-5">
                  That folder you&apos;ve been meaning to clean since 2023? One rule handles it.
                </p>
              </div>
            </ScrollReveal>

            <ScrollReveal direction="up" distance={30} className="mt-12">
              <DraftedPlate
                dimensionTop="— 840 files → 4 folders —"
                innerClassName="p-3 md:p-4"
                className="bg-transparent"
              >
                <FormaBeforeAfter />
              </DraftedPlate>
            </ScrollReveal>
          </div>
        </section>

        {/* ─── USE CASES (bento cards + trust signals) ──────────────────── */}
        <UseCasesBento />

        {/* ─── ILLUSTRATED TRUST ──────────────────────────────────────── */}
        <IllustratedTrustSection />

        {/* ─── PRICING (split card) ─────────────────────────────────────── */}
        <section
          id="pricing"
          aria-labelledby="pricing-heading"
          className="scroll-mt-16 border-y border-[var(--rule-faint)] py-24 md:py-32"
        >
          <ScrollReveal direction="up" distance={30} className="mx-auto w-full max-w-[1200px] px-6">
            <div className="relative">
              {/* Corner ticks (pricing plate) */}
              <span aria-hidden="true" className="pointer-events-none absolute -top-px -left-px z-10 h-[1.5px] w-4 bg-[rgba(255,252,248,0.55)]" />
              <span aria-hidden="true" className="pointer-events-none absolute -top-px -left-px z-10 h-4 w-[1.5px] bg-[rgba(255,252,248,0.55)]" />
              <span aria-hidden="true" className="pointer-events-none absolute -top-px -right-px z-10 h-[1.5px] w-4 bg-[rgba(255,252,248,0.55)]" />
              <span aria-hidden="true" className="pointer-events-none absolute -top-px -right-px z-10 h-4 w-[1.5px] bg-[rgba(255,252,248,0.55)]" />
              <span aria-hidden="true" className="pointer-events-none absolute -bottom-px -left-px z-10 h-[1.5px] w-4 bg-[rgba(255,252,248,0.55)]" />
              <span aria-hidden="true" className="pointer-events-none absolute -bottom-px -left-px z-10 h-4 w-[1.5px] bg-[rgba(255,252,248,0.55)]" />
              <span aria-hidden="true" className="pointer-events-none absolute -bottom-px -right-px z-10 h-[1.5px] w-4 bg-[rgba(255,252,248,0.55)]" />
              <span aria-hidden="true" className="pointer-events-none absolute -bottom-px -right-px z-10 h-4 w-[1.5px] bg-[rgba(255,252,248,0.55)]" />

            <div
              className="anchor-dark overflow-hidden rounded-[1.8rem] border border-[rgba(255,255,255,0.06)] shadow-[0_40px_80px_rgba(60,48,24,0.14)]"
              style={{
                background:
                  "radial-gradient(120% 80% at 85% 10%, rgba(201, 126, 102, 0.16) 0%, rgba(201, 126, 102, 0) 55%), radial-gradient(100% 70% at 10% 90%, rgba(91, 124, 153, 0.08) 0%, rgba(91, 124, 153, 0) 50%), linear-gradient(180deg, #1F1A14 0%, #1A1611 100%)",
              }}
            >
              <div className="grid md:grid-cols-2">
                {/* Left: headline */}
                <div className="flex flex-col justify-center p-8 md:p-10 lg:p-14">
                  <MonoLabel
                    variant="fig"
                    className="mb-3 flex items-center gap-2.5 text-[rgba(255,252,248,0.64)] before:block before:h-px before:w-7 before:bg-[rgba(255,252,248,0.48)]"
                  >
                    FIG.&nbsp;07 · PRICING PLATE
                  </MonoLabel>
                  <p className="eyebrow">Pricing</p>
                  <h2 id="pricing-heading" className="display-lg mt-5 text-[var(--ink-primary)]">
                    One price. You own it.
                  </h2>
                  <p className="prose-editorial mt-5 max-w-md">
                    No account. No cloud. No &ldquo;Pro tier&rdquo; that unlocks the features you actually need. A Mac app. Yours.
                  </p>
                </div>

                {/* Right: price + features + CTA */}
                <div className="border-t border-[var(--rule-faint)] p-8 md:border-l md:border-t-0 md:p-10 lg:p-14">
                  <p className="font-display text-[3.5rem] font-medium tracking-[-0.02em] text-[var(--ink-primary)] md:text-[4.5rem] md:leading-none">
                    $29
                  </p>
                  <p className="mt-1 text-[13px] font-medium tracking-[0.12em] uppercase text-[var(--ink-faint)]">
                    One-time purchase
                  </p>

                  <ul className="mt-8 space-y-3.5">
                    {[
                      "Preview every move before it runs",
                      "Pay once, keep it forever",
                      "Runs locally on your Mac. macOS 15+",
                    ].map((item) => (
                      <li key={item} className="flex items-start gap-3">
                        <span className="mt-[7px] h-1.5 w-1.5 shrink-0 rounded-full bg-forma-steel-blue" aria-hidden="true" />
                        <span className="text-[15px] leading-relaxed text-[var(--ink-secondary)]">
                          {item}
                        </span>
                      </li>
                    ))}
                  </ul>

                  <div className="mt-10">
                    <TrackedAppStoreLink
                      location="pricing_primary"
                      className={cn(
                        formaShellCtaVariants({ variant: "primary" }),
                        "h-12 w-full px-6 text-[15px]"
                      )}
                    >
                      Get Forma for Mac
                    </TrackedAppStoreLink>
                  </div>
                </div>
              </div>
            </div>
            </div>
          </ScrollReveal>
        </section>

        {/* ─── FAQ ──────────────────────────────────────────────────────── */}
        <FAQSection />

        {/* ─── FINAL CTA ────────────────────────────────────────────────── */}
        <section
          aria-labelledby="closing-heading"
          className="border-t border-[var(--rule-faint)] bg-[var(--canvas-bone)] py-20 md:py-24"
        >
          <div className="mx-auto w-full max-w-[1200px] px-6">
            <div
              className="anchor-dark overflow-hidden rounded-[2rem] border border-[rgba(255,255,255,0.08)] shadow-[0_32px_72px_rgba(36,24,14,0.18)]"
              style={{
                background:
                  "radial-gradient(110% 90% at 85% 15%, rgba(201, 126, 102, 0.14) 0%, rgba(201, 126, 102, 0) 52%), radial-gradient(90% 70% at 10% 90%, rgba(91, 124, 153, 0.1) 0%, rgba(91, 124, 153, 0) 48%), linear-gradient(180deg, #1E1A16 0%, #16120E 100%)",
              }}
            >
              <div className="grid gap-10 p-8 md:p-10 lg:grid-cols-[1.1fr,0.9fr] lg:p-14">
                <div>
                  <p className="eyebrow">Start with one folder</p>
                  <h2 id="closing-heading" className="display-lg mt-5 text-[var(--ink-primary)]">
                    Give the messiest folder one clean pass.
                  </h2>
                  <p className="prose-editorial mt-5 max-w-[34rem]">
                    You do not need a whole system overhaul to know whether Forma is useful.
                    Start with the folder you keep avoiding, review the batch, and keep what works.
                  </p>

                  <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                    <TrackedAppStoreLink
                      location="homepage_final_primary"
                      className={cn(
                        formaShellCtaVariants({ variant: "primary" }),
                        "h-12 px-6 text-[15px]"
                      )}
                    >
                      Get Forma for Mac
                    </TrackedAppStoreLink>
                    <Link
                      href="/blog"
                      className={cn(
                        formaShellCtaVariants({ variant: "secondary" }),
                        "h-12 px-6 text-[15px]"
                      )}
                    >
                      Read the preview-first guides
                    </Link>
                  </div>
                </div>

                <div className="rounded-[1.5rem] border border-[rgba(255,255,255,0.08)] bg-[rgba(255,255,255,0.03)] p-6 shadow-[var(--shell-shadow-soft)]">
                  <p className="eyebrow">What happens next</p>
                  <ol className="mt-5 space-y-4">
                    {closingChecklist.map((item, index) => (
                      <li key={item} className="flex items-start gap-4">
                        <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-[rgba(255,255,255,0.12)] bg-[rgba(255,255,255,0.04)] text-[13px] font-semibold text-[var(--ink-primary)] tabular-nums">
                          {index + 1}
                        </span>
                        <span className="pt-1 text-[15px] leading-relaxed text-[var(--ink-secondary)]">
                          {item}
                        </span>
                      </li>
                    ))}
                  </ol>
                  <p className="mt-6 text-[14px] leading-relaxed text-[var(--ink-faint)]">
                    Want to ask before buying?{" "}
                    <TrackedMailtoLink
                      email={SUPPORT_EMAIL}
                      location="homepage_final_cta"
                      className="font-medium text-forma-steel-blue underline underline-offset-4 decoration-forma-steel-blue/30 transition-[text-decoration-color,color] duration-200 hover:decoration-forma-steel-blue/60"
                    >
                      {SUPPORT_EMAIL}
                    </TrackedMailtoLink>
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>
    </>
  );
}
