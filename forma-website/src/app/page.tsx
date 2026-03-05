import type { ReactNode } from "react";
import Image from "next/image";
import Link from "next/link";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";
import FAQSection from "@/components/sections/FAQSection";
import MacWindowFrame from "@/components/ui/MacWindowFrame";
import { faqs } from "@/lib/faq";
import { SITE_NAME, SITE_URL, WEBSITE_LAST_UPDATED_ISO } from "@/lib/site";

const proofItems = [
  {
    title: "Preview-first",
    body: "Nothing moves until you approve the batch.",
  },
  {
    title: "Local-only",
    body: "Files stay on your Mac. No account required.",
  },
  {
    title: "Undo built in",
    body: "Reverse a bad batch without cleanup archaeology.",
  },
  {
    title: "One-time purchase",
    body: "$29 once. No subscription or premium-tier maze.",
  },
] as const;

const heroAnnotations = [
  {
    title: "Review queue",
    body: "Approve the exact files that should move.",
    className: "left-4 top-4 md:-left-5 md:top-8",
  },
  {
    title: "Rule-aware decisions",
    body: "Every row carries its destination before you run it.",
    className: "right-4 top-6 md:-right-8 md:top-20",
  },
  {
    title: "Undo stays close",
    body: "The workflow assumes you may want to reverse it later.",
    className: "bottom-4 left-4 md:bottom-6 md:left-10",
  },
] as const;

const workflowSteps = [
  {
    step: "Step 01",
    title: "Write the rule in plain English.",
    body:
      "Start with one pattern and one destination. Forma turns it into a repeatable rule instead of another fiddly settings panel.",
    bullets: [
      "Readable conditions instead of brittle automation syntax",
      "One rule can cover screenshots, PDFs, imports, or project drops",
      "Built for the way Mac users actually describe clutter",
    ],
    image: "/screenshots/story/forma-paper-02-rules.png",
    alt: "Forma rule builder showing conditions and a destination folder",
  },
  {
    step: "Step 02",
    title: "Approve the batch, not the gamble.",
    body:
      "Preview every change before it happens. Keep files in. Leave files out. The product earns trust by showing its work before it touches anything.",
    bullets: [
      "Each file is visible before the move runs",
      "Skipped files stay out of the batch",
      "The destination is legible at a glance",
    ],
    image: "/screenshots/story/forma-paper-03-preview.png",
    alt: "Forma preview queue showing selected files and destinations before moving them",
  },
] as const;

const useCases = [
  {
    title: "Screenshots and exports",
    rule: "\"Move screenshots older than 7 days to Images.\"",
    body: "Turn recurring desktop noise into one maintained rule instead of one more weekly cleanup ritual.",
  },
  {
    title: "PDFs and paperwork",
    rule: "\"Put invoices in Finance. Archive old contracts.\"",
    body: "Use rules that stay legible when you revisit them in three months.",
  },
  {
    title: "Project overflow",
    rule: "\"Route exports, recordings, and drafts into the right project home.\"",
    body: "Keep work-in-progress files moving without surrendering control to a black box.",
  },
] as const;

function SectionEyebrow({ children }: { children: ReactNode }) {
  return (
    <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-forma-steel-blue">
      {children}
    </p>
  );
}

function ProofCard({ title, body }: { title: string; body: string }) {
  return (
    <div className="rounded-2xl border border-[var(--border-subtle)] bg-white/70 p-5 shadow-[0_12px_30px_rgba(15,18,24,0.04)] backdrop-blur">
      <p className="text-sm font-semibold text-[var(--text-primary)]">{title}</p>
      <p className="mt-2 text-sm leading-relaxed text-[var(--text-secondary)]">{body}</p>
    </div>
  );
}

function Annotation({
  title,
  body,
  className,
}: {
  title: string;
  body: string;
  className: string;
}) {
  return (
    <div
      className={`absolute hidden max-w-[220px] rounded-2xl border border-[var(--border-medium)] bg-[rgba(250,250,248,0.94)] px-4 py-3 shadow-[0_18px_40px_rgba(15,18,24,0.12)] backdrop-blur md:block ${className}`}
    >
      <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forma-steel-blue">
        {title}
      </p>
      <p className="mt-1.5 text-sm leading-relaxed text-[var(--text-secondary)]">{body}</p>
    </div>
  );
}

function WorkflowPanel({
  step,
  title,
  body,
  bullets,
  image,
  alt,
  reverse = false,
}: {
  step: string;
  title: string;
  body: string;
  bullets: readonly string[];
  image: string;
  alt: string;
  reverse?: boolean;
}) {
  return (
    <article className="rounded-[2rem] border border-[var(--border-subtle)] bg-white/70 p-5 shadow-[0_18px_40px_rgba(15,18,24,0.05)] md:p-8">
      <div
        className={`grid items-center gap-8 lg:grid-cols-[0.92fr,1.08fr] ${reverse ? "lg:[&>*:first-child]:order-2 lg:[&>*:last-child]:order-1" : ""}`}
      >
        <div>
          <SectionEyebrow>{step}</SectionEyebrow>
          <h3 className="mt-4 max-w-[18ch] text-3xl font-semibold tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.5rem]">
            {title}
          </h3>
          <p className="mt-4 max-w-xl text-base leading-relaxed text-[var(--text-secondary)]">
            {body}
          </p>
          <ul className="mt-6 space-y-3">
            {bullets.map((bullet) => (
              <li key={bullet} className="flex items-start gap-3">
                <span className="mt-[6px] h-2 w-2 rounded-full bg-forma-sage" />
                <span className="text-sm leading-relaxed text-[var(--text-secondary)]">{bullet}</span>
              </li>
            ))}
          </ul>
        </div>

        <div className="overflow-hidden rounded-[1.5rem] border border-[var(--border-medium)] bg-[var(--bg-secondary)]">
          <Image
            src={image}
            alt={alt}
            width={1312}
            height={900}
            className="h-auto w-full"
          />
        </div>
      </div>
    </article>
  );
}

function UseCaseCard({
  title,
  rule,
  body,
}: {
  title: string;
  rule: string;
  body: string;
}) {
  return (
    <article className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-6">
      <h3 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
        {title}
      </h3>
      <p className="mt-4 rounded-xl border border-[var(--border-medium)] bg-[var(--surface-glass)] px-4 py-3 font-mono text-[12px] leading-relaxed text-[var(--text-secondary)]">
        {rule}
      </p>
      <p className="mt-4 text-[15px] leading-relaxed text-[var(--text-secondary)]">{body}</p>
    </article>
  );
}

export default function Home() {
  const softwareApplicationJsonLd = {
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
  };

  const organizationJsonLd = {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: SITE_NAME,
    url: SITE_URL,
    sameAs: [],
  };

  const websiteJsonLd = {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: SITE_NAME,
    url: SITE_URL,
    inLanguage: "en-US",
    dateModified: WEBSITE_LAST_UPDATED_ISO,
  };

  const faqJsonLd = {
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
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@graph": [
              softwareApplicationJsonLd,
              organizationJsonLd,
              websiteJsonLd,
              faqJsonLd,
            ],
          }),
        }}
      />

      <main id="main-content" className="relative overflow-hidden">
        <section
          id="top"
          className="relative overflow-hidden border-b border-[var(--border-subtle)] bg-[linear-gradient(180deg,#fafaf8_0%,#f5f2eb_55%,#f2f2f0_100%)]"
        >
          <div className="absolute inset-x-0 top-0 h-[320px] bg-[radial-gradient(circle_at_top_left,rgba(74,107,136,0.14),transparent_42%),radial-gradient(circle_at_top_right,rgba(107,143,113,0.14),transparent_38%)]" />

          <div className="site-container relative py-10 md:py-14 lg:py-16">
            <div className="grid items-center gap-10 lg:grid-cols-[0.84fr,1.16fr] lg:items-start lg:gap-14">
              <div>
                <SectionEyebrow>Preview-first file organization for Mac</SectionEyebrow>
                <h1 className="mt-5 max-w-[11ch] text-[3rem] font-semibold leading-[0.98] tracking-[-0.05em] text-[var(--text-primary)] sm:text-[3.8rem] lg:text-[4.8rem]">
                  A file organizer for people who gave up on file organizers.
                </h1>
                <p className="mt-6 max-w-xl text-lg leading-relaxed text-[var(--text-secondary)] md:text-xl">
                  Write the rule in plain English. Review every move before it happens. Undo
                  the whole batch if it&apos;s wrong.
                </p>

                <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                  <TrackedAppStoreLink
                    location="hero_primary"
                    className="inline-flex items-center justify-center rounded-xl bg-[var(--cta-bg)] px-6 py-3.5 text-sm font-semibold text-[var(--cta-text)] transition-colors hover:bg-[var(--cta-bg-hover)]"
                  >
                    Download for Mac
                  </TrackedAppStoreLink>
                  <a
                    href="#how-it-works"
                    className="inline-flex items-center justify-center rounded-xl border border-[var(--border-medium)] bg-[rgba(255,255,255,0.66)] px-6 py-3.5 text-sm font-semibold text-[var(--text-primary)] transition-colors hover:border-[var(--border-strong)] hover:bg-[rgba(255,255,255,0.82)]"
                  >
                    Watch a real cleanup
                  </a>
                </div>

                <div className="mt-5 flex flex-wrap gap-2">
                  {["$29 once", "Local-only", "No account", "Never deletes files"].map((item) => (
                    <span
                      key={item}
                      className="rounded-full border border-[var(--border-medium)] bg-[rgba(255,255,255,0.72)] px-3 py-1.5 text-xs font-medium text-[var(--text-secondary)]"
                    >
                      {item}
                    </span>
                  ))}
                </div>
              </div>

              <div className="relative">
                <Annotation {...heroAnnotations[0]} />
                <Annotation {...heroAnnotations[1]} />
                <Annotation {...heroAnnotations[2]} />

                <MacWindowFrame className="overflow-visible">
                  <Image
                    src="/screenshots/light/forma-01-hero-main-window.png"
                    alt="Forma preview queue showing pending file moves, rules, and a right-side inspector"
                    width={1440}
                    height={900}
                    priority
                    className="h-auto w-full"
                  />
                </MacWindowFrame>
              </div>
            </div>

            <div className="mt-10 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
              {proofItems.map((item) => (
                <ProofCard key={item.title} title={item.title} body={item.body} />
              ))}
            </div>
          </div>
        </section>

        <section id="how-it-works" className="scroll-mt-16 bg-[var(--bg-primary)] py-14 md:py-20">
          <div className="site-container">
            <div className="max-w-3xl">
              <SectionEyebrow>How Forma works</SectionEyebrow>
              <h2 className="mt-4 text-4xl font-semibold tracking-[-0.04em] text-[var(--text-primary)] md:text-[3.5rem]">
                Automation without blind trust.
              </h2>
              <p className="mt-5 max-w-2xl text-lg leading-relaxed text-[var(--text-secondary)]">
                The site now has one job: show the mechanism, not just the promise. Rule creation,
                review-before-action, and undo safety all need to appear before pricing.
              </p>
            </div>

            <div className="mt-10 space-y-6">
              {workflowSteps.map((step, index) => (
                <WorkflowPanel
                  key={step.step}
                  step={step.step}
                  title={step.title}
                  body={step.body}
                  bullets={step.bullets}
                  image={step.image}
                  alt={step.alt}
                  reverse={index % 2 === 1}
                />
              ))}
            </div>
          </div>
        </section>

        <section className="border-y border-[var(--border-subtle)] bg-[linear-gradient(180deg,#f0eee8_0%,#f7f5ef_100%)] py-14 md:py-20">
          <div className="site-container">
            <div className="grid items-center gap-8 lg:grid-cols-[0.8fr,1.2fr]">
              <div>
                <SectionEyebrow>Transformation</SectionEyebrow>
                <h2 className="mt-4 max-w-[12ch] text-4xl font-semibold tracking-[-0.04em] text-[var(--text-primary)] md:text-[3.5rem]">
                  From pile to system.
                </h2>
                <p className="mt-5 max-w-xl text-lg leading-relaxed text-[var(--text-secondary)]">
                  Forma is strongest when it turns recurring clutter into one maintainable rule.
                  This is the exact before-and-after proof the current homepage was missing.
                </p>

                <div className="mt-8 grid gap-4 sm:grid-cols-3">
                  <div className="rounded-2xl border border-[var(--border-medium)] bg-[rgba(255,255,255,0.72)] p-4">
                    <p className="text-3xl font-semibold tracking-[-0.04em] text-[var(--text-primary)]">
                      200
                    </p>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--text-secondary)]">
                      Files cleaned up by one rule instead of one more cleanup session.
                    </p>
                  </div>
                  <div className="rounded-2xl border border-[var(--border-medium)] bg-[rgba(255,255,255,0.72)] p-4">
                    <p className="text-3xl font-semibold tracking-[-0.04em] text-[var(--text-primary)]">
                      3
                    </p>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--text-secondary)]">
                      Destinations that stay legible when you revisit them later.
                    </p>
                  </div>
                  <div className="rounded-2xl border border-[var(--border-medium)] bg-[rgba(255,255,255,0.72)] p-4">
                    <p className="text-3xl font-semibold tracking-[-0.04em] text-[var(--text-primary)]">
                      0
                    </p>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--text-secondary)]">
                      Blind moves. The batch is reviewed before it runs.
                    </p>
                  </div>
                </div>

                <div className="mt-8">
                  <TrackedAppStoreLink
                    location="post_proof_primary"
                    className="inline-flex items-center justify-center rounded-xl bg-[var(--cta-bg)] px-6 py-3.5 text-sm font-semibold text-[var(--cta-text)] transition-colors hover:bg-[var(--cta-bg-hover)]"
                  >
                    Download for Mac
                  </TrackedAppStoreLink>
                </div>
              </div>

              <div className="overflow-hidden rounded-[2rem] border border-[var(--border-medium)] bg-white shadow-[0_24px_60px_rgba(15,18,24,0.08)]">
                <Image
                  src="/screenshots/story/forma-paper-04-before-after.png"
                  alt="Before and after file organization showing a cluttered desktop turned into organized destination folders"
                  width={1312}
                  height={900}
                  className="h-auto w-full"
                />
              </div>
            </div>
          </div>
        </section>

        <section className="bg-[var(--bg-primary)] py-14 md:py-20">
          <div className="site-container">
            <div className="max-w-3xl">
              <SectionEyebrow>Use cases</SectionEyebrow>
              <h2 className="mt-4 text-4xl font-semibold tracking-[-0.04em] text-[var(--text-primary)] md:text-[3.25rem]">
                Built for recurring clutter, not tidy demos.
              </h2>
              <p className="mt-5 max-w-2xl text-lg leading-relaxed text-[var(--text-secondary)]">
                The strongest use cases are the ones you repeat every week. Start with one rule,
                one folder, and one visible payoff.
              </p>
            </div>

            <div className="mt-10 grid gap-5 lg:grid-cols-3">
              {useCases.map((useCase) => (
                <UseCaseCard
                  key={useCase.title}
                  title={useCase.title}
                  rule={useCase.rule}
                  body={useCase.body}
                />
              ))}
            </div>
          </div>
        </section>

        <section
          id="pricing"
          className="scroll-mt-16 border-y border-[var(--border-subtle)] bg-[var(--bg-secondary)] py-14 md:py-20"
        >
          <div className="site-container">
            <div className="grid gap-6 lg:grid-cols-[0.9fr,1.1fr]">
              <div className="rounded-[2rem] border border-[var(--border-medium)] bg-[var(--bg-primary)] p-8 md:p-10">
                <SectionEyebrow>Pricing</SectionEyebrow>
                <h2 className="mt-4 text-[3.5rem] font-semibold tracking-[-0.05em] text-[var(--text-primary)] md:text-[4.75rem]">
                  $29 once.
                </h2>
                <p className="mt-3 text-2xl font-semibold tracking-[-0.03em] text-[var(--text-primary)]">
                  Not another subscription.
                </p>
                <p className="mt-5 max-w-lg text-lg leading-relaxed text-[var(--text-secondary)]">
                  No account. No cloud tax. No premium tier maze. Just a native Mac utility you
                  own and can trust with your files.
                </p>

                <ul className="mt-8 space-y-3">
                  {[
                    "Preview every move before it runs",
                    "Undo remains part of the workflow",
                    "Runs locally on macOS 15 or later",
                  ].map((item) => (
                    <li key={item} className="flex items-start gap-3">
                      <span className="mt-[6px] h-2 w-2 rounded-full bg-forma-steel-blue" />
                      <span className="text-sm leading-relaxed text-[var(--text-secondary)]">
                        {item}
                      </span>
                    </li>
                  ))}
                </ul>

                <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                  <TrackedAppStoreLink
                    location="pricing_primary"
                    className="inline-flex items-center justify-center rounded-xl bg-[var(--cta-bg)] px-6 py-3.5 text-sm font-semibold text-[var(--cta-text)] transition-colors hover:bg-[var(--cta-bg-hover)]"
                  >
                    Download for Mac
                  </TrackedAppStoreLink>
                  <Link
                    href="/support"
                    className="inline-flex items-center justify-center rounded-xl border border-[var(--border-medium)] px-6 py-3.5 text-sm font-semibold text-[var(--text-primary)] transition-colors hover:border-[var(--border-strong)] hover:bg-[var(--surface-glass)]"
                  >
                    Talk to support
                  </Link>
                </div>
              </div>

              <div className="rounded-[2rem] border border-[var(--border-medium)] bg-[linear-gradient(180deg,rgba(255,255,255,0.62)_0%,rgba(255,255,255,0.3)_100%)] p-8 md:p-10">
                <SectionEyebrow>What you are buying</SectionEyebrow>
                <h3 className="mt-4 text-3xl font-semibold tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.5rem]">
                  Controlled automation that still feels native.
                </h3>
                <p className="mt-5 max-w-xl text-base leading-relaxed text-[var(--text-secondary)]">
                  Forma wins when it makes file cleanup lighter without asking you to surrender
                  judgment. The site should sell that promise as clearly as the app already does.
                </p>

                <div className="mt-8 grid gap-4 sm:grid-cols-2">
                  <div className="rounded-2xl border border-[var(--border-medium)] bg-[rgba(255,255,255,0.72)] p-4">
                    <p className="text-sm font-semibold text-[var(--text-primary)]">
                      Safer than auto-sorters
                    </p>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--text-secondary)]">
                      Preview-first review means you stay in charge before files move.
                    </p>
                  </div>
                  <div className="rounded-2xl border border-[var(--border-medium)] bg-[rgba(255,255,255,0.72)] p-4">
                    <p className="text-sm font-semibold text-[var(--text-primary)]">
                      Designed for real mess
                    </p>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--text-secondary)]">
                      Screenshots, PDFs, exports, and project debris are the starting point.
                    </p>
                  </div>
                  <div className="rounded-2xl border border-[var(--border-medium)] bg-[rgba(255,255,255,0.72)] p-4">
                    <p className="text-sm font-semibold text-[var(--text-primary)]">
                      Undo is expected
                    </p>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--text-secondary)]">
                      The product assumes you may want to reverse a batch and keeps that path close.
                    </p>
                  </div>
                  <div className="rounded-2xl border border-[var(--border-medium)] bg-[rgba(255,255,255,0.72)] p-4">
                    <p className="text-sm font-semibold text-[var(--text-primary)]">
                      No account required
                    </p>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--text-secondary)]">
                      Local-only operation and no account wall keep the product honest.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <FAQSection />
      </main>
    </>
  );
}
