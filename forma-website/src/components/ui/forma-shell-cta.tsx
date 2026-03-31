import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"

import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"

const formaShellCtaVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-xl border text-sm font-semibold transition-all duration-200 outline-none select-none disabled:pointer-events-none disabled:opacity-50 active:translate-y-px",
  {
    variants: {
      variant: {
        primary:
          "border-[var(--shell-cta-border)] bg-[var(--shell-cta-bg)] text-[var(--shell-cta-text)] shadow-[var(--shell-shadow-soft)] hover:bg-[var(--shell-cta-bg-hover)] hover:shadow-[var(--shell-shadow-strong)]",
        secondary:
          "border-[var(--shell-cta-secondary-border)] bg-[var(--shell-cta-secondary-bg)] text-[var(--shell-cta-secondary-text)] hover:bg-[var(--shell-cta-secondary-bg-hover)]",
        ghost:
          "border-transparent bg-transparent text-[var(--text-secondary)] hover:bg-[var(--shell-surface)] hover:text-[var(--text-primary)]",
      },
    },
    defaultVariants: {
      variant: "primary",
    },
  }
)

type FormaShellCtaProps = Omit<
  React.ComponentProps<typeof Button>,
  "variant" | "size"
> &
  VariantProps<typeof formaShellCtaVariants>

function FormaShellCta({
  className,
  variant,
  ...props
}: FormaShellCtaProps) {
  return (
    <Button
      variant="default"
      className={cn(
        "h-11 px-5",
        formaShellCtaVariants({ variant }),
        className
      )}
      {...props}
    />
  )
}

export { FormaShellCta, formaShellCtaVariants }
