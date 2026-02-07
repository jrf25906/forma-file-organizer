import {
  HeroSection,
  CredibilityStrip,
  FeaturesSection,
  BeforeAfterSection,
  PricingSection,
  FAQSection,
  NewsletterSection,
} from "@/components/sections";
import Footer from "@/components/Footer";

export default function Home() {
  return (
    <div className="gradient-bg">
      <main id="top" className="relative overflow-hidden">
        <HeroSection />
        <CredibilityStrip />
        <FeaturesSection />
        <BeforeAfterSection />
        <PricingSection />
        <FAQSection />
        <NewsletterSection />
      </main>
      <Footer />
    </div>
  );
}
