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
} from "@/components";

export default function Home() {
  return (
    <main id="main-content" className="relative" tabIndex={-1}>
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
