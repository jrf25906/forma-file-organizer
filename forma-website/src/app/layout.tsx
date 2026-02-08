import type { Metadata } from "next";
import { DM_Sans, Instrument_Serif, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import clsx from "clsx";
import { Header } from "@/components/Header";
import { ThemeProvider } from "@/components/ThemeProvider";

const instrumentSerif = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  variable: "--font-instrument-serif",
  display: "swap",
  adjustFontFallback: true,
});

const dmSans = DM_Sans({
  subsets: ["latin"],
  variable: "--font-dm-sans",
  display: "swap",
  adjustFontFallback: true,
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-jetbrains-mono",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://formafiles.com"),
  title: {
    default: "Forma | Give your files form",
    template: "%s | Forma",
  },
  description:
    "A file organizer for people who gave up on file organizers. Make rules, preview moves, approve changes, undo anything. $29 once, forever. macOS native.",
  keywords: [
    "file organizer",
    "macOS utility",
    "productivity app",
    "desktop cleanup",
    "file management",
    "mac app",
  ],
  authors: [{ name: "Forma" }],
  openGraph: {
    title: "Forma | Give your files form",
    description:
      "A file organizer for people who gave up on file organizers. $29 once, forever.",
    url: "https://formafiles.com",
    siteName: "Forma",
    locale: "en_US",
    type: "website",
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
    apple: "/app-icon-1024.png",
  },
  twitter: {
    card: "summary_large_image",
    title: "Forma",
    description:
      "A file organizer for people who gave up on file organizers.",
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
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "Forma",
    applicationCategory: "ProductivityApplication",
    operatingSystem: "macOS 14+",
    offers: {
      "@type": "Offer",
      price: "29",
      priceCurrency: "USD",
      description: "One-time purchase. No subscription.",
    },
    description:
      "A file organizer for people who gave up on file organizers. Make rules, preview, approve, undo.",
    featureList:
      "Natural language rules, Preview before moving, Full undo history, Local-only privacy",
    author: {
      "@type": "Organization",
      name: "Forma",
    },
  };

  return (
    <html lang="en" data-theme="light" suppressHydrationWarning>
      <body
        className={clsx(
          "min-h-screen antialiased overflow-x-hidden font-body",
          instrumentSerif.variable,
          dmSans.variable,
          jetbrainsMono.variable
        )}
      >
        <ThemeProvider defaultTheme="light">
          <a
            href="#main-content"
            className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-[100] focus:px-4 focus:py-2 focus:bg-forma-obsidian focus:text-forma-bone focus:rounded-lg focus:outline-none focus:ring-2 focus:ring-forma-steel-blue"
          >
            Skip to main content
          </a>
          {/* Structured data - static JSON, no user input */}
          <script
            type="application/ld+json"
            dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
          />
          <Header />
          <div id="main-content" tabIndex={-1} className="outline-none">
            {children}
          </div>
        </ThemeProvider>
      </body>
    </html>
  );
}
