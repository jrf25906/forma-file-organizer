import type { Metadata } from "next";
import LegalPageShell from "@/components/legal/LegalPageShell";
import { SITE_URL } from "@/lib/site";

export const metadata: Metadata = {
  title: "Terms of Use",
  description: "Terms for using the Forma macOS app and related website surfaces.",
  alternates: {
    canonical: `${SITE_URL}/terms`,
  },
};

const termsSections = [
  {
    paragraphs: [
      "These terms govern your use of the Forma macOS app and related website surfaces. If you download Forma from the Mac App Store, Apple's terms and policies also apply.",
    ],
  },
  {
    title: "License",
    paragraphs: [
      "We grant you a limited, non-exclusive, non-transferable, revocable license to install and use the app for personal use or internal business use, subject to these terms.",
    ],
  },
  {
    title: "Acceptable use",
    paragraphs: [
      "You agree not to misuse the app, attempt to reverse engineer it beyond what is allowed by applicable law, or use it in ways that violate the rights of others.",
    ],
  },
  {
    title: "Warranty disclaimer",
    paragraphs: [
      "The app is provided AS IS and AS AVAILABLE, without warranties of any kind.",
      "That includes no promise that every rule suggestion, match, or workflow will be correct for every folder structure. Preview and undo remain part of the expected product workflow.",
    ],
  },
  {
    title: "Limitation of liability",
    paragraphs: [
      "To the fullest extent permitted by law, Forma is not liable for indirect, incidental, special, or consequential damages arising from use of the app.",
    ],
  },
  {
    title: "Changes to these terms",
    paragraphs: [
      "We may update these terms from time to time. If we do, we will update the last-updated date on this page.",
    ],
  },
] as const;

export default function TermsPage() {
  return (
    <LegalPageShell
      eyebrow="Legal"
      title="Terms for a local-first Mac utility."
      description="These terms cover your use of Forma and its website surfaces. The goal is to state the rules plainly, not hide product limitations behind decorative legal copy."
      lastUpdated="February 4, 2026"
      contactLocation="terms_page"
      summaryChips={["macOS app", "Mac App Store purchase", "Preview and undo workflow"]}
      plainLanguageTitle="Use it responsibly, and keep the preview step."
      plainLanguagePoints={[
        "Forma gives you tooling for controlled organization, not a guarantee that every rule will be right on the first try.",
        "You remain responsible for how you use the app and the files you choose to organize.",
        "If the terms change, the date on this page changes with them.",
      ]}
      sections={termsSections}
      relatedLinks={[
        {
          href: "/privacy",
          label: "Privacy Policy",
          description: "See exactly what stays on your Mac and what the website may process.",
        },
        {
          href: "/support",
          label: "Support",
          description: "Contact support if you need help understanding app behavior or permissions.",
        },
        {
          href: "/blog",
          label: "Guides",
          description: "Read the workflows behind the product so the app behavior is clear before you run it.",
        },
      ]}
    />
  );
}
