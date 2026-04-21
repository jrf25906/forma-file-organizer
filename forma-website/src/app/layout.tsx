import type { Metadata } from "next";
import Script from "next/script";
import { Inter_Tight, JetBrains_Mono, Newsreader } from "next/font/google";
import "./globals.css";
import clsx from "clsx";
import { Header } from "@/components/Header";
import Footer from "@/components/Footer";
import { ThemeProvider } from "@/components/ThemeProvider";
import { SITE_NAME, SITE_TAGLINE, SITE_URL } from "@/lib/site";

const interTight = Inter_Tight({
  subsets: ["latin"],
  variable: "--font-inter-tight",
  display: "swap",
  adjustFontFallback: true,
});

const newsreader = Newsreader({
  subsets: ["latin"],
  variable: "--font-newsreader",
  display: "swap",
  axes: ["opsz"],
  weight: ["400", "500", "600"],
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
    "A file organizer for people who gave up on file organizers. Write rules in plain English, preview every move, and undo recent batches when something was wrong. $29 once for Mac.",
  keywords: [
    "organize mac files",
    "organize downloads folder mac",
    "organize desktop files mac",
    "file organizer",
    "macOS utility",
    "desktop cleanup",
    "adhd file organization",
    "adhd desktop clutter",
    "file organizer for adhd",
    "adhd productivity mac",
    "executive function file management",
  ],
  authors: [{ name: SITE_NAME }],
  alternates: {
    canonical: SITE_URL,
  },
  openGraph: {
    title: `${SITE_NAME} — A file organizer for people who gave up on file organizers`,
    description:
      "Write rules in plain English, preview every move, and undo recent batches when something was wrong. $29 once for Mac.",
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
      "Write rules in plain English, preview every move, and undo recent batches when something was wrong.",
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
            __html: `(function(){try{var m=window.matchMedia('(prefers-color-scheme: light)').matches;document.documentElement.setAttribute('data-theme',m?'light':'dark')}catch(e){}})()`,
          }}
        />
      </head>
      <body
        className={clsx(
          "min-h-screen antialiased overflow-x-hidden font-body bg-[var(--canvas-paper)] text-[var(--ink-primary)]",
          interTight.variable,
          newsreader.variable,
          jetbrainsMono.variable,
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

        <ThemeProvider defaultTheme="system">
          <div className="relative mx-auto flex min-h-screen w-full max-w-[1920px] flex-col border-x border-[var(--shell-border)] bg-[var(--bg-primary)] shadow-[var(--shell-shadow)]">
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
          </div>
        </ThemeProvider>
      </body>
    </html>
  );
}
