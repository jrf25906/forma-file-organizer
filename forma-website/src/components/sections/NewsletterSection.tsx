"use client";

import { useState, useRef, type FormEvent } from "react";
import { Loader2, CheckCircle2 } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";

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
          <div
            ref={cardRef}
            className="bg-[var(--bg-secondary)] border border-[var(--border-subtle)] rounded-2xl p-6 md:px-12 md:py-12 text-center"
          >
            <h2 className="font-display text-2xl md:text-3xl text-[var(--text-primary)]">
              Stay in the loop
            </h2>

            <p className="mt-3 text-[15px] leading-relaxed text-[var(--text-secondary)]">
              Updates on new features and the occasional file organization joke.
            </p>

            <div className="mt-6">
              {formState === "success" ? (
                <div className="flex items-center justify-center gap-2 text-forma-sage py-3">
                  <CheckCircle2 className="w-4 h-4" />
                  <span className="font-display text-base">You&apos;re in.</span>
                </div>
              ) : (
                <form
                  onSubmit={handleSubmit}
                  className="flex flex-col sm:flex-row gap-2.5 max-w-sm mx-auto"
                >
                  <div className="flex-1 relative">
                    <input
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
                      className={`w-full rounded-lg bg-[var(--input-bg)] border px-3.5 py-2.5 text-[14px] text-[var(--text-primary)] placeholder:text-[var(--text-muted)] focus:outline-none focus:border-forma-steel-blue/50 focus:ring-1 focus:ring-forma-steel-blue/30 transition-all disabled:opacity-50 ${formState === "error" ? "border-red-400" : "border-[var(--border-strong)]"}`}
                    />
                  </div>
                  <button
                    type="submit"
                    disabled={formState === "loading"}
                    className="inline-flex cursor-pointer items-center justify-center gap-2 whitespace-nowrap rounded-xl border border-[var(--border-medium)] bg-[var(--cta-bg)] px-5 py-2.5 text-[14px] font-medium text-[var(--cta-text)] transition-all duration-200 hover:bg-[var(--cta-bg-hover)] hover:shadow-md active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    {formState === "loading" ? (
                      <>
                        <Loader2 className="w-3.5 h-3.5 animate-spin" />
                        <span>Subscribing</span>
                      </>
                    ) : (
                      <span>Subscribe</span>
                    )}
                  </button>
                </form>
              )}

              {formState === "error" && errorMessage && (
                <p role="alert" className="mt-2 text-[13px] text-red-400">
                  {errorMessage}
                </p>
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
