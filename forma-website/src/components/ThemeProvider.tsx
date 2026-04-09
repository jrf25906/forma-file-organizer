"use client";

import { createContext, useEffect, useState, type ReactNode } from "react";

type Theme = "dark" | "light" | "system";
type ResolvedTheme = "dark" | "light";

interface ThemeContextType {
  /** The current theme setting ("dark" | "light" | "system") */
  theme: Theme;
  /** The resolved theme after system preference evaluation */
  resolvedTheme: ResolvedTheme;
  /** Update the theme */
  setTheme: (theme: Theme) => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

interface ThemeProviderProps {
  children: ReactNode;
  /** Default theme on first visit (default "system") */
  defaultTheme?: Theme;
}

function getSystemTheme(): ResolvedTheme {
  if (typeof window === "undefined") return "dark";
  return window.matchMedia("(prefers-color-scheme: light)").matches
    ? "light"
    : "dark";
}

export function ThemeProvider({
  children,
  defaultTheme = "system",
}: ThemeProviderProps) {
  const [theme, setThemeState] = useState<Theme>(defaultTheme);
  const [systemTheme, setSystemTheme] = useState<ResolvedTheme>(() =>
    getSystemTheme()
  );
  const resolvedTheme: ResolvedTheme =
    theme === "system" ? systemTheme : theme;

  // Apply resolved theme to document.
  useEffect(() => {
    document.documentElement.setAttribute("data-theme", resolvedTheme);
  }, [resolvedTheme]);

  // Listen for system changes only when theme follows system.
  useEffect(() => {
    if (theme !== "system") return;

    const mql = window.matchMedia("(prefers-color-scheme: light)");
    const onChange = () => {
      const next = mql.matches ? "light" : "dark";
      setSystemTheme(next);
    };

    const syncFrame = window.requestAnimationFrame(onChange);
    mql.addEventListener("change", onChange);
    return () => {
      window.cancelAnimationFrame(syncFrame);
      mql.removeEventListener("change", onChange);
    };
  }, [theme]);

  const setTheme = (next: Theme) => {
    setThemeState(next);
  };

  const value: ThemeContextType = {
    theme,
    resolvedTheme,
    setTheme,
  };

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
}
