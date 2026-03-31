import * as React from "react"

import { Card } from "@/components/ui/card"
import { cn } from "@/lib/utils"

function FormaShellCard({
  className,
  ...props
}: React.ComponentProps<typeof Card>) {
  return (
    <Card
      className={cn(
        "rounded-2xl border border-[var(--shell-border)] bg-[var(--shell-surface)] text-[var(--text-primary)] shadow-[var(--shell-shadow)] ring-0",
        className
      )}
      {...props}
    />
  )
}

export { FormaShellCard }
