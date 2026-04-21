import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";
import dynamic from "next/dynamic";
import { ScrollReveal } from "@/components/animation/ScrollReveal";
import { HEADER_SHELL_LAYOUT } from "@/lib/header-shell-layout";
import { HeroCanvasBackground } from "@/components/effects/HeroCanvasBackground";
import { formaShellCtaVariants } from "@/components/ui/forma-shell-cta";
import { cn } from "@/lib/utils";
const FAQSection = dynamic(() => import("@/components/sections/FAQSection"));
const FormaBeforeAfter = dynamic(() => import("@/components/sections/FormaBeforeAfter"));
const UseCasesBento = dynamic(() => import("@/components/sections/UseCasesBento"));
const FeaturesBento = dynamic(() => import("@/components/sections/FeaturesBento"));
import FormaHeroWindow from "@/components/sections/FormaHeroWindow";
import HeroEntrance from "@/components/animation/HeroEntrance";
import { faqs } from "@/lib/faq";
import { SITE_NAME, SITE_URL, WEBSITE_LAST_UPDATED_ISO } from "@/lib/site";

/* ═══════════════════════════════════════════════════════════════════════════
   CONTENT DATA
   ═══════════════════════════════════════════════════════════════════════════ */

const workflowSteps = [
  {
    number: "1",
    label: "WRITE\u00b7RULE",
    title: "Describe the rule.",
    body: "\u2018PDFs with invoice in the name go to Finances.\u2019 That\u2019s a real rule. No twelve-tab settings panel.",
  },
  {
    number: "2",
    label: "LOCAL\u00b7PREVIEW",
    title: "Preview the batch.",
    body: "See every file that matched, where it\u2019s going, and why. Uncheck anything that shouldn\u2019t move. Nothing happens until you say so.",
  },
  {
    number: "3",
    label: "UNDO\u00b7BUILT\u00b7IN",
    title: "Undo the batch.",
    body: "If something was wrong, reverse the recent batch in Forma without moving everything back by hand.",
  },
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

          <HeroEntrance
            className={`site-container relative z-10 ${HEADER_SHELL_LAYOUT.heroClearanceClassName}`}
          >
            <div className="grid items-center gap-10 lg:grid-cols-[3fr_4fr] lg:items-center lg:gap-14">
              {/* Left: copy */}
              <div className="min-w-0">
                <p data-hero="eyebrow" className="eyebrow">
                  For the perpetually messy
                </p>
                <h1 data-hero="headline" className="display-xl mt-6 text-[var(--ink-primary)]">
                  A file organizer for people who gave up on file organizers.
                </h1>
                <p data-hero="subtext" className="prose-editorial mt-6">
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

              {/* Right: live app replica */}
              <div data-hero="window" className="relative min-w-0">
                <FormaHeroWindow />
              </div>
            </div>
          </HeroEntrance>
        </section>

        {/* ─── FEATURE HIGHLIGHTS (bento cards) ────────────────────────── */}
        <FeaturesBento />

        {/* ─── HOW FORMA WORKS (3 steps) ────────────────────────────────── */}
        <section
          id="how-it-works"
          aria-labelledby="how-it-works-heading"
          className="relative z-10 scroll-mt-16 border-b border-[var(--rule-faint)] py-24 md:py-32"
        >
          <div className="mx-auto w-full max-w-[1200px] px-6">
            <div className="md:grid md:grid-cols-[1fr_2fr] md:gap-18 md:items-start">
              {/* Left: section intro */}
              <div className="mb-12 md:mb-0 md:sticky md:top-28">
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
                    className="border-t border-[var(--rule-faint)] pt-8 first:border-t-0 first:pt-0"
                  >
                    <div className="flex items-baseline gap-3">
                      <span
                        aria-hidden="true"
                        className="text-[4rem] font-bold leading-none tracking-[-0.04em] text-[var(--ink-faint)] sm:text-[4.5rem] md:text-[5.5rem]"
                      >
                        {step.number}
                      </span>
                      <p className="text-[12px] font-semibold uppercase tracking-[0.12em] text-[var(--forma-steel-blue)]">
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
              <FormaBeforeAfter />
            </ScrollReveal>
          </div>
        </section>

        {/* ─── USE CASES (bento cards + trust signals) ──────────────────── */}
        <UseCasesBento />

        {/* ─── PRICING (split card) ─────────────────────────────────────── */}
        <section
          id="pricing"
          aria-labelledby="pricing-heading"
          className="scroll-mt-16 border-y border-[var(--rule-faint)] py-24 md:py-32"
        >
          <ScrollReveal direction="up" distance={30} className="mx-auto w-full max-w-[1200px] px-6">
            <div className="anchor-dark overflow-hidden rounded-[1.8rem] border border-[var(--rule-faint)] bg-[var(--canvas-paper)] shadow-[0_40px_80px_rgba(60,48,24,0.14)]">
              <div className="grid md:grid-cols-2">
                {/* Left: headline */}
                <div className="flex flex-col justify-center p-8 md:p-10 lg:p-14">
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
                      className="btn-forma-primary w-full px-7 py-4 text-[15px]"
                    >
                      Get Forma &mdash; $29
                    </TrackedAppStoreLink>
                  </div>
                </div>
              </div>
            </div>
          </ScrollReveal>
        </section>

        {/* ─── FAQ ──────────────────────────────────────────────────────── */}
        <FAQSection />
      </main>
    </>
  );
}
