import Link from "next/link";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import { HEADER_SHELL_LAYOUT } from "@/lib/header-shell-layout";
import { SUPPORT_EMAIL } from "@/lib/site";

type LegalSection = {
  title?: string;
  paragraphs: readonly string[];
};

type RelatedLink = {
  href: string;
  label: string;
  description: string;
};

type LegalPageShellProps = {
  eyebrow: string;
  title: string;
  description: string;
  lastUpdated: string;
  contactLocation: string;
  summaryChips: readonly string[];
  plainLanguageTitle: string;
  plainLanguagePoints: readonly string[];
  sections: readonly LegalSection[];
  relatedLinks: readonly RelatedLink[];
};

export default function LegalPageShell({
  eyebrow,
  title,
  description,
  lastUpdated,
  contactLocation,
  summaryChips,
  plainLanguageTitle,
  plainLanguagePoints,
  sections,
  relatedLinks,
}: LegalPageShellProps) {
  return (
    <main id="main-content" className={`relative ${HEADER_SHELL_LAYOUT.routeClearanceClassName}`}>
      <section className="mx-auto w-full max-w-[1100px] px-6">
        <header className="border-b border-[var(--rule-faint)] pb-12 md:pb-16">
          <div className="grid gap-10 lg:grid-cols-[1.05fr,0.95fr]">
            <div>
              <p className="eyebrow">{eyebrow}</p>
              <h1 className="display-lg mt-5 text-[var(--ink-primary)]">{title}</h1>
              <p className="prose-editorial mt-5">{description}</p>

              <div className="mt-8 flex flex-wrap gap-2">
                <span className="rounded-full border border-[var(--rule-faint)] bg-[var(--canvas-bone)] px-3 py-1.5 text-xs font-medium text-[var(--ink-secondary)]">
                  Last updated {lastUpdated}
                </span>
                {summaryChips.map((chip) => (
                  <span
                    key={chip}
                    className="rounded-full border border-[var(--rule-faint)] bg-[var(--canvas-bone)] px-3 py-1.5 text-xs font-medium text-[var(--ink-secondary)]"
                  >
                    {chip}
                  </span>
                ))}
              </div>
            </div>

            <aside className="rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] p-6">
              <p className="eyebrow">In plain language</p>
              <h2 className="mt-4 font-display text-[1.5rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
                {plainLanguageTitle}
              </h2>
              <ul className="mt-4 space-y-3">
                {plainLanguagePoints.map((item) => (
                  <li key={item} className="flex items-start gap-3">
                    <span className="mt-[6px] h-2 w-2 rounded-full bg-forma-sage" />
                    <span className="text-sm leading-relaxed text-[var(--ink-secondary)]">
                      {item}
                    </span>
                  </li>
                ))}
              </ul>
            </aside>
          </div>
        </header>

        <div className="mt-12 grid gap-10 lg:grid-cols-[1.08fr,0.92fr]">
          <article className="max-w-[68ch]">
            <div className="space-y-10">
              {sections.map((section, index) => (
                <section
                  key={`${section.title ?? "intro"}-${index}`}
                  className="border-b border-[var(--rule-faint)] pb-10 last:border-b-0 last:pb-0"
                >
                  {section.title ? (
                    <h2 className="font-display text-[1.75rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
                      {section.title}
                    </h2>
                  ) : null}
                  <div className="mt-4 space-y-4 text-[1.0625rem] leading-[1.65] text-[var(--ink-primary)]">
                    {section.paragraphs.map((paragraph) => (
                      <p key={paragraph} className="text-wrap-pretty">{paragraph}</p>
                    ))}
                  </div>
                </section>
              ))}
            </div>
          </article>

          <div className="space-y-6">
            <section className="rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] p-7">
              <h2 className="font-display text-[1.375rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
                Questions or concerns?
              </h2>
              <p className="mt-3 text-[15px] leading-relaxed text-[var(--ink-secondary)]">
                If something in this policy is unclear, email us directly. We would rather
                explain the rule than hide behind vague legal copy.
              </p>
              <p className="mt-5">
                <TrackedMailtoLink
                  email={SUPPORT_EMAIL}
                  location={contactLocation}
                  className="text-forma-steel-blue transition-opacity hover:opacity-80"
                >
                  {SUPPORT_EMAIL}
                </TrackedMailtoLink>
              </p>
            </section>

            <section className="rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] p-7">
              <h2 className="font-display text-[1.375rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
                Related pages
              </h2>
              <ul className="mt-4 space-y-4">
                {relatedLinks.map((link) => (
                  <li key={link.href} className="rounded-xl border border-[var(--rule-faint)] bg-[var(--canvas-paper)] p-4">
                    <Link
                      href={link.href}
                      className="text-sm font-semibold text-forma-steel-blue transition-opacity hover:opacity-80"
                    >
                      {link.label}
                    </Link>
                    <p className="mt-1 text-sm leading-relaxed text-[var(--ink-secondary)]">
                      {link.description}
                    </p>
                  </li>
                ))}
              </ul>
            </section>
          </div>
        </div>

        <div className="mt-16">
          <Link
            href="/"
            className="text-sm text-[var(--ink-faint)] transition-colors hover:text-[var(--ink-secondary)]"
          >
            &larr; Back to home
          </Link>
        </div>
      </section>
    </main>
  );
}
