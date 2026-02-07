"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  type ReactNode,
} from "react";

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
  defaultTheme = "system",
}: ThemeProviderProps) {
  const [theme, setThemeState] = useState<Theme>(defaultTheme);
  const [resolvedTheme, setResolvedTheme] = useState<ResolvedTheme>("dark");
  const [mounted, setMounted] = useState(false);

  // Resolve system preference to actual theme
  const resolveTheme = useCallback(
    (themeValue: Theme): ResolvedTheme => {
      if (themeValue === "system") {
        if (typeof window === "undefined") return "dark";
        return window.matchMedia("(prefers-color-scheme: dark)").matches
          ? "dark"
          : "light";
      }
      return themeValue;
    },
    []
  );

  // Apply theme to document
  const applyTheme = useCallback((resolved: ResolvedTheme) => {
    document.documentElement.setAttribute("data-theme", resolved);
    setResolvedTheme(resolved);
  }, []);

  // Set theme handler
  const setTheme = useCallback(
    (newTheme: Theme) => {
      setThemeState(newTheme);
      const resolved = resolveTheme(newTheme);
      applyTheme(resolved);
    },
    [resolveTheme, applyTheme]
  );

  // Initialize on mount and listen for system preference changes
  useEffect(() => {
    setMounted(true);

    const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");

    // Set initial theme
    const resolved = resolveTheme(theme);
    applyTheme(resolved);

    // Listen for system preference changes
    const handleChange = () => {
      // Only update if current theme is "system"
      if (theme === "system") {
        const newResolved = mediaQuery.matches ? "dark" : "light";
        applyTheme(newResolved);
      }
    };

    mediaQuery.addEventListener("change", handleChange);

    return () => {
      mediaQuery.removeEventListener("change", handleChange);
    };
  }, [theme, resolveTheme, applyTheme]);

  // Prevent flash by not rendering until mounted
  // The server will render with default theme, client will reconcile
  const value: ThemeContextType = {
    theme,
    resolvedTheme: mounted ? resolvedTheme : "dark",
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
