// ---------------------------------------------------------------------------
// FormaFileCard — faithful HTML replica of the native FileRow.swift component
// Two scale modes: "compact" (hero, 48px) and "full" (before/after, 60px)
// ---------------------------------------------------------------------------

import type { FormaFile, FileCategory } from "@/lib/forma-design-tokens";
import { categoryColors, cardTokens } from "@/lib/forma-design-tokens";
import {
  DocumentIcon,
  ImageIcon,
  VideoIcon,
  AudioIcon,
  ArchiveIcon,
} from "@/components/icons/FileTypeIcons";

// ---------------------------------------------------------------------------
// Scale config
// ---------------------------------------------------------------------------

interface ScaleConfig {
  height: number;
  minWidth: number;
  maxWidth: number;
  radius: number;
  thumbSize: number;
  thumbIconSize: number;
  filenameFontSize: number;
  metaFontSize: number;
  dotSize: number;
  showDestination: boolean;
  gap: number;
  paddingX: number;
}

const scales: Record<"compact" | "full", ScaleConfig> = {
  compact: {
    height: 48,
    minWidth: 200,
    maxWidth: 210,
    radius: 6,
    thumbSize: 32,
    thumbIconSize: 14,
    filenameFontSize: 11,
    metaFontSize: 9,
    dotSize: 4,
    showDestination: false,
    gap: 8,
    paddingX: 8,
  },
  full: {
    height: 60,
    minWidth: 280,
    maxWidth: 290,
    radius: 8,
    thumbSize: 40,
    thumbIconSize: 17,
    filenameFontSize: 13,
    metaFontSize: 10,
    dotSize: 5,
    showDestination: true,
    gap: 10,
    paddingX: 10,
  },
};

// ---------------------------------------------------------------------------
// Icon map
// ---------------------------------------------------------------------------

const categoryIcon: Record<FileCategory, React.ComponentType<React.SVGProps<SVGSVGElement>>> = {
  documents: DocumentIcon,
  images: ImageIcon,
  videos: VideoIcon,
  audio: AudioIcon,
  archives: ArchiveIcon,
};

// ---------------------------------------------------------------------------
// Truncation helper
// ---------------------------------------------------------------------------

function truncateName(name: string, max: number): string {
  if (name.length <= max) return name;
  const ext = name.lastIndexOf(".");
  if (ext === -1) return name.slice(0, max - 1) + "\u2026";
  const base = name.slice(0, ext);
  const suffix = name.slice(ext); // e.g. ".png"
  const available = max - suffix.length - 1; // 1 for ellipsis
  if (available < 4) return name.slice(0, max - 1) + "\u2026";
  return base.slice(0, available) + "\u2026" + suffix;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

interface FormaFileCardProps {
  file: FormaFile;
  scale?: "compact" | "full";
  className?: string;
  style?: React.CSSProperties;
}

export function FormaFileCard({
  file,
  scale = "compact",
  className = "",
  style,
}: FormaFileCardProps) {
  const s = scales[scale];
  const color = categoryColors[file.category];
  const Icon = categoryIcon[file.category];
  const statusColor = file.status === "ready" ? cardTokens.statusReady : cardTokens.statusPending;
  const maxChars = scale === "compact" ? 22 : 30;

  return (
    <div
      className={`flex items-stretch select-none pointer-events-none ${className}`}
      style={{
        height: s.height,
        minWidth: s.minWidth,
        maxWidth: s.maxWidth,
        borderRadius: s.radius,
        background: cardTokens.bg,
        border: `0.5px solid ${cardTokens.border}`,
        overflow: "hidden",
        fontFamily: cardTokens.font,
        ...style,
      }}
    >
      {/* Category rail */}
      <div
        style={{
          width: cardTokens.railWidth,
          flexShrink: 0,
          background: color,
          opacity: 0.8,
          borderRadius: 1,
          margin: `${Math.round(s.height * 0.18)}px 0`,
          marginLeft: 4,
        }}
      />

      {/* Thumbnail */}
      <div
        style={{
          width: s.thumbSize,
          height: s.thumbSize,
          flexShrink: 0,
          borderRadius: s.radius - 2,
          background: `linear-gradient(135deg, ${color}1A, ${color}0D)`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          margin: "auto 0",
          marginLeft: s.gap,
        }}
      >
        <Icon
          width={s.thumbIconSize}
          height={s.thumbIconSize}
          style={{ color, opacity: 0.7 }}
        />
      </div>

      {/* Content area — two lines */}
      <div
        style={{
          flex: 1,
          minWidth: 0,
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          gap: scale === "compact" ? 2 : 3,
          paddingLeft: s.gap,
          paddingRight: s.paddingX,
        }}
      >
        {/* Line 1: filename + destination pill */}
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <span
            style={{
              fontSize: s.filenameFontSize,
              fontWeight: 600,
              color: cardTokens.labelPrimary,
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
              lineHeight: 1.3,
            }}
          >
            {truncateName(file.name, maxChars)}
          </span>

          {s.showDestination && file.destination && (
            <span
              style={{
                flexShrink: 0,
                fontSize: s.metaFontSize,
                fontWeight: 500,
                color: cardTokens.pillText,
                background: cardTokens.pillBg,
                border: `1px solid ${cardTokens.pillBorder}`,
                borderRadius: 999,
                padding: "1px 7px",
                whiteSpace: "nowrap",
                lineHeight: 1.5,
                marginLeft: "auto",
              }}
            >
              {file.destination}
            </span>
          )}
        </div>

        {/* Line 2: ext · age · status dot */}
        <div style={{ display: "flex", alignItems: "center", gap: 5 }}>
          <span
            style={{
              fontSize: s.metaFontSize,
              fontWeight: 400,
              color: cardTokens.labelTertiary,
              letterSpacing: "0.01em",
              lineHeight: 1,
            }}
          >
            {file.ext}
          </span>
          <span
            style={{
              fontSize: s.metaFontSize,
              color: cardTokens.labelTertiary,
              lineHeight: 1,
            }}
          >
            {file.age}
          </span>
          <span
            style={{
              width: s.dotSize,
              height: s.dotSize,
              borderRadius: "50%",
              background: statusColor,
              flexShrink: 0,
            }}
          />
        </div>
      </div>
    </div>
  );
}
