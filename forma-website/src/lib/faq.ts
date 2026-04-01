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
      "No. Forma only moves files \u2014 never deletes. You review every move before it happens, and you can undo the recent batch if something was wrong.",
    category: "safety",
    lastUpdated: WEBSITE_LAST_UPDATED_ISO,
  },
  {
    id: "macos-version",
    question: "What macOS version do I need?",
    answer:
      "macOS 15 or later. Forma supports both Intel and Apple Silicon Macs.",
    category: "compatibility",
    lastUpdated: WEBSITE_LAST_UPDATED_ISO,
  },
  {
    id: "rules-overview",
    question: "How do rules work?",
    answer:
      "A rule is a condition and a destination, written in plain English. Example: \u2018if the filename contains screenshot, move it to ~/Screenshots.\u2019 That\u2019s a real rule.",
    category: "rules",
    lastUpdated: WEBSITE_LAST_UPDATED_ISO,
  },
  {
    id: "undo-history",
    question: "Can I undo moves?",
    answer:
      "Yes. Forma keeps recent move history available so you can undo a single file or the recent batch when something was wrong.",
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
      "Yes. Everything runs locally on your Mac. No file contents, names, or folder structures leave your machine.",
    category: "privacy",
    lastUpdated: WEBSITE_LAST_UPDATED_ISO,
  },
];
