/**
 * Icon Styling System for Forma Website
 *
 * Uses Phosphor Icons (@phosphor-icons/react) with consistent sizing and styling.
 *
 * Icon Sizes:
 * - xs:  w-3 h-3  (12px) - Inline indicators, compact badges
 * - sm:  w-4 h-4  (16px) - List items, buttons, small features
 * - md:  w-5 h-5  (20px) - Secondary features, details
 * - lg:  w-6 h-6  (24px) - Primary features, default size
 * - xl:  w-7 h-7  (28px) - Emphasis icons, section headers
 * - 2xl: w-8 h-8  (32px) - Large display icons
 * - 3xl: w-10 h-10 (40px) - Navigation, footer links
 *
 * Icon Weights (Phosphor):
 * - thin:    Minimal, delicate appearance
 * - light:   Subtle, clean look
 * - regular: Default, balanced (recommended)
 * - bold:    Strong emphasis
 * - fill:    Solid, filled style
 * - duotone: Two-tone for depth
 *
 * Brand Colors:
 * - text-forma-bone       - Primary on dark backgrounds
 * - text-forma-steel-blue - Accent, interactive elements
 * - text-forma-sage       - Success, positive actions
 * - text-forma-warm-orange - Attention, highlights
 * - text-forma-muted-blue - Secondary accent
 * - text-forma-soft-green - Soft success variant
 */

// Icon size class mappings
export const iconSizes = {
  xs: "w-3 h-3",    // 12px - Compact indicators
  sm: "w-4 h-4",    // 16px - Buttons, list items
  md: "w-5 h-5",    // 20px - Secondary features
  lg: "w-6 h-6",    // 24px - Primary features (default)
  xl: "w-7 h-7",    // 28px - Emphasis
  "2xl": "w-8 h-8", // 32px - Large display
  "3xl": "w-10 h-10", // 40px - Navigation
} as const;

// Icon color class mappings using brand palette
export const iconColors = {
  // Primary colors
  bone: "text-forma-bone",
  "steel-blue": "text-forma-steel-blue",
  sage: "text-forma-sage",
  "warm-orange": "text-forma-warm-orange",
  "muted-blue": "text-forma-muted-blue",
  "soft-green": "text-forma-soft-green",

  // Muted variants (for subtle/secondary icons)
  "bone-50": "text-forma-bone/50",
  "bone-60": "text-forma-bone/60",
  "bone-70": "text-forma-bone/70",
  "bone-80": "text-forma-bone/80",
} as const;

// Common icon style combinations
export const iconStyles = {
  // Feature cards
  featureCard: "w-6 h-6",
  featureCardSecondary: "w-5 h-5",

  // Navigation & UI
  navIcon: "w-5 h-5",
  buttonIcon: "w-4 h-4",

  // Indicators
  indicator: "w-4 h-4",
  indicatorSmall: "w-3 h-3",

  // Content
  inlineIcon: "w-4 h-4",
  listIcon: "w-5 h-5",

  // Decorative (large background elements)
  decorative: "w-24 h-24",
} as const;

// Helper to combine size and color
export function getIconClasses(
  size: keyof typeof iconSizes = "lg",
  color?: keyof typeof iconColors
): string {
  const sizeClass = iconSizes[size];
  const colorClass = color ? iconColors[color] : "";
  return [sizeClass, colorClass].filter(Boolean).join(" ");
}

// Type exports for TypeScript users
export type IconSize = keyof typeof iconSizes;
export type IconColor = keyof typeof iconColors;
