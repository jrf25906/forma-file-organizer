import type { Metadata } from "next";
import Link from "next/link";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import { SUPPORT_EMAIL } from "@/lib/site";

export const metadata: Metadata = {
  title: "Support",
  description:
    "Get help with Forma setup, permissions, and organization workflows.",
  alternates: {
    canonical: "https://formafiles.com/support",
  },
};

export default function SupportPage() {
  return (
    <main id="main-content" className="relative py-20 md:py-24">
      <div className="site-container mx-auto max-w-4xl">
        <header className="mb-10 border-b border-[var(--border-subtle)] pb-8">
          <p className="mb-3 text-xs uppercase tracking-[0.14em] text-[var(--text-muted)]">
            Support
          </p>
          <h1 className="text-4xl font-semibold tracking-[-0.02em] text-[var(--text-primary)] md:text-5xl">
            Support without a ticket maze
          </h1>
          <p className="mt-4 max-w-2xl text-base leading-relaxed text-[var(--text-secondary)]">
            Send what happened, what you expected, and your macOS version. We will help you get
            unstuck without making you fight the website first.
          </p>
        </header>

        <div className="grid gap-6 md:grid-cols-[0.9fr,1.1fr]">
          <section className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-7">
            <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
              Contact
            </h2>
            <p className="mt-3 text-[15px] leading-relaxed text-[var(--text-secondary)]">
              Include the folder involved, what rule or action you ran, and whether the issue is
              repeatable.
            </p>
            <p className="mt-5">
              <TrackedMailtoLink
                email={SUPPORT_EMAIL}
                location="support_page"
                className="text-forma-steel-blue transition-opacity hover:opacity-80"
              >
                {SUPPORT_EMAIL}
              </TrackedMailtoLink>
            </p>
          </section>

          <section className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-7">
            <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
              Quick fixes
            </h2>
            <ul className="mt-4 list-disc space-y-2 pl-5 text-[15px] leading-relaxed text-[var(--text-secondary)]">
              <li>
                If a folder is not scanning, remove it and add it again in Forma, then confirm
                access in macOS settings.
              </li>
              <li>
                If a move fails, confirm the destination folder is available and has enough free
                space.
              </li>
              <li>
                If results look off, run preview again and adjust your rule before approving
                changes.
              </li>
            </ul>
          </section>
        </div>

        <section className="mt-6 rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-7">
          <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
            Guides
          </h2>
          <p className="mt-3 max-w-2xl text-[15px] leading-relaxed text-[var(--text-secondary)]">
            If you want the workflow behind the product instead of just the fix, start here.
          </p>
          <ul className="mt-5 list-disc space-y-2 pl-5 text-[15px] leading-relaxed text-[var(--text-secondary)]">
            <li>
              <Link
                href="/blog/organize-mac-files"
                className="text-forma-steel-blue transition-opacity hover:opacity-80"
              >
                How to Organize Mac Files
              </Link>
            </li>
            <li>
              <Link
                href="/blog/organize-downloads-folder-mac"
                className="text-forma-steel-blue transition-opacity hover:opacity-80"
              >
                Organize Downloads Folder on Mac
              </Link>
            </li>
            <li>
              <Link
                href="/blog/organize-desktop-files-mac"
                className="text-forma-steel-blue transition-opacity hover:opacity-80"
              >
                Organize Desktop Files on Mac
              </Link>
            </li>
          </ul>
        </section>

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
