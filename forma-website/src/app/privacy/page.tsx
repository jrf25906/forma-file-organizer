import type { Metadata } from "next";
import Link from "next/link";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import { SUPPORT_EMAIL } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How Forma handles data in the app and on the website.",
  alternates: {
    canonical: "https://formafiles.com/privacy",
  },
};

export default function PrivacyPolicyPage() {
  return (
    <main id="main-content" className="relative py-24 overflow-hidden">
      <div className="orb orb-sage w-96 h-96 top-0 left-1/4 animate-float-slower opacity-20" />
      <div className="orb orb-blue w-72 h-72 bottom-1/4 right-0 animate-float opacity-20" />

      <div className="relative z-10 max-w-3xl mx-auto px-6">
        <div className="glass-card rounded-2xl p-8 md:p-12">
          <h1 className="mb-2 font-display text-3xl text-[var(--text-primary)] md:text-4xl">
            Privacy Policy
          </h1>
          <p className="mb-8 text-sm text-[var(--text-muted)]">
            Effective date: 2026-02-04
          </p>

          <div className="space-y-8 leading-relaxed text-[var(--text-secondary)]">
            <section className="space-y-3">
              <p>
                Forma is built to keep your files private. The app runs
                locally, and your file names, folder structure, and contents
                are not uploaded to our servers for processing.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="font-display text-xl text-[var(--text-primary)]">
                What the app stores on your device
              </h2>
              <p>
                To provide file-organization features, Forma may process and
                store data locally on your Mac, including file metadata (such
                as names, paths, sizes, timestamps, and types), rules and
                preferences, activity/undo history, and on-device analytics.
                This data remains on your device.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="font-display text-xl text-[var(--text-primary)]">
                Third-party AI services
              </h2>
              <p>
                Forma does not send your file data to third-party AI services
                for processing. Smart features run locally on your Mac.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="font-display text-xl text-[var(--text-primary)]">
                Folder permissions and bookmarks
              </h2>
              <p>
                Forma only accesses folders you explicitly grant permission to
                on macOS. If you grant access, Forma may store security-scoped
                bookmarks locally (including in the Keychain) to remember that
                permission.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="font-display text-xl text-[var(--text-primary)]">
                Website data
              </h2>
              <p>
                When you visit the website, our hosting provider may process
                standard request logs (for example: IP address and user agent)
                for security and reliability. If we add analytics, we&apos;ll
                update this policy and describe how to opt out where
                applicable.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="font-display text-xl text-[var(--text-primary)]">
                Contact
              </h2>
              <p>
                Questions? Email{" "}
                <TrackedMailtoLink
                  email={SUPPORT_EMAIL}
                  location="privacy_page"
                  className="text-forma-sage hover:opacity-80 transition-opacity"
                >
                  {SUPPORT_EMAIL}
                </TrackedMailtoLink>
                .
              </p>
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
