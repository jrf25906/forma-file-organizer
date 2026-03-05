import type { Metadata } from "next";
import Script from "next/script";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import clsx from "clsx";
import { Header } from "@/components/Header";
import Footer from "@/components/Footer";
import { ThemeProvider } from "@/components/ThemeProvider";
import { SITE_NAME, SITE_TAGLINE, SITE_URL } from "@/lib/site";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
  adjustFontFallback: true,
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-jetbrains-mono",
  display: "swap",
});

const googleVerificationToken = process.env.NEXT_PUBLIC_GOOGLE_SITE_VERIFICATION;
const bingVerificationToken = process.env.NEXT_PUBLIC_BING_SITE_VERIFICATION;

const metadataVerification: Metadata["verification"] = {
  ...(googleVerificationToken ? { google: googleVerificationToken } : {}),
  ...(bingVerificationToken
    ? { other: { "msvalidate.01": bingVerificationToken } }
    : {}),
};

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: `${SITE_NAME} | ${SITE_TAGLINE}`,
    template: `%s | ${SITE_NAME}`,
  },
  description:
    "A file organizer for people who gave up on file organizers. Create rules in plain language, preview every move, and undo anytime. $29 once. Native macOS app.",
  keywords: [
    "organize mac files",
    "organize downloads folder mac",
    "organize desktop files mac",
    "file organizer",
    "macOS utility",
    "desktop cleanup",
  ],
  authors: [{ name: SITE_NAME }],
  alternates: {
    canonical: SITE_URL,
  },
  openGraph: {
    title: `${SITE_NAME} — A file organizer for people who gave up on file organizers`,
    description:
      "Create rules in plain language, preview every move, and undo anytime. $29 once. Native macOS app.",
    url: SITE_URL,
    siteName: SITE_NAME,
    locale: "en_US",
    type: "website",
  },
  icons: {
    icon: [
      { url: "/favicon.svg?v=20260211b", type: "image/svg+xml", sizes: "any" },
      { url: "/favicon.ico?v=20260211b", type: "image/x-icon" },
    ],
    shortcut: "/favicon.ico?v=20260211b",
    apple: "/app-icon-1024.png",
  },
  twitter: {
    card: "summary_large_image",
    title: SITE_NAME,
    description:
      "Create rules in plain language, preview every move, and undo anytime.",
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
  verification: metadataVerification,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const plausibleDomain = process.env.NEXT_PUBLIC_PLAUSIBLE_DOMAIN?.trim();
  const plausibleScriptSrc =
    process.env.NEXT_PUBLIC_PLAUSIBLE_SRC?.trim() ??
    "https://plausible.io/js/script.js";

  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{document.documentElement.setAttribute('data-theme','light')}catch(e){}})()`,
          }}
        />
      </head>
      <body
        className={clsx(
          "min-h-screen antialiased overflow-x-hidden font-body",
          inter.variable,
          jetbrainsMono.variable
        )}
      >
        {plausibleDomain ? (
          <>
            <Script
              async
              src={plausibleScriptSrc}
              strategy="afterInteractive"
            />
            <Script
              id="plausible-init"
              strategy="afterInteractive"
              dangerouslySetInnerHTML={{
                __html: `window.plausible=window.plausible||function(){(plausible.q=plausible.q||[]).push(arguments)};plausible.init=plausible.init||function(i){plausible.o=i||{}};plausible.init();`,
              }}
            />
          </>
        ) : null}

        <ThemeProvider defaultTheme="light">
          <a
            href="#main-content"
            className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-[100] focus:px-4 focus:py-2 focus:bg-forma-obsidian focus:text-forma-bone focus:rounded-lg focus:outline-none focus:ring-2 focus:ring-forma-steel-blue"
          >
            Skip to main content
          </a>
          <Header />
          <div tabIndex={-1} className="outline-none">
            {children}
          </div>
          <Footer />
        </ThemeProvider>
      </body>
    </html>
  );
}
