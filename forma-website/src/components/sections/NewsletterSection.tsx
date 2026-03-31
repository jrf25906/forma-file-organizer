"use client";

import { useState, useRef, type FormEvent } from "react";
import { Loader2, CheckCircle2 } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";
import { trackEvent } from "@/lib/analytics";
import { FormaShellCard } from "@/components/ui/forma-shell-card";
import { FormaShellSectionHeading } from "@/components/ui/forma-shell-section-heading";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

type FormState = "idle" | "loading" | "success" | "error";

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export default function NewsletterSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const cardRef = useRef<HTMLDivElement>(null);

  const [email, setEmail] = useState("");
  const [formState, setFormState] = useState<FormState>("idle");
  const [errorMessage, setErrorMessage] = useState("");

  useGSAP(
    () => {
      if (!sectionRef.current || !cardRef.current) return;

      const reducedMotion = getReducedMotionValue();

      if (reducedMotion) {
        gsap.set(cardRef.current, { opacity: 1, y: 0 });
        return;
      }

      const triggerTop = sectionRef.current.getBoundingClientRect().top;
      if (triggerTop <= window.innerHeight * 0.85) {
        gsap.set(cardRef.current, { opacity: 1, y: 0 });
        return;
      }

      gsap.fromTo(
        cardRef.current,
        { opacity: 0.88, y: 24 },
        {
          opacity: 1,
          y: 0,
          immediateRender: false,
          duration: formaDuration.normal,
          ease: formaReveal,
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 85%",
            toggleActions: "play none none none",
            invalidateOnRefresh: true,
            onRefresh: (self) => {
              if (self.progress > 0) {
                gsap.set(cardRef.current, { opacity: 1, y: 0 });
              }
            },
          },
        }
      );
    },
    { scope: sectionRef }
  );

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setErrorMessage("");

    if (!isValidEmail(email)) {
      setFormState("error");
      setErrorMessage("Please enter a valid email address.");
      return;
    }

    setFormState("loading");

    try {
      const res = await fetch("/api/newsletter", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });

      if (!res.ok) {
        throw new Error("Request failed");
      }

      setFormState("success");
      setEmail("");
      trackEvent("newsletter_submit_success", { location: "newsletter_section" });
    } catch {
      setFormState("error");
      setErrorMessage("Something went wrong. Try again.");
    }
  }

  return (
    <section
      ref={sectionRef}
      id="newsletter"
      className="py-10 md:py-16"
    >
      <div className="site-container">
        <div className="mx-auto max-w-2xl">
          <div ref={cardRef}>
            <FormaShellCard className="px-6 py-6 text-center md:px-12 md:py-12">
              <FormaShellSectionHeading
                title="Stay in the loop"
                description="Updates on new features and the occasional file organization joke."
                align="center"
              />

              <div className="mt-6">
                {formState === "success" ? (
                  <div className="flex items-center justify-center gap-2 py-3 text-forma-sage">
                    <CheckCircle2 className="h-4 w-4" />
                    <span className="font-display text-base">You&apos;re in.</span>
                  </div>
                ) : (
                  <form
                    onSubmit={handleSubmit}
                    className="mx-auto flex max-w-sm flex-col gap-2.5 sm:flex-row"
                  >
                    <Input
                      type="email"
                      value={email}
                      onChange={(e) => {
                        setEmail(e.target.value);
                        if (formState === "error") setFormState("idle");
                      }}
                      placeholder="you@example.com"
                      required
                      disabled={formState === "loading"}
                      aria-label="Email address"
                      aria-invalid={formState === "error"}
                      className={cn(
                        "h-11 flex-1 rounded-xl border bg-[var(--shell-surface-muted)] px-4 text-[14px] text-[var(--text-primary)] placeholder:text-[var(--text-muted)] focus-visible:border-forma-steel-blue focus-visible:ring-2 focus-visible:ring-forma-steel-blue/20 disabled:opacity-50",
                        formState === "error"
                          ? "border-red-400"
                          : "border-[var(--shell-border)]"
                      )}
                    />
                    <Button
                      type="submit"
                      disabled={formState === "loading"}
                      className="h-11 cursor-pointer whitespace-nowrap rounded-xl border border-[var(--shell-cta-border)] bg-[var(--shell-cta-bg)] px-5 text-[14px] font-semibold text-[var(--shell-cta-text)] transition-all duration-200 hover:bg-[var(--shell-cta-bg-hover)] hover:shadow-[var(--shell-shadow-strong)]"
                    >
                      {formState === "loading" ? (
                        <>
                          <Loader2 className="h-3.5 w-3.5 animate-spin" />
                          <span>Subscribing</span>
                        </>
                      ) : (
                        <span>Subscribe</span>
                      )}
                    </Button>
                  </form>
                )}

                {formState === "error" && errorMessage && (
                  <p role="alert" className="mt-2 text-[13px] text-red-400">
                    {errorMessage}
                  </p>
                )}
              </div>
            </FormaShellCard>
          </div>
        </div>
      </div>
    </section>
  );
}
