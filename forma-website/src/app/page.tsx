import Link from "next/link";
import {
  HeroSection,
  CredibilityStrip,
  FeaturesSection,
  BeforeAfterSection,
  SocialProofSection,
  PricingSection,
  FAQSection,
  NewsletterSection,
} from "@/components/sections";
import Footer from "@/components/Footer";
import { SectionTransition } from "@/components/animation/SectionTransition";
import { faqs } from "@/lib/faq";
import { SITE_NAME, SITE_URL, WEBSITE_LAST_UPDATED_ISO } from "@/lib/site";

export default function Home() {
  const softwareApplicationJsonLd = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: SITE_NAME,
    applicationCategory: "ProductivityApplication",
    operatingSystem: "macOS 15+",
    offers: {
      "@type": "Offer",
      price: "29",
      priceCurrency: "USD",
      description: "One-time purchase. No subscription.",
      url: `${SITE_URL}/#pricing`,
    },
    description:
      "A file organizer for people who gave up on file organizers. Make rules, preview, approve, undo.",
    featureList: [
      "Human-readable rules",
      "Preview before moving",
      "Full undo history",
      "Local-only privacy",
    ],
    url: SITE_URL,
  };

  const organizationJsonLd = {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: SITE_NAME,
    url: SITE_URL,
    sameAs: [],
  };

  const websiteJsonLd = {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: SITE_NAME,
    url: SITE_URL,
    inLanguage: "en-US",
    dateModified: WEBSITE_LAST_UPDATED_ISO,
  };

  const faqJsonLd = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqs.map((faqEntry) => ({
      "@type": "Question",
      name: faqEntry.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: faqEntry.answer,
      },
    })),
  };

  return (
    <div className="bg-[var(--bg-primary)]">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@graph": [
              softwareApplicationJsonLd,
              organizationJsonLd,
              websiteJsonLd,
              faqJsonLd,
            ],
          }),
        }}
      />

      <main id="top" className="relative overflow-x-clip">
        <HeroSection />
        <CredibilityStrip />
        <SectionTransition
          fromColor="var(--bg-primary)"
          toColor="var(--features-bg-from)"
          height="clamp(8px, 1.8vw, 24px)"
        />
        <FeaturesSection />
        <SectionTransition
          fromColor="var(--features-bg-from)"
          toColor="var(--bg-primary)"
          height="clamp(4px, 1vw, 12px)"
        />
        <BeforeAfterSection />
        <SocialProofSection />
        <SectionTransition
          fromColor="var(--bg-primary)"
          toColor="var(--bg-secondary)"
          height="clamp(8px, 1.8vw, 24px)"
        />
        <PricingSection />
        <FAQSection />

        <section id="guides" className="py-10 md:py-14">
          <div className="site-container">
            <div className="mx-auto max-w-4xl rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-6 md:p-8">
              <p className="text-xs uppercase tracking-[0.14em] text-[var(--text-muted)]">
                Learn
              </p>
              <h2 className="mt-3 font-display text-3xl text-[var(--text-primary)] md:text-4xl">
                Guides for organizing Mac files
              </h2>
              <p className="mt-3 max-w-2xl text-[15px] leading-relaxed text-[var(--text-secondary)]">
                Read practical, workflow-first guides built around real desktop
                cleanup and maintenance habits.
              </p>
              <div className="mt-6 grid gap-3 md:grid-cols-3">
                <Link
                  href="/blog/organize-mac-files"
                  className="rounded-xl border border-[var(--border-subtle)] px-4 py-3 text-sm text-[var(--text-secondary)] transition-colors hover:border-[var(--border-medium)] hover:text-[var(--text-primary)]"
                >
                  How to Organize Mac Files
                </Link>
                <Link
                  href="/blog/organize-downloads-folder-mac"
                  className="rounded-xl border border-[var(--border-subtle)] px-4 py-3 text-sm text-[var(--text-secondary)] transition-colors hover:border-[var(--border-medium)] hover:text-[var(--text-primary)]"
                >
                  Organize Downloads Folder on Mac
                </Link>
                <Link
                  href="/blog/organize-desktop-files-mac"
                  className="rounded-xl border border-[var(--border-subtle)] px-4 py-3 text-sm text-[var(--text-secondary)] transition-colors hover:border-[var(--border-medium)] hover:text-[var(--text-primary)]"
                >
                  Organize Desktop Files on Mac
                </Link>
              </div>
            </div>
          </div>
        </section>

        <NewsletterSection />
      </main>
      <Footer />
    </div>
  );
}
