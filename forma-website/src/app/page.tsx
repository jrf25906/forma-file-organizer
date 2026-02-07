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
    <>
      <main className="relative mb-[220px] shadow-2xl overflow-hidden bg-forma-obsidian">
        <HeroSection />
        <CredibilityStrip />
        <FeaturesSection />
        <BeforeAfterSection />
        <PricingSection />
        <FAQSection />
        <NewsletterSection />
      </main>
      <Footer />
    </>
  );
}
