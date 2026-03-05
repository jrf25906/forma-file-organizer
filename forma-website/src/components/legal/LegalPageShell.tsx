import Link from "next/link";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
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
    <main id="main-content" className="relative py-20 md:py-24">
      <div className="site-container mx-auto max-w-5xl">
        <header className="overflow-hidden rounded-[2rem] border border-[var(--border-subtle)] bg-[linear-gradient(180deg,rgba(255,255,255,0.82)_0%,rgba(255,255,255,0.46)_100%)] p-7 shadow-[0_18px_40px_rgba(15,18,24,0.05)] md:p-10">
          <div className="grid gap-8 lg:grid-cols-[1.05fr,0.95fr]">
            <div>
              <p className="mb-3 text-xs uppercase tracking-[0.14em] text-forma-steel-blue">
                {eyebrow}
              </p>
              <h1 className="text-4xl font-semibold tracking-[-0.03em] text-[var(--text-primary)] md:text-5xl">
                {title}
              </h1>
              <p className="mt-4 max-w-3xl text-base leading-relaxed text-[var(--text-secondary)]">
                {description}
              </p>

              <div className="mt-6 flex flex-wrap gap-2">
                <span className="rounded-full border border-[var(--border-medium)] bg-[rgba(255,255,255,0.72)] px-3 py-1.5 text-xs font-medium text-[var(--text-secondary)]">
                  Last updated {lastUpdated}
                </span>
                {summaryChips.map((chip) => (
                  <span
                    key={chip}
                    className="rounded-full border border-[var(--border-medium)] bg-[rgba(255,255,255,0.72)] px-3 py-1.5 text-xs font-medium text-[var(--text-secondary)]"
                  >
                    {chip}
                  </span>
                ))}
              </div>
            </div>

            <section className="rounded-[1.5rem] border border-[var(--border-subtle)] bg-[rgba(255,255,255,0.58)] p-6">
              <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-forma-steel-blue">
                In plain language
              </p>
              <h2 className="mt-4 text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
                {plainLanguageTitle}
              </h2>
              <ul className="mt-4 space-y-3">
                {plainLanguagePoints.map((item) => (
                  <li key={item} className="flex items-start gap-3">
                    <span className="mt-[6px] h-2 w-2 rounded-full bg-forma-sage" />
                    <span className="text-sm leading-relaxed text-[var(--text-secondary)]">
                      {item}
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          </div>
        </header>

        <div className="mt-8 grid gap-6 lg:grid-cols-[1.08fr,0.92fr]">
          <section className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-7 md:p-8">
            <div className="space-y-8">
              {sections.map((section, index) => (
                <section
                  key={`${section.title ?? "intro"}-${index}`}
                  className="border-b border-[var(--border-subtle)] pb-8 last:border-b-0 last:pb-0"
                >
                  {section.title ? (
                    <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
                      {section.title}
                    </h2>
                  ) : null}
                  <div className="mt-3 space-y-3 text-[15px] leading-relaxed text-[var(--text-secondary)]">
                    {section.paragraphs.map((paragraph) => (
                      <p key={paragraph}>{paragraph}</p>
                    ))}
                  </div>
                </section>
              ))}
            </div>
          </section>

          <div className="space-y-6">
            <section className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-7">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
                Questions or concerns?
              </h2>
              <p className="mt-3 text-[15px] leading-relaxed text-[var(--text-secondary)]">
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

            <section className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-7">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
                Related pages
              </h2>
              <ul className="mt-4 space-y-4">
                {relatedLinks.map((link) => (
                  <li key={link.href} className="rounded-xl border border-[var(--border-subtle)] bg-[var(--surface-glass)] p-4">
                    <Link
                      href={link.href}
                      className="text-sm font-semibold text-forma-steel-blue transition-opacity hover:opacity-80"
                    >
                      {link.label}
                    </Link>
                    <p className="mt-1 text-sm leading-relaxed text-[var(--text-secondary)]">
                      {link.description}
                    </p>
                  </li>
                ))}
              </ul>
            </section>
          </div>
        </div>

        <div className="mt-10">
          <Link
            href="/"
            className="text-sm text-[var(--text-muted)] transition-colors hover:text-[var(--text-secondary)]"
          >
            &larr; Back to home
          </Link>
        </div>
      </div>
    </main>
  );
}
