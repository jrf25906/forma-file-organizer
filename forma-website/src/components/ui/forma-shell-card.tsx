import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import type { ComponentProps } from "react";

type FormaShellCardProps = ComponentProps<typeof Card> & {
  /**
   * "canvas"  — default; clean outlined card on warm canvas, minimal shadow
   * "anchor"  — dark scoped anchor (product shell, hero-adjacent)
   * "floating" — translucent header treatment (Header.tsx floating pill)
   */
  tone?: "canvas" | "anchor" | "floating";
};

const TONE_CLASS = {
  canvas:
    "rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-paper)] text-[var(--ink-primary)] shadow-[var(--shell-shadow-soft)] ring-0",
  anchor:
    "anchor-dark rounded-2xl border border-[var(--rule-faint)] bg-[var(--shell-surface)] text-[var(--ink-primary)] shadow-[var(--shell-shadow)] ring-0",
  floating:
    "rounded-2xl border border-[var(--header-shell-border)] bg-[var(--header-shell-surface)] text-[var(--ink-primary)] shadow-[var(--header-shell-shadow)] ring-0 backdrop-blur-xl backdrop-saturate-150",
} as const;

function FormaShellCard({ tone = "canvas", className, ...props }: FormaShellCardProps) {
  return <Card className={cn(TONE_CLASS[tone], className)} {...props} />;
}

export { FormaShellCard };
