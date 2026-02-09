"use client";

import { useState, useRef, type FormEvent } from "react";
import { Loader2, CheckCircle2 } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";
import { MagneticButton } from "@/components/animation/MagneticButton";

type FormState = "idle" | "loading" | "success" | "error";

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export default function NewsletterSection() {
  const enableScrollAnimations = true;
  const sectionRef = useRef<HTMLElement>(null);
  const cardRef = useRef<HTMLDivElement>(null);

  const [email, setEmail] = useState("");
  const [formState, setFormState] = useState<FormState>("idle");
  const [errorMessage, setErrorMessage] = useState("");

  useGSAP(
    () => {
      if (!enableScrollAnimations) return;
      if (!sectionRef.current || !cardRef.current) return;

      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;

      if (prefersReducedMotion) {
        gsap.set(cardRef.current, { opacity: 1, y: 0 });
        return;
      }

      gsap.fromTo(
        cardRef.current,
        { opacity: 0, y: 40 },
        {
          opacity: 1,
          y: 0,
          duration: formaDuration.normal,
          ease: formaReveal,
          scrollTrigger: {
            trigger: sectionRef.current,
            start: "top 85%",
            toggleActions: "play none none none",
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
      className="py-16 md:py-20"
    >
      <div className="site-container">
        {/* Glow halo behind the dark card */}
        <div className="relative mx-auto max-w-2xl">
          <div className="pointer-events-none absolute -inset-8 rounded-3xl bg-[radial-gradient(ellipse_at_center,rgba(91,124,153,0.15)_0%,rgba(122,157,126,0.08)_40%,transparent_70%)] blur-2xl" aria-hidden="true" />

          <div
            ref={cardRef}
            className="relative rounded-2xl bg-forma-obsidian px-8 py-10 md:px-12 md:py-12 text-center"
          >
            <h2 className="font-display text-2xl md:text-3xl text-forma-bone">
              Stay in the loop
            </h2>

            <p className="mt-3 text-[15px] text-forma-bone/55 leading-relaxed">
              Updates on new features and the occasional file organization joke.
            </p>

            <div className="mt-8">
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
                      className={`w-full rounded-lg bg-white/10 border px-3.5 py-2.5 text-[14px] text-forma-bone placeholder:text-forma-bone/30 focus:outline-none focus:border-forma-steel-blue/50 focus:ring-1 focus:ring-forma-steel-blue/30 transition-all disabled:opacity-50 ${formState === "error" ? "border-red-400" : "border-white/15"}`}
                    />
                  </div>
                  <MagneticButton strength={0.2}>
                    <button
                      type="submit"
                      disabled={formState === "loading"}
                      className="inline-flex items-center justify-center gap-2 rounded-xl bg-forma-bone text-forma-obsidian border border-forma-bone/20 px-5 py-2.5 text-[14px] font-medium transition-all duration-200 hover:bg-forma-bone/90 hover:shadow-md active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer whitespace-nowrap"
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
                  </MagneticButton>
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
