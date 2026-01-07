import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

/**
 * Combines class names using clsx and tailwind-merge.
 * This utility handles conditional classes and ensures
 * Tailwind CSS classes are properly merged without conflicts.
 *
 * @example
 * ```tsx
 * cn("px-4 py-2", "bg-blue-500", isActive && "bg-blue-700")
 * // => "px-4 py-2 bg-blue-700" (when isActive is true)
 *
 * cn("text-sm", className) // merge external className prop
 * ```
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
