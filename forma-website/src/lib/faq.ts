import { WEBSITE_LAST_UPDATED_ISO } from "@/lib/site";

export type FaqEntry = {
  id: string;
  question: string;
  answer: string;
  category: string;
  lastUpdated: string;
};

export const faqs: FaqEntry[] = [
  {
    id: "file-safety",
    question: "Will it delete my files?",
    answer:
      "No. Forma only moves files; it never deletes anything. Every move appears in a preview first, and you approve changes before they run. You can undo moves later from history.",
    category: "safety",
    lastUpdated: WEBSITE_LAST_UPDATED_ISO,
  },
  {
    id: "macos-version",
    question: "What macOS version do I need?",
    answer:
      "macOS 14 (Sonoma) or later. Forma supports both Intel and Apple Silicon Macs.",
    category: "compatibility",
    lastUpdated: WEBSITE_LAST_UPDATED_ISO,
  },
  {
    id: "rules-overview",
    question: "How do rules work?",
    answer:
      "Rules are straightforward: if a file matches a condition (for example, filename contains 'screenshot'), move it to a destination folder. You define the rules, Forma executes them.",
    category: "rules",
    lastUpdated: WEBSITE_LAST_UPDATED_ISO,
  },
  {
    id: "undo-history",
    question: "Can I undo moves?",
    answer:
      "Yes. Forma keeps a full history of activity, and you can undo moves even after time has passed.",
    category: "undo",
    lastUpdated: WEBSITE_LAST_UPDATED_ISO,
  },
  {
    id: "external-storage",
    question: "Does it work with iCloud, Dropbox, or external drives?",
    answer:
      "Yes. Forma can watch and organize files on mounted volumes you explicitly allow.",
    category: "storage",
    lastUpdated: WEBSITE_LAST_UPDATED_ISO,
  },
  {
    id: "privacy",
    question: "Is my data private?",
    answer:
      "Yes. Everything runs locally on your Mac. Files, filenames, and folder structures are not uploaded for organization logic.",
    category: "privacy",
    lastUpdated: WEBSITE_LAST_UPDATED_ISO,
  },
];

