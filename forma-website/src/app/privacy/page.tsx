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
    <main id="main-content" className="bg-[#FAFAF8] py-14 md:py-20">
      <div className="site-container mx-auto max-w-4xl">
        <div className="rounded-2xl border border-[#E5E7EB] bg-[#F2F2F0] p-7 md:p-10">
          <h1 className="mb-2 text-4xl font-semibold tracking-[-0.02em] text-[#1C1C1E] md:text-5xl">
            Privacy
          </h1>
          <p className="mb-8 text-sm text-[#646A75]">
            Last updated: February 4, 2026
          </p>

          <div className="space-y-8 text-[16px] leading-relaxed text-[#555555]">
            <section className="space-y-3">
              <p>
                Forma is built around local processing. File names, folder
                structure, and file contents stay on your Mac unless you
                explicitly share them.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                What Forma stores on your Mac
              </h2>
              <p>
                To organize files, Forma stores data locally on your Mac,
                including file metadata (such as names, paths, sizes,
                timestamps, and types), your rules and preferences, and
                activity and undo history.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                AI and third-party processing
              </h2>
              <p>
                Forma does not send your file data to third-party AI services
                for organization. Smart features run on your Mac.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                Data sales and sharing
              </h2>
              <p>
                We do not sell your file data or share it with data brokers.
                Data access is limited to operating the app and keeping the
                website secure and reliable.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                Folder permissions and bookmarks
              </h2>
              <p>
                Forma only accesses folders you explicitly grant permission to
                in macOS. If you grant access, Forma stores security-scoped
                bookmarks locally (including in your Keychain) so it can keep
                that permission.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                Website data
              </h2>
              <p>
                When you visit formafiles.com, our hosting provider may process
                standard request logs (for example, IP address and user agent)
                for security and reliability. If we add analytics, we&apos;ll
                update this policy with details and available controls.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                Policy updates
              </h2>
              <p>
                If this policy changes, we will update the &quot;Last
                updated&quot; date on this page and publish the revised
                version here.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                Contact
              </h2>
              <p>
                Questions? Email{" "}
                <TrackedMailtoLink
                  email={SUPPORT_EMAIL}
                  location="privacy_page"
                  className="text-[#4A6B88] transition-opacity hover:opacity-80"
                >
                  {SUPPORT_EMAIL}
                </TrackedMailtoLink>
                .
              </p>
            </section>
          </div>

          <div className="mt-12 border-t border-[#D9DDE2] pt-8">
            <Link
              href="/"
              className="text-sm text-[#646A75] transition-colors hover:text-[#4C5463]"
            >
              &larr; Back to home
            </Link>
          </div>
        </div>
      </div>
    </main>
  );
}
