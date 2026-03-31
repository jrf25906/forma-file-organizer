"use client";

import { useState, useRef, useCallback, useEffect } from "react";
import Image from "next/image";

// ─── macOS Dock Apps ─────────────────────────────────────────────────────────
const DOCK_ICON_PATH = "/dock-icons";
const baseDockApps = [
  "Finder",
  "Safari",
  "Messages",
  "Mail",
  // The center split perfectly intersects here (4 apps left, 4 apps right)
  "Photos",
  "Music",
  "Notes",
  "Calendar",
];

// ─── Cluttered Desktop Files (Before) ────────────────────────────────────────
const desktopFiles = [
  { name: "Screenshot 2026-01-15 at 9.42.17 AM.png", type: "image", x: 3, y: 3 },
  { name: "IMG_4392.HEIC", type: "image", x: 16, y: 1 },
  { name: "Invoice_Feb2026.pdf", type: "pdf", x: 30, y: 5 },
  { name: "budget-v3-FINAL.xlsx", type: "spreadsheet", x: 39, y: 2 },
  { name: "notes.txt", type: "text", x: 70, y: 4 },
  { name: "Untitled.sketch", type: "design", x: 85, y: 1 },
  { name: "meeting-recording.mp4", type: "video", x: 6, y: 18 },
  { name: "app-mockup-v3.png", type: "image", x: 22, y: 16 },
  { name: "contract-draft.docx", type: "doc", x: 38, y: 20 },
  { name: "README.md", type: "text", x: 55, y: 17 },
  { name: "DSC_0847.JPG", type: "image", x: 72, y: 19 },
  { name: "tax-return-2025.pdf", type: "pdf", x: 86, y: 16 },
  { name: "presentation-deck.pptx", type: "slides", x: 2, y: 33 },
  { name: "holiday-photo.jpg", type: "image", x: 15, y: 35 },
  { name: "banner-draft.png", type: "image", x: 32, y: 32 },
  { name: "project-plan.pdf", type: "pdf", x: 37, y: 36 },
  { name: "Screen Recording...03.mov", type: "video", x: 64, y: 33 },
  { name: "old-resume.docx", type: "doc", x: 80, y: 34 },
  { name: "logo-final-FINAL2.ai", type: "design", x: 5, y: 49 },
  { name: "receipts-jan.pdf", type: "pdf", x: 20, y: 50 },
  { name: "backup.zip", type: "archive", x: 36, y: 48 },
  { name: "wireframes.fig", type: "design", x: 52, y: 51 },
  { name: "song-idea.mp3", type: "audio", x: 68, y: 49 },
  { name: "Untitled 2.sketch", type: "design", x: 84, y: 50 },
  { name: "client-feedback.pdf", type: "pdf", x: 4, y: 64 },
  { name: "photo-album.zip", type: "archive", x: 18, y: 66 },
  { name: "icon-set.svg", type: "design", x: 34, y: 63 },
  { name: "quarterly-report.xlsx", type: "spreadsheet", x: 52, y: 65 },
  { name: "demo-video.mp4", type: "video", x: 70, y: 64 },
] as const;

type FileType = (typeof desktopFiles)[number]["type"];

// Maps file types to real macOS system icon PNGs (extracted via NSWorkspace)
const FILE_ICON_PATH = "/file-icons";
const fileIconMap: Record<FileType, string> = {
  image: "image",
  pdf: "pdf",
  doc: "doc",
  text: "txt",
  spreadsheet: "spreadsheet",
  video: "video",
  audio: "audio",
  design: "design",
  slides: "slides",
  archive: "zip",
};

// ─── Positioned Desktop File ─────────────────────────────────────────────────
function DesktopFile({ file }: { file: (typeof desktopFiles)[number] }) {
  return (
    <div
      className="absolute flex w-[76px] cursor-default select-none flex-col items-center gap-0.5"
      style={{ left: `${file.x}%`, top: `${file.y}%` }}
    >
      <Image
        src={`${FILE_ICON_PATH}/${fileIconMap[file.type]}.png`}
        alt=""
        width={40}
        height={40}
        draggable={false}
        aria-hidden="true"
        style={{ filter: "drop-shadow(0 1px 2px rgba(0,0,0,0.15))" }}
      />
      <span
        className="max-w-[74px] truncate text-center text-white"
        style={{
          fontSize: 9,
          lineHeight: 1.25,
          textShadow: "0 1px 4px rgba(0,0,0,0.6), 0 0px 1px rgba(0,0,0,0.4)",
          fontFamily:
            '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
          fontWeight: 400,
        }}
      >
        {file.name}
      </span>
    </div>
  );
}

// ─── Organized Folder Data ───────────────────────────────────────────────────
const desktopFolders = [
  { name: "Documents" },
  { name: "Finance" },
  { name: "Images" },
  { name: "Design" },
  { name: "Media" },
  { name: "Projects" },
];

function DesktopFolder({ folder, x, y }: { folder: (typeof desktopFolders)[number]; x: number; y: number }) {
  return (
    <div
      className="absolute flex w-[76px] cursor-default select-none flex-col items-center gap-[3px]"
      style={{ left: `${x}%`, top: `${y}%` }}
    >
      <div className="relative flex h-[48px] w-[56px] items-end justify-center">
        <Image
          src={`${FILE_ICON_PATH}/folder-open.png`}
          alt=""
          width={48}
          height={48}
          draggable={false}
          aria-hidden="true"
          className="relative z-10"
          style={{ filter: "drop-shadow(0 1px 3px rgba(0,0,0,0.2))" }}
        />
      </div>
      <span
        className="max-w-[74px] text-center text-white"
        style={{
          fontSize: 9.5,
          lineHeight: 1.25,
          textShadow: "0 1px 4px rgba(0,0,0,0.6), 0 0px 1px rgba(0,0,0,0.4)",
          fontFamily:
            '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
          fontWeight: 500,
        }}
      >
        {folder.name}
      </span>
    </div>
  );
}

// ─── macOS Menu Bar ─────────────────────────────────────────────────────────
function MenuBar({ activeApp = "Finder" }: { activeApp?: string }) {
  return (
    <div
      className="flex h-6 items-center justify-between px-3.5"
      style={{ background: "rgba(0,0,0,0.35)", backdropFilter: "blur(20px)" }}
    >
      <div className="flex items-center gap-3.5">
        {/* Apple logo */}
        <svg width="12" height="14" viewBox="0 0 24 24" fill="white" style={{ opacity: 0.9 }}>
          <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701" />
        </svg>
        {activeApp === "Forma" && (
          <Image
            src="/app-icon-1024.png"
            alt=""
            width={14}
            height={14}
            draggable={false}
            aria-hidden="true"
            style={{ borderRadius: 3, marginRight: -6, transform: "scale(1.15)" }}
          />
        )}
        <span style={{ fontSize: 11, fontWeight: 600, color: "rgba(255,255,255,0.95)", textShadow: "0 1px 2px rgba(0,0,0,0.25)" }}>
          {activeApp}
        </span>
        {(activeApp === "Forma"
          ? ["File", "Edit", "View", "Organize"]
          : ["File", "Edit", "View", "Go"]
        ).map((m) => (
          <span key={m} style={{ fontSize: 11, color: "rgba(255,255,255,0.85)", textShadow: "0 1px 2px rgba(0,0,0,0.25)" }}>
            {m}
          </span>
        ))}
      </div>
      <div className="flex items-center gap-3">
        {/* Wi-Fi */}
        <svg width="12" height="10" viewBox="0 0 16 12" fill="none">
          <path
            d="M8 11.5L5.5 8.5C6.4 7.7 7.2 7.3 8 7.3s1.6.4 2.5 1.2L8 11.5z"
            fill="rgba(255,255,255,0.75)"
          />
          <path
            d="M8 7.3C6 7.3 4.3 8 3 9.3"
            stroke="rgba(255,255,255,0.5)"
            strokeWidth="1.2"
            strokeLinecap="round"
            fill="none"
          />
          <path
            d="M8 7.3C10 7.3 11.7 8 13 9.3"
            stroke="rgba(255,255,255,0.5)"
            strokeWidth="1.2"
            strokeLinecap="round"
            fill="none"
          />
          <path
            d="M1 6.5C3.5 4.2 5.7 3 8 3s4.5 1.2 7 3.5"
            stroke="rgba(255,255,255,0.4)"
            strokeWidth="1.2"
            strokeLinecap="round"
            fill="none"
          />
        </svg>
        {/* Battery */}
        <svg width="18" height="9" viewBox="0 0 22 11" fill="none">
          <rect x="0.5" y="0.5" width="18" height="10" rx="2" stroke="rgba(255,255,255,0.6)" strokeWidth="1" />
          <rect x="2" y="2" width="12" height="7" rx="1" fill="rgba(255,255,255,0.7)" />
          <rect x="19" y="3" width="2.5" height="5" rx="1" fill="rgba(255,255,255,0.4)" />
        </svg>
        <span style={{ fontSize: 10.5, color: "rgba(255,255,255,0.9)", fontWeight: 500, textShadow: "0 1px 2px rgba(0,0,0,0.25)" }}>
          Wed 9:42 AM
        </span>
      </div>
    </div>
  );
}

// ─── macOS Dock ──────────────────────────────────────────────────────────────
function Dock({ showForma = false }: { showForma?: boolean }) {
  return (
    <div
      className="absolute bottom-1 left-1/2 flex -translate-x-1/2 items-end gap-[3px] rounded-2xl px-2 py-1"
      style={{
        background: "rgba(255,255,255,0.15)",
        backdropFilter: "blur(30px)",
        border: "1px solid rgba(255,255,255,0.2)",
      }}
    >
      {baseDockApps.map((name, i) => {
        // Drop Forma into the 5th slot precisely on the "After" side
        const isFormaSlot = i === 4;
        const iconName = (showForma && isFormaSlot) ? "Forma" : name;
        const src = iconName === "Forma" ? "/app-icon-1024.png" : `${DOCK_ICON_PATH}/${name}.png`;
        const scale = iconName === "Forma" ? "scale(0.82)" : "none";

        return (
          <Image
            key={name}
            src={src}
            alt={iconName}
            width={34}
            height={34}
            draggable={false}
            style={{
              borderRadius: 34 * 0.22,
              boxShadow: "0 1px 4px rgba(0,0,0,0.2)",
              transform: scale,
            }}
          />
        );
      })}
    </div>
  );
}

// ─── Desktop Backgrounds ──────────────────────────────────────────────────────
const DESKTOP_BG = "linear-gradient(170deg, #3B4B6B 0%, #2A3550 40%, #1E2740 100%)";

// macOS-style colorful wavy wallpaper (layered radial gradients)
const AFTER_WALLPAPER = [
  "radial-gradient(ellipse 120% 80% at 10% 90%, #4158D0 0%, transparent 50%)",
  "radial-gradient(ellipse 100% 70% at 80% 20%, #C850C0 0%, transparent 45%)",
  "radial-gradient(ellipse 90% 100% at 60% 80%, #FFCC70 0%, transparent 40%)",
  "radial-gradient(ellipse 110% 60% at 30% 10%, #0093E9 0%, transparent 50%)",
  "radial-gradient(ellipse 80% 90% at 90% 70%, #F77062 0%, transparent 45%)",
  "radial-gradient(ellipse 100% 80% at 50% 50%, #6C63FF 0%, transparent 55%)",
  "linear-gradient(135deg, #1a1040 0%, #0f1a3a 40%, #1a0a2e 100%)",
].join(", ");

// ═════════════════════════════════════════════════════════════════════════════
// MAIN COMPONENT
// ═════════════════════════════════════════════════════════════════════════════

export default function FormaBeforeAfter() {
  const containerRef = useRef<HTMLDivElement>(null);
  const [sliderPos, setSliderPos] = useState(50);
  const [isDragging, setIsDragging] = useState(false);

  const handleMove = useCallback((clientX: number) => {
    if (!containerRef.current) return;
    const rect = containerRef.current.getBoundingClientRect();
    const x = clientX - rect.left;
    const pct = Math.max(5, Math.min(95, (x / rect.width) * 100));
    setSliderPos(pct);
  }, []);

  useEffect(() => {
    if (!isDragging) return;
    const onMove = (e: MouseEvent | TouchEvent) => {
      e.preventDefault();
      const clientX = "touches" in e ? e.touches[0].clientX : e.clientX;
      handleMove(clientX);
    };
    const onUp = () => setIsDragging(false);
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    window.addEventListener("touchmove", onMove, { passive: false });
    window.addEventListener("touchend", onUp);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
      window.removeEventListener("touchmove", onMove);
      window.removeEventListener("touchend", onUp);
    };
  }, [isDragging, handleMove]);

  return (
    <div className="mx-auto w-full max-w-[960px]">
      {/* Before / After labels */}
      <div className="mb-3 flex justify-between px-1">
        <span className="text-xs font-semibold uppercase tracking-[0.12em] text-[var(--text-muted)]">
          Before
        </span>
        <span className="text-xs font-semibold uppercase tracking-[0.12em] text-[var(--text-muted)]">
          After
        </span>
      </div>

      {/* Slider container */}
      <div
        ref={containerRef}
        className="relative w-full select-none overflow-hidden rounded-2xl border border-[var(--border-subtle)]"
        style={{
          aspectRatio: "16 / 10",
          cursor: isDragging ? "grabbing" : "default",
          boxShadow: "0 4px 24px rgba(0,0,0,0.08), 0 1px 4px rgba(0,0,0,0.04)",
        }}
        role="img"
        aria-label="Interactive before and after comparison showing a cluttered desktop transformed into organized folders by Forma"
      >
        {/* ── BEFORE (Cluttered Desktop) ── */}
        <div className="absolute inset-0 overflow-hidden" style={{ background: DESKTOP_BG }}>
          <MenuBar />
          <Dock />
          <div className="absolute" style={{ inset: "28px 8px 56px 8px" }}>
            {desktopFiles.map((file, i) => (
              <DesktopFile key={i} file={file} />
            ))}
          </div>
        </div>

        {/* ── AFTER (Clean Desktop with Organized Folders) ── */}
        <div
          className="absolute inset-0 overflow-hidden"
          style={{
            clipPath: `inset(0 0 0 ${sliderPos}%)`,
            background: AFTER_WALLPAPER,
          }}
        >
          <MenuBar activeApp="Forma" />
          <Dock showForma />
          <div className="absolute" style={{ inset: "28px 8px 56px 8px" }}>
            {desktopFolders.map((folder, i) => (
              <DesktopFolder key={i} folder={folder} x={82} y={2 + i * 16} />
            ))}
          </div>
        </div>

        {/* ── SLIDER LINE ── */}
        <div
          className="absolute bottom-0 top-0 z-30 w-[3px] -translate-x-1/2 bg-white"
          style={{
            left: `${sliderPos}%`,
            boxShadow: "0 0 8px rgba(0,0,0,0.15)",
          }}
        />

        {/* ── SLIDER HANDLE ── */}
        <div
          onMouseDown={(e) => {
            e.preventDefault();
            setIsDragging(true);
          }}
          onTouchStart={() => setIsDragging(true)}
          className="absolute top-1/2 z-[31] flex h-11 w-11 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full bg-white"
          style={{
            left: `${sliderPos}%`,
            boxShadow: "0 2px 8px rgba(0,0,0,0.15), 0 0 0 2px rgba(0,0,0,0.05)",
            cursor: isDragging ? "grabbing" : "grab",
          }}
          role="slider"
          aria-label="Drag to compare before and after"
          aria-valuenow={Math.round(sliderPos)}
          aria-valuemin={5}
          aria-valuemax={95}
          aria-valuetext={`Showing ${100 - Math.round(sliderPos)}% before and ${Math.round(sliderPos)}% after`}
          tabIndex={0}
          onKeyDown={(e) => {
            if (e.key === "ArrowLeft") setSliderPos((p) => Math.max(5, p - 2));
            if (e.key === "ArrowRight") setSliderPos((p) => Math.min(95, p + 2));
          }}
        >
          <div className="flex items-center gap-[3px]">
            <span className="text-[10px] text-[#999]">◂</span>
            <span className="text-[10px] text-[#999]">▸</span>
          </div>
        </div>
      </div>

      <p className="mt-3.5 text-center text-[13px] text-[var(--text-muted)]">
        Drag the slider to see the transformation
      </p>
    </div>
  );
}
