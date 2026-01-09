import {
  Navigation,
  Hero,
  LogoMarquee,
  Features,
  UglyReality,
  Architecture,
  Personas,
  Privacy,
  Comparison,
  HowItWorks,
  Pricing,
  Testimonials,
  FAQ,
  DownloadCTA,
  Footer,
  GridBackground,
} from "@/components";

export default function Home() {
  return (
    <main id="main-content" className="relative" tabIndex={-1}>
      {/* Grid background - structure emergence effect */}
      <GridBackground />
      <Navigation />
      <Hero />
      <LogoMarquee />
      <Features />
      <UglyReality />
      <Architecture />
      <Personas />
      <Privacy />
      <Comparison />
      <HowItWorks />
      <Pricing />
      <Testimonials />
      <FAQ />
      <DownloadCTA />
      <Footer />
    </main>
  );
}
