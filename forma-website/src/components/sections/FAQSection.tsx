"use client";

import { useState, useRef, useCallback } from "react";
import { Plus, Minus } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaStagger, formaDuration } from "@/lib/animation";

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
    <div className="border-b border-black/10 last:border-0">
      <button
        onClick={onToggle}
        aria-expanded={isOpen}
        aria-controls={`faq-answer-${index}`}
        className="w-full py-5 flex items-start justify-between gap-4 text-left group cursor-pointer"
      >
        <span className="font-display text-lg text-forma-obsidian group-hover:text-forma-obsidian/85 transition-colors">
          {faq.question}
        </span>
        <div className="shrink-0 mt-1 w-5 h-5 rounded-full bg-black/[0.04] flex items-center justify-center transition-colors group-hover:bg-black/[0.07]">
          {isOpen ? (
            <Minus className="w-3.5 h-3.5 text-forma-obsidian/45" />
          ) : (
            <Plus className="w-3.5 h-3.5 text-forma-obsidian/45" />
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
          <p className="pb-5 text-forma-obsidian/72 leading-relaxed pr-8">
            {faq.answer}
          </p>
        </div>
      </div>
    </div>
  );
}

export default function FAQSection() {
  const enableScrollAnimations = false;
  const sectionRef = useRef<HTMLElement>(null);
  const headingRef = useRef<HTMLHeadingElement>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const contactRef = useRef<HTMLDivElement>(null);
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  const handleToggle = useCallback(
    (index: number) => {
      setOpenIndex(openIndex === index ? null : index);
    },
    [openIndex]
  );

  useGSAP(
    () => {
      if (!enableScrollAnimations) return;
      if (!sectionRef.current) return;

      const tl = gsap.timeline({
        scrollTrigger: {
          trigger: sectionRef.current,
          start: "top 75%",
          toggleActions: "play none none reverse",
        },
      });

      tl.from(headingRef.current, {
        opacity: 0,
        y: 30,
        duration: formaDuration.normal,
        ease: formaReveal,
      })
        .from(
          listRef.current?.children ?? [],
          {
            opacity: 0,
            y: 20,
            stagger: formaStagger.normal,
            duration: formaDuration.fast,
            ease: formaReveal,
          },
          "-=0.5"
        )
        .from(
          contactRef.current,
          {
            opacity: 0,
            y: 15,
            duration: formaDuration.fast,
            ease: formaReveal,
          },
          "-=0.2"
        );
    },
    { scope: sectionRef }
  );

  return (
    <section
      ref={sectionRef}
      id="faq"
      className="scroll-mt-16 py-24 md:py-32"
    >
      <div className="site-container">
        <div className="mx-auto max-w-3xl">
        {/* Heading */}
        <h2
          ref={headingRef}
          className="font-display text-3xl md:text-4xl text-forma-obsidian text-center mb-12"
        >
          Questions
        </h2>

        {/* FAQ list */}
        <div ref={listRef}>
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
        <div ref={contactRef} className="text-center mt-12">
          <p className="text-forma-obsidian/62">
            Something else?{" "}
            <a
              href="mailto:hello@forma.app"
              className="text-forma-obsidian underline underline-offset-4 decoration-black/25 hover:decoration-black/50 hover:text-forma-obsidian/82 transition-all"
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
