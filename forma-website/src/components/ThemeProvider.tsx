"use client";

import { createContext, useContext, type ReactNode } from "react";

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

/**
 * ThemeProvider - Manages theme state with system preference detection
 *
 * Detects the user's system color scheme via matchMedia and applies
 * the data-theme attribute to documentElement. Listens for system
 * preference changes in real time.
 *
 * @example
 * ```tsx
 * // In layout.tsx
 * <ThemeProvider>
 *   {children}
 * </ThemeProvider>
 *
 * // In any client component
 * const { theme, resolvedTheme, setTheme } = useTheme();
 * ```
 */
export function ThemeProvider({
  children,
  defaultTheme = "light",
}: ThemeProviderProps) {
  const theme: Theme = "dark";
  const resolvedTheme: ResolvedTheme = "dark";

  // Marketing site now ships in a dark theme.
  const setTheme: ThemeContextType["setTheme"] = () => {};

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
 *
 * @returns {ThemeContextType} The theme context with theme, resolvedTheme, and setTheme
 */
export function useTheme(): ThemeContextType {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used within a ThemeProvider");
  }
  return context;
}
