"use client";

import { useEffect, useState } from "react";

import {
  HEADER_SHELL_LAYOUT,
  type HeaderShellMode,
} from "@/lib/header-shell-layout";

function getHeaderShellMode(
  scrollY: number,
  threshold: number
): HeaderShellMode {
  return scrollY > threshold
    ? HEADER_SHELL_LAYOUT.scrolledMode
    : HEADER_SHELL_LAYOUT.topMode;
}

export function useHeaderShellMode(threshold: number): HeaderShellMode {
  const [mode, setMode] = useState<HeaderShellMode>(
    HEADER_SHELL_LAYOUT.topMode
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
