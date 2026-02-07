"use client";

import { useState, useRef, type FormEvent } from "react";
import { Loader2, ArrowRight, CheckCircle2 } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation";
import { formaReveal, formaDuration } from "@/lib/animation";

type FormState = "idle" | "loading" | "success" | "error";

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export default function NewsletterSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const headingRef = useRef<HTMLHeadingElement>(null);
  const subtextRef = useRef<HTMLParagraphElement>(null);
  const formWrapperRef = useRef<HTMLDivElement>(null);

  const [email, setEmail] = useState("");
  const [formState, setFormState] = useState<FormState>("idle");
  const [errorMessage, setErrorMessage] = useState("");

  useGSAP(
    () => {
      if (!sectionRef.current) return;

      const tl = gsap.timeline({
        scrollTrigger: {
          trigger: sectionRef.current,
          start: "top 80%",
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
          subtextRef.current,
          {
            opacity: 0,
            y: 20,
            duration: formaDuration.fast,
            ease: formaReveal,
          },
          "-=0.5"
        )
        .from(
          formWrapperRef.current,
          {
            opacity: 0,
            y: 20,
            duration: formaDuration.fast,
            ease: formaReveal,
          },
          "-=0.3"
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
      className="py-24 md:py-32 px-6"
    >
      <div className="max-w-xl mx-auto text-center">
        {/* Heading */}
        <h2
          ref={headingRef}
          className="font-display text-3xl md:text-4xl text-forma-bone"
        >
          Stay in the loop
        </h2>

        {/* Subtext */}
        <p
          ref={subtextRef}
          className="mt-4 text-forma-bone/60 leading-relaxed"
        >
          Updates on new features, tips, and the occasional file organization
          joke.
        </p>

        {/* Form */}
        <div ref={formWrapperRef} className="mt-10">
          {formState === "success" ? (
            <div className="flex items-center justify-center gap-2 text-forma-sage py-4">
              <CheckCircle2 className="w-5 h-5" />
              <span className="font-display text-lg">You&apos;re in!</span>
            </div>
          ) : (
            <form
              onSubmit={handleSubmit}
              className="flex flex-col sm:flex-row gap-3 max-w-md mx-auto"
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
                  className="w-full rounded-xl bg-white/5 border border-forma-bone/10 px-4 py-3 text-forma-bone placeholder:text-forma-bone/30 focus:outline-none focus:border-forma-steel-blue/50 focus:ring-1 focus:ring-forma-steel-blue/30 transition-all disabled:opacity-50"
                />
              </div>
              <button
                type="submit"
                disabled={formState === "loading"}
                className="dark-button inline-flex items-center justify-center gap-2 rounded-xl border px-6 py-3 font-display transition-all duration-300 hover:scale-[1.02] hover:shadow-lg hover:shadow-forma-steel-blue/15 active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer whitespace-nowrap"
              >
                {formState === "loading" ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    <span>Subscribing</span>
                  </>
                ) : (
                  <>
                    <span>Subscribe</span>
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </button>
            </form>
          )}

          {/* Error message */}
          {formState === "error" && errorMessage && (
            <p className="mt-3 text-sm text-forma-warm-orange">
              {errorMessage}
            </p>
          )}
        </div>
      </div>
    </section>
  );
}
