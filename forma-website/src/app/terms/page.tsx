import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Terms of Use",
  description: "Terms of use for the Forma macOS app and related services.",
};

export default function TermsPage() {
  return (
    <section className="relative py-24 overflow-hidden">
      <div className="orb orb-blue w-96 h-96 top-0 right-1/4 animate-float-slower opacity-20" />
      <div className="orb orb-sage w-72 h-72 bottom-1/4 left-0 animate-float opacity-20" />

      <div className="relative z-10 max-w-3xl mx-auto px-6">
        <div className="glass-card rounded-2xl p-8 md:p-12">
          <h1 className="font-display text-3xl md:text-4xl text-forma-bone mb-2">
            Terms of Use (EULA)
          </h1>
          <p className="text-sm text-forma-bone/50 mb-8">
            Effective date: 2026-02-04
          </p>

          <div className="space-y-8 text-forma-bone/70 leading-relaxed">
            <section className="space-y-3">
              <p>
                These Terms govern your use of the Forma macOS application
                (the &quot;App&quot;). If you download the App from the Mac App
                Store, your use may also be subject to Apple&apos;s terms and
                policies.
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
