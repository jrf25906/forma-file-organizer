import type { Metadata } from "next";
import { DM_Sans, Instrument_Serif, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import clsx from "clsx";
import { LenisGSAPProvider } from "@/lib/animation";
import { Header } from "@/components/Header";
import { SpotlightCursor } from "@/components/ui/SpotlightCursor";

// Editorial serif for dramatic headlines
// adjustFontFallback: Reduces CLS by adjusting fallback font metrics
// to match Instrument Serif's character widths and line heights
const instrumentSerif = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  variable: "--font-display",
  display: "swap",
  adjustFontFallback: true,
});

// Clean sans for body - distinctive but readable
const dmSans = DM_Sans({
  subsets: ["latin"],
  variable: "--font-body",
  display: "swap",
  adjustFontFallback: true,
});

// Monospace for technical moments
const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-mono",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://forma.app"),
  title: {
    default: "Forma | Give your files form",
    template: "%s | Forma",
  },
  description:
    "Intelligent file organization for macOS. Forma uses local AI to group files by context, project, and workflow—not just file type. 100% private, native Swift.",
  keywords: ["file organizer", "macOS utility", "productivity app", "local AI", "desktop cleanup"],
  authors: [{ name: "Forma Team" }],
  openGraph: {
    title: "Forma | Give your files form",
    description: "Stop organizing. Start working. The native macOS app that organizes your files by context, not just extension.",
    url: "https://forma.app",
    siteName: "Forma",
    locale: "en_US",
    type: "website",
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
    apple: "/app-icon-1024.svg",
  },
  twitter: {
    card: "summary_large_image",
    title: "Forma",
    description: "Intelligent file organization for creative professionals.",
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  // Structured Data for LLMs and Search Engines
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "Forma",
    "applicationCategory": "ProductivityApplication",
    "operatingSystem": "macOS 14+",
    "offers": {
      "@type": "Offer",
      "price": "0",
      "priceCurrency": "USD",
      "description": "Free during Public Beta"
    },
    "description": "Intelligent organization for creative professionals who refuse to settle for chaos.",
    "featureList": "Context-aware sorting, Natural language commands, Undo history, Local-only privacy",
    "author": {
      "@type": "Organization",
      "name": "Forma"
    }
  };

  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={clsx(
          "min-h-screen antialiased overflow-x-hidden font-body",
          instrumentSerif.variable,
          dmSans.variable,
          jetbrainsMono.variable
        )}
      >
        {/* Skip to main content link for keyboard/screen reader users */}
        <a
          href="#main-content"
          className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-[100] focus:px-4 focus:py-2 focus:bg-forma-obsidian focus:text-forma-bone focus:rounded-lg focus:outline-none focus:ring-2 focus:ring-forma-steel-blue"
        >
          Skip to main content
        </a>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
        <Header />
        <LenisGSAPProvider
          options={{
            lerp: 0.1,
            duration: 1.2,
            smoothWheel: true,
            wheelMultiplier: 1,
            touchMultiplier: 2,
          }}
        >
          <main id="main-content" tabIndex={-1} className="outline-none">
            {children}
          </main>
          <SpotlightCursor />
        </LenisGSAPProvider>
      </body>
    </html>
  );
}
