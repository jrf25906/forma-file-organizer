"use client";

import Link from "next/link";
import { useState, useRef, useCallback } from "react";
import { Plus, Minus } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";
import { faqs } from "@/lib/faq";
import { SUPPORT_EMAIL } from "@/lib/site";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";

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
    <div className="border-b border-[var(--border-medium)] last:border-0">
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

      const triggerTop = sectionRef.current.getBoundingClientRect().top;
      if (triggerTop <= window.innerHeight * 0.8) {
        gsap.set(contentRef.current, { opacity: 1, y: 0 });
        return;
      }

      // Single scroll reveal for the whole section content
      gsap.fromTo(
        contentRef.current,
        { opacity: 0.88, y: 24 },
        {
          opacity: 1,
          y: 0,
          immediateRender: false,
          duration: formaDuration.normal,
          ease: formaReveal,
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 80%",
            toggleActions: "play none none none",
            invalidateOnRefresh: true,
            onRefresh: (self) => {
              if (self.progress > 0) {
                gsap.set(contentRef.current, { opacity: 1, y: 0 });
              }
            },
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
      className="scroll-mt-16 bg-[var(--bg-secondary)] py-10 md:py-20"
    >
      <div className="site-container">
        <div ref={contentRef} className="mx-auto max-w-2xl">
          <p className="mb-4 text-[11px] font-medium tracking-[0.15em] uppercase text-forma-steel-blue text-center">
            FAQ
          </p>
          <h2 className="mb-6 text-center font-display text-3xl text-[var(--text-primary)] md:text-[2.25rem]">
            Common Questions
          </h2>

          <div className="border border-[var(--border-subtle)] rounded-2xl px-5 md:px-8">
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
          <div className="mt-6 text-center">
            <p className="text-[14px] text-[var(--text-muted)]">
              Something else?{" "}
              <TrackedMailtoLink
                email={SUPPORT_EMAIL}
                location="faq_section"
                className="text-forma-steel-blue font-medium underline underline-offset-4 decoration-forma-steel-blue/30 hover:decoration-forma-steel-blue/60 transition-all"
              >
                {SUPPORT_EMAIL}
              </TrackedMailtoLink>
            </p>
            <p className="mt-2 text-[14px] text-[var(--text-muted)]">
              Need a full walkthrough?{" "}
              <Link
                href="/blog"
                className="text-forma-steel-blue font-medium underline underline-offset-4 decoration-forma-steel-blue/30 hover:decoration-forma-steel-blue/60 transition-all"
              >
                Read our organization guides
              </Link>
              .
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
