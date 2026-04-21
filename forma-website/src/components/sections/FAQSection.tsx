"use client";

import Link from "next/link";
import { useRef } from "react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";
import { faqs } from "@/lib/faq";
import { SUPPORT_EMAIL } from "@/lib/site";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import { FormaShellSectionHeading } from "@/components/ui/forma-shell-section-heading";
import { MonoLabel } from "@/components/ui/MonoLabel";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";

type FAQEntranceRevealOptions = {
  reducedMotion: boolean;
  triggerTop: number;
  viewportHeight: number;
};

export function shouldRevealFAQSectionImmediately({
  reducedMotion,
  triggerTop,
  viewportHeight,
}: FAQEntranceRevealOptions): boolean {
  return reducedMotion || triggerTop <= viewportHeight * 0.8;
}

export default function FAQSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (!sectionRef.current || !contentRef.current) return;

      const reducedMotion = getReducedMotionValue();
      const triggerTop = sectionRef.current.getBoundingClientRect().top;

      if (
        shouldRevealFAQSectionImmediately({
          reducedMotion,
          triggerTop,
          viewportHeight: window.innerHeight,
        })
      ) {
        gsap.set(contentRef.current, { opacity: 1, y: 0 });
        return;
      }

      gsap.fromTo(
        contentRef.current,
        { opacity: 0, y: 24 },
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
      className="scroll-mt-16 py-24 md:py-32"
    >
      <div className="mx-auto w-full max-w-[960px] px-6">
        <div ref={contentRef}>
          <FormaShellSectionHeading
            eyebrow="FAQ"
            title="Common questions"
            size="lg"
          />

          <div className="mt-10 border-y border-[var(--rule-faint)]">
            <Accordion type="single" collapsible defaultValue={faqs[0]?.id}>
              {faqs.map((faq, index) => (
                <AccordionItem
                  key={faq.id}
                  value={faq.id}
                  className="border-b border-[var(--rule-faint)] last:border-b-0"
                >
                  <AccordionTrigger className="py-5 text-left text-[16px] leading-6 font-medium text-[var(--ink-primary)] hover:no-underline md:py-6 md:text-[17px]">
                    <span className="flex items-center gap-3">
                      <span aria-hidden="true" className="inline-block h-3 w-[1.5px] bg-[var(--ink-draft)]" />
                      <MonoLabel variant="section" className="tabular-nums">
                        § 09.{String(index + 1).padStart(2, "0")}
                      </MonoLabel>
                      <span>{faq.question}</span>
                    </span>
                  </AccordionTrigger>
                  <AccordionContent className="pr-8 text-[15px] leading-relaxed text-[var(--ink-secondary)]">
                    {faq.answer}
                  </AccordionContent>
                </AccordionItem>
              ))}
            </Accordion>
          </div>

          <div className="mt-8 space-y-2">
            <p className="text-[14px] text-[var(--ink-faint)]">
              Something else?{" "}
              <TrackedMailtoLink
                email={SUPPORT_EMAIL}
                location="faq_section"
                className="font-medium text-forma-steel-blue underline underline-offset-4 decoration-forma-steel-blue/30 transition-[text-decoration-color,color] duration-200 hover:decoration-forma-steel-blue/60"
              >
                {SUPPORT_EMAIL}
              </TrackedMailtoLink>
            </p>
            <p className="text-[14px] text-[var(--ink-faint)]">
              Need a full walkthrough?{" "}
              <Link
                href="/blog"
                className="font-medium text-forma-steel-blue underline underline-offset-4 decoration-forma-steel-blue/30 transition-[text-decoration-color,color] duration-200 hover:decoration-forma-steel-blue/60"
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
