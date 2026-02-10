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
import { SectionTransition } from "@/components/animation/SectionTransition";

export default function Home() {
  return (
    <div className="bg-[var(--bg-primary)]">
      <SpotlightCursor />
      <main id="top" className="relative overflow-hidden">
        <AuroraBackground>
          <HeroSection />
          <CredibilityStrip />
        </AuroraBackground>
        <SectionTransition fromColor="var(--bg-primary)" toColor="#0F0F11" height="80px" />
        <FeaturesSection />
        <SectionTransition fromColor="#0F0F11" toColor="var(--bg-primary)" height="80px" />
        <BeforeAfterSection />
        <SectionTransition fromColor="var(--bg-primary)" toColor="var(--bg-secondary)" height="60px" />
        <PricingSection />
        <SectionTransition fromColor="var(--bg-secondary)" toColor="var(--bg-secondary)" height="40px" />
        <FAQSection />
        <SectionTransition fromColor="var(--bg-secondary)" toColor="var(--bg-primary)" height="60px" />
        <NewsletterSection />
      </main>
      <Footer />
    </div>
  );
}
