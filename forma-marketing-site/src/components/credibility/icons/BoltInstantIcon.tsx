"use client";

import { forwardRef, useRef, useEffect, useImperativeHandle } from "react";
import { gsap } from "@/lib/animation/gsap-config";
import type { DrawableIconHandle } from "./MonitorNativeIcon";

interface BoltInstantIconProps {
  size?: number;
  className?: string;
  color?: string;
  delay?: number;
}

/**
 * BoltInstantIcon - Animated lightning bolt
 *
 * Draws quickly with a flash effect to convey
 * "instant response, zero delay"
 */
export const BoltInstantIcon = forwardRef<DrawableIconHandle, BoltInstantIconProps>(
  ({ size = 24, className = "", color = "currentColor", delay = 0 }, ref) => {
    const boltRef = useRef<SVGPathElement>(null);
    const glowRef = useRef<SVGPathElement>(null);
    const containerRef = useRef<SVGSVGElement>(null);

    useImperativeHandle(ref, () => ({
      draw: () => {
        const tl = gsap.timeline();

        // Charge-up glow (anticipation before the strike)
        // This normalizes total animation time to ~1.0s like other icons
        if (glowRef.current) {
          tl.fromTo(
            glowRef.current,
            { opacity: 0, scale: 0.8, transformOrigin: "center" },
            { opacity: 0.3, scale: 1, duration: 0.4, ease: "power2.out" },
            delay
          );
        }

        // Draw bolt quickly (it's instant, after all)
        if (boltRef.current) {
          const length = boltRef.current.getTotalLength();
          tl.fromTo(
            boltRef.current,
            { strokeDashoffset: length },
            { strokeDashoffset: 0, duration: 0.25, ease: "power3.out" },
            "-=0.1" // Overlap with charge-up
          );
        }

        // Flash glow effect (intensify on strike)
        if (glowRef.current) {
          tl.to(
            glowRef.current,
            { opacity: 0.8, duration: 0.08, ease: "power2.in" },
            "-=0.1"
          );
          tl.to(glowRef.current, {
            opacity: 0,
            duration: 0.35,
            ease: "power2.out",
          });
        }

        // Fill appears after stroke
        if (boltRef.current) {
          tl.to(
            boltRef.current,
            { fillOpacity: 0.15, duration: 0.25, ease: "power2.out" },
            "-=0.25"
          );
        }

        // Idle Electrical Hum
        tl.add(() => {
          if (glowRef.current) {
            gsap.to(glowRef.current, {
              opacity: 0.3,
              duration: 0.1,
              repeat: -1,
              yoyo: true,
              ease: "rough({ template: none.out, strength: 1, points: 20, taper: none, randomize: true, clamp: false })"
            });
          }
          if (containerRef.current) {
            gsap.to(containerRef.current, {
              y: "-=3",
              duration: 0.1,
              repeat: -1,
              yoyo: true,
              ease: "rough({ strength: 0.5, points: 5, taper: none, randomize: true, clamp: false })",
              delay: 2 // Occasional twitch
            });
          }
        });
      },
      reset: () => {
        if (boltRef.current) {
          const length = boltRef.current.getTotalLength();
          gsap.set(boltRef.current, { strokeDashoffset: length, fillOpacity: 0 });
        }
        if (glowRef.current) {
          gsap.set(glowRef.current, { opacity: 0 });
        }
        gsap.killTweensOf([glowRef.current, containerRef.current]);
        gsap.set(containerRef.current, { y: 0 });
      },
      hover: () => {
        // Intense Strike
        const tl = gsap.timeline();

        if (boltRef.current) {
          tl.to(boltRef.current, {
            scale: 1.2,
            fillOpacity: 0.8,
            duration: 0.05,
            ease: "power1.inOut",
            transformOrigin: "center"
          });
          tl.to(boltRef.current, {
            scale: 1,
            fillOpacity: 0.15,
            duration: 0.2,
            ease: "bounce.out"
          });
        }
        if (glowRef.current) {
          gsap.fromTo(glowRef.current,
            { opacity: 0.8, scale: 1.2, transformOrigin: "center" },
            { opacity: 0, scale: 1, duration: 0.3, ease: "power2.out" }
          );
        }
      },
      unhover: () => {
        // Return to idle state (handled by idle loop, but ensure clean transition)
        if (boltRef.current) {
          gsap.to(boltRef.current, {
            scale: 1,
            fillOpacity: 0.15,
            duration: 0.3
          });
        }
      }
    }));

    useEffect(() => {
      if (boltRef.current) {
        const length = boltRef.current.getTotalLength();
        gsap.set(boltRef.current, {
          strokeDasharray: length,
          strokeDashoffset: length,
          fillOpacity: 0,
        });
      }
      if (glowRef.current) {
        gsap.set(glowRef.current, { opacity: 0 });
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
        {/* Glow effect (drawn under bolt) */}
        <path
          ref={glowRef}
          d="M13 2L4.5 13H11L10 22L19.5 10H12.5L13 2Z"
          fill={color}
          style={{ filter: "blur(4px)" }}
        />

        {/* Lightning bolt */}
        <path
          ref={boltRef}
          d="M13 2L4.5 13H11L10 22L19.5 10H12.5L13 2Z"
          stroke={color}
          strokeWidth="1.5"
          strokeLinecap="round"
          strokeLinejoin="round"
          fill={color}
        />
      </svg>
    );
  }
);

BoltInstantIcon.displayName = "BoltInstantIcon";

export default BoltInstantIcon;
