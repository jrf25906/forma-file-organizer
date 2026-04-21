import { cn } from "@/lib/utils";
import type { HTMLAttributes, ReactNode } from "react";

interface FormaShellSectionHeadingProps extends Omit<HTMLAttributes<HTMLDivElement>, "title"> {
  title: ReactNode;
  eyebrow?: ReactNode;
  description?: ReactNode;
  align?: "left" | "center";
  size?: "md" | "lg" | "xl";
  /** When true, draws a hairline rule above the eyebrow for editorial section breaks */
  ruled?: boolean;
}

const SIZE_CLASS = {
  md: "display-md",
  lg: "display-lg",
  xl: "display-xl",
} as const;

export function FormaShellSectionHeading({
  title,
  eyebrow,
  description,
  align = "left",
  size = "lg",
  ruled = false,
  className,
  ...rest
}: FormaShellSectionHeadingProps) {
  return (
    <div
      className={cn(
        "space-y-4",
        align === "center" && "mx-auto max-w-3xl text-center",
        ruled && "border-t border-[var(--rule-faint)] pt-8",
        className,
      )}
      {...rest}
    >
      {eyebrow ? <p className="eyebrow">{eyebrow}</p> : null}
      <h2 className={cn(SIZE_CLASS[size], "text-[var(--ink-primary)]")}>{title}</h2>
      {description ? (
        <p className={cn("prose-editorial", align === "center" && "mx-auto")}>{description}</p>
      ) : null}
    </div>
  );
}
