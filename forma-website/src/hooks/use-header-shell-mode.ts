"use client";

import { useEffect, useState } from "react";

export type HeaderShellMode = "top" | "scrolled";

export function getHeaderShellMode(
  scrollY: number,
  threshold: number
): HeaderShellMode {
  return scrollY > threshold ? "scrolled" : "top";
}

export function useHeaderShellMode(threshold: number): HeaderShellMode {
  const [mode, setMode] = useState<HeaderShellMode>(() =>
    getHeaderShellMode(
      typeof window === "undefined" ? 0 : window.scrollY,
      threshold
    )
  );

  useEffect(() => {
    const updateMode = () => {
      setMode(getHeaderShellMode(window.scrollY, threshold));
    };

    updateMode();
    window.addEventListener("scroll", updateMode, { passive: true });

    return () => {
      window.removeEventListener("scroll", updateMode);
    };
  }, [threshold]);

  return mode;
}

export default useHeaderShellMode;
