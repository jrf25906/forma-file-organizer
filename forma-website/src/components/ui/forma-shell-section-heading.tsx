import * as React from "react"

import { cn } from "@/lib/utils"

type FormaShellSectionHeadingProps = React.HTMLAttributes<HTMLDivElement> & {
  eyebrow?: React.ReactNode
  title: React.ReactNode
  description?: React.ReactNode
  align?: "left" | "center"
}

function FormaShellSectionHeading({
  eyebrow,
  title,
  description,
  align = "left",
  className,
  ...props
}: FormaShellSectionHeadingProps) {
  return (
    <div
      className={cn(
        "space-y-3",
        align === "center" && "mx-auto max-w-3xl text-center",
        className
      )}
      {...props}
    >
      {eyebrow ? (
        <p className="text-[11px] font-semibold tracking-[0.15em] uppercase text-forma-steel-blue">
          {eyebrow}
        </p>
      ) : null}
      <h2 className="font-display text-[1.875rem] leading-[1.1] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem]">
        {title}
      </h2>
      {description ? (
        <p className="max-w-2xl text-[15px] leading-relaxed text-[var(--text-secondary)]">
          {description}
        </p>
      ) : null}
    </div>
  )
}

export { FormaShellSectionHeading }
