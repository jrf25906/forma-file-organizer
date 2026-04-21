import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

type MonoLabelVariant = "fig" | "section" | "dim";

export interface MonoLabelProps {
  variant: MonoLabelVariant;
  children: ReactNode;
  className?: string;
  as?: "span" | "p";
}

const variantClasses: Record<MonoLabelVariant, string> = {
  fig: "text-[10px] tracking-[0.14em] uppercase font-bold text-[var(--ink-draft)]",
  section: "text-[11px] tracking-[0.1em] uppercase font-bold text-[var(--ink-draft)]",
  dim: "text-[9.5px] tracking-[0.14em] uppercase font-semibold text-[var(--ink-draft)]",
};

export function MonoLabel({ variant, children, className, as: As = "span" }: MonoLabelProps) {
  return (
    <As className={cn("font-mono inline-flex items-center", variantClasses[variant], className)}>
      {children}
    </As>
  );
}
