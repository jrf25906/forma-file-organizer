"use client";

import { forwardRef, useRef, useEffect, useImperativeHandle } from "react";
import { gsap } from "@/lib/animation/gsap-config";

export interface DrawableIconHandle {
  draw: () => void;
  reset: () => void;
  hover?: () => void;
  unhover?: () => void;
}

interface MonitorNativeIconProps {
  size?: number;
  className?: string;
  color?: string;
  /** Delay before drawing starts (in seconds) */
  delay?: number;
}

/**
 * MonitorNativeIcon - Animated macOS monitor icon
 *
 * Draws a monitor with macOS-style traffic light dots,
 * conveying "native Mac app, not Electron bloat"
 */
export const MonitorNativeIcon = forwardRef<DrawableIconHandle, MonitorNativeIconProps>(
  ({ size = 24, className = "", color = "currentColor", delay = 0 }, ref) => {
    const monitorRef = useRef<SVGPathElement>(null);
    const standRef = useRef<SVGPathElement>(null);
    const dotsRef = useRef<SVGGElement>(null);
    const containerRef = useRef<SVGSVGElement>(null);
    const codeLine1Ref = useRef<SVGPathElement>(null);
    const codeLine2Ref = useRef<SVGPathElement>(null);

    useImperativeHandle(ref, () => ({
      draw: () => {
        const tl = gsap.timeline();

        // Draw monitor outline
        if (monitorRef.current) {
          const length = monitorRef.current.getTotalLength();
          tl.fromTo(
            monitorRef.current,
            { strokeDashoffset: length },
            { strokeDashoffset: 0, duration: 0.6, ease: "power2.out" },
            delay
          );
        }

        // Draw stand
        if (standRef.current) {
          const length = standRef.current.getTotalLength();
          tl.fromTo(
            standRef.current,
            { strokeDashoffset: length },
            { strokeDashoffset: 0, duration: 0.3, ease: "power2.out" },
            "-=0.2"
          );
        }

        // Pop in traffic light dots
        if (dotsRef.current) {
          const dots = dotsRef.current.querySelectorAll("circle");
          tl.fromTo(
            dots,
            { scale: 0, transformOrigin: "center" },
            { scale: 1, duration: 0.3, stagger: 0.05, ease: "back.out(2)" },
            "-=0.1"
          );
        }

        // Idle animation
        tl.add(() => {
          if (monitorRef.current) {
            gsap.to(monitorRef.current, {
              strokeWidth: 2,
              duration: 1.5,
              repeat: -1,
              yoyo: true,
              ease: "sine.inOut"
            });
            gsap.to(containerRef.current, {
              y: "-=2",
              duration: 2,
              repeat: -1,
              yoyo: true,
              ease: "sine.inOut",
              delay: 0.5
            });
          }
        });
      },
      reset: () => {
        if (monitorRef.current) {
          const length = monitorRef.current.getTotalLength();
          gsap.set(monitorRef.current, { strokeDashoffset: length, strokeWidth: 1.5 });
        }
        if (standRef.current) {
          const length = standRef.current.getTotalLength();
          gsap.set(standRef.current, { strokeDashoffset: length });
        }
        if (dotsRef.current) {
          const dots = dotsRef.current.querySelectorAll("circle");
          gsap.set(dots, { scale: 0 });
        }
        gsap.killTweensOf([monitorRef.current, containerRef.current]);
        gsap.set(containerRef.current, { y: 0 });
      },
      hover: () => {
        // "Native Snap" - expand slightly
        gsap.to(containerRef.current, {
          scale: 1.1,
          duration: 0.4,
          ease: "elastic.out(1, 0.5)"
        });

        // Typing effect on imaginary code lines (we'll add these elements)
        if (codeLine1Ref.current && codeLine2Ref.current) {
          const l1 = codeLine1Ref.current.getTotalLength();
          const l2 = codeLine2Ref.current.getTotalLength();

          gsap.fromTo(codeLine1Ref.current,
            { strokeDashoffset: l1, opacity: 1 },
            { strokeDashoffset: 0, duration: 0.3, ease: "none" }
          );
          gsap.fromTo(codeLine2Ref.current,
            { strokeDashoffset: l2, opacity: 1 },
            { strokeDashoffset: 0, duration: 0.3, ease: "none", delay: 0.15 }
          );
        }
      },
      unhover: () => {
        gsap.to(containerRef.current, {
          scale: 1,
          duration: 0.3,
          ease: "power2.out"
        });

        if (codeLine1Ref.current && codeLine2Ref.current) {
          gsap.to([codeLine1Ref.current, codeLine2Ref.current], {
            opacity: 0,
            duration: 0.2
          });
        }
      }
    }));

    // Initialize stroke-dasharray on mount
    useEffect(() => {
      if (monitorRef.current) {
        const length = monitorRef.current.getTotalLength();
        gsap.set(monitorRef.current, {
          strokeDasharray: length,
          strokeDashoffset: length,
        });
      }
      if (standRef.current) {
        const length = standRef.current.getTotalLength();
        gsap.set(standRef.current, {
          strokeDasharray: length,
          strokeDashoffset: length,
        });
      }
      if (dotsRef.current) {
        const dots = dotsRef.current.querySelectorAll("circle");
        gsap.set(dots, { scale: 0 });
      }
      if (codeLine1Ref.current) {
        const length = codeLine1Ref.current.getTotalLength();
        gsap.set(codeLine1Ref.current, { strokeDasharray: length, strokeDashoffset: length, opacity: 0 });
      }
      if (codeLine2Ref.current) {
        const length = codeLine2Ref.current.getTotalLength();
        gsap.set(codeLine2Ref.current, { strokeDasharray: length, strokeDashoffset: length, opacity: 0 });
      }
    }, []);

    return (
      <svg
        ref={containerRef}
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill="none"
        className={className}
        aria-hidden="true"
      >
        {/* Monitor frame */}
        <path
          ref={monitorRef}
          d="M3 5C3 3.89543 3.89543 3 5 3H19C20.1046 3 21 3.89543 21 5V15C21 16.1046 20.1046 17 19 17H5C3.89543 17 3 16.1046 3 15V5Z"
          stroke={color}
          strokeWidth="1.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />

        {/* Stand */}
        <path
          ref={standRef}
          d="M8 21H16M12 17V21"
          stroke={color}
          strokeWidth="1.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />

        {/* macOS traffic light dots */}
        <g ref={dotsRef}>
          <circle cx="6.5" cy="6" r="1" fill="#FF5F56" />
          <circle cx="9.5" cy="6" r="1" fill="#FFBD2E" />
          <circle cx="12.5" cy="6" r="1" fill="#27C93F" />
        </g>

        {/* Invisible code lines for hover effect */}
        <path
          ref={codeLine1Ref}
          d="M6 10H18"
          stroke={color}
          strokeWidth="1.5"
          strokeLinecap="round"
          opacity="0"
        />
        <path
          ref={codeLine2Ref}
          d="M6 13H14"
          stroke={color}
          strokeWidth="1.5"
          strokeLinecap="round"
          opacity="0"
        />
      </svg>
    );
  }
);

MonitorNativeIcon.displayName = "MonitorNativeIcon";

export default MonitorNativeIcon;
