import type { Metadata } from "next";

import { Footer } from "@/components/Footer";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How Forma handles data in the app and on the website.",
};

export default function PrivacyPolicyPage() {
  return (
    <div className="relative min-h-screen">
      <main className="relative z-10 mb-[220px] shadow-2xl overflow-hidden">
        <section className="relative px-6 py-section-lg">
          <div className="max-w-3xl mx-auto">
            <div className="rounded-2xl border border-forma-bone/10 bg-forma-obsidian/70 backdrop-blur-md p-8 md:p-12">
              <h1 className="font-display text-4xl md:text-5xl text-forma-bone mb-3">
                Privacy Policy
              </h1>
              <p className="text-sm text-forma-bone/50 mb-10">
                Effective date: 2026-02-04
              </p>

              <div className="space-y-10 text-forma-bone/70 leading-relaxed">
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
                    Forma only accesses folders you explicitly grant permission
                    to on macOS. If you grant access, Forma may store
                    security-scoped bookmarks locally (including in the
                    Keychain) to remember that permission.
                  </p>
                </section>

                <section className="space-y-3">
                  <h2 className="font-display text-xl text-forma-bone">
                    Website data
                  </h2>
                  <p>
                    When you visit the website, our hosting provider may process
                    standard request logs (for example: IP address and user
                    agent) for security and reliability. If we add analytics,
                    we&apos;ll update this policy and describe how to opt out
                    where applicable.
                  </p>
                </section>

                <section className="space-y-3">
                  <h2 className="font-display text-xl text-forma-bone">
                    Contact
                  </h2>
                  <p>
                    Questions? Email{" "}
                    <a
                      className="text-forma-steel-blue hover:opacity-80 transition-opacity"
                      href="mailto:hello@forma.app"
                    >
                      hello@forma.app
                    </a>
                    .
                  </p>
                </section>
              </div>
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </div>
  );
}

