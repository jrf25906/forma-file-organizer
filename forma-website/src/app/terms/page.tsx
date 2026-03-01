import type { Metadata } from "next";
import Link from "next/link";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import { SUPPORT_EMAIL } from "@/lib/site";

export const metadata: Metadata = {
  title: "Terms of Use",
  description: "Terms for using the Forma macOS app and related services.",
  alternates: {
    canonical: "https://formafiles.com/terms",
  },
};

export default function TermsPage() {
  return (
    <main id="main-content" className="bg-[#FAFAF8] py-14 md:py-20">
      <div className="site-container mx-auto max-w-4xl">
        <div className="rounded-2xl border border-[#E5E7EB] bg-[#F2F2F0] p-7 md:p-10">
          <h1 className="mb-2 text-4xl font-semibold tracking-[-0.02em] text-[#1C1C1E] md:text-5xl">
            Terms of Use
          </h1>
          <p className="mb-8 text-sm text-[#646A75]">
            Last updated: February 4, 2026
          </p>

          <div className="space-y-8 text-[16px] leading-relaxed text-[#555555]">
            <section className="space-y-3">
              <p>
                These terms govern your use of the Forma macOS app
                (&quot;App&quot;). If you download Forma from the Mac App Store,
                Apple&apos;s terms and policies also apply.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                License
              </h2>
              <p>
                We grant you a limited, non-exclusive, non-transferable,
                revocable license to install and use the App for your personal
                use or internal business use, subject to these terms.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                Acceptable use
              </h2>
              <p>
                You agree not to misuse the App, attempt to reverse engineer
                it beyond what is allowed by applicable law, or use it in ways
                that violate the rights of others.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                Warranty disclaimer
              </h2>
              <p>
                The App is provided &quot;AS IS&quot; and &quot;AS
                AVAILABLE&quot; without warranties of any kind.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                Limitation of liability
              </h2>
              <p>
                To the fullest extent permitted by law, Forma is not liable for
                indirect, incidental, special, or consequential damages arising
                from use of the App.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                Changes to these terms
              </h2>
              <p>
                We may update these terms from time to time. If we do, we will
                update the &quot;Last updated&quot; date on this page.
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
                  location="terms_page"
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
