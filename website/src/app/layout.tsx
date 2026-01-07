import type { Metadata } from "next";
import "./globals.css";
import { ThemeProvider } from "@/components/ThemeProvider";

export const metadata: Metadata = {
  title: "Forma | Intelligent File Organization for macOS",
  description:
    "Transform digital chaos into clarity. Forma uses smart rules and AI-powered insights to automatically organize your files, saving you hours every week.",
  keywords: [
    "file organization",
    "macOS app",
    "productivity",
    "file management",
    "automation",
    "AI file organizer",
  ],
  authors: [{ name: "Forma" }],
  openGraph: {
    title: "Forma | Intelligent File Organization for macOS",
    description:
      "Transform digital chaos into clarity. Forma uses smart rules and AI-powered insights to automatically organize your files.",
    type: "website",
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "Forma | Intelligent File Organization for macOS",
    description:
      "Transform digital chaos into clarity with AI-powered file organization.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" data-theme="dark" suppressHydrationWarning>
      <body className="min-h-screen gradient-bg noise-overlay">
        {/* Skip Link for Accessibility - WCAG 2.4.1 */}
        <a href="#main-content" className="skip-link">
          Skip to main content
        </a>
        <ThemeProvider>{children}</ThemeProvider>
      </body>
    </html>
  );
}
