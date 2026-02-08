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
  const enableScrollAnimations = false;
  const sectionRef = useRef<HTMLElement>(null);
  const headingRef = useRef<HTMLHeadingElement>(null);
  const subtextRef = useRef<HTMLParagraphElement>(null);
  const formWrapperRef = useRef<HTMLDivElement>(null);

  const [email, setEmail] = useState("");
  const [formState, setFormState] = useState<FormState>("idle");
  const [errorMessage, setErrorMessage] = useState("");

  useGSAP(
    () => {
      if (!enableScrollAnimations) return;
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
      className="py-20 md:py-28"
    >
      <div className="site-container">
        <div className="mx-auto max-w-xl text-center">
        <h2
          ref={headingRef}
          className="font-display text-2xl md:text-3xl text-forma-obsidian"
        >
          Stay in the loop
        </h2>

        <p
          ref={subtextRef}
          className="mt-3 text-[15px] text-forma-obsidian/50 leading-relaxed"
        >
          Updates on new features and the occasional file organization joke.
        </p>

        <div ref={formWrapperRef} className="mt-8">
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
                  className="w-full rounded-lg bg-white border border-black/[0.1] px-3.5 py-2.5 text-[14px] text-forma-obsidian placeholder:text-forma-obsidian/30 focus:outline-none focus:border-forma-steel-blue/40 focus:ring-1 focus:ring-forma-steel-blue/20 transition-all disabled:opacity-50"
                />
              </div>
              <button
                type="submit"
                disabled={formState === "loading"}
                className="dark-button inline-flex items-center justify-center gap-2 rounded-lg border px-5 py-2.5 text-[14px] font-medium transition-all duration-200 hover:shadow-md active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer whitespace-nowrap"
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
            <p className="mt-2 text-[13px] text-forma-warm-orange">
              {errorMessage}
            </p>
          )}
        </div>
        </div>
      </div>
    </section>
  );
}
