"use client";
// ---------------------------------------------------------------------------
// FormaHeroWindow — High-fidelity HTML replica of the Forma app main window
// Purely presentational. No interactivity, no animations.
// Uses hardcoded light-mode colors sampled from the native app.
// ---------------------------------------------------------------------------

import Image from "next/image";

/* ═══════════════════════════════════════════════════════════════════════════
   TOKENS — sampled from real Forma macOS app (light mode)
   ═══════════════════════════════════════════════════════════════════════════ */

const t = {
  font: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", system-ui, sans-serif',
  // Window chrome — the real app toolbar is a warm near-white
  windowBg: "#FAFAF7",
  titleBarBg: "#F6F5F2",
  toolbarBg: "#F6F5F2",
  toolbarBorder: "rgba(0,0,0,0.06)",
  // Sidebar — distinct warm gray panel
  sidebarBg: "#EEEDEA",
  sidebarBorder: "rgba(0,0,0,0.06)",
  sidebarHeaderColor: "#8E8E93",
  sidebarItemColor: "#3C3C43",
  sidebarSelectedBg: "rgba(74,107,136,0.14)",
  sidebarSelectedColor: "#4A6B88",
  // Inspector — slightly lighter than sidebar
  inspectorBg: "#F4F3F0",
  inspectorBorder: "rgba(0,0,0,0.05)",
  // Cards (inspector)
  cardBg: "#FFFFFF",
  cardBorder: "rgba(0,0,0,0.06)",
  cardShadow: "0 1px 3px rgba(0,0,0,0.06), 0 0 0 0.5px rgba(0,0,0,0.04)",
  // Text
  labelPrimary: "#1A1A1A",
  labelSecondary: "rgba(60,60,67,0.6)",
  labelTertiary: "rgba(60,60,67,0.36)",
  // Status
  statusReady: "#5AC466",
  statusPending: "#E8744F",
  // Accent — Forma uses a warm teal/steel-blue, not pure blue
  accent: "#4A6B88",
  // Pending pill — orange
  pendingPillBg: "#E8744F",
  pendingPillText: "#FFFFFF",
  // Organize CTA — warm orange
  organizeBg: "#E8744F",
  organizeText: "#FFFFFF",
  // Category colors
  catDocuments: "#6B8CA8",
  catImages: "#C97E66",
  catVideos: "#6B7FA8",
  catArchives: "#8BA688",
} as const;

// Main content gradient (subtle warm mesh, matches the real app)
const contentGradient =
  "linear-gradient(170deg, #FAFAF7 0%, #F7F5F1 30%, #F4F1EC 55%, #F2EFEA 80%, #EFECEA 100%)";

/* ═══════════════════════════════════════════════════════════════════════════
   FILE DATA
   ═══════════════════════════════════════════════════════════════════════════ */

interface HeroFile {
  name: string;
  ext: string;
  icon: string;
  status: "ready" | "pending";
  statusLabel: string;
  destination?: string;
  categoryColor: string;
  age: string;
}

const heroFiles: HeroFile[] = [
  {
    name: "Q3-Budget-Report.xlsx",
    ext: "XLSX",
    icon: "spreadsheet",
    status: "ready",
    statusLabel: "Ready",
    destination: "~/Finance",
    categoryColor: t.catDocuments,
    age: "today",
  },
  {
    name: "Screenshot 2026-03-12 at 10.41 AM.png",
    ext: "PNG",
    icon: "image",
    status: "ready",
    statusLabel: "Ready",
    destination: "~/Screenshots",
    categoryColor: t.catImages,
    age: "today",
  },
  {
    name: "project-proposal-v2.pdf",
    ext: "PDF",
    icon: "pdf",
    status: "ready",
    statusLabel: "Ready",
    destination: "~/Documents",
    categoryColor: t.catDocuments,
    age: "today",
  },
  {
    name: "vacation-photos.zip",
    ext: "ZIP",
    icon: "zip",
    status: "pending",
    statusLabel: "Needs destination",
    destination: undefined,
    categoryColor: t.catArchives,
    age: "today",
  },
  {
    name: "meeting-recording-mar14.mp4",
    ext: "MP4",
    icon: "video",
    status: "ready",
    statusLabel: "Ready",
    destination: "~/Media",
    categoryColor: t.catVideos,
    age: "today",
  },
];

/* ═══════════════════════════════════════════════════════════════════════════
   SVG ICONS
   ═══════════════════════════════════════════════════════════════════════════ */

function SearchIcon({ size = 10, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <circle cx="6.5" cy="6.5" r="5" stroke={color} strokeWidth="1.5" />
      <path d="M10.5 10.5L14.5 14.5" stroke={color} strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
}

function FolderIcon({ size = 11, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path
        d="M2 4.5C2 3.67 2.67 3 3.5 3H6.29a1 1 0 01.7.29L8 4.3h4.5c.83 0 1.5.67 1.5 1.5v6.2c0 .83-.67 1.5-1.5 1.5h-9A1.5 1.5 0 012 12V4.5z"
        stroke={color}
        strokeWidth="1.2"
        fill="none"
      />
    </svg>
  );
}

function ClockIcon({ size = 10, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <circle cx="8" cy="8" r="6.5" stroke={color} strokeWidth="1.2" />
      <path d="M8 4.5V8.5L10.5 10" stroke={color} strokeWidth="1.2" strokeLinecap="round" />
    </svg>
  );
}

function ChevronDownIcon({ size = 8, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M4 6L8 10L12 6" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function GridIcon({ size = 12, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="2" y="2" width="5" height="5" rx="1" stroke={color} strokeWidth="1.2" />
      <rect x="9" y="2" width="5" height="5" rx="1" stroke={color} strokeWidth="1.2" />
      <rect x="2" y="9" width="5" height="5" rx="1" stroke={color} strokeWidth="1.2" />
      <rect x="9" y="9" width="5" height="5" rx="1" stroke={color} strokeWidth="1.2" />
    </svg>
  );
}

function ListIcon({ size = 12, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M2 4h12M2 8h12M2 12h12" stroke={color} strokeWidth="1.3" strokeLinecap="round" />
    </svg>
  );
}

function DetailIcon({ size = 12, color = t.labelPrimary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="2" y="2" width="12" height="3" rx="1" fill={color} opacity="0.15" stroke={color} strokeWidth="0.8" />
      <rect x="2" y="7" width="12" height="3" rx="1" fill={color} opacity="0.15" stroke={color} strokeWidth="0.8" />
      <rect x="2" y="12" width="12" height="2" rx="1" fill={color} opacity="0.15" stroke={color} strokeWidth="0.8" />
    </svg>
  );
}

function SidebarToggleIcon({ size = 12, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="1.5" y="2" width="13" height="12" rx="2" stroke={color} strokeWidth="1.2" />
      <path d="M5.5 2V14" stroke={color} strokeWidth="1.2" />
    </svg>
  );
}

function ColumnViewIcon({ size = 12, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="1.5" y="2" width="13" height="12" rx="2" stroke={color} strokeWidth="1.2" />
      <path d="M5.5 2V14M10.5 2V14" stroke={color} strokeWidth="1.0" />
    </svg>
  );
}

function GearIcon({ size = 12, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <circle cx="8" cy="8" r="2" stroke={color} strokeWidth="1.2" />
      <path
        d="M8 1.5v1.3M8 13.2v1.3M1.5 8h1.3M13.2 8h1.3M3.4 3.4l.92.92M11.68 11.68l.92.92M3.4 12.6l.92-.92M11.68 4.32l.92-.92"
        stroke={color}
        strokeWidth="1.1"
        strokeLinecap="round"
      />
    </svg>
  );
}

function HelpIcon({ size = 12, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <circle cx="8" cy="8" r="6.5" stroke={color} strokeWidth="1.2" />
      <path d="M6 6.5a2 2 0 113.5 1.5c-.5.4-1 .7-1 1.3V10" stroke={color} strokeWidth="1.1" strokeLinecap="round" />
      <circle cx="8.25" cy="11.75" r="0.5" fill={color} />
    </svg>
  );
}

function SmartRulesIcon({ size = 12, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M3 3h10v2H3zM3 7h7v2H3zM3 11h5v2H3z" stroke={color} strokeWidth="1.1" strokeLinecap="round" />
      <path d="M12 9l1.5 1.5L12 12" stroke={color} strokeWidth="1.1" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function AnalyticsIcon({ size = 12, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="2" y="8" width="3" height="6" rx="0.5" stroke={color} strokeWidth="1.1" />
      <rect x="6.5" y="5" width="3" height="9" rx="0.5" stroke={color} strokeWidth="1.1" />
      <rect x="11" y="2" width="3" height="12" rx="0.5" stroke={color} strokeWidth="1.1" />
    </svg>
  );
}

function PlusIcon({ size = 10, color = t.accent }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M8 3v10M3 8h10" stroke={color} strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
}

function DesktopLocIcon({ size = 12 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="2" y="2" width="12" height="9" rx="1.5" stroke={t.labelTertiary} strokeWidth="1.1" />
      <path d="M5.5 14h5M8 11v3" stroke={t.labelTertiary} strokeWidth="1.1" strokeLinecap="round" />
    </svg>
  );
}

function DownloadLocIcon({ size = 12 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M8 2v8M5 7.5L8 10.5 11 7.5" stroke={t.sidebarSelectedColor} strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M3 12.5h10" stroke={t.sidebarSelectedColor} strokeWidth="1.2" strokeLinecap="round" />
    </svg>
  );
}

function DocLocIcon({ size = 12 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M4 2h5.5L13 5.5V13a1 1 0 01-1 1H4a1 1 0 01-1-1V3a1 1 0 011-1z" stroke={t.labelTertiary} strokeWidth="1.1" />
      <path d="M9 2v4h4" stroke={t.labelTertiary} strokeWidth="1.1" />
    </svg>
  );
}

function PicturesLocIcon({ size = 12 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="2" y="3" width="12" height="10" rx="1.5" stroke={t.labelTertiary} strokeWidth="1.1" />
      <circle cx="5.5" cy="6.5" r="1.5" stroke={t.labelTertiary} strokeWidth="1" />
      <path d="M2.5 11l3-3 2.5 2.5L10.5 8l3.5 4" stroke={t.labelTertiary} strokeWidth="1" strokeLinejoin="round" />
    </svg>
  );
}

function MusicLocIcon({ size = 12 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <circle cx="5" cy="12" r="2" stroke={t.labelTertiary} strokeWidth="1.1" />
      <path d="M7 12V3l6-1.5v9" stroke={t.labelTertiary} strokeWidth="1.1" />
      <circle cx="11" cy="10.5" r="2" stroke={t.labelTertiary} strokeWidth="1.1" />
    </svg>
  );
}

function PauseIcon({ size = 10, color = t.labelTertiary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="4" y="3" width="3" height="10" rx="0.5" fill={color} />
      <rect x="9" y="3" width="3" height="10" rx="0.5" fill={color} />
    </svg>
  );
}

function CheckboxIcon({ checked = false, size = 14 }: { checked?: boolean; size?: number }) {
  if (checked) {
    return (
      <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
        <rect x="1.5" y="1.5" width="13" height="13" rx="3" fill={t.accent} stroke={t.accent} strokeWidth="1" />
        <path d="M4.5 8L7 10.5L11.5 5.5" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="1.5" y="1.5" width="13" height="13" rx="3" stroke="rgba(0,0,0,0.15)" strokeWidth="1" fill="none" />
    </svg>
  );
}

function FolderMoveIcon({ size = 12, color = t.labelSecondary }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path
        d="M2 4.5C2 3.67 2.67 3 3.5 3H6l1.5 1.5H12.5c.83 0 1.5.67 1.5 1.5v6c0 .83-.67 1.5-1.5 1.5h-9A1.5 1.5 0 012 12V4.5z"
        stroke={color}
        strokeWidth="1.1"
        fill="none"
      />
      <path d="M7 9h4M9.5 7L11.5 9 9.5 11" stroke={color} strokeWidth="1" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   SUB-COMPONENTS
   ═══════════════════════════════════════════════════════════════════════════ */

function Toolbar() {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        height: 36,
        padding: "0 12px",
        background: t.toolbarBg,
        borderBottom: `1px solid ${t.toolbarBorder}`,
        fontFamily: t.font,
        fontSize: 11,
      }}
    >
      {/* Left: Tab pills */}
      <div style={{ display: "flex", alignItems: "center", gap: 2 }}>
        <div
          style={{
            padding: "3px 10px",
            borderRadius: 6,
            background: t.pendingPillBg,
            color: t.pendingPillText,
            fontWeight: 600,
            fontSize: 10,
          }}
        >
          Pending 5
        </div>
        <div
          style={{
            padding: "3px 10px",
            borderRadius: 6,
            color: t.labelSecondary,
            fontWeight: 500,
            fontSize: 10,
          }}
        >
          All Files
        </div>
      </div>

      {/* Center: File count pill */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 6,
          padding: "3px 12px",
          borderRadius: 99,
          background: "rgba(0,0,0,0.04)",
          border: "1px solid rgba(0,0,0,0.06)",
        }}
      >
        <svg width={10} height={10} viewBox="0 0 16 16" fill="none">
          <circle cx="8" cy="8" r="5.5" stroke={t.labelTertiary} strokeWidth="1.2" />
          <path d="M8 5v3l2 1.5" stroke={t.labelTertiary} strokeWidth="1" strokeLinecap="round" />
        </svg>
        <span style={{ color: t.labelSecondary, fontSize: 10, fontWeight: 500 }}>4 selected</span>
      </div>

      {/* Right: Sort + view toggles */}
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 3 }}>
          <ClockIcon size={10} color={t.labelTertiary} />
          <span style={{ color: t.labelSecondary, fontSize: 10 }}>Newest</span>
          <ChevronDownIcon size={7} color={t.labelTertiary} />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 1 }}>
          {/* View mode icons — detail view is selected (filled bg) */}
          <div style={{ padding: "2px 4px", borderRadius: 4 }}>
            <GridIcon size={12} color={t.labelTertiary} />
          </div>
          <div style={{ padding: "2px 4px", borderRadius: 4 }}>
            <ListIcon size={12} color={t.labelTertiary} />
          </div>
          <div
            style={{
              padding: "2px 4px",
              borderRadius: 4,
              background: "rgba(0,0,0,0.08)",
            }}
          >
            <DetailIcon size={12} color={t.labelPrimary} />
          </div>
          <div style={{ padding: "2px 4px", borderRadius: 4 }}>
            <ColumnViewIcon size={12} color={t.labelTertiary} />
          </div>
        </div>
      </div>
    </div>
  );
}

function SidebarSection({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div style={{ marginBottom: 10 }}>
      <div
        style={{
          fontSize: 9,
          fontWeight: 600,
          color: t.sidebarHeaderColor,
          textTransform: "uppercase",
          letterSpacing: 0.8,
          padding: "0 10px",
          marginBottom: 3,
        }}
      >
        {title}
      </div>
      {children}
    </div>
  );
}

function SidebarItem({
  icon,
  label,
  selected = false,
  badge,
  color,
}: {
  icon: React.ReactNode;
  label: string;
  selected?: boolean;
  badge?: string;
  color?: string;
}) {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 7,
        padding: "4px 10px",
        marginLeft: 4,
        marginRight: 4,
        borderRadius: 6,
        background: selected ? t.sidebarSelectedBg : "transparent",
        cursor: "default",
      }}
    >
      <span style={{ flexShrink: 0, display: "flex" }}>{icon}</span>
      <span
        style={{
          flex: 1,
          fontSize: 11.5,
          fontWeight: selected ? 600 : 400,
          color: color ?? (selected ? t.sidebarSelectedColor : t.sidebarItemColor),
          lineHeight: 1.4,
        }}
      >
        {label}
      </span>
      {badge && (
        <span
          style={{
            fontSize: 9,
            fontWeight: 500,
            color: selected ? t.sidebarSelectedColor : t.labelTertiary,
            background: selected ? "rgba(74,107,136,0.10)" : "rgba(0,0,0,0.05)",
            borderRadius: 99,
            padding: "1px 6px",
            lineHeight: 1.5,
          }}
        >
          {badge}
        </span>
      )}
    </div>
  );
}

function Sidebar() {
  return (
    <div
      style={{
        width: 170,
        flexShrink: 0,
        background: t.sidebarBg,
        borderRight: `1px solid ${t.sidebarBorder}`,
        display: "flex",
        flexDirection: "column",
        fontFamily: t.font,
        padding: "8px 0",
        overflow: "hidden",
      }}
    >
      {/* Search */}
      <div
        style={{
          margin: "0 8px 10px",
          padding: "5px 7px",
          borderRadius: 6,
          background: "rgba(0,0,0,0.04)",
          border: "1px solid rgba(0,0,0,0.05)",
          display: "flex",
          alignItems: "center",
          gap: 5,
        }}
      >
        <SearchIcon size={10} color={t.labelTertiary} />
        <span style={{ fontSize: 11, color: t.labelTertiary }}>Search files...</span>
      </div>

      {/* Locations */}
      <SidebarSection title="Locations">
        <SidebarItem icon={<DesktopLocIcon size={13} />} label="Desktop" />
        <SidebarItem
          icon={<DownloadLocIcon size={13} />}
          label="Downloads"
          selected
          badge="5"
        />
        <SidebarItem icon={<DocLocIcon size={13} />} label="Documents" badge="1" />
        <SidebarItem icon={<PicturesLocIcon size={13} />} label="Pictures" badge="1" />
        <SidebarItem icon={<MusicLocIcon size={13} />} label="Music" />
      </SidebarSection>

      {/* Tools */}
      <SidebarSection title="Tools">
        <SidebarItem icon={<SmartRulesIcon size={13} color={t.labelTertiary} />} label="Smart Rules" />
        <SidebarItem icon={<AnalyticsIcon size={13} color={t.labelTertiary} />} label="Analytics" />
      </SidebarSection>

      {/* Separator */}
      <div style={{ height: 1, background: "rgba(0,0,0,0.06)", margin: "2px 10px 6px" }} />

      {/* Actions */}
      <SidebarSection title="Actions">
        <SidebarItem icon={<PlusIcon size={11} color={t.accent} />} label="New Rule" color={t.accent} />
        <SidebarItem icon={<FolderIcon size={12} color={t.accent} />} label="Add Folder" color={t.accent} />
      </SidebarSection>

      {/* Spacer */}
      <div style={{ flex: 1 }} />

      {/* Footer — Settings + Help with labels, matching real app */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "5px 10px",
          borderTop: `1px solid rgba(0,0,0,0.06)`,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 5 }}>
          <GearIcon size={13} color={t.labelTertiary} />
          <span style={{ fontSize: 11, color: t.sidebarItemColor }}>Settings</span>
        </div>
        <HelpIcon size={14} color={t.labelTertiary} />
      </div>
    </div>
  );
}

function FileRow({ file, index }: { file: HeroFile; index: number }) {
  const isReady = file.status === "ready";
  const statusColor = isReady ? t.statusReady : t.statusPending;

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 8,
        padding: "7px 12px",
        borderBottom: index < heroFiles.length - 1 ? `1px solid rgba(0,0,0,0.04)` : undefined,
        fontFamily: t.font,
        background: index === 0 ? "rgba(0,0,0,0.02)" : "transparent",
      }}
    >
      {/* Checkbox */}
      <CheckboxIcon checked={isReady} size={14} />

      {/* File icon in a subtle container (matches real app) */}
      <div
        style={{
          width: 32,
          height: 32,
          flexShrink: 0,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          borderRadius: 6,
          background: "rgba(0,0,0,0.03)",
          border: "0.5px solid rgba(0,0,0,0.04)",
        }}
      >
        <Image
          src={`/file-icons/${file.icon}.png`}
          alt=""
          width={22}
          height={22}
          draggable={false}
          aria-hidden="true"
          style={{ objectFit: "contain" }}
        />
      </div>

      {/* Status dot + name + metadata */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 5 }}>
          <span
            style={{
              width: 6,
              height: 6,
              borderRadius: "50%",
              background: statusColor,
              flexShrink: 0,
            }}
          />
          <span
            style={{
              fontSize: 12,
              fontWeight: 500,
              color: t.labelPrimary,
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
            }}
          >
            {file.name}
          </span>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 5, marginTop: 2, paddingLeft: 11 }}>
          <FolderIcon size={9} color={t.labelTertiary} />
          <span style={{ fontSize: 10, color: t.labelTertiary, fontWeight: 400 }}>
            {file.ext}
          </span>
          <span style={{ fontSize: 10, color: t.labelTertiary }}>
            &middot;
          </span>
          <svg width={9} height={9} viewBox="0 0 16 16" fill="none">
            <circle cx="8" cy="8" r="6" stroke={t.labelTertiary} strokeWidth="1.1" />
            <path d="M8 4.5V8.5L10.5 10" stroke={t.labelTertiary} strokeWidth="1" strokeLinecap="round" />
          </svg>
          <span style={{ fontSize: 10, color: t.labelTertiary }}>
            {file.age}
          </span>
          <span style={{ fontSize: 10, color: statusColor, fontWeight: 500, marginLeft: 4 }}>
            {file.statusLabel}
          </span>
        </div>
      </div>

      {/* Right side: destination or Set Destination button */}
      {file.destination ? (
        <span
          style={{
            fontSize: 10,
            color: t.labelTertiary,
            flexShrink: 0,
            whiteSpace: "nowrap",
          }}
        >
          {file.destination}
        </span>
      ) : (
        <div
          style={{
            fontSize: 10,
            fontWeight: 500,
            color: t.statusPending,
            padding: "3px 10px",
            borderRadius: 6,
            border: `1px solid rgba(232,116,79,0.25)`,
            background: "rgba(232,116,79,0.06)",
            flexShrink: 0,
            whiteSpace: "nowrap",
          }}
        >
          Set Destination
        </div>
      )}
    </div>
  );
}

function FileList() {
  return (
    <div
      style={{
        flex: 1,
        display: "flex",
        flexDirection: "column",
        background: contentGradient,
        minWidth: 0,
        position: "relative",
      }}
    >
      {/* File rows */}
      <div style={{ flex: 1 }}>
        {heroFiles.map((file, i) => (
          <FileRow key={file.name} file={file} index={i} />
        ))}
      </div>

      {/* Floating Action Bar — frosted glass pill (matching real app) */}
      <div
        style={{
          margin: "0 12px 12px",
          padding: "7px 8px 7px 12px",
          borderRadius: 20,
          background: "rgba(240,238,234,0.82)",
          backdropFilter: "blur(20px)",
          WebkitBackdropFilter: "blur(20px)",
          border: "1px solid rgba(0,0,0,0.06)",
          boxShadow: "0 2px 8px rgba(0,0,0,0.06), 0 0 0 0.5px rgba(0,0,0,0.03)",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          fontFamily: t.font,
        }}
      >
        {/* Left: checkmark + status */}
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <svg width={14} height={14} viewBox="0 0 16 16" fill="none">
            <circle cx="8" cy="8" r="7" fill={t.statusReady} />
            <path d="M5 8L7 10L11 6" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          <span style={{ fontSize: 11, color: t.labelSecondary, fontWeight: 400 }}>4 files ready</span>
        </div>

        {/* Right: action buttons */}
        <div style={{ display: "flex", alignItems: "center", gap: 5 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 4, height: 22, padding: "0 10px", borderRadius: 8, background: "rgba(0,0,0,0.05)" }}>
            <FolderMoveIcon size={11} color={t.labelSecondary} />
            <span style={{ fontSize: 10.5, fontWeight: 500, color: t.labelSecondary }}>Move</span>
          </div>
          <div style={{ display: "flex", alignItems: "center", height: 22, padding: "0 10px", borderRadius: 8, background: "rgba(0,0,0,0.05)" }}>
            <span style={{ fontSize: 10.5, fontWeight: 500, color: t.labelSecondary }}>Skip</span>
          </div>
          <button
            onClick={() => window.dispatchEvent(new CustomEvent('forma-organize-click'))}
            className="transition-transform active:scale-95 hover:brightness-110 cursor-pointer pointer-events-auto"
            style={{
              display: "flex",
              alignItems: "center",
              gap: 4,
              height: 22,
              padding: "0 14px",
              borderRadius: 8,
              background: t.organizeBg,
              color: t.organizeText,
              border: "none",
            }}
          >
            <FolderMoveIcon size={11} color="#FFFFFF" />
            <span style={{ fontSize: 10.5, fontWeight: 600 }}>Organize 4</span>
          </button>
          {/* Close X */}
          <svg width={14} height={14} viewBox="0 0 16 16" fill="none" style={{ marginLeft: 8, opacity: 0.4 }}>
            <path d="M4 4L12 12M12 4L4 12" stroke={t.labelPrimary} strokeWidth="1.5" strokeLinecap="round" />
          </svg>
        </div>
      </div>
    </div>
  );
}

function Inspector() {
  return (
    <div
      style={{
        width: 180,
        flexShrink: 0,
        background: t.inspectorBg,
        borderLeft: `1px solid ${t.inspectorBorder}`,
        fontFamily: t.font,
        padding: "6px 7px",
        display: "flex",
        flexDirection: "column",
        gap: 5,
        overflow: "hidden",
      }}
    >
      {/* Dashboard / File Details tabs */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "0 2px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 2, fontSize: 9, color: t.accent, fontWeight: 500 }}>
          <span style={{ fontSize: 10 }}>&lsaquo;</span>
          Dashboard
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 2, fontSize: 9, color: t.labelTertiary }}>
          <svg width={9} height={9} viewBox="0 0 16 16" fill="none">
            <path d="M4 2h5.5L13 5.5V13a1 1 0 01-1 1H4a1 1 0 01-1-1V3a1 1 0 011-1z" stroke={t.labelTertiary} strokeWidth="1.1" />
          </svg>
          File Details
        </div>
      </div>

      {/* Current Task card */}
      <div
        style={{
          background: t.cardBg,
          borderRadius: 8,
          padding: "9px 10px",
          boxShadow: t.cardShadow,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 5, marginBottom: 5 }}>
          <svg width={13} height={13} viewBox="0 0 16 16" fill="none">
            <circle cx="8" cy="8" r="7" fill="none" stroke={t.statusPending} strokeWidth="1.5" />
            <path d="M8 5v3.5M8 10.5v.5" stroke={t.statusPending} strokeWidth="1.5" strokeLinecap="round" />
          </svg>
          <span style={{ fontSize: 11.5, fontWeight: 600, color: t.labelPrimary }}>5 Files</span>
        </div>
        <div style={{ fontSize: 9.5, color: t.labelSecondary, marginBottom: 7 }}>
          4 ready, 1 needs destination.
        </div>

        {/* Action buttons row */}
        <div style={{ display: "flex", gap: 4, marginBottom: 7 }}>
          <div style={{
            flex: 1,
            padding: "4px 0",
            borderRadius: 5,
            border: `1px solid ${t.accent}`,
            textAlign: "center",
            fontSize: 8.5,
            fontWeight: 500,
            color: t.accent,
          }}>
            View Activity
          </div>
          <div style={{
            flex: 1,
            padding: "4px 0",
            borderRadius: 5,
            border: "1px solid rgba(0,0,0,0.10)",
            textAlign: "center",
            fontSize: 8.5,
            fontWeight: 500,
            color: t.labelSecondary,
          }}>
            Manage Rules
          </div>
        </div>

        {/* Progress bar */}
        <div>
          <div
            style={{
              height: 3,
              borderRadius: 2,
              background: "rgba(0,0,0,0.06)",
              overflow: "hidden",
            }}
          >
            <div
              style={{
                width: "0%",
                height: "100%",
                borderRadius: 2,
                background: t.accent,
              }}
            />
          </div>
          <div style={{ display: "flex", justifyContent: "space-between", marginTop: 4 }}>
            <span style={{ fontSize: 7.5, fontWeight: 600, color: t.labelTertiary, textTransform: "uppercase", letterSpacing: 0.4 }}>0% organized</span>
            <span style={{ fontSize: 7.5, color: t.labelTertiary }}>0/5 Files</span>
          </div>
        </div>

        {/* Category breakdown */}
        <div style={{ display: "flex", gap: 5, marginTop: 5 }}>
          {[
            { color: t.catDocuments, count: 2 },
            { color: t.catImages, count: 1 },
            { color: t.catVideos, count: 1 },
            { color: t.catArchives, count: 1 },
          ].map((cat, i) => (
            <div key={i} style={{ display: "flex", alignItems: "center", gap: 2 }}>
              <div
                style={{
                  width: 7,
                  height: 7,
                  borderRadius: 2,
                  background: cat.color,
                  opacity: 0.7,
                }}
              />
              <span style={{ fontSize: 7.5, color: t.labelTertiary, fontWeight: 500 }}>
                {cat.count}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Automation card */}
      <div
        style={{
          background: t.cardBg,
          borderRadius: 8,
          padding: "7px 8px",
          boxShadow: t.cardShadow,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 5 }}>
          <div style={{ fontSize: 8, fontWeight: 600, color: t.sidebarHeaderColor, textTransform: "uppercase", letterSpacing: 0.5 }}>
            Automation
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 3 }}>
            <div
              style={{
                width: 4,
                height: 4,
                borderRadius: "50%",
                background: t.statusReady,
              }}
            />
            <span style={{ fontSize: 8.5, color: t.statusReady, fontWeight: 500 }}>Active</span>
          </div>
        </div>

        {/* Timer + scan info — horizontal layout like real app */}
        <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 4 }}>
          {/* Timer ring */}
          <div style={{ position: "relative", width: 30, height: 30, flexShrink: 0 }}>
            <svg width={30} height={30} viewBox="0 0 30 30">
              <circle cx="15" cy="15" r="12.5" fill="none" stroke="rgba(0,0,0,0.06)" strokeWidth="2" />
              <circle
                cx="15"
                cy="15"
                r="12.5"
                fill="none"
                stroke={t.accent}
                strokeWidth="2"
                strokeLinecap="round"
                strokeDasharray={`${2 * Math.PI * 12.5}`}
                strokeDashoffset={`${2 * Math.PI * 12.5 * 0.8}`}
                transform="rotate(-90 15 15)"
                opacity={0.6}
              />
            </svg>
            <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <span style={{ fontSize: 8.5, fontWeight: 700, color: t.labelPrimary }}>52s</span>
            </div>
          </div>

          {/* Scan info + buttons */}
          <div style={{ flex: 1 }}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 3 }}>
              <span style={{ fontSize: 8.5, fontWeight: 500, color: t.labelPrimary }}>Next scan</span>
              <span style={{ fontSize: 8.5, color: t.labelTertiary }}>1m ago</span>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 2 }}>
              <div
                style={{
                  flex: 1,
                  padding: "2px 0",
                  borderRadius: 4,
                  background: "rgba(0,0,0,0.05)",
                  textAlign: "center",
                  fontSize: 8.5,
                  fontWeight: 500,
                  color: t.labelSecondary,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  gap: 2,
                }}
              >
                <svg width={7} height={7} viewBox="0 0 16 16" fill="none">
                  <path d="M3 8h10M8 3v10" stroke={t.labelSecondary} strokeWidth="1.5" strokeLinecap="round" />
                </svg>
                Scan
              </div>
              <div
                style={{
                  width: 18,
                  height: 16,
                  borderRadius: 4,
                  background: "rgba(0,0,0,0.05)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <PauseIcon size={7} color={t.labelTertiary} />
              </div>
            </div>
          </div>
        </div>

        <div style={{ fontSize: 8.5, color: t.statusPending, fontWeight: 400 }}>
          5 pending for review
        </div>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   MAIN COMPONENT
   ═══════════════════════════════════════════════════════════════════════════ */

export default function FormaHeroWindow() {
  return (
    <div
      className="relative overflow-hidden rounded-[10px]"
      style={{
        fontFamily: t.font,
        background: t.windowBg,
        minWidth: 540,
        boxShadow: `
          0 0 0 0.5px rgba(0,0,0,0.10),
          0 1px 3px rgba(0,0,0,0.08),
          0 8px 20px rgba(0,0,0,0.10),
          0 24px 48px -8px rgba(0,0,0,0.15)
        `,
      }}
      role="img"
      aria-label="Forma app main window showing file organization queue with sidebar, file list, and inspector panel"
    >
      {/* macOS Title Bar */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          height: 40,
          padding: "0 14px",
          background: t.titleBarBg,
          borderBottom: `1px solid ${t.toolbarBorder}`,
        }}
      >
        {/* Traffic lights */}
        <div style={{ display: "flex", gap: 7, marginRight: 10 }}>
          <div style={{ width: 11, height: 11, borderRadius: "50%", background: "#FF5F57", border: "0.5px solid #e1483f" }} />
          <div style={{ width: 11, height: 11, borderRadius: "50%", background: "#FEBC2E", border: "0.5px solid #d89e24" }} />
          <div style={{ width: 11, height: 11, borderRadius: "50%", background: "#28C840", border: "0.5px solid #20a032" }} />
        </div>

        {/* Sidebar toggle */}
        <SidebarToggleIcon size={14} color={t.labelTertiary} />

        {/* Title */}
        <div style={{ flex: 1, textAlign: "center" }}>
          <span style={{ fontSize: 12, fontWeight: 500, color: t.labelPrimary, letterSpacing: 0.1 }}>
            Forma: File Management
          </span>
        </div>

        {/* Spacer for symmetry */}
        <div style={{ width: 76 }} />
      </div>

      {/* Toolbar */}
      <Toolbar />

      {/* Body: 3-column layout */}
      <div
        style={{
          display: "flex",
          minHeight: 380,
        }}
      >
        <Sidebar />
        <FileList />
        <Inspector />
      </div>
    </div>
  );
}
