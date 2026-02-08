"use client";

import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useGSAP } from "@gsap/react";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger, useGSAP);

  gsap.defaults({
    ease: "power3.out",
    duration: 0.85,
    immediateRender: false,
  });

  ScrollTrigger.defaults({
    toggleActions: "play none none none",
    start: "top 80%",
    end: "bottom 20%",
  });

  ScrollTrigger.config({
    ignoreMobileResize: true,
    autoRefreshEvents: "visibilitychange,DOMContentLoaded,load",
  });
}

export { gsap, ScrollTrigger, useGSAP };
