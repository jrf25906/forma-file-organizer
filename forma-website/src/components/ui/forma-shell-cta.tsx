import { cva } from "class-variance-authority";

export const formaShellCtaVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-xl border text-sm font-semibold transition-[transform,box-shadow,background-color,border-color,color] duration-200 ease-out outline-none select-none disabled:pointer-events-none disabled:opacity-50 active:translate-y-px focus-visible:ring-2 focus-visible:ring-forma-steel-blue focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--canvas-paper)]",
  {
    variants: {
      variant: {
        primary:
          "border-transparent bg-[var(--shell-cta-bg)] text-[var(--shell-cta-text)] shadow-[var(--shell-shadow-soft)] hover:bg-[var(--shell-cta-bg-hover)] hover:shadow-[var(--shell-shadow-strong)]",
        secondary:
          "border-[var(--shell-cta-secondary-border)] bg-[var(--shell-cta-secondary-bg)] text-[var(--shell-cta-secondary-text)] hover:bg-[var(--shell-cta-secondary-bg-hover)]",
        ghost:
          "border-transparent bg-transparent text-[var(--ink-secondary)] hover:bg-[rgba(26,26,26,0.04)] hover:text-[var(--ink-primary)]",
      },
    },
    defaultVariants: { variant: "primary" },
  },
);
