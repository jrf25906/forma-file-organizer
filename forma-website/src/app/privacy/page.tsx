import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How Forma handles data in the app and on the website.",
};

export default function PrivacyPolicyPage() {
  return (
    <section className="relative py-24 overflow-hidden">
      <div className="orb orb-sage w-96 h-96 top-0 left-1/4 animate-float-slower opacity-20" />
      <div className="orb orb-blue w-72 h-72 bottom-1/4 right-0 animate-float opacity-20" />

      <div className="relative z-10 max-w-3xl mx-auto px-6">
        <div className="glass-card rounded-2xl p-8 md:p-12">
          <h1 className="font-display text-3xl md:text-4xl text-forma-bone mb-2">
            Privacy Policy
          </h1>
          <p className="text-sm text-forma-bone/50 mb-8">
            Effective date: 2026-02-04
          </p>

          <div className="space-y-8 text-forma-bone/70 leading-relaxed">
            <section className="space-y-3">
              <p>
                Forma is built to keep your files private. The app runs
                locally, and your file names, folder structure, and contents
                are not uploaded to our servers for processing.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="font-display text-xl text-forma-bone">
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
              <h2 className="font-display text-xl text-forma-bone">
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
              <h2 className="font-display text-xl text-forma-bone">
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
              <h2 className="font-display text-xl text-forma-bone">
                Contact
              </h2>
              <p>
                Questions? Email{" "}
                <a
                  className="text-forma-sage hover:opacity-80 transition-opacity"
                  href="mailto:hello@forma.app"
                >
                  hello@forma.app
                </a>
                .
              </p>
            </section>
          </div>

          <div className="mt-12 pt-8 border-t border-forma-bone/10">
            <Link
              href="/"
              className="text-sm text-forma-bone/50 hover:text-forma-bone/70 transition-colors"
            >
              &larr; Back to home
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}
