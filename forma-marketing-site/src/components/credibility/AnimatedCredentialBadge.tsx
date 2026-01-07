"use client";

import {
  useRef,
  useEffect,
  useState,
  type ReactNode,
  type ComponentType,
  type RefObject,
} from "react";
import SplitType from "split-type";
import { gsap, ScrollTrigger } from "@/lib/animation/gsap-config";
import { MagneticButton } from "@/components/animation/MagneticButton";
import { useReducedMotion } from "@/hooks/use-reduced-motion";
import type { DrawableIconHandle } from "./icons";

interface AnimatedCredentialBadgeProps {
  /** The animated icon component to render */
  Icon: ComponentType<{
    size?: number;
    className?: string;
    color?: string;
    delay?: number;
    ref?: RefObject<DrawableIconHandle | null>;
  }>;
  /** Primary label text (e.g., "Mac-Native") */
  label: string;
  /** Secondary hint text shown on hover (e.g., "Not another Electron app") */
  hint: string;
  /** Stagger delay for choreographed entrance (in seconds) */
  staggerDelay?: number;
  /** Icon color */
  iconColor?: string;
  /** Additional className for the badge container */
  className?: string;
}

/**
 * AnimatedCredentialBadge - A single tech credential with premium animations
 *
 * Features:
 * - DrawSVG-style icon animation on scroll
 * - SplitText character wave on hover
 * - Magnetic pull effect
 * - Hint text reveal
 */
/**
 * PulsingStatusRing - An ethereal ring that pulses to indicate active monitoring
 */
function PulsingStatusRing({ color }: { color: string }) {
  const ringRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ringRef.current) return;

    // Rotating gradient ring
    gsap.to(ringRef.current, {
      rotation: 360,
      duration: 20,
      repeat: -1,
      ease: "none"
    });

    // Breathing scale
    gsap.to(ringRef.current, {
      scale: 1.1,
      opacity: 0.6,
      duration: 3,
      repeat: -1,
      yoyo: true,
      ease: "sine.inOut"
    });
  }, []);

  return (
    <div className="absolute inset-0 -m-1.5 rounded-full pointer-events-none overflow-hidden">
      <div
        ref={ringRef}
        className="absolute inset-0 rounded-full opacity-40"
        style={{
          background: `conic-gradient(from 0deg, transparent 0%, ${color} 50%, transparent 100%)`,
          maskImage: "radial-gradient(transparent 60%, black 70%)",
          WebkitMaskImage: "radial-gradient(transparent 60%, black 70%)"
        }}
      />
    </div>
  );
}

export function AnimatedCredentialBadge({
  Icon,
  label,
  hint,
  staggerDelay = 0,
  iconColor = "#5B7C99", // forma-steel-blue
  className = "",
}: AnimatedCredentialBadgeProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const labelRef = useRef<HTMLSpanElement>(null);
  const hintRef = useRef<HTMLSpanElement>(null);
  const iconRef = useRef<DrawableIconHandle>(null);
  const splitInstanceRef = useRef<SplitType | null>(null);
  const [hasAnimated, setHasAnimated] = useState(false);
  const reducedMotion = useReducedMotion();

  // Set up scroll-triggered icon draw animation
  useEffect(() => {
    const container = containerRef.current;
    if (!container || reducedMotion) return;

    // Create scroll trigger to draw icon when entering viewport
    const trigger = ScrollTrigger.create({
      trigger: container,
      start: "top 85%",
      onEnter: () => {
        if (!hasAnimated && iconRef.current) {
          iconRef.current.draw();
          setHasAnimated(true);
        }
      },
    });

    return () => {
      trigger.kill();
    };
  }, [hasAnimated, reducedMotion]);

  // Set up SplitType for hover animation
  useEffect(() => {
    const labelEl = labelRef.current;
    if (!labelEl || reducedMotion) return;

    // Split the label text into characters
    splitInstanceRef.current = new SplitType(labelEl, {
      types: "chars",
      tagName: "span",
    });

    // Style chars for animation
    if (splitInstanceRef.current.chars) {
      gsap.set(splitInstanceRef.current.chars, {
        display: "inline-block",
        willChange: "transform",
      });
    }

    return () => {
      if (splitInstanceRef.current) {
        splitInstanceRef.current.revert();
        splitInstanceRef.current = null;
      }
    };
  }, [label, reducedMotion]);

  // Hover animation handlers
  const handleMouseEnter = () => {
    if (reducedMotion) return;

    // Trigger icon's internal hover animation
    iconRef.current?.hover?.();

    // Animate characters with wave effect
    if (splitInstanceRef.current?.chars) {
      gsap.to(splitInstanceRef.current.chars, {
        y: -4,
        stagger: 0.02,
        duration: 0.4,
        ease: "elastic.out(1.2, 0.5)",
      });
    }

    // Show hint
    if (hintRef.current) {
      gsap.to(hintRef.current, {
        opacity: 1,
        y: 0,
        duration: 0.3,
        ease: "power2.out",
      });
    }
  };

  const handleMouseLeave = () => {
    if (reducedMotion) return;

    // Trigger icon's internal unhover animation
    iconRef.current?.unhover?.();

    // Reset characters
    if (splitInstanceRef.current?.chars) {
      gsap.to(splitInstanceRef.current.chars, {
        y: 0,
        stagger: 0.015,
        duration: 0.3,
        ease: "power2.out",
      });
    }

    // Hide hint
    if (hintRef.current) {
      gsap.to(hintRef.current, {
        opacity: 0,
        y: 4,
        duration: 0.2,
        ease: "power2.in",
      });
    }
  };

  return (
    <MagneticButton strength={0.12} className="cursor-default">
      <div
        ref={containerRef}
        className={`group relative flex items-center gap-3 px-4 py-2 rounded-full transition-all duration-300 hover:bg-forma-obsidian/[0.03] ${className}`}
        onMouseEnter={handleMouseEnter}
        onMouseLeave={handleMouseLeave}
      >
        {/* Icon container with pulsing ring */}
        <div className="relative flex-shrink-0">
          <PulsingStatusRing color={iconColor} />

          {/* Verified Dot */}
          <div
            className="absolute -top-0.5 -right-0.5 w-2 h-2 rounded-full border-2 border-forma-bone z-20"
            style={{
              background: "#4ade80", // Success green
              boxShadow: `0 0 8px ${iconColor}50`
            }}
          />

          <Icon
            ref={iconRef}
            size={26}
            color={iconColor}
            delay={staggerDelay}
            className="relative z-10 transition-transform duration-300 group-hover:scale-110"
          />
        </div>

        {/* Label with SplitText hover */}
        <span
          ref={labelRef}
          className="text-lg font-medium text-forma-obsidian/70 group-hover:text-forma-obsidian transition-colors duration-300 tracking-tight"
        >
          {label}
        </span>

        {/* Hint text - reveals on hover */}
        <span
          ref={hintRef}
          className="absolute left-1/2 -translate-x-1/2 top-full mt-2 text-xs whitespace-nowrap opacity-0 translate-y-1"
          style={{ color: iconColor }}
        >
          {hint}
        </span>
      </div>
    </MagneticButton>
  );
}

export default AnimatedCredentialBadge;
