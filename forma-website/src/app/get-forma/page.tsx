import type { Metadata } from "next";
import Link from "next/link";

const PLACEHOLDER_MAC_APP_STORE_URL = "https://apps.apple.com/app/forma/id0000000000";

export const metadata: Metadata = {
  title: "Get Forma",
  description:
    "Download Forma for macOS. If the App Store link is not available yet, join launch updates.",
  alternates: {
    canonical: "https://formafiles.com/get-forma",
  },
};

export default function GetFormaPage() {
  const configuredMacAppStoreUrl = process.env.NEXT_PUBLIC_MAC_APP_STORE_URL?.trim();
  const liveMacAppStoreUrl =
    configuredMacAppStoreUrl &&
    configuredMacAppStoreUrl !== PLACEHOLDER_MAC_APP_STORE_URL
      ? configuredMacAppStoreUrl
      : null;

  return (
    <main id="main-content" className="relative overflow-hidden py-24">
      <div className="orb orb-sage h-96 w-96 left-1/4 top-0 animate-float-slower opacity-20" />
      <div className="orb orb-blue h-72 w-72 bottom-1/4 right-0 animate-float opacity-20" />

      <div className="relative z-10 mx-auto max-w-3xl px-6">
        <div className="glass-card rounded-2xl p-8 md:p-12">
          <h1 className="font-display text-3xl text-[var(--text-primary)] md:text-4xl">
            Get Forma
          </h1>
          <p className="mt-4 max-w-2xl leading-relaxed text-[var(--text-secondary)]">
            Forma is a native macOS file organizer built for macOS 15+.
            Download from the Mac App Store, or join launch updates below if the listing is
            not live in your region yet.
          </p>

          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            {liveMacAppStoreUrl ? (
              <a
                href={liveMacAppStoreUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center rounded-xl bg-[var(--cta-bg)] px-6 py-3 text-sm font-semibold text-[var(--cta-text)] transition-all hover:bg-[var(--cta-bg-hover)]"
              >
                Open in Mac App Store
              </a>
            ) : (
              <Link
                href="/#newsletter"
                className="inline-flex items-center justify-center rounded-xl bg-[var(--cta-bg)] px-6 py-3 text-sm font-semibold text-[var(--cta-text)] transition-all hover:bg-[var(--cta-bg-hover)]"
              >
                Join Launch Updates
              </Link>
            )}

            <Link
              href="/support"
              className="inline-flex items-center justify-center rounded-xl border border-[var(--border-medium)] px-6 py-3 text-sm font-medium text-[var(--text-secondary)] transition-colors hover:border-[var(--border-strong)] hover:text-[var(--text-primary)]"
            >
              Contact Support
            </Link>
          </div>

          <div className="mt-10 border-t border-[var(--border-subtle)] pt-6">
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
