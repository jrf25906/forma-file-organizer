"use client";

import { useScrollAnimation } from "@/hooks/useScrollAnimation";
import { useEffect, useState } from "react";

interface AnimatedTextProps {
  children: string;
  className?: string;
  delay?: number;
  stagger?: number;
  animation?: "fade" | "slide" | "blur" | "chars";
}

export function AnimatedHeadline({
  children,
  className = "",
  delay = 0,
  animation = "slide",
}: AnimatedTextProps) {
  const { ref, isVisible } = useScrollAnimation({ threshold: 0.2 });

  const baseStyles = "transition-all duration-1000 ease-out";
  const hiddenStyles = {
    fade: "opacity-0",
    slide: "opacity-0 translate-y-12",
    blur: "opacity-0 blur-lg",
    chars: "opacity-0",
  };

  return (
    <div ref={ref} className="overflow-hidden">
      <span
        className={`block ${baseStyles} ${!isVisible ? hiddenStyles[animation] : ""} ${className}`}
        style={{ transitionDelay: `${delay}ms` }}
      >
        {children}
      </span>
    </div>
  );
}

export function AnimatedWords({
  children,
  className = "",
  delay = 0,
  stagger = 80,
}: AnimatedTextProps) {
  const { ref, isVisible } = useScrollAnimation({ threshold: 0.2 });
  const words = children.split(" ");

  return (
    <span ref={ref} className={className}>
      {words.map((word, i) => (
        <span key={i} className="inline-block overflow-hidden">
          <span
            className={`inline-block transition-all duration-700 ease-out ${
              !isVisible ? "opacity-0 translate-y-full" : ""
            }`}
            style={{ transitionDelay: `${delay + i * stagger}ms` }}
          >
            {word}
            {i < words.length - 1 ? "\u00A0" : ""}
          </span>
        </span>
      ))}
    </span>
  );
}

export function AnimatedChars({
  children,
  className = "",
  delay = 0,
  stagger = 30,
}: AnimatedTextProps) {
  const { ref, isVisible } = useScrollAnimation({ threshold: 0.2 });
  const chars = children.split("");

  return (
    <span ref={ref} className={className}>
      {chars.map((char, i) => (
        <span
          key={i}
          className={`inline-block transition-all duration-500 ease-out ${
            !isVisible ? "opacity-0 translate-y-4 blur-sm" : ""
          }`}
          style={{ transitionDelay: `${delay + i * stagger}ms` }}
        >
          {char === " " ? "\u00A0" : char}
        </span>
      ))}
    </span>
  );
}

export function TypewriterText({
  children,
  className = "",
  delay = 0,
  speed = 50,
}: Omit<AnimatedTextProps, "animation" | "stagger"> & { speed?: number }) {
  const { ref, isVisible } = useScrollAnimation({ threshold: 0.2 });
  const [displayedText, setDisplayedText] = useState("");
  const [showCursor, setShowCursor] = useState(true);

  useEffect(() => {
    if (!isVisible) return;

    let i = 0;
    const timer = setTimeout(() => {
      const interval = setInterval(() => {
        if (i < children.length) {
          setDisplayedText(children.slice(0, i + 1));
          i++;
        } else {
          clearInterval(interval);
          setTimeout(() => setShowCursor(false), 1000);
        }
      }, speed);

      return () => clearInterval(interval);
    }, delay);

    return () => clearTimeout(timer);
  }, [isVisible, children, delay, speed]);

  return (
    <span ref={ref} className={className}>
      {displayedText}
      <span
        className={`inline-block w-0.5 h-[1em] bg-current ml-0.5 ${
          showCursor ? "animate-blink" : "opacity-0"
        }`}
      />
    </span>
  );
}

export function RevealOnScroll({
  children,
  className = "",
  delay = 0,
  direction = "up",
}: {
  children: React.ReactNode;
  className?: string;
  delay?: number;
  direction?: "up" | "down" | "left" | "right";
}) {
  const { ref, isVisible } = useScrollAnimation({ threshold: 0.15 });

  const directionStyles = {
    up: "translate-y-16",
    down: "-translate-y-16",
    left: "translate-x-16",
    right: "-translate-x-16",
  };

  return (
    <div
      ref={ref}
      className={`transition-all duration-1000 ease-out ${
        !isVisible ? `opacity-0 ${directionStyles[direction]}` : ""
      } ${className}`}
      style={{ transitionDelay: `${delay}ms` }}
    >
      {children}
    </div>
  );
}

export function StaggerChildren({
  children,
  className = "",
  stagger = 100,
  baseDelay = 0,
}: {
  children: React.ReactNode[];
  className?: string;
  stagger?: number;
  baseDelay?: number;
}) {
  const { ref, isVisible } = useScrollAnimation({ threshold: 0.1 });

  return (
    <div ref={ref} className={className}>
      {children.map((child, i) => (
        <div
          key={i}
          className={`transition-all duration-700 ease-out ${
            !isVisible ? "opacity-0 translate-y-8" : ""
          }`}
          style={{ transitionDelay: `${baseDelay + i * stagger}ms` }}
        >
          {child}
        </div>
      ))}
    </div>
  );
}
