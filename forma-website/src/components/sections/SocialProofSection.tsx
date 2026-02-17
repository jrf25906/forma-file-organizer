"use client";

import { ScrollReveal } from "@/components/animation/ScrollReveal";

// ---------------------------------------------------------------------------
// Design Principles Section
// Replaces placeholder testimonials with honest trust-building content.
// TODO: Swap back to real testimonials once genuine user quotes are collected.
// When ready, restore the testimonial format and update aria-label.
// ---------------------------------------------------------------------------

const principles = [
  {
    heading: "Preview first",
    body: "Every proposed move appears in a queue before anything happens. See source, destination, and the rule behind it.",
  },
  {
    heading: "Undo always",
    body: "Full action history with one-click rollback. Experiment freely — every change is reversible.",
  },
  {
    heading: "Private by design",
    body: "100% on-device processing. Your files and their names never leave your Mac.",
  },
];

export default function SocialProofSection() {
  return (
    <section
      id="principles"
      className="relative overflow-hidden py-10 md:py-16"
      aria-label="Design principles"
    >
      <div className="site-container">
        <ScrollReveal direction="up" distance={20}>
          <p className="mb-8 text-center text-[11px] font-medium uppercase tracking-[0.15em] text-forma-steel-blue md:mb-10">
            How Forma works
          </p>
        </ScrollReveal>

        <ScrollReveal stagger={0.1} threshold={85}>
          <div className="mx-auto grid max-w-4xl grid-cols-1 gap-4 md:grid-cols-3">
            {principles.map((p) => (
              <div
                key={p.heading}
                className="flex flex-col rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-5 md:p-6"
              >
                <p className="text-[13px] font-medium text-[var(--text-primary)]">
                  {p.heading}
                </p>
                <p className="mt-2 flex-1 text-[14px] leading-relaxed text-[var(--text-secondary)]">
                  {p.body}
                </p>
              </div>
            ))}
          </div>
        </ScrollReveal>
      </div>
    </section>
  );
}
