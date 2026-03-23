import type { ReactNode } from "react";
import { Eye, GitBranch, Type, Undo2, Camera, FileText, FolderOpen, Shield, RotateCcw, Scan } from "lucide-react";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";
import { ScrollReveal } from "@/components/animation/ScrollReveal";
import FAQSection from "@/components/sections/FAQSection";
import FormaBeforeAfter from "@/components/sections/FormaBeforeAfter";
import FormaHeroWindow from "@/components/sections/FormaHeroWindow";
import HeroEntrance from "@/components/animation/HeroEntrance";
import { faqs } from "@/lib/faq";
import { SITE_NAME, SITE_URL, WEBSITE_LAST_UPDATED_ISO } from "@/lib/site";

/* ═══════════════════════════════════════════════════════════════════════════
   CONTENT DATA
   ═══════════════════════════════════════════════════════════════════════════ */

const featureHighlights = [
  {
    icon: Type,
    title: "Natural language rules",
    body: "Write conditions and destinations in plain English. No regex, no scripts.",
    color: "text-forma-steel-blue",
    bgTint: "bg-[rgba(74,107,136,0.14)]",
    borderTint: "border-[rgba(74,107,136,0.22)]",
  },
  {
    icon: GitBranch,
    title: "Auto-grouping",
    body: "One rule handles 200 similar files instead of writing 200 rules.",
    color: "text-forma-muted-blue",
    bgTint: "bg-[rgba(107,127,168,0.14)]",
    borderTint: "border-[rgba(107,127,168,0.22)]",
  },
  {
    icon: Eye,
    title: "Preview before action",
    body: "See exactly what will happen before it happens. Toggle files on or off.",
    color: "text-forma-sage",
    bgTint: "bg-[rgba(107,143,113,0.14)]",
    borderTint: "border-[rgba(107,143,113,0.22)]",
  },
  {
    icon: Undo2,
    title: "Full undo history",
    body: "Reverse any move, any time. Every action is tracked and reversible.",
    color: "text-forma-warm-orange",
    bgTint: "bg-[rgba(184,107,82,0.14)]",
    borderTint: "border-[rgba(184,107,82,0.22)]",
  },
] as const;

const workflowSteps = [
  {
    number: "1",
    label: "WRITE\u00b7RULE",
    title: "Write the rule.",
    body: "Set a plain English condition and a destination. Forma turns it into a repeatable rule instead of another fiddly settings panel.",
  },
  {
    number: "2",
    label: "LOCAL\u00b7PREVIEW",
    title: "Local preview.",
    body: "Review every change before it happens. Keep files in, leave files out. The batch earns trust by showing its work first.",
  },
  {
    number: "3",
    label: "UNDO\u00b7BUILT\u00b7IN",
    title: "Undo any batch.",
    body: "Reverse any move from history. Forma keeps the path back close, in case it\u2019s wrong.",
  },
] as const;

const useCases = [
  {
    icon: Camera,
    title: "Screenshots and exports",
    body: "Turn recurring desktop noise into one maintained rule instead of one more weekly cleanup ritual.",
    color: "text-forma-warm-orange",
    bgTint: "bg-[rgba(184,107,82,0.14)]",
    borderTint: "border-[rgba(184,107,82,0.22)]",
  },
  {
    icon: FileText,
    title: "PDFs and paperwork",
    body: "Use rules that stay legible when you revisit them in three months.",
    color: "text-forma-steel-blue",
    bgTint: "bg-[rgba(74,107,136,0.14)]",
    borderTint: "border-[rgba(74,107,136,0.22)]",
  },
  {
    icon: FolderOpen,
    title: "Project overflow",
    body: "Keep work-in-progress files moving without surrendering control to a black box.",
    color: "text-forma-muted-blue",
    bgTint: "bg-[rgba(107,127,168,0.14)]",
    borderTint: "border-[rgba(107,127,168,0.22)]",
  },
  {
    icon: Scan,
    title: "Preview-first",
    body: "Nothing moves until you approve the batch. The product earns trust by showing its work before it touches anything.",
    color: "text-forma-sage",
    bgTint: "bg-[rgba(107,143,113,0.14)]",
    borderTint: "border-[rgba(107,143,113,0.22)]",
  },
  {
    icon: Shield,
    title: "Local-only privacy",
    body: "Files stay on your Mac. No account required. No cloud dependency.",
    color: "text-forma-steel-blue",
    bgTint: "bg-[rgba(74,107,136,0.14)]",
    borderTint: "border-[rgba(74,107,136,0.22)]",
  },
  {
    icon: RotateCcw,
    title: "Undo system",
    body: "Reverse a bad batch without cleanup archaeology. The workflow assumes you may want to reverse it later.",
    color: "text-forma-warm-orange",
    bgTint: "bg-[rgba(184,107,82,0.14)]",
    borderTint: "border-[rgba(184,107,82,0.22)]",
  },
] as const;

/* ═══════════════════════════════════════════════════════════════════════════
   SECTION COMPONENTS
   ═══════════════════════════════════════════════════════════════════════════ */

function SectionEyebrow({ children }: { children: ReactNode }) {
  return (
    <p className="text-[12px] font-semibold uppercase tracking-[0.12em] text-forma-steel-blue">
      {children}
    </p>
  );
}

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
        "A file organizer for people who gave up on file organizers. Write rules in plain language, preview every move, and undo anytime.",
      featureList: [
        "Plain-language rules",
        "Preview every move before approval",
        "Full undo history",
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

      <main id="main-content" className="relative overflow-hidden">
        {/* ─── HERO ─────────────────────────────────────────────────────── */}
        <section
          id="top"
          className="relative overflow-hidden border-b border-[var(--border-subtle)] bg-[var(--bg-primary)]"
        >
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,var(--gradient-accent-blue),transparent_42%),radial-gradient(circle_at_top_right,var(--gradient-accent-green),transparent_38%)]" />

          <HeroEntrance className="site-container relative py-12 md:py-16 lg:py-24">
            <div className="grid items-center gap-10 lg:grid-cols-[3fr_4fr] lg:items-center lg:gap-14">
              {/* Left: copy */}
              <div>
                <div data-hero="eyebrow">
                  <SectionEyebrow>Forma &mdash; Preview-first organization</SectionEyebrow>
                </div>
                <h1 data-hero="headline" className="mt-6 text-[1.75rem] font-bold leading-[1.08] tracking-[-0.035em] text-[var(--text-primary)] text-balance sm:text-[2.5rem] md:text-[3rem] lg:text-[3.5rem]">
                  A file organizer for people who gave up on file organizers.
                </h1>
                <p data-hero="subtext" className="mt-6 max-w-lg text-base leading-relaxed text-[var(--text-secondary)] md:text-[1.125rem]">
                  Write rules in plain English. Review every move before it happens. Undo
                  the whole batch if it&apos;s wrong.
                </p>

                <div data-hero="cta" className="mt-8">
                  <TrackedAppStoreLink
                    location="hero_primary"
                    className="inline-flex items-center justify-center rounded-xl bg-gradient-to-br from-[#944A35] to-[#A86048] px-7 py-3.5 text-[15px] font-semibold text-white shadow-[0_4px_16px_rgba(148,74,53,0.35)] transition-[transform,box-shadow,filter] duration-200 ease-out will-change-transform hover:-translate-y-0.5 hover:shadow-[0_6px_20px_rgba(148,74,53,0.45)] hover:brightness-110 active:scale-[0.97]"
                  >
                    Download for Mac
                  </TrackedAppStoreLink>
                  <p className="mt-3 text-[13px] text-[var(--text-muted)]">
                    $29 once. macOS 15+. No subscription.
                  </p>
                </div>
              </div>

              {/* Right: live app replica */}
              <div data-hero="window" className="relative">
                <FormaHeroWindow />
              </div>
            </div>
          </HeroEntrance>
        </section>

        {/* ─── FEATURE HIGHLIGHTS STRIP ─────────────────────────────────── */}
        <section aria-labelledby="features-heading" className="border-b border-[var(--border-subtle)] bg-[var(--bg-primary)] py-20 md:py-28">
          <div className="site-container">
            <div className="text-center">
              <SectionEyebrow>The logic of craftsmanship</SectionEyebrow>
              <h2 id="features-heading" className="mx-auto mt-5 max-w-2xl text-[1.875rem] font-semibold leading-[1.15] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem] md:leading-[1.1]">
                Automation without blind trust.
              </h2>
              <p className="mx-auto mt-5 max-w-xl text-base leading-relaxed text-[var(--text-secondary)] md:text-[1.125rem]">
                Plain language rules, preview-first logic, and full undo history.
              </p>
            </div>

            <ScrollReveal direction="up" distance={30} stagger={0.08} className="mx-auto mt-14 grid max-w-4xl gap-10 sm:grid-cols-2 lg:grid-cols-4">
              {featureHighlights.map((feature) => {
                const Icon = feature.icon;
                return (
                  <div key={feature.title} className="text-center">
                    <div className={`mx-auto flex h-14 w-14 items-center justify-center rounded-2xl border ${feature.borderTint} ${feature.bgTint}`}>
                      <Icon className={`h-7 w-7 ${feature.color}`} strokeWidth={1.5} />
                    </div>
                    <p className="mt-4 text-[15px] font-medium text-[var(--text-primary)]">
                      {feature.title}
                    </p>
                    <p className="mt-2 text-[15px] leading-relaxed text-[var(--text-secondary)]">
                      {feature.body}
                    </p>
                  </div>
                );
              })}
            </ScrollReveal>
          </div>
        </section>

        {/* ─── HOW FORMA WORKS (3 steps) ────────────────────────────────── */}
        <section id="how-it-works" aria-labelledby="how-it-works-heading" className="scroll-mt-16 bg-[var(--bg-primary)] py-20 md:py-28" style={{ backgroundImage: "linear-gradient(180deg, var(--bg-primary), rgba(74, 107, 136, 0.04), rgba(74, 107, 136, 0.06), rgba(74, 107, 136, 0.04), var(--bg-primary))" }}>
          <div className="site-container">
            <div className="mx-auto max-w-5xl md:grid md:grid-cols-[1fr_2fr] md:gap-16 md:items-start">
              {/* Left: section intro */}
              <div className="mb-10 md:mb-0 md:sticky md:top-24">
                <SectionEyebrow>How Forma works</SectionEyebrow>
                <h2 id="how-it-works-heading" className="mt-5 text-[1.875rem] font-semibold leading-[1.15] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem] md:leading-[1.1]">
                  Three steps. No learning curve.
                </h2>
              </div>

              {/* Right: steps */}
              <ScrollReveal direction="up" distance={24} stagger={0.1} className="grid gap-10 md:gap-12">
                {workflowSteps.map((step) => (
                  <div key={step.number} className="text-left">
                    <div className="flex items-baseline gap-3">
                      <span aria-hidden="true" className="text-[4rem] font-bold leading-none tracking-[-0.04em] text-forma-steel-blue/60 sm:text-[4.5rem] md:text-[5.5rem]">
                        {step.number}
                      </span>
                      <p className="text-[12px] font-semibold uppercase tracking-[0.12em] text-forma-steel-blue">
                        {step.label}
                      </p>
                    </div>
                    <h3 className="mt-4 text-xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
                      {step.title}
                    </h3>
                    <p className="mt-3 text-[15px] leading-relaxed text-[var(--text-secondary)]">
                      {step.body}
                    </p>
                  </div>
                ))}
              </ScrollReveal>
            </div>
          </div>
        </section>

        {/* ─── BEFORE & AFTER ───────────────────────────────────────────── */}
        <section aria-labelledby="before-after-heading" className="border-y border-[var(--border-subtle)] bg-[var(--bg-secondary)] py-20 md:py-28">
          <div className="site-container">
            <ScrollReveal direction="up" distance={24} className="mx-auto max-w-4xl">
              <div>
                <SectionEyebrow>Before and after</SectionEyebrow>
                <h2 id="before-after-heading" className="mt-5 max-w-xl text-[1.875rem] font-semibold leading-[1.15] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem] md:leading-[1.1]">
                  One rule. Hundreds of files.
                </h2>
                <p className="mt-5 max-w-lg text-base leading-relaxed text-[var(--text-secondary)] md:text-[1.125rem]">
                  Forma turns recurring clutter into one maintainable rule.
                </p>
              </div>
            </ScrollReveal>

            <ScrollReveal direction="up" distance={30} delay={150} className="mx-auto mt-12 max-w-4xl">
              <div>
                <FormaBeforeAfter />
              </div>
            </ScrollReveal>
          </div>
        </section>

        {/* ─── USE CASES (2x3 grid) ─────────────────────────────────────── */}
        <section aria-labelledby="use-cases-heading" className="bg-[var(--bg-primary)] py-20 md:py-28" style={{ backgroundImage: "radial-gradient(circle, rgba(107, 143, 113, 0.08) 1px, transparent 1px)", backgroundSize: "24px 24px" }}>
          <div className="site-container">
            <div className="text-center">
              <SectionEyebrow>How you&apos;ll use it</SectionEyebrow>
              <h2 id="use-cases-heading" className="mx-auto mt-5 max-w-2xl text-[1.875rem] font-semibold leading-[1.15] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem] md:leading-[1.1]">
                Built for recurring clutter.
              </h2>
              <p className="mx-auto mt-5 max-w-lg text-base leading-relaxed text-[var(--text-secondary)] md:text-[1.125rem]">
                Start with one rule, one folder, and one visible payoff.
              </p>
            </div>

            <ScrollReveal direction="up" distance={24} stagger={0.06} className="mx-auto mt-14 grid max-w-5xl gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {useCases.map((useCase) => {
                const Icon = useCase.icon;
                return (
                  <article
                    key={useCase.title}
                    className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-7 transition-shadow duration-300 hover:shadow-[0_4px_20px_rgba(0,0,0,0.06)]"
                  >
                    <div className={`flex h-12 w-12 items-center justify-center rounded-xl border ${useCase.borderTint} ${useCase.bgTint}`}>
                      <Icon className={`h-6 w-6 ${useCase.color}`} strokeWidth={1.5} />
                    </div>
                    <h3 className="mt-5 text-[15px] font-medium text-[var(--text-primary)]">
                      {useCase.title}
                    </h3>
                    <p className="mt-2 text-[15px] leading-relaxed text-[var(--text-secondary)]">
                      {useCase.body}
                    </p>
                  </article>
                );
              })}
            </ScrollReveal>
          </div>
        </section>

        {/* ─── PRICING (split card) ─────────────────────────────────────── */}
        <section
          id="pricing"
          aria-labelledby="pricing-heading"
          className="scroll-mt-16 border-y border-[var(--border-subtle)] bg-[var(--bg-secondary)] py-20 md:py-28"
          style={{ backgroundImage: "linear-gradient(135deg, var(--bg-secondary), rgba(184, 107, 82, 0.03), rgba(74, 107, 136, 0.04))" }}
        >
          <ScrollReveal direction="up" distance={30} className="site-container">
            <div className="mx-auto max-w-4xl overflow-hidden rounded-[2rem] border border-[var(--border-medium)] bg-[var(--bg-primary)] border-t-[3px] border-t-forma-warm-orange">
              <div className="grid md:grid-cols-2">
                {/* Left: headline */}
                <div className="flex flex-col justify-center p-8 md:p-10 lg:p-14">
                  <SectionEyebrow>Transparent</SectionEyebrow>
                  <h2 id="pricing-heading" className="mt-5 text-[1.875rem] font-semibold leading-[1.15] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem] md:leading-[1.1]">
                    One purchase. No subscriptions.
                  </h2>
                  <p className="mt-5 max-w-md text-base leading-relaxed text-[var(--text-secondary)]">
                    No account. No cloud tax. No premium tier maze. Just a native Mac utility you
                    own and can trust with your files.
                  </p>
                </div>

                {/* Right: price + features + CTA */}
                <div className="border-t border-[var(--border-subtle)] p-8 md:border-l md:border-t-0 md:p-10 lg:p-14">
                  <p className="text-[3.5rem] font-bold tracking-[-0.04em] text-[var(--text-primary)] md:text-[4.5rem] md:leading-none">
                    $29
                  </p>
                  <p className="mt-1 text-[13px] font-medium tracking-[0.12em] uppercase text-[var(--text-muted)]">
                    One-time purchase
                  </p>

                  <ul className="mt-8 space-y-3.5">
                    {[
                      "Preview every move before it runs",
                      "No subscription \u2014 yours forever",
                      "No cloud dependency. Runs locally on macOS 15+",
                    ].map((item) => (
                      <li key={item} className="flex items-start gap-3">
                        <span className="mt-[7px] h-1.5 w-1.5 shrink-0 rounded-full bg-forma-steel-blue" aria-hidden="true" />
                        <span className="text-[15px] leading-relaxed text-[var(--text-secondary)]">
                          {item}
                        </span>
                      </li>
                    ))}
                  </ul>

                  <div className="mt-10">
                    <TrackedAppStoreLink
                      location="pricing_primary"
                      className="inline-flex items-center justify-center rounded-xl bg-gradient-to-br from-[#944A35] to-[#A86048] px-7 py-3.5 text-[15px] font-semibold text-white shadow-[0_4px_16px_rgba(148,74,53,0.35)] transition-[transform,box-shadow,filter] duration-200 ease-out will-change-transform hover:-translate-y-0.5 hover:shadow-[0_6px_20px_rgba(148,74,53,0.45)] hover:brightness-110 active:scale-[0.97]"
                    >
                      Download for Mac
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
