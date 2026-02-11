import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Support",
  description:
    "Get help with Forma, contact support, and find troubleshooting tips.",
  alternates: {
    canonical: "https://formafiles.com/support",
  },
};

export default function SupportPage() {
  return (
    <main id="main-content" className="relative py-24 overflow-hidden">
      <div className="orb orb-sage w-96 h-96 top-0 left-1/4 animate-float-slower opacity-20" />
      <div className="orb orb-blue w-72 h-72 bottom-1/4 right-0 animate-float opacity-20" />

      <div className="relative z-10 max-w-3xl mx-auto px-6">
        <div className="glass-card rounded-2xl p-8 md:p-12">
          <h1 className="mb-4 font-display text-3xl text-[var(--text-primary)] md:text-4xl">
            Support
          </h1>
          <p className="mb-8 leading-relaxed text-[var(--text-secondary)]">
            Need help with Forma? Email us and include any details that might
            help (macOS version, what you expected to happen, and what
            happened).
          </p>

          <div className="space-y-6 leading-relaxed text-[var(--text-secondary)]">
            <section className="space-y-3">
              <h2 className="font-display text-xl text-[var(--text-primary)]">
                Contact
              </h2>
              <p>
                <a
                  className="text-forma-sage hover:opacity-80 transition-opacity"
                  href="mailto:hello@forma.app"
                >
                  hello@forma.app
                </a>
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="font-display text-xl text-[var(--text-primary)]">
                Common issues
              </h2>
              <ul className="list-disc pl-5 space-y-2">
                <li>
                  If a folder isn&apos;t scanning, re-grant access in Forma
                  and macOS settings.
                </li>
                <li>
                  If a move fails, check that the destination folder has
                  permission and enough free space.
                </li>
                <li>
                  If you want to reset permissions, remove the folder from
                  Forma and re-add it.
                </li>
              </ul>
            </section>
          </div>

          <div className="mt-12 border-t border-[var(--border-subtle)] pt-8">
            <Link
              href="/"
              className="text-sm text-[var(--text-muted)] transition-colors hover:text-[var(--text-secondary)]"
            >
              &larr; Back to home
            </Link>
          </div>
        </div>
      </div>
    </main>
  );
}
