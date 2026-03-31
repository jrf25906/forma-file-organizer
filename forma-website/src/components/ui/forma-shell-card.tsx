import * as React from "react"

import { Card } from "@/components/ui/card"
import { cn } from "@/lib/utils"

const SHELL_CARD_VARIANTS = {
  default:
    "rounded-2xl border border-[var(--shell-border)] bg-[var(--shell-surface)] text-[var(--text-primary)] shadow-[var(--shell-shadow)] ring-0",
  floating:
    "rounded-2xl border border-[var(--header-shell-border)] bg-[var(--header-shell-surface)] text-[var(--text-primary)] shadow-[var(--header-shell-shadow)] ring-0 backdrop-blur-xl backdrop-saturate-150",
} as const

type FormaShellCardProps = React.ComponentProps<typeof Card> & {
  variant?: keyof typeof SHELL_CARD_VARIANTS
}

function FormaShellCard({
  className,
  variant = "default",
  ...props
}: FormaShellCardProps) {
  return (
    <Card
      data-shell-variant={variant}
      className={cn(
        SHELL_CARD_VARIANTS[variant],
        className
      )}
      {...props}
    />
  )
}

export { FormaShellCard }
