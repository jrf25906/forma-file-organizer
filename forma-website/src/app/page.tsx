import {
  HeroSection,
  CredibilityStrip,
  FeaturesSection,
  MidPageCTA,
  BeforeAfterSection,
  PricingSection,
  FAQSection,
  NewsletterSection,
} from "@/components/sections";
import Footer from "@/components/Footer";

export default function Home() {
  return (
    <div className="bg-[linear-gradient(180deg,#ffffff_0%,#f2f4f7_100%)]">
      <main id="top" className="relative overflow-hidden">
        <HeroSection />
        <CredibilityStrip />
        <FeaturesSection />
        <MidPageCTA heading="Ready to get organized?" />
        <BeforeAfterSection />
        <MidPageCTA heading="Join thousands of organized desktops." />
        <PricingSection />
        <FAQSection />
        <NewsletterSection />
      </main>
      <Footer />
    </div>
  );
}
