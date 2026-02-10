"use client";

import { useEffect, useRef } from "react";
import Lenis from "lenis";

let globalLenis: Lenis | null = null;

export function setGlobalLenis(lenis: Lenis | null) {
  globalLenis = lenis;
}

export function useLenis() {
  return {
    scrollTo: (target: string | number | HTMLElement, options?: { offset?: number; duration?: number }) => {
      if (globalLenis) {
        globalLenis.scrollTo(target, options);
      } else {
        // Fallback to native scroll when Lenis isn't available
        if (typeof target === "string") {
          const el = document.querySelector(target);
          if (el) {
            const y = el.getBoundingClientRect().top + window.scrollY + (options?.offset ?? -100);
            window.scrollTo({ top: y, behavior: "smooth" });
          }
        } else if (typeof target === "number") {
          window.scrollTo({ top: target, behavior: "smooth" });
        }
      }
    },
  };
}

export default useLenis;
