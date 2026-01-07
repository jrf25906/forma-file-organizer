"use client";

import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useGSAP } from "@gsap/react";

// Only register plugins on the client side to avoid SSR issues
if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger, useGSAP);

  // Set sensible defaults for GSAP
  // Using 0.85s as the baseline creates more deliberate, premium-feeling motion
  gsap.defaults({
    ease: "power3.out",
    duration: 0.85,
  });

  // Configure ScrollTrigger defaults
  ScrollTrigger.defaults({
    toggleActions: "play none none reverse",
    start: "top 80%",
    end: "bottom 20%",
  });

  // Optimize for smooth scrolling performance
  ScrollTrigger.config({
    ignoreMobileResize: true,
    autoRefreshEvents: "visibilitychange,DOMContentLoaded,load",
  });
}

export { gsap, ScrollTrigger, useGSAP };
