import type { Metadata } from "next";
import LegalPageShell from "@/components/legal/LegalPageShell";
import { SITE_URL } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How Forma handles app data, folder access, and website request data.",
  alternates: {
    canonical: `${SITE_URL}/privacy`,
  },
};

const privacySections = [
  {
    paragraphs: [
      "Forma is built around local processing. File names, folder structure, and file contents stay on your Mac unless you explicitly share them.",
    ],
  },
  {
    title: "What Forma stores on your Mac",
    paragraphs: [
      "To organize files, Forma stores data locally on your Mac, including file metadata such as names, paths, sizes, timestamps, and file types.",
      "Forma also stores your rules, preferences, activity history, and undo history so the app can explain what happened and let you reverse changes when needed.",
    ],
  },
  {
    title: "AI and third-party processing",
    paragraphs: [
      "Forma does not send your file data to third-party AI services for organization. Smart features run on your Mac.",
      "If that changes, the product and this policy will state it directly instead of burying it in a settings footnote.",
    ],
  },
  {
    title: "Data sales and sharing",
    paragraphs: [
      "We do not sell your file data or share it with data brokers.",
      "Any website-side processing is limited to operating the site and keeping it secure and reliable.",
    ],
  },
  {
    title: "Folder permissions and bookmarks",
    paragraphs: [
      "Forma only accesses folders you explicitly grant permission to in macOS.",
      "If you grant access, Forma stores security-scoped bookmarks locally, including Keychain-backed bookmark data when needed, so it can preserve that permission on your Mac.",
    ],
  },
  {
    title: "Website data",
    paragraphs: [
      "When you visit formafiles.com, our hosting provider may process standard request logs such as IP address and user agent for security and reliability.",
      "If we add analytics or additional website processing, this page will be updated with the specific data involved and the controls available.",
    ],
  },
  {
    title: "Policy updates",
    paragraphs: [
      "If this policy changes, we will update the last-updated date on this page and publish the revised version here.",
    ],
  },
] as const;

export default function PrivacyPolicyPage() {
  return (
    <LegalPageShell
      eyebrow="Legal"
      title="Privacy that matches the product promise."
      description="Forma is sold on control, reversibility, and local-first behavior. This policy explains what the app stores, what stays on your Mac, and what the website processes."
      lastUpdated="February 4, 2026"
      contactLocation="privacy_page"
      summaryChips={["Local-first", "No file uploads", "Security-scoped access only"]}
      plainLanguageTitle="Your files are not the business model."
      plainLanguagePoints={[
        "Forma runs organization logic on your Mac instead of shipping file data to third parties.",
        "Folder access only happens after you explicitly grant permission in macOS.",
        "The website may process basic request logs for security, but it does not change how the app handles files.",
      ]}
      sections={privacySections}
      relatedLinks={[
        {
          href: "/terms",
          label: "Terms of Use",
          description: "Read the usage terms and warranty limitations for the app and website.",
        },
        {
          href: "/support",
          label: "Support",
          description: "Reach out directly if you need help with permissions, rules, or an unexpected result.",
        },
        {
          href: "/get-forma",
          label: "Get Forma",
          description: "See the app download page with pricing, support, and product promise context.",
        },
      ]}
    />
  );
}
