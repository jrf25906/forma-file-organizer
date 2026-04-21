import { cn } from "@/lib/utils";

interface FigureProps {
  className?: string;
  title?: string;
}

const stroke = "var(--ink-draft)";
const accent = "var(--forma-warm-orange)";

/** Axonometric folder — used as the hero and story mascot moment. */
export function FolderFigure({ className, title = "Folder" }: FigureProps) {
  return (
    <svg
      role="img"
      aria-label={title}
      viewBox="0 0 120 96"
      fill="none"
      className={cn("block", className)}
    >
      <title>{title}</title>
      {/* top face */}
      <path d="M12 44 L60 30 L108 44 L60 58 Z" stroke={stroke} strokeWidth="1.3" fill="#FFFDF8" />
      {/* left face */}
      <path d="M12 44 L12 76 L60 92 L60 58 Z" stroke={stroke} strokeWidth="1.3" fill="rgba(45,63,82,0.05)" />
      {/* right face */}
      <path d="M60 58 L108 44 L108 76 L60 92 Z" stroke={stroke} strokeWidth="1.3" fill="rgba(45,63,82,0.10)" />
      {/* tab on lid */}
      <path d="M30 36 L48 32 L62 36 L44 40 Z" stroke={stroke} strokeWidth="1.1" fill="#FFFDF8" />
      {/* cross-hatch on front face */}
      <path
        d="M16 52 L60 88 M24 50 L60 82 M32 48 L60 74 M40 46 L60 66"
        stroke={stroke}
        strokeOpacity="0.35"
        strokeWidth="0.6"
      />
    </svg>
  );
}

/** Isometric Mac window outline — used in "how it works". */
export function MacWindowFigure({ className, title = "Window" }: FigureProps) {
  return (
    <svg
      role="img"
      aria-label={title}
      viewBox="0 0 120 90"
      fill="none"
      className={cn("block", className)}
    >
      <title>{title}</title>
      <path d="M10 22 L90 10 L110 22 L30 34 Z" stroke={stroke} strokeWidth="1.2" fill="rgba(45,63,82,0.04)" />
      <path d="M10 22 L10 70 L30 82 L30 34 Z" stroke={stroke} strokeWidth="1.2" fill="#FFFDF8" />
      <path d="M30 34 L110 22 L110 70 L30 82 Z" stroke={stroke} strokeWidth="1.2" fill="rgba(45,63,82,0.08)" />
      <circle cx="18" cy="28" r="1.6" fill={stroke} />
      <circle cx="22" cy="27" r="1.6" fill={stroke} />
      <circle cx="26" cy="26" r="1.6" fill={stroke} />
      <path
        d="M42 46 L96 40 M42 54 L96 48 M42 62 L96 56"
        stroke={stroke}
        strokeOpacity="0.4"
        strokeWidth="0.8"
      />
    </svg>
  );
}

/** Preview queue — a stack of rows being checked. */
export function PreviewQueueFigure({ className, title = "Preview queue" }: FigureProps) {
  return (
    <svg
      role="img"
      aria-label={title}
      viewBox="0 0 120 90"
      fill="none"
      className={cn("block", className)}
    >
      <title>{title}</title>
      {[0, 14, 28, 42].map((y, i) => (
        <g key={y}>
          <rect
            x="14"
            y={14 + y}
            width="92"
            height="10"
            stroke={stroke}
            strokeWidth="1"
            fill={i % 2 ? "rgba(45,63,82,0.04)" : "#FFFDF8"}
          />
          <rect
            x="18"
            y={17 + y}
            width="4"
            height="4"
            stroke={stroke}
            strokeWidth="0.9"
            fill={i < 3 ? accent : "transparent"}
          />
          <path d={`M28 ${19 + y} L72 ${19 + y}`} stroke={stroke} strokeOpacity="0.5" strokeWidth="0.8" />
          <path
            d={`M78 ${19 + y} L100 ${19 + y}`}
            stroke={stroke}
            strokeOpacity="0.3"
            strokeWidth="0.7"
            strokeDasharray="2 2"
          />
        </g>
      ))}
    </svg>
  );
}

/** Undo stack — a card being reversed out of a pile. */
export function UndoStackFigure({ className, title = "Undo" }: FigureProps) {
  return (
    <svg
      role="img"
      aria-label={title}
      viewBox="0 0 120 90"
      fill="none"
      className={cn("block", className)}
    >
      <title>{title}</title>
      <rect x="26" y="34" width="60" height="40" stroke={stroke} strokeWidth="1.1" fill="rgba(45,63,82,0.06)" />
      <rect x="22" y="30" width="60" height="40" stroke={stroke} strokeWidth="1.1" fill="rgba(45,63,82,0.04)" />
      <rect x="18" y="26" width="60" height="40" stroke={stroke} strokeWidth="1.2" fill="#FFFDF8" />
      <path d="M96 46 A 14 14 0 1 0 96 74 L90 74" stroke={accent} strokeWidth="1.4" />
      <path d="M90 74 L96 70 M90 74 L96 78" stroke={accent} strokeWidth="1.4" />
    </svg>
  );
}

/** Rule card — a tagged note representing a plain-language rule. */
export function RuleCardFigure({ className, title = "Rule" }: FigureProps) {
  return (
    <svg
      role="img"
      aria-label={title}
      viewBox="0 0 120 90"
      fill="none"
      className={cn("block", className)}
    >
      <title>{title}</title>
      <rect x="14" y="14" width="92" height="62" stroke={stroke} strokeWidth="1.2" fill="#FFFDF8" />
      <rect x="14" y="14" width="92" height="14" stroke={stroke} strokeWidth="1.2" fill="rgba(201,126,102,0.14)" />
      <path d="M22 22 L54 22" stroke={stroke} strokeOpacity="0.65" strokeWidth="1" />
      <path
        d="M22 40 L98 40 M22 48 L90 48 M22 56 L80 56 M22 64 L70 64"
        stroke={stroke}
        strokeOpacity="0.4"
        strokeWidth="0.8"
      />
    </svg>
  );
}
