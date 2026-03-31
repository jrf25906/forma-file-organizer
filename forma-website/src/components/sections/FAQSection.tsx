"use client";

import Link from "next/link";
import { useRef } from "react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";
import { faqs } from "@/lib/faq";
import { SUPPORT_EMAIL } from "@/lib/site";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import { FormaShellCard } from "@/components/ui/forma-shell-card";
import { FormaShellSectionHeading } from "@/components/ui/forma-shell-section-heading";
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
      className="scroll-mt-16 bg-[var(--bg-secondary)] py-20 md:py-28"
    >
      <div className="site-container">
        <div ref={contentRef} className="mx-auto max-w-2xl">
          <FormaShellSectionHeading
            eyebrow="FAQ"
            title="Common questions"
            align="center"
          />

          <FormaShellCard className="mt-8 px-5 py-2 md:px-8">
            <Accordion type="single" collapsible defaultValue={faqs[0]?.id}>
              {faqs.map((faq) => (
                <AccordionItem
                  key={faq.id}
                  value={faq.id}
                  className="border-b border-[var(--shell-border)] last:border-b-0"
                >
                  <AccordionTrigger className="py-5 text-left text-[16px] leading-6 font-medium text-[var(--text-primary)] hover:no-underline md:py-6 md:text-[17px]">
                    {faq.question}
                  </AccordionTrigger>
                  <AccordionContent className="pr-8 text-[15px] leading-relaxed text-[var(--text-secondary)]">
                    {faq.answer}
                  </AccordionContent>
                </AccordionItem>
              ))}
            </Accordion>
          </FormaShellCard>

          <div className="mt-6 space-y-2 text-center">
            <p className="text-[14px] text-[var(--text-muted)]">
              Something else?{" "}
              <TrackedMailtoLink
                email={SUPPORT_EMAIL}
                location="faq_section"
                className="font-medium text-forma-steel-blue underline underline-offset-4 decoration-forma-steel-blue/30 transition-all hover:decoration-forma-steel-blue/60"
              >
                {SUPPORT_EMAIL}
              </TrackedMailtoLink>
            </p>
            <p className="text-[14px] text-[var(--text-muted)]">
              Need a full walkthrough?{" "}
              <Link
                href="/blog"
                className="font-medium text-forma-steel-blue underline underline-offset-4 decoration-forma-steel-blue/30 transition-all hover:decoration-forma-steel-blue/60"
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
