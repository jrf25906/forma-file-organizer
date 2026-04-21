import type { ReactNode } from "react";
import { cn } from "@/lib/utils";
import { MonoLabel } from "@/components/ui/MonoLabel";

export interface DraftedPlateProps {
  children: ReactNode;
  fig?: string;
  dimensionTop?: string;
  dimensionSide?: string;
  tone?: "paper" | "ink";
  className?: string;
  innerClassName?: string;
}

/**
 * Drafting plate — bordered container with four corner ticks and optional
 * FIG label / dimension marks. Paper tone is the default warm plate; ink
 * tone is used for dark-anchored sections (pricing, final CTA).
 */
export function DraftedPlate({
  children,
  fig,
  dimensionTop,
  dimensionSide,
  tone = "paper",
  className,
  innerClassName,
}: DraftedPlateProps) {
  const isInk = tone === "ink";
  const strokeColor = isInk ? "rgba(255,252,248,0.55)" : "var(--ink-draft)";
  const tickStyle = { background: strokeColor } as const;
  const labelChipBg = isInk ? "rgba(20,18,14,0.72)" : "var(--canvas-paper)";

  return (
    <div
      className={cn("relative", isInk ? "" : "bg-[rgba(255,253,248,0.72)]", className)}
      style={{ border: `1.5px solid ${strokeColor}`, borderRadius: "2px" }}
    >
      {/* corner ticks — 8 small bars forming an L at each corner */}
      <span aria-hidden="true" className="absolute -top-px -left-px h-[1.5px] w-4" style={tickStyle} />
      <span aria-hidden="true" className="absolute -top-px -left-px h-4 w-[1.5px]" style={tickStyle} />
      <span aria-hidden="true" className="absolute -top-px -right-px h-[1.5px] w-4" style={tickStyle} />
      <span aria-hidden="true" className="absolute -top-px -right-px h-4 w-[1.5px]" style={tickStyle} />
      <span aria-hidden="true" className="absolute -bottom-px -left-px h-[1.5px] w-4" style={tickStyle} />
      <span aria-hidden="true" className="absolute -bottom-px -left-px h-4 w-[1.5px]" style={tickStyle} />
      <span aria-hidden="true" className="absolute -bottom-px -right-px h-[1.5px] w-4" style={tickStyle} />
      <span aria-hidden="true" className="absolute -bottom-px -right-px h-4 w-[1.5px]" style={tickStyle} />

      {dimensionTop ? (
        <span
          aria-hidden="true"
          className="absolute -top-[10px] left-1/2 -translate-x-1/2 px-2"
          style={{ background: labelChipBg }}
        >
          <MonoLabel variant="dim">{dimensionTop}</MonoLabel>
        </span>
      ) : null}

      {dimensionSide ? (
        <span
          aria-hidden="true"
          className="absolute -right-[8px] top-1/2 origin-center -translate-y-1/2 rotate-90 px-2"
          style={{ background: labelChipBg }}
        >
          <MonoLabel variant="dim">{dimensionSide}</MonoLabel>
        </span>
      ) : null}

      <div className={cn("relative z-[1] p-5 md:p-6", innerClassName)}>
        {fig ? (
          <div className="mb-4">
            <MonoLabel variant="fig">{fig}</MonoLabel>
          </div>
        ) : null}
        {children}
      </div>
    </div>
  );
}
