import type { ReactNode } from "react";
import { Eye, EyeClosed, GitBranch, Type, Undo2, Camera, Image, FileText, FileCheck, Folder, FolderOpen, Shield, ShieldCheck, RotateCcw, History, Scan, ScanSearch } from "lucide-react";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";
import ScrollDrivenTornado from "@/components/effects/ScrollDrivenTornado";
import { ScrollReveal } from "@/components/animation/ScrollReveal";
import FAQSection from "@/components/sections/FAQSection";
import FormaBeforeAfter from "@/components/sections/FormaBeforeAfter";
import FormaHeroWindow from "@/components/sections/FormaHeroWindow";
import HeroEntrance from "@/components/animation/HeroEntrance";
import { faqs } from "@/lib/faq";
import { SITE_NAME, SITE_URL, WEBSITE_LAST_UPDATED_ISO } from "@/lib/site";

/* ═══════════════════════════════════════════════════════════════════════════
   CUSTOM ICONS
   ═══════════════════════════════════════════════════════════════════════════ */

function AnimatedTypeCursor({ className, strokeWidth, ...props }: React.SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth || "2"}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      {...props}
    >
      <g className="origin-center transition-all duration-300 ease-out group-hover:-translate-x-[3px] group-hover:scale-75">
        <path d="M12 4v16" />
        <path d="M4 7V5a1 1 0 0 1 1-1h14a1 1 0 0 1 1 1v2" />
        <path d="M9 20h6" />
      </g>
      <path d="M19 4v16" className="opacity-0 transition-opacity duration-300 group-hover:opacity-100 group-hover:animate-blink" strokeWidth={1.5} />
    </svg>
  );
}

function AnimatedLayersIcon({ className, strokeWidth, ...props }: React.SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth || "2"}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      {...props}
    >
      <g className="origin-center transition-all duration-300 ease-out group-hover:scale-110">
        <polygon 
          points="12 2 2 7 12 12 22 7 12 2" 
          className="transition-transform duration-300 ease-out" 
        />
        <polyline 
          points="2 12 12 17 22 12" 
          className="transition-all duration-300 ease-out group-hover:-translate-y-[5px] group-hover:opacity-0" 
        />
        <polyline 
          points="2 17 12 22 22 17" 
          className="transition-all duration-300 ease-out group-hover:-translate-y-[10px] group-hover:opacity-0" 
        />
      </g>
    </svg>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   CONTENT DATA
   ═══════════════════════════════════════════════════════════════════════════ */

const featureHighlights = [
  {
    icon: AnimatedTypeCursor,
    title: "Natural language rules",
    body: "Describe what you want in words, not code. \u2018If it\u2019s a screenshot, put it in Screenshots.\u2019 Done.",
    color: "text-forma-steel-blue",
    bgTint: "bg-[rgba(74,107,136,0.14)]",
    borderTint: "border-[rgba(74,107,136,0.22)]",
    animationClass: "",
  },
  {
    icon: AnimatedLayersIcon,
    title: "Auto-grouping",
    body: "One rule catches 200 similar files. Not 200 rules for 200 files.",
    color: "text-forma-muted-blue",
    bgTint: "bg-[rgba(107,127,168,0.14)]",
    borderTint: "border-[rgba(107,127,168,0.22)]",
    animationClass: "",
  },
  {
    icon: Eye,
    hoverIcon: EyeClosed,
    title: "Preview before action",
    body: "See every file that matched before anything moves. Uncheck the ones you\u2019re not sure about.",
    color: "text-forma-sage",
    bgTint: "bg-[rgba(107,143,113,0.14)]",
    borderTint: "border-[rgba(107,143,113,0.22)]",
    animationClass: "group-hover:animate-eye-blink",
  },
  {
    icon: RotateCcw,
    hoverIcon: History,
    title: "Full undo history",
    body: "Changed your mind Tuesday about what you did Monday? One click.",
    color: "text-forma-warm-orange",
    bgTint: "bg-[rgba(184,107,82,0.14)]",
    borderTint: "border-[rgba(184,107,82,0.22)]",
    animationClass: "group-hover:animate-undo-spin",
  },
] as const;

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
    title: "Undo any batch.",
    body: "Every batch lives in your history. Reverse the whole thing weeks later when you realize past-you was wrong.",
  },
] as const;

const useCases = [
  {
    icon: Camera,
    hoverIcon: Image,
    title: "Screenshots and exports",
    body: "Your desktop has 400 screenshots on it right now. Don\u2019t look. Just write a rule.",
    color: "text-forma-warm-orange",
    bgTint: "bg-[rgba(184,107,82,0.14)]",
    borderTint: "border-[rgba(184,107,82,0.22)]",
    animationClass: "group-hover:animate-camera-snap",
  },
  {
    icon: FileText,
    hoverIcon: FileCheck,
    title: "PDFs and paperwork",
    body: "Invoices, tax forms, bank statements. Rules you can still understand when tax season hits.",
    color: "text-forma-steel-blue",
    bgTint: "bg-[rgba(74,107,136,0.14)]",
    borderTint: "border-[rgba(74,107,136,0.22)]",
    animationClass: "group-hover:animate-doc-shuffle",
  },
  {
    icon: Folder,
    hoverIcon: FolderOpen,
    title: "Project overflow",
    body: "Exports, renders, drafts \u2014 the files that pile up mid-project. Move them without losing track.",
    color: "text-forma-muted-blue",
    bgTint: "bg-[rgba(107,127,168,0.14)]",
    borderTint: "border-[rgba(107,127,168,0.22)]",
    animationClass: "group-hover:animate-folder-pop",
  },
  {
    icon: Scan,
    hoverIcon: ScanSearch,
    title: "Preview-first",
    body: "Nothing moves until you approve the batch. Every file, every destination, visible before it happens.",
    color: "text-forma-sage",
    bgTint: "bg-[rgba(107,143,113,0.14)]",
    borderTint: "border-[rgba(107,143,113,0.22)]",
    animationClass: "group-hover:animate-scan-pulse",
  },
  {
    icon: Shield,
    hoverIcon: ShieldCheck,
    title: "Local-only privacy",
    body: "Your files never leave your Mac. No account, no uploads, no \u2018we take privacy seriously\u2019 blog post.",
    color: "text-forma-steel-blue",
    bgTint: "bg-[rgba(74,107,136,0.14)]",
    borderTint: "border-[rgba(74,107,136,0.22)]",
    animationClass: "group-hover:animate-shield-block",
  },
  {
    icon: RotateCcw,
    hoverIcon: History,
    title: "Undo system",
    body: "Moved 200 files to the wrong folder? One click to undo. No archaeological dig required.",
    color: "text-forma-warm-orange",
    bgTint: "bg-[rgba(184,107,82,0.14)]",
    borderTint: "border-[rgba(184,107,82,0.22)]",
    animationClass: "group-hover:animate-undo-spin",
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
        "A file organizer for people who gave up on file organizers. Write rules in plain English, preview every move, undo anytime. $29 for Mac.",
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

      <main id="main-content" className="relative overflow-hidden w-full h-full">
        <ScrollDrivenTornado />
        
        {/* ─── HERO ─────────────────────────────────────────────────────── */}
        <section
          id="top"
          className="relative overflow-hidden border-b border-[var(--border-subtle)] bg-transparent"
        >
          {/* We removed the static background gradients here so the WebGL shines through */}

          <HeroEntrance className="site-container relative z-10 py-12 md:py-16 lg:py-24">
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
                  Tell it where things should go &mdash; in plain English, not regex.
                  Preview the batch before anything moves. Undo the whole thing when you change your mind.
                </p>

                <div data-hero="cta" className="mt-8">
                  <TrackedAppStoreLink
                    location="hero_primary"
                    className="inline-flex items-center justify-center rounded-xl bg-gradient-to-br from-[#944A35] to-[#A86048] px-7 py-3.5 text-[15px] font-semibold text-white shadow-[0_4px_16px_rgba(148,74,53,0.35)] transition-[transform,box-shadow,filter] duration-200 ease-out will-change-transform hover:-translate-y-0.5 hover:shadow-[0_6px_20px_rgba(148,74,53,0.45)] hover:brightness-110 active:scale-[0.97]"
                  >
                    Get Forma for Mac
                  </TrackedAppStoreLink>
                  <p className="mt-3 text-[13px] text-[var(--text-muted)]">
                    $29 once. No subscription. No account. Just a Mac app.
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
        <section aria-labelledby="features-heading" className="relative z-10 border-b border-[var(--border-subtle)] bg-transparent py-20 md:py-28">
          <div className="site-container">
            <div className="text-center max-w-4xl mx-auto">
              <SectionEyebrow>What makes it different</SectionEyebrow>
              <h2 id="features-heading" className="mx-auto mt-5 max-w-2xl text-[1.875rem] font-semibold leading-[1.15] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem] md:leading-[1.1]">
                Automation you can actually see.
              </h2>
              <p className="mx-auto mt-5 max-w-xl text-base leading-relaxed text-[var(--text-secondary)] md:text-[1.125rem]">
                Most file organizers run in the background and hope for the best. Forma shows you what it&apos;s about to do.
              </p>
            </div>

            <ScrollReveal direction="up" distance={30} stagger={0.08} className="mx-auto mt-14 grid max-w-4xl gap-10 sm:grid-cols-2 lg:grid-cols-4">
              {featureHighlights.map((feature) => {
                const Icon = feature.icon;
                const HoverIcon = ('hoverIcon' in feature ? feature.hoverIcon : null) as React.ComponentType<any> | null;
                return (
                  <div key={feature.title} className="text-center group cursor-default">
                    <div className={`mx-auto flex h-14 w-14 items-center justify-center rounded-2xl border ${feature.borderTint} ${feature.bgTint} transition-transform duration-300`}>
                      {HoverIcon ? (
                        <div className="relative h-7 w-7">
                          <Icon className={`absolute inset-0 h-7 w-7 transition-opacity duration-300 group-hover:opacity-0 ${feature.color}`} strokeWidth={1.5} />
                          <HoverIcon className={`absolute inset-0 h-7 w-7 opacity-0 transition-opacity duration-300 group-hover:opacity-100 ${feature.color} ${feature.animationClass}`} strokeWidth={1.5} />
                        </div>
                      ) : (
                        <Icon className={`h-7 w-7 ${feature.color} ${feature.animationClass}`} strokeWidth={1.5} />
                      )}
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
        <section id="how-it-works" aria-labelledby="how-it-works-heading" className="relative z-10 scroll-mt-16 bg-[rgba(253,252,251,0.5)] backdrop-blur-[2px] py-20 md:py-28 border-b border-[var(--border-subtle)]">
          <div className="site-container">
            <div className="mx-auto max-w-5xl md:grid md:grid-cols-[1fr_2fr] md:gap-16 md:items-start">
              {/* Left: section intro */}
              <div className="mb-10 md:mb-0 md:sticky md:top-24">
                <SectionEyebrow>How Forma works</SectionEyebrow>
                <h2 id="how-it-works-heading" className="mt-5 text-[1.875rem] font-semibold leading-[1.15] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem] md:leading-[1.1]">
                  Three steps. No manual.
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
        <section aria-labelledby="before-after-heading" className="relative z-10 border-y border-[var(--border-subtle)] bg-transparent py-20 md:py-28">
          <div className="site-container">
            <ScrollReveal direction="up" distance={24} className="mx-auto max-w-4xl">
              <div>
                <SectionEyebrow>Before and after</SectionEyebrow>
                <h2 id="before-after-heading" className="mt-5 max-w-xl text-[1.875rem] font-semibold leading-[1.15] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem] md:leading-[1.1]">
                  One rule. Hundreds of files. Zero guilt.
                </h2>
                <p className="mt-5 max-w-lg text-base leading-relaxed text-[var(--text-secondary)] md:text-[1.125rem]">
                  That folder you&apos;ve been meaning to clean since 2023? One rule handles it.
                </p>
              </div>
            </ScrollReveal>

            <ScrollReveal direction="up" distance={30} delay={0.15} className="mx-auto mt-12 max-w-4xl">
              <div>
                <FormaBeforeAfter />
              </div>
            </ScrollReveal>
          </div>
        </section>

        {/* ─── USE CASES (2x3 grid) ─────────────────────────────────────── */}
        <section aria-labelledby="use-cases-heading" className="relative z-10 bg-transparent py-20 md:py-28">
          <div className="site-container">
            <div className="text-center max-w-3xl mx-auto">
              <SectionEyebrow>Where it clicks</SectionEyebrow>
              <h2 id="use-cases-heading" className="mx-auto mt-5 max-w-2xl text-[1.875rem] font-semibold leading-[1.15] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem] md:leading-[1.1]">
                Start with the folder that bothers you most.
              </h2>
              <p className="mx-auto mt-5 max-w-lg text-base leading-relaxed text-[var(--text-secondary)] md:text-[1.125rem]">
                One rule, one folder, one visible payoff. Expand from there.
              </p>
            </div>

            <ScrollReveal direction="up" distance={24} stagger={0.06} className="mx-auto mt-14 grid max-w-5xl gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {useCases.map((useCase) => {
                const Icon = useCase.icon;
                const HoverIcon = ('hoverIcon' in useCase ? useCase.hoverIcon : null) as React.ComponentType<any> | null;
                return (
                  <article
                    key={useCase.title}
                    className="group rounded-2xl cursor-default border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-7 transition-shadow duration-300 hover:shadow-[0_8px_30px_rgba(0,0,0,0.06)]"
                  >
                    <div className={`flex h-12 w-12 items-center justify-center rounded-xl border ${useCase.borderTint} ${useCase.bgTint} transition-transform duration-300`}>
                      {HoverIcon ? (
                        <div className="relative h-6 w-6">
                          <Icon className={`absolute inset-0 h-6 w-6 transition-opacity duration-300 group-hover:opacity-0 ${useCase.color}`} strokeWidth={1.5} />
                          <HoverIcon className={`absolute inset-0 h-6 w-6 opacity-0 transition-opacity duration-300 group-hover:opacity-100 ${useCase.color} ${useCase.animationClass}`} strokeWidth={1.5} />
                        </div>
                      ) : (
                        <Icon className={`h-6 w-6 ${useCase.color} ${useCase.animationClass}`} strokeWidth={1.5} />
                      )}
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

        {/* ─── OPAQUE BACKGROUND WRAPPER TO HIDE 3D CANVAS BELOW USE CASES ─ */}
        <div className="relative z-20 bg-[var(--bg-primary)]">
          {/* ─── PRICING (split card) ─────────────────────────────────────── */}
          <section
            id="pricing"
            aria-labelledby="pricing-heading"
            className="scroll-mt-16 border-y border-[var(--border-subtle)] bg-[var(--bg-secondary)] py-20 md:py-28"
            style={{ backgroundImage: "linear-gradient(135deg, var(--bg-secondary), rgba(184, 107, 82, 0.03), rgba(74, 107, 136, 0.04))" }}
          >
            <ScrollReveal direction="up" distance={30} className="site-container">
            <div className="mx-auto max-w-4xl overflow-hidden rounded-[2rem] border-[3px] border-forma-warm-orange bg-[var(--bg-primary)]">
              <div className="grid md:grid-cols-2">
                {/* Left: headline */}
                <div className="flex flex-col justify-center p-8 md:p-10 lg:p-14">
                  <SectionEyebrow>Pricing</SectionEyebrow>
                  <h2 id="pricing-heading" className="mt-5 text-[1.875rem] font-semibold leading-[1.15] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem] md:leading-[1.1]">
                    One price. You own it.
                  </h2>
                  <p className="mt-5 max-w-md text-base leading-relaxed text-[var(--text-secondary)]">
                    No account. No cloud. No &ldquo;Pro tier&rdquo; that unlocks the features you actually need. A Mac app. Yours.
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
                      "Pay once, keep it forever",
                      "Runs locally on your Mac. macOS 15+",
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
        </div>
      </main>
    </>
  );
}
