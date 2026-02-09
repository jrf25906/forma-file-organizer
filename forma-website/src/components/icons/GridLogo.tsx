import { cn } from "@/lib/utils";

interface GridLogoProps {
  size?: number;
  gap?: number;
  className?: string;
}

const opacities = [1, 1, 1, 0.7, 0.7, 0.7, 0.4, 0.4, 0.4];

export function GridLogo({ size = 4.5, gap = 2.5, className }: GridLogoProps) {
  return (
    <div
      className={cn("grid grid-cols-3", className)}
      style={{ gap: `${gap}px` }}
      aria-hidden="true"
    >
      {opacities.map((opacity, i) => (
        <span
          key={i}
          className="forma-logo-dot rounded-full"
          style={{ width: `${size}px`, height: `${size}px`, opacity }}
        />
      ))}
    </div>
  );
}
