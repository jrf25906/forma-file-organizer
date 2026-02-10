"use client";

import { useRef, useMemo, type CSSProperties } from "react";
import { useGSAP } from "@/lib/animation/gsap-config";
import { gsap } from "@/lib/animation/gsap-config";
import { getReducedMotionValue } from "@/hooks/use-reduced-motion";

interface TextRevealProps {
  children: string;
  /** Split by words or individual characters */
  type?: "words" | "chars";
  /** Stagger delay between elements in seconds */
  stagger?: number;
  /** Whether to scrub with scroll or trigger once */
  scrub?: boolean;
  className?: string;
  /** HTML tag to render (default: span) */
  as?: "span" | "h1" | "h2" | "h3" | "p";
  style?: CSSProperties;
}

export function TextReveal({
  children,
  type = "words",
  stagger = 0.03,
  scrub = false,
  className,
  as: Tag = "span",
  style,
}: TextRevealProps) {
  const containerRef = useRef<HTMLElement>(null);

  const elements = useMemo(() => {
    if (type === "chars") {
      return children.split("").map((char, i) => (
        <span
          key={i}
          className="inline-block"
          data-reveal-element
          style={{ whiteSpace: char === " " ? "pre" : undefined }}
        >
          {char}
        </span>
      ));
    }

    const words = children.split(" ");
    return words.flatMap((word, i) => {
      const els = [
        <span key={`w${i}`} className="inline-block overflow-hidden">
          <span className="inline-block" data-reveal-element>
            {word}
          </span>
        </span>,
      ];
      if (i < words.length - 1) {
        els.push(<span key={`s${i}`} className="inline"> </span>);
      }
      return els;
    });
  }, [children, type]);

  useGSAP(
    () => {
      if (!containerRef.current || getReducedMotionValue()) {
        // Show all text immediately
        const els = containerRef.current?.querySelectorAll("[data-reveal-element]");
        if (els) gsap.set(els, { opacity: 1, y: 0 });
        return;
      }

      const els = containerRef.current.querySelectorAll("[data-reveal-element]");
      if (!els.length) return;

      gsap.set(els, { opacity: 0, y: 30 });

      const config: gsap.TweenVars = {
        opacity: 1,
        y: 0,
        stagger,
        duration: 0.6,
        ease: "power3.out",
      };

      if (scrub) {
        gsap.to(els, {
          ...config,
          scrollTrigger: {
            trigger: containerRef.current,
            start: "top 80%",
            end: "top 30%",
            scrub: 1,
          },
        });
      } else {
        gsap.to(els, {
          ...config,
          scrollTrigger: {
            trigger: containerRef.current,
            start: "top 85%",
            toggleActions: "play none none none",
          },
        });
      }
    },
    { scope: containerRef }
  );

  return (
    // @ts-expect-error - dynamic tag type
    <Tag ref={containerRef} className={className} style={style}>
      {elements}
    </Tag>
  );
}

export default TextReveal;
