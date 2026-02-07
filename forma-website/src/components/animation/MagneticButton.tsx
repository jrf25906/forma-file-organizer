"use client";

import React, { forwardRef } from "react";
import { useMagnetic } from "@/hooks/use-magnetic";
import { cn } from "@/lib/utils";

interface MagneticButtonProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Strength of the magnetic pull (0-1, default 0.3) */
  strength?: number;
  /** Additional CSS classes */
  className?: string;
  /** Whether the magnetic effect is enabled */
  enabled?: boolean;
  /** Children to render */
  children?: React.ReactNode;
}

/**
 * MagneticButton - A wrapper component that adds a magnetic hover effect
 *
 * The element smoothly translates toward the cursor position when hovering
 * and springs back to center when the cursor leaves. Uses GSAP with
 * formaMagnetic easing for follow and formaSnap for elastic spring-back.
 *
 * This is a div wrapper that adds magnetic behavior to its children.
 * Wrap your interactive elements (buttons, links) with this component.
 *
 * @example
 * ```tsx
 * <MagneticButton strength={0.3}>
 *   <button className="btn">Click me</button>
 * </MagneticButton>
 *
 * <MagneticButton strength={0.5}>
 *   <a href="/about">About us</a>
 * </MagneticButton>
 * ```
 */
export const MagneticButton = forwardRef<HTMLDivElement, MagneticButtonProps>(
  ({ children, strength = 0.3, className, enabled = true, ...props }, ref) => {
    const magneticRef = useMagnetic<HTMLDivElement>({ strength, enabled });

    // Combine refs
    const setRef = (node: HTMLDivElement | null) => {
      (magneticRef as React.MutableRefObject<HTMLDivElement | null>).current =
        node;
      if (typeof ref === "function") {
        ref(node);
      } else if (ref) {
        ref.current = node;
      }
    };

    return (
      <div
        ref={setRef}
        className={cn("inline-block", className)}
        {...props}
      >
        {children}
      </div>
    );
  }
);

MagneticButton.displayName = "MagneticButton";

export default MagneticButton;
