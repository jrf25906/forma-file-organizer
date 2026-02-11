"use client";

import { createContext, useContext, useEffect, useState, type ReactNode } from "react";

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

function resolveTheme(theme: Theme): ResolvedTheme {
  if (theme === "system") return getSystemTheme();
  return theme;
}

export function ThemeProvider({
  children,
  defaultTheme = "system",
}: ThemeProviderProps) {
  const [theme, setThemeState] = useState<Theme>(defaultTheme);
  const [resolvedTheme, setResolvedTheme] = useState<ResolvedTheme>(() =>
    resolveTheme(defaultTheme)
  );

  // Apply resolved theme to document and listen for system changes
  useEffect(() => {
    const resolved = resolveTheme(theme);
    setResolvedTheme(resolved);
    document.documentElement.setAttribute("data-theme", resolved);

    if (theme !== "system") return;

    const mql = window.matchMedia("(prefers-color-scheme: light)");
    const onChange = () => {
      const next = mql.matches ? "light" : "dark";
      setResolvedTheme(next);
      document.documentElement.setAttribute("data-theme", next);
    };
    mql.addEventListener("change", onChange);
    return () => mql.removeEventListener("change", onChange);
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

/**
 * useTheme - Access the current theme context
 *
 * Must be used within a ThemeProvider.
 */
export function useTheme(): ThemeContextType {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used within a ThemeProvider");
  }
  return context;
}
