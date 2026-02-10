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
import { SectionTransition } from "@/components/animation/SectionTransition";

export default function Home() {
  return (
    <div className="bg-[var(--bg-primary)]">
      <main id="top" className="relative overflow-x-clip">
        <HeroSection />
        <CredibilityStrip />
        <SectionTransition fromColor="var(--bg-primary)" toColor="#0F0F11" height="40px" />
        <FeaturesSection />
        <SectionTransition fromColor="#0F0F11" toColor="var(--bg-primary)" height="32px" />
        <BeforeAfterSection />
        <SectionTransition fromColor="var(--bg-primary)" toColor="var(--bg-secondary)" height="40px" />
        <PricingSection />
        <FAQSection />
        <NewsletterSection />
      </main>
      <Footer />
    </div>
  );
}
