"use client";

import { useState } from "react";
import { Plus, Minus } from "@phosphor-icons/react";

const faqs = [
  {
    question: "Will it delete my files?",
    answer:
      "No. Forma only moves files—it never deletes anything. Every move shows up in a preview first, and you have to approve it. If you change your mind later, you can undo any move from the history.",
  },
  {
    question: "What macOS version do I need?",
    answer:
      "macOS 13 (Ventura) or later. Works on both Intel and Apple Silicon Macs.",
  },
  {
    question: "How do rules work?",
    answer:
      "Rules are simple: if a file matches a condition (like \"filename contains 'screenshot'\"), move it somewhere. You write the rules, Forma follows them. Nothing fancy, nothing magical.",
  },
  {
    question: "Can I undo moves?",
    answer:
      "Yes. Forma keeps a full history of everything it's done. You can undo any move, even weeks later.",
  },
  {
    question: "Does it work with iCloud/Dropbox/external drives?",
    answer:
      "Yes. Forma can watch and organize files on any mounted volume.",
  },
  {
    question: "Is my data private?",
    answer:
      "Completely. Everything runs locally on your Mac. No files, filenames, or folder structures ever leave your computer.",
  },
];

function FAQItem({
  faq,
  isOpen,
  onToggle,
}: {
  faq: (typeof faqs)[0];
  isOpen: boolean;
  onToggle: () => void;
}) {
  return (
    <div className="border-b border-forma-bone/10 last:border-0">
      <button
        onClick={onToggle}
        aria-expanded={isOpen}
        className="w-full py-5 flex items-start justify-between gap-4 text-left"
      >
        <span className="font-display text-lg text-forma-bone">
          {faq.question}
        </span>
        <div className="shrink-0 mt-1">
          {isOpen ? (
            <Minus className="w-4 h-4 text-forma-bone/40" />
          ) : (
            <Plus className="w-4 h-4 text-forma-bone/40" />
          )}
        </div>
      </button>

      {isOpen && (
        <p className="pb-5 text-forma-bone/60 leading-relaxed pr-8">
          {faq.answer}
        </p>
      )}
    </div>
  );
}

export default function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <section id="faq" className="py-24 px-6">
      <div className="max-w-2xl mx-auto">
        <h2 className="font-display text-3xl md:text-4xl text-forma-bone mb-12 text-center">
          Questions
        </h2>

        <div>
          {faqs.map((faq, index) => (
            <FAQItem
              key={index}
              faq={faq}
              isOpen={openIndex === index}
              onToggle={() => setOpenIndex(openIndex === index ? null : index)}
            />
          ))}
        </div>

        <div className="text-center mt-12">
          <p className="text-forma-bone/50">
            Something else?{" "}
            <a
              href="mailto:hello@forma.app"
              className="text-forma-bone underline underline-offset-4 hover:text-forma-bone/80"
            >
              hello@forma.app
            </a>
          </p>
        </div>
      </div>
    </section>
  );
}
