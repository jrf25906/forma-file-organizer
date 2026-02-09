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
import { AuroraBackground } from "@/components/ui/AuroraBackground";
import { SpotlightCursor } from "@/components/ui/SpotlightCursor";

export default function Home() {
  return (
    <div className="bg-forma-bone">
      <SpotlightCursor />
      <main id="top" className="relative overflow-hidden">
        <AuroraBackground>
          <HeroSection />
          <CredibilityStrip />
        </AuroraBackground>
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
