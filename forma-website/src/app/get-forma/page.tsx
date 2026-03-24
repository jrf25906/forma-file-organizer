import type { Metadata } from "next";
import Link from "next/link";
import { MAC_APP_STORE_URL } from "@/lib/links";

export const metadata: Metadata = {
  title: "Get Forma",
  description:
    "Download Forma for Mac and get support with setup if needed.",
  alternates: {
    canonical: "https://formafiles.com/get-forma",
  },
};

export default function GetFormaPage() {
  const liveMacAppStoreUrl = MAC_APP_STORE_URL;

  return (
    <main id="main-content" className="relative py-20 md:py-24">
      <div className="site-container mx-auto max-w-4xl">
        <header className="mb-10 border-b border-[var(--border-subtle)] pb-8">
          <p className="mb-3 text-xs uppercase tracking-[0.14em] text-[var(--text-muted)]">
            Get Forma
          </p>
          <h1 className="text-4xl font-semibold tracking-[-0.02em] text-[var(--text-primary)] md:text-5xl">
            $29 once. Download Forma for Mac.
          </h1>
          <p className="mt-4 max-w-3xl text-base leading-relaxed text-[var(--text-secondary)]">
            Forma is a native macOS file organizer for macOS 15 or later. Download it from the
            Mac App Store, then start with one rule and one folder.
          </p>
        </header>

        <div className="grid gap-6 lg:grid-cols-[1.05fr,0.95fr]">
          <section className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-7 md:p-8">
            <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
              Download and start clean
            </h2>
            <p className="mt-3 max-w-xl text-[15px] leading-relaxed text-[var(--text-secondary)]">
              The shortest path is still the right one: install, create one plain-language rule,
              preview the batch, then organize.
            </p>

            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <a
                href={liveMacAppStoreUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center rounded-xl bg-[var(--cta-bg)] px-6 py-3.5 text-sm font-semibold text-[var(--cta-text)] transition-colors hover:bg-[var(--cta-bg-hover)]"
              >
                Open Mac App Store
              </a>

              <Link
                href="/support"
                className="inline-flex items-center justify-center rounded-xl border border-[var(--border-medium)] px-6 py-3.5 text-sm font-semibold text-[var(--text-primary)] transition-colors hover:border-[var(--border-strong)] hover:bg-[var(--surface-glass)]"
              >
                Contact Support
              </Link>
            </div>
          </section>

          <section className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-7 md:p-8">
            <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
              What you get
            </h2>
            <ul className="mt-4 space-y-3">
              {[
                "Plain-language rules instead of brittle file scripts",
                "Preview-first review before files move",
                "Undo built into the workflow, not hidden after the fact",
                "Local-only operation with no account wall",
              ].map((item) => (
                <li key={item} className="flex items-start gap-3">
                  <span className="mt-[6px] h-2 w-2 rounded-full bg-forma-sage" />
                  <span className="text-sm leading-relaxed text-[var(--text-secondary)]">{item}</span>
                </li>
              ))}
            </ul>
          </section>
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
