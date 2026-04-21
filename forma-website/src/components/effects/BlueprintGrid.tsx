import { cn } from "@/lib/utils";

export interface BlueprintGridProps {
  opacity?: "faint" | "stronger";
  className?: string;
}

export function BlueprintGrid({ opacity = "faint", className }: BlueprintGridProps) {
  const stroke = opacity === "stronger" ? "var(--grid-stronger)" : "var(--grid-faint)";
  return (
    <div
      aria-hidden="true"
      className={cn("pointer-events-none absolute inset-0", className)}
      style={{
        backgroundImage: `
          linear-gradient(90deg, ${stroke} 1px, transparent 1px),
          linear-gradient(0deg, ${stroke} 1px, transparent 1px)
        `,
        backgroundSize: "24px 24px, 24px 24px",
      }}
    />
  );
}
