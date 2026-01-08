"use client";

import { useEffect, useState, useRef } from "react";
import { motion, useInView } from "framer-motion";

interface AnimatedStatProps {
  value: number;
  suffix: string;
  prefix?: string;
  description: string;
  color: string;
  personaKey: string; // Used to re-trigger animation on persona change
}

// Easing function for smooth deceleration
const easeOutQuart = (t: number): number => 1 - Math.pow(1 - t, 4);

export default function AnimatedStat({
  value,
  suffix,
  prefix = "",
  description,
  color,
  personaKey,
}: AnimatedStatProps) {
  const [displayValue, setDisplayValue] = useState(0);
  const ref = useRef<HTMLDivElement>(null);
  const isInView = useInView(ref, { once: false, margin: "-50px" });
  const animationRef = useRef<number | null>(null);

  // Determine if we should show decimal places based on the value
  const showDecimals = value % 1 !== 0 || value < 10;

  useEffect(() => {
    // Reset and animate when persona changes or comes into view
    if (!isInView) return;

    // Cancel any ongoing animation
    if (animationRef.current) {
      cancelAnimationFrame(animationRef.current);
    }

    // Reset to 0 for new animation
    setDisplayValue(0);

    const duration = 1200; // ms
    const startTime = performance.now();

    const animate = (currentTime: number) => {
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const easedProgress = easeOutQuart(progress);
      const currentValue = easedProgress * value;

      setDisplayValue(currentValue);

      if (progress < 1) {
        animationRef.current = requestAnimationFrame(animate);
      }
    };

    // Small delay for visual effect when switching personas
    const timeout = setTimeout(() => {
      animationRef.current = requestAnimationFrame(animate);
    }, 100);

    return () => {
      clearTimeout(timeout);
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [isInView, value, personaKey]);

  // Format the display value
  const formattedValue = showDecimals
    ? displayValue.toFixed(1)
    : Math.round(displayValue).toString();

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.3 }}
      className="glass-card rounded-xl p-4 inline-flex items-center gap-4"
    >
      <div
        className={`w-14 h-14 rounded-xl bg-forma-${color}/20 flex items-center justify-center overflow-hidden`}
      >
        <motion.span
          key={personaKey}
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ duration: 0.3, ease: "easeOut" }}
          className={`text-2xl font-display font-bold text-forma-${color}`}
        >
          {formattedValue}
          {prefix && <span className="text-lg">{prefix}</span>}
        </motion.span>
      </div>
      <div>
        <motion.div
          key={`suffix-${personaKey}`}
          initial={{ x: -10, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          transition={{ duration: 0.3, delay: 0.1 }}
          className="text-forma-bone font-medium"
        >
          {suffix}
        </motion.div>
        <motion.div
          key={`desc-${personaKey}`}
          initial={{ x: -10, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          transition={{ duration: 0.3, delay: 0.15 }}
          className="text-sm text-forma-bone/50"
        >
          {description}
        </motion.div>
      </div>
    </motion.div>
  );
}
