"use client";

import { cn } from "@/lib/utils";

interface SectionTransitionProps {
  /** Color of the gradient (from section above to section below) */
  fromColor?: string;
  toColor?: string;
  /** Height of the transition zone */
  height?: string;
  className?: string;
}

export function SectionTransition({
  fromColor = "transparent",
  toColor = "transparent",
  height = "120px",
  className,
}: SectionTransitionProps) {
  return (
    <div
      className={cn("pointer-events-none relative", className)}
      aria-hidden="true"
      style={{
        height,
        background: `linear-gradient(180deg, ${fromColor} 0%, ${toColor} 100%)`,
      }}
    />
  );
}

export default SectionTransition;
