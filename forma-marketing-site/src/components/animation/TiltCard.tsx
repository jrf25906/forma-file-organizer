"use client";

import React, { forwardRef } from "react";
import { useTilt } from "@/hooks/use-tilt";
import { useReducedMotion } from "@/hooks/use-reduced-motion";
import { cn } from "@/lib/utils";

interface TiltCardProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Maximum rotation angle in degrees (default 10) */
  maxRotation?: number;
  /** Scale on hover (default 1.02) */
  scale?: number;
  /** Whether to show a glare effect following the tilt (default false) */
  glare?: boolean;
  /** Additional CSS classes */
  className?: string;
  /** Whether the tilt effect is enabled (overrides reduced motion check) */
  enabled?: boolean;
  /** Children to render inside the card */
  children?: React.ReactNode;
}

/**
 * TiltCard - A wrapper component that adds a 3D tilt effect
 *
 * The card tilts toward the cursor position when hovering and
 * returns to flat when the cursor leaves. Optionally includes
 * a glare overlay that follows the tilt angle.
 *
 * Accessibility: Automatically disables tilt effect when user
 * prefers reduced motion, as 3D transforms can cause vestibular
 * discomfort for some users.
 *
 * @example
 * ```tsx
 * // Basic usage
 * <TiltCard>
 *   <h2>Feature Card</h2>
 *   <p>This card tilts on hover</p>
 * </TiltCard>
 *
 * // With glare effect
 * <TiltCard glare maxRotation={15} scale={1.05}>
 *   <img src="/feature.png" alt="Feature" />
 *   <p>Premium card with glare</p>
 * </TiltCard>
 *
 * // Subtle tilt for icons
 * <TiltCard maxRotation={5} scale={1}>
 *   <Icon />
 * </TiltCard>
 * ```
 */
export const TiltCard = forwardRef<HTMLDivElement, TiltCardProps>(
  (
    {
      children,
      maxRotation = 10,
      scale = 1.02,
      glare = false,
      className,
      enabled,
      ...props
    },
    ref
  ) => {
    // Check if user prefers reduced motion
    const reducedMotion = useReducedMotion();

    // Determine if tilt should be enabled
    // If enabled prop is explicitly set, use it; otherwise, disable for reduced motion
    const shouldEnableTilt = enabled !== undefined ? enabled : !reducedMotion;

    const tiltRef = useTilt<HTMLDivElement>({
      maxRotation,
      scale,
      glare,
      enabled: shouldEnableTilt,
    });

    // Combine refs
    const combinedRef = (node: HTMLDivElement | null) => {
      (tiltRef as React.MutableRefObject<HTMLDivElement | null>).current = node;
      if (typeof ref === "function") {
        ref(node);
      } else if (ref) {
        ref.current = node;
      }
    };

    return (
      <div
        ref={combinedRef}
        className={cn(
          // 3D transform container styles
          "relative",
          // Only apply 3D perspective when tilt is enabled
          shouldEnableTilt && "[perspective:1000px]",
          shouldEnableTilt && "[transform-style:preserve-3d]",
          // Performance hint only when animating
          shouldEnableTilt && "will-change-transform",
          className
        )}
        {...props}
      >
        {children}
      </div>
    );
  }
);

TiltCard.displayName = "TiltCard";

export default TiltCard;
