import {
  Navigation,
  Hero,
  Pricing,
  FAQ,
  Footer,
} from "@/components";

export default function Home() {
  return (
    <main id="main-content" className="relative" tabIndex={-1}>
      <Navigation />
      <Hero />
      <Pricing />
      <FAQ />
      <Footer />
    </main>
  );
}
