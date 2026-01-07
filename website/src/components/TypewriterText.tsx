"use client";

import { useEffect, useState, useRef } from "react";
import { motion } from "framer-motion";

interface TypewriterTextProps {
  text: string;
  speed?: number; // ms per character
  delay?: number; // initial delay before starting
  className?: string;
  onComplete?: () => void;
  triggerKey?: string | number; // Changes to this restart the animation
}

export default function TypewriterText({
  text,
  speed = 20,
  delay = 200,
  className = "",
  onComplete,
  triggerKey,
}: TypewriterTextProps) {
  const [displayedText, setDisplayedText] = useState("");
  const [isComplete, setIsComplete] = useState(false);
  const [showCursor, setShowCursor] = useState(true);
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);
  const cursorIntervalRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    // Reset state when text or triggerKey changes
    setDisplayedText("");
    setIsComplete(false);
    setShowCursor(true);

    // Clear any existing timeouts
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }

    let currentIndex = 0;

    const typeNextChar = () => {
      if (currentIndex < text.length) {
        // Type multiple characters at once for faster feel with long quotes
        const charsPerTick = text.length > 100 ? 2 : 1;
        const nextChars = text.slice(currentIndex, currentIndex + charsPerTick);
        setDisplayedText(text.slice(0, currentIndex + charsPerTick));
        currentIndex += charsPerTick;

        // Vary speed slightly for natural feel
        const variance = Math.random() * 10 - 5;
        timeoutRef.current = setTimeout(typeNextChar, speed + variance);
      } else {
        setIsComplete(true);
        onComplete?.();
      }
    };

    // Start typing after delay
    timeoutRef.current = setTimeout(typeNextChar, delay);

    // Cursor blink effect
    cursorIntervalRef.current = setInterval(() => {
      setShowCursor((prev) => !prev);
    }, 530);

    return () => {
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
      if (cursorIntervalRef.current) clearInterval(cursorIntervalRef.current);
    };
  }, [text, speed, delay, onComplete, triggerKey]);

  return (
    <span className={className}>
      {displayedText}
      <motion.span
        animate={{ opacity: showCursor && !isComplete ? 1 : 0 }}
        transition={{ duration: 0.1 }}
        className="inline-block w-[2px] h-[1em] bg-forma-steel-blue ml-0.5 align-middle"
      />
    </span>
  );
}
