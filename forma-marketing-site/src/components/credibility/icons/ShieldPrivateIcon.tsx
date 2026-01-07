"use client";

import { forwardRef, useRef, useEffect, useImperativeHandle } from "react";
import { gsap } from "@/lib/animation/gsap-config";
import type { DrawableIconHandle } from "./MonitorNativeIcon";

interface ShieldPrivateIconProps {
  size?: number;
  className?: string;
  color?: string;
  delay?: number;
}

/**
 * ShieldPrivateIcon - Animated privacy shield with lock
 *
 * Shield draws first, then a lock fades in at center,
 * conveying "your files stay local, protected"
 */
export const ShieldPrivateIcon = forwardRef<DrawableIconHandle, ShieldPrivateIconProps>(
  ({ size = 24, className = "", color = "currentColor", delay = 0 }, ref) => {
    const shieldRef = useRef<SVGPathElement>(null);
    const lockBodyRef = useRef<SVGRectElement>(null);
    const lockShackleRef = useRef<SVGPathElement>(null);
    const containerRef = useRef<SVGSVGElement>(null);

    useImperativeHandle(ref, () => ({
      draw: () => {
        const tl = gsap.timeline();

        // Draw shield outline
        if (shieldRef.current) {
          const length = shieldRef.current.getTotalLength();
          tl.fromTo(
            shieldRef.current,
            { strokeDashoffset: length },
            { strokeDashoffset: 0, duration: 0.7, ease: "power2.out" },
            delay
          );
        }

        // Draw lock shackle
        if (lockShackleRef.current) {
          const length = lockShackleRef.current.getTotalLength();
          tl.fromTo(
            lockShackleRef.current,
            { strokeDashoffset: length, opacity: 0 },
            { strokeDashoffset: 0, opacity: 1, duration: 0.4, ease: "power2.out" },
            "-=0.2"
          );
        }

        // Fade in lock body
        if (lockBodyRef.current) {
          tl.fromTo(
            lockBodyRef.current,
            { opacity: 0, scale: 0.8, transformOrigin: "center" },
            { opacity: 1, scale: 1, duration: 0.3, ease: "back.out(1.5)" },
            "-=0.2"
          );
        }

        // Start idle animation after draw
        tl.add(() => {
          gsap.to(containerRef.current, {
            y: "-=2",
            duration: 1.5,
            repeat: -1,
            yoyo: true,
            ease: "sine.inOut"
          });
        });
      },
      reset: () => {
        if (shieldRef.current) {
          const length = shieldRef.current.getTotalLength();
          gsap.set(shieldRef.current, { strokeDashoffset: length });
        }
        if (lockShackleRef.current) {
          const length = lockShackleRef.current.getTotalLength();
          gsap.set(lockShackleRef.current, { strokeDashoffset: length, opacity: 0 });
        }
        if (lockBodyRef.current) {
          gsap.set(lockBodyRef.current, { opacity: 0, scale: 0.8 });
        }
        gsap.killTweensOf(containerRef.current);
        gsap.set(containerRef.current, { y: 0 });
      },
      // New hover methods
      hover: () => {
        // Lock snaps shut
        if (lockShackleRef.current) {
          gsap.to(lockShackleRef.current, {
            y: 2,
            duration: 0.2,
            ease: "power2.in"
          });
        }
        // Shield glows
        if (shieldRef.current) {
          gsap.to(shieldRef.current, {
            stroke: "#4ade80", // bright green
            duration: 0.3
          });
        }
        if (lockBodyRef.current) {
          gsap.to(lockBodyRef.current, {
            fill: "#4ade80",
            duration: 0.3
          });
        }
      },
      unhover: () => {
        if (lockShackleRef.current) {
          gsap.to(lockShackleRef.current, {
            y: 0,
            duration: 0.3,
            ease: "power2.out"
          });
        }
        if (shieldRef.current) {
          gsap.to(shieldRef.current, {
            stroke: color,
            duration: 0.3
          });
        }
        if (lockBodyRef.current) {
          gsap.to(lockBodyRef.current, {
            fill: color,
            duration: 0.3
          });
        }
      }
    }));

    useEffect(() => {
      // Init logic remains
      if (shieldRef.current) {
        const length = shieldRef.current.getTotalLength();
        gsap.set(shieldRef.current, {
          strokeDasharray: length,
          strokeDashoffset: length,
        });
      }
      if (lockShackleRef.current) {
        const length = lockShackleRef.current.getTotalLength();
        gsap.set(lockShackleRef.current, {
          strokeDasharray: length,
          strokeDashoffset: length,
          opacity: 0,
        });
      }
      if (lockBodyRef.current) {
        gsap.set(lockBodyRef.current, { opacity: 0, scale: 0.8 });
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
        {/* Shield outline */}
        <path
          ref={shieldRef}
          d="M12 2L4 6V12C4 16.4183 7.58172 20 12 20C16.4183 20 20 16.4183 20 12V6L12 2Z"
          stroke={color}
          strokeWidth="1.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />

        {/* Lock shackle */}
        <path
          ref={lockShackleRef}
          d="M10 11V9C10 7.89543 10.8954 7 12 7C13.1046 7 14 7.89543 14 9V11"
          stroke={color}
          strokeWidth="1.5"
          strokeLinecap="round"
        />

        {/* Lock body */}
        <rect
          ref={lockBodyRef}
          x="9"
          y="11"
          width="6"
          height="5"
          rx="1"
          fill={color}
          opacity="0.9"
        />
      </svg>
    );
  }
);

ShieldPrivateIcon.displayName = "ShieldPrivateIcon";

export default ShieldPrivateIcon;
