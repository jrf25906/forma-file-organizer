"use client";

import { useState, useRef, useCallback } from "react";
import { Plus, Minus } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";

const faqs = [
  {
    question: "Will it delete my files?",
    answer:
      "No. Forma only moves files\u2014it never deletes anything. Every move shows up in a preview first, and you have to approve it. If you change your mind later, you can undo any move from the history.",
  },
  {
    question: "What macOS version do I need?",
    answer:
      "macOS 14 (Sonoma) or later. Works on both Intel and Apple Silicon Macs.",
  },
  {
    question: "How do rules work?",
    answer:
      "Rules are simple: if a file matches a condition (like \u201Cfilename contains screenshot\u201D), move it somewhere. You write the rules, Forma follows them. Nothing fancy, nothing magical.",
  },
  {
    question: "Can I undo moves?",
    answer:
      "Yes. Forma keeps a full history of everything it\u2019s done. You can undo any move, even weeks later.",
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
  index,
  isOpen,
  onToggle,
}: {
  faq: (typeof faqs)[number];
  index: number;
  isOpen: boolean;
  onToggle: () => void;
}) {
  const answerRef = useRef<HTMLDivElement>(null);
  const innerRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (!answerRef.current || !innerRef.current) return;

      if (isOpen) {
        const height = innerRef.current.scrollHeight;
        gsap.fromTo(
          answerRef.current,
          { height: 0, opacity: 0 },
          {
            height,
            opacity: 1,
            duration: 0.4,
            ease: "power2.out",
          }
        );
      } else {
        gsap.to(answerRef.current, {
          height: 0,
          opacity: 0,
          duration: 0.3,
          ease: "power2.inOut",
        });
      }
    },
    { dependencies: [isOpen] }
  );

  return (
    <div className="border-b border-white/[0.08] last:border-0">
      <button
        onClick={onToggle}
        aria-expanded={isOpen}
        aria-controls={`faq-answer-${index}`}
        className="w-full py-4.5 flex items-center justify-between gap-4 text-left group cursor-pointer"
      >
        <span
          id={`faq-question-${index}`}
          className="font-display text-[17px] text-[var(--text-primary)] group-hover:text-[var(--text-primary)]/80 transition-colors"
        >
          {faq.question}
        </span>
        <div className="shrink-0 w-5 h-5 flex items-center justify-center">
          {isOpen ? (
            <Minus className="w-3.5 h-3.5 text-[var(--text-muted)]" />
          ) : (
            <Plus className="w-3.5 h-3.5 text-[var(--text-muted)]" />
          )}
        </div>
      </button>

      <div
        ref={answerRef}
        id={`faq-answer-${index}`}
        role="region"
        aria-labelledby={`faq-question-${index}`}
        className="overflow-hidden"
        style={{ height: 0, opacity: 0 }}
      >
        <div ref={innerRef}>
          <p className="pb-5 text-[15px] text-[var(--text-secondary)] leading-relaxed pr-8">
            {faq.answer}
          </p>
        </div>
      </div>
    </div>
  );
}

export default function FAQSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  const handleToggle = useCallback(
    (index: number) => {
      setOpenIndex((prev) => (prev === index ? null : index));
    },
    []
  );

  useGSAP(
    () => {
      if (!sectionRef.current || !contentRef.current) return;

      const reducedMotion = getReducedMotionValue();

      if (reducedMotion) {
        gsap.set(contentRef.current, { opacity: 1, y: 0 });
        return;
      }

      // Single scroll reveal for the whole section content
      gsap.fromTo(
        contentRef.current,
        { opacity: 0, y: 40 },
        {
          opacity: 1,
          y: 0,
          duration: formaDuration.normal,
          ease: formaReveal,
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 80%",
            toggleActions: "play none none none",
          },
        }
      );
    },
    { scope: sectionRef }
  );

  return (
    <section
      ref={sectionRef}
      id="faq"
      className="scroll-mt-16 py-16 md:py-24 bg-[var(--bg-secondary)]"
    >
      <div className="site-container">
        <div ref={contentRef} className="mx-auto max-w-2xl" style={{ opacity: 0 }}>
          <p className="mb-4 text-[11px] font-medium tracking-[0.15em] uppercase text-forma-steel-blue/70 text-center">
            FAQ
          </p>
          <h2 className="font-display text-3xl md:text-[2.25rem] text-[var(--text-primary)] text-center mb-10">
            Common Questions
          </h2>

          <div className="border border-white/[0.06] rounded-2xl px-6 md:px-8">
            {faqs.map((faq, index) => (
              <FAQItem
                key={index}
                faq={faq}
                index={index}
                isOpen={openIndex === index}
                onToggle={() => handleToggle(index)}
              />
            ))}
          </div>

          {/* Contact link */}
          <div className="text-center mt-10">
            <p className="text-[14px] text-[var(--text-muted)]">
              Something else?{" "}
              <a
                href="mailto:hello@forma.app"
                className="text-forma-steel-blue font-medium underline underline-offset-4 decoration-forma-steel-blue/30 hover:decoration-forma-steel-blue/60 transition-all"
              >
                hello@forma.app
              </a>
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
