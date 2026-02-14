"use client";

import { ScrollReveal } from "@/components/animation/ScrollReveal";

// ---------------------------------------------------------------------------
// Social Proof Section
// Replace placeholder quotes with real testimonials as they come in.
// To hide this section entirely, remove it from page.tsx.
// ---------------------------------------------------------------------------

const testimonials = [
  {
    quote:
      "I've tried Hazel, automator scripts, even wrote my own — Forma is the first one that stuck because I can actually see what it's going to do before it does it.",
    author: "Beta tester",
    role: "Software engineer",
  },
  {
    quote:
      "My Downloads folder had 2,000+ files. Forma grouped them, I approved the moves, and it was done in under a minute. Should've done this years ago.",
    author: "Beta tester",
    role: "Designer",
  },
  {
    quote:
      "The undo history is what sold me. I'm not precious about organizing anymore because I know I can always roll it back.",
    author: "Beta tester",
    role: "Freelancer",
  },
];

export default function SocialProofSection() {
  return (
    <section
      id="social-proof"
      className="relative overflow-hidden py-10 md:py-16"
      aria-label="What people are saying"
    >
      <div className="site-container">
        <ScrollReveal direction="up" distance={20}>
          <p className="mb-8 text-center text-[11px] font-medium uppercase tracking-[0.15em] text-forma-steel-blue md:mb-10">
            Early feedback
          </p>
        </ScrollReveal>

        <ScrollReveal stagger={0.1} threshold={85}>
          <div className="mx-auto grid max-w-4xl grid-cols-1 gap-4 md:grid-cols-3">
            {testimonials.map((t) => (
              <blockquote
                key={t.quote}
                className="flex flex-col rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-5 md:p-6"
              >
                <p className="flex-1 text-[14px] leading-relaxed text-[var(--text-secondary)]">
                  &ldquo;{t.quote}&rdquo;
                </p>
                <footer className="mt-4 border-t border-[var(--border-subtle)] pt-3">
                  <p className="text-[13px] font-medium text-[var(--text-primary)]">
                    {t.author}
                  </p>
                  <p className="text-[12px] text-[var(--text-muted)]">
                    {t.role}
                  </p>
                </footer>
              </blockquote>
            ))}
          </div>
        </ScrollReveal>
      </div>
    </section>
  );
}
