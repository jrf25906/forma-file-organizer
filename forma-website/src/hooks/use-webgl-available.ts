"use client";
import { useState, useEffect } from "react";

export function useWebGLAvailable(): boolean {
  const [available, setAvailable] = useState(false);

  useEffect(() => {
    // Disable on mobile for battery/performance
    const isMobile = window.innerWidth < 768;
    if (isMobile) {
      setAvailable(false);
      return;
    }

    try {
      const canvas = document.createElement("canvas");
      const gl = canvas.getContext("webgl2") || canvas.getContext("webgl");
      setAvailable(!!gl);
    } catch {
      setAvailable(false);
    }
  }, []);

  return available;
}
