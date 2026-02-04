import type { Metadata } from "next";

import { Footer } from "@/components/Footer";

export const metadata: Metadata = {
  title: "Terms of Use",
  description: "Terms of use for the Forma macOS app and related services.",
};

export default function TermsPage() {
  return (
    <div className="relative min-h-screen">
      <main className="relative z-10 mb-[220px] shadow-2xl overflow-hidden">
        <section className="relative px-6 py-section-lg">
          <div className="max-w-3xl mx-auto">
            <div className="rounded-2xl border border-forma-bone/10 bg-forma-obsidian/70 backdrop-blur-md p-8 md:p-12">
              <h1 className="font-display text-4xl md:text-5xl text-forma-bone mb-3">
                Terms of Use (EULA)
              </h1>
              <p className="text-sm text-forma-bone/50 mb-10">
                Effective date: 2026-02-04
              </p>

              <div className="space-y-10 text-forma-bone/70 leading-relaxed">
                <section className="space-y-3">
                  <p>
                    These Terms govern your use of the Forma macOS application
                    (the &quot;App&quot;). If you download the App from the Mac
                    App Store, your use may also be subject to Apple&apos;s
                    terms and policies.
                  </p>
                </section>

                <section className="space-y-3">
                  <h2 className="font-display text-xl text-forma-bone">
                    License
                  </h2>
                  <p>
                    Forma grants you a limited, non-exclusive, non-transferable,
                    revocable license to install and use the App for your own
                    personal or internal business use, subject to these Terms.
                  </p>
                </section>

                <section className="space-y-3">
                  <h2 className="font-display text-xl text-forma-bone">
                    No warranty
                  </h2>
                  <p>
                    The App is provided &quot;AS IS&quot; and &quot;AS
                    AVAILABLE&quot; without warranties of any kind.
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

