"use client";

import { CSSProperties, forwardRef } from "react";

// ═══════════════════════════════════════════════════════════════════════════
// FILE ICON
// macOS-style file icons for the desktop scatter effect.
// Various file types with appropriate styling.
// ═══════════════════════════════════════════════════════════════════════════

export type FileType = "screenshot" | "pdf" | "document" | "spreadsheet" | "image" | "folder";

interface FileIconProps {
    type: FileType;
    size?: number;
    className?: string;
    style?: CSSProperties;
    /** Unique ID for GSAP targeting */
    id?: string;
    /** Optional label shown below icon */
    label?: string;
}

const FileIcon = forwardRef<HTMLDivElement, FileIconProps>(
    ({ type, size = 64, className = "", style = {}, id, label }, ref) => {
        const iconContent = getIconContent(type, size);

        return (
            <div
                ref={ref}
                id={id}
                className={`flex flex-col items-center gap-1.5 ${className}`}
                style={{
                    width: size,
                    ...style,
                }}
            >
                {/* Icon Container */}
                <div
                    className="relative"
                    style={{
                        width: size,
                        height: size,
                        filter: "drop-shadow(0 4px 8px rgba(0,0,0,0.15))",
                    }}
                >
                    {iconContent}
                </div>

                {/* Label */}
                {label && (
                    <span
                        className="text-white/90 text-center leading-tight font-medium truncate w-full px-1"
                        style={{
                            fontSize: Math.max(9, size * 0.14),
                            textShadow: "0 1px 3px rgba(0,0,0,0.5)",
                        }}
                    >
                        {label}
                    </span>
                )}
            </div>
        );
    }
);

FileIcon.displayName = "FileIcon";
export default FileIcon;

// ═══════════════════════════════════════════════════════════════════════════
// ICON CONTENT RENDERERS
// ═══════════════════════════════════════════════════════════════════════════

function getIconContent(type: FileType, size: number) {
    switch (type) {
        case "screenshot":
            return <ScreenshotIcon size={size} />;
        case "pdf":
            return <PDFIcon size={size} />;
        case "document":
            return <DocumentIcon size={size} />;
        case "spreadsheet":
            return <SpreadsheetIcon size={size} />;
        case "image":
            return <ImageIcon size={size} />;
        case "folder":
            return <FolderIcon size={size} />;
        default:
            return <DocumentIcon size={size} />;
    }
}

// Screenshot Icon - macOS style with image preview hint
function ScreenshotIcon({ size }: { size: number }) {
    return (
        <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
            {/* Main rounded rectangle (screenshot preview) */}
            <rect
                x="4"
                y="8"
                width="56"
                height="48"
                rx="6"
                fill="url(#screenshot-gradient)"
            />
            {/* Inner content area simulation */}
            <rect
                x="8"
                y="16"
                width="48"
                height="36"
                rx="2"
                fill="#1a1a2e"
                opacity="0.3"
            />
            {/* Camera/screenshot indicator */}
            <circle cx="52" cy="14" r="4" fill="#ff6b6b" opacity="0.9" />
            {/* Decorative lines simulating content */}
            <rect x="12" y="22" width="24" height="3" rx="1.5" fill="white" opacity="0.4" />
            <rect x="12" y="28" width="32" height="2" rx="1" fill="white" opacity="0.25" />
            <rect x="12" y="33" width="28" height="2" rx="1" fill="white" opacity="0.25" />
            <defs>
                <linearGradient id="screenshot-gradient" x1="4" y1="8" x2="60" y2="56" gradientUnits="userSpaceOnUse">
                    <stop stopColor="#667eea" />
                    <stop offset="1" stopColor="#764ba2" />
                </linearGradient>
            </defs>
        </svg>
    );
}

// PDF Icon - Red document style
function PDFIcon({ size }: { size: number }) {
    return (
        <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
            {/* Document shape with folded corner */}
            <path
                d="M12 4C12 2.89543 12.8954 2 14 2H38L52 16V58C52 59.1046 51.1046 60 50 60H14C12.8954 60 12 59.1046 12 58V4Z"
                fill="url(#pdf-gradient)"
            />
            {/* Folded corner */}
            <path
                d="M38 2L52 16H40C38.8954 16 38 15.1046 38 14V2Z"
                fill="#a83232"
            />
            {/* PDF text */}
            <text
                x="32"
                y="42"
                textAnchor="middle"
                fill="white"
                fontSize="12"
                fontWeight="bold"
                fontFamily="system-ui"
            >
                PDF
            </text>
            <defs>
                <linearGradient id="pdf-gradient" x1="12" y1="2" x2="52" y2="60" gradientUnits="userSpaceOnUse">
                    <stop stopColor="#e74c3c" />
                    <stop offset="1" stopColor="#c0392b" />
                </linearGradient>
            </defs>
        </svg>
    );
}

// Document Icon - Word-style blue
function DocumentIcon({ size }: { size: number }) {
    return (
        <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
            <path
                d="M12 4C12 2.89543 12.8954 2 14 2H38L52 16V58C52 59.1046 51.1046 60 50 60H14C12.8954 60 12 59.1046 12 58V4Z"
                fill="url(#doc-gradient)"
            />
            <path
                d="M38 2L52 16H40C38.8954 16 38 15.1046 38 14V2Z"
                fill="#2563a8"
            />
            {/* Lines simulating text */}
            <rect x="18" y="24" width="28" height="3" rx="1.5" fill="white" opacity="0.5" />
            <rect x="18" y="32" width="24" height="2" rx="1" fill="white" opacity="0.35" />
            <rect x="18" y="38" width="26" height="2" rx="1" fill="white" opacity="0.35" />
            <rect x="18" y="44" width="20" height="2" rx="1" fill="white" opacity="0.35" />
            <defs>
                <linearGradient id="doc-gradient" x1="12" y1="2" x2="52" y2="60" gradientUnits="userSpaceOnUse">
                    <stop stopColor="#3b82f6" />
                    <stop offset="1" stopColor="#2563eb" />
                </linearGradient>
            </defs>
        </svg>
    );
}

// Spreadsheet Icon - Excel-style green
function SpreadsheetIcon({ size }: { size: number }) {
    return (
        <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
            <path
                d="M12 4C12 2.89543 12.8954 2 14 2H38L52 16V58C52 59.1046 51.1046 60 50 60H14C12.8954 60 12 59.1046 12 58V4Z"
                fill="url(#sheet-gradient)"
            />
            <path
                d="M38 2L52 16H40C38.8954 16 38 15.1046 38 14V2Z"
                fill="#166534"
            />
            {/* Grid pattern */}
            <rect x="18" y="24" width="28" height="26" rx="2" fill="white" opacity="0.2" />
            <line x1="18" y1="34" x2="46" y2="34" stroke="white" strokeWidth="1" opacity="0.4" />
            <line x1="18" y1="42" x2="46" y2="42" stroke="white" strokeWidth="1" opacity="0.4" />
            <line x1="30" y1="24" x2="30" y2="50" stroke="white" strokeWidth="1" opacity="0.4" />
            <defs>
                <linearGradient id="sheet-gradient" x1="12" y1="2" x2="52" y2="60" gradientUnits="userSpaceOnUse">
                    <stop stopColor="#22c55e" />
                    <stop offset="1" stopColor="#16a34a" />
                </linearGradient>
            </defs>
        </svg>
    );
}

// Image Icon - Photo style with mountains
function ImageIcon({ size }: { size: number }) {
    return (
        <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
            <rect
                x="4"
                y="10"
                width="56"
                height="44"
                rx="6"
                fill="url(#image-gradient)"
            />
            {/* Sun */}
            <circle cx="18" cy="24" r="6" fill="#fbbf24" opacity="0.9" />
            {/* Mountains */}
            <path
                d="M4 44L20 28L32 40L44 26L60 44V48C60 51.3137 57.3137 54 54 54H10C6.68629 54 4 51.3137 4 48V44Z"
                fill="#1e3a5f"
                opacity="0.5"
            />
            <defs>
                <linearGradient id="image-gradient" x1="4" y1="10" x2="60" y2="54" gradientUnits="userSpaceOnUse">
                    <stop stopColor="#0ea5e9" />
                    <stop offset="1" stopColor="#0284c7" />
                </linearGradient>
            </defs>
        </svg>
    );
}

// Folder Icon - macOS style folder
function FolderIcon({ size }: { size: number }) {
    return (
        <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
            {/* Folder back */}
            <path
                d="M4 14C4 11.7909 5.79086 10 8 10H24L28 16H56C58.2091 16 60 17.7909 60 20V52C60 54.2091 58.2091 56 56 56H8C5.79086 56 4 54.2091 4 52V14Z"
                fill="url(#folder-gradient)"
            />
            {/* Folder front/lid highlight */}
            <path
                d="M4 22C4 19.7909 5.79086 18 8 18H56C58.2091 18 60 19.7909 60 22V52C60 54.2091 58.2091 56 56 56H8C5.79086 56 4 54.2091 4 52V22Z"
                fill="url(#folder-front-gradient)"
            />
            <defs>
                <linearGradient id="folder-gradient" x1="4" y1="10" x2="60" y2="56" gradientUnits="userSpaceOnUse">
                    <stop stopColor="#60a5fa" />
                    <stop offset="1" stopColor="#3b82f6" />
                </linearGradient>
                <linearGradient id="folder-front-gradient" x1="32" y1="18" x2="32" y2="56" gradientUnits="userSpaceOnUse">
                    <stop stopColor="#93c5fd" />
                    <stop offset="1" stopColor="#60a5fa" />
                </linearGradient>
            </defs>
        </svg>
    );
}

// ═══════════════════════════════════════════════════════════════════════════
// ARCHIVE FOLDER ICON
// Special folder icon for the "Archive" destination
// ═══════════════════════════════════════════════════════════════════════════

interface ArchiveFolderProps {
    size?: number;
    className?: string;
    style?: CSSProperties;
    id?: string;
    isReceiving?: boolean;
}

export function ArchiveFolder({
    size = 80,
    className = "",
    style = {},
    id,
    isReceiving = false,
}: ArchiveFolderProps) {
    return (
        <div
            id={id}
            className={`flex flex-col items-center gap-2 transition-transform duration-300 ${
                isReceiving ? "scale-110" : ""
            } ${className}`}
            style={style}
        >
            <div
                className={`relative transition-all duration-300 ${
                    isReceiving ? "drop-shadow-[0_0_20px_rgba(122,157,126,0.6)]" : ""
                }`}
                style={{
                    width: size,
                    height: size,
                    filter: "drop-shadow(0 6px 12px rgba(0,0,0,0.2))",
                }}
            >
                <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
                    {/* Folder back */}
                    <path
                        d="M4 14C4 11.7909 5.79086 10 8 10H24L28 16H56C58.2091 16 60 17.7909 60 20V52C60 54.2091 58.2091 56 56 56H8C5.79086 56 4 54.2091 4 52V14Z"
                        fill="url(#archive-gradient)"
                    />
                    {/* Folder front */}
                    <path
                        d="M4 22C4 19.7909 5.79086 18 8 18H56C58.2091 18 60 19.7909 60 22V52C60 54.2091 58.2091 56 56 56H8C5.79086 56 4 54.2091 4 52V22Z"
                        fill="url(#archive-front-gradient)"
                    />
                    {/* Archive symbol (box with down arrow) */}
                    <rect x="24" y="28" width="16" height="14" rx="2" fill="white" opacity="0.4" />
                    <path d="M32 30L32 38M32 38L28 34M32 38L36 34" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" opacity="0.6" />
                    <defs>
                        <linearGradient id="archive-gradient" x1="4" y1="10" x2="60" y2="56" gradientUnits="userSpaceOnUse">
                            <stop stopColor="#7A9D7E" />
                            <stop offset="1" stopColor="#5B8C61" />
                        </linearGradient>
                        <linearGradient id="archive-front-gradient" x1="32" y1="18" x2="32" y2="56" gradientUnits="userSpaceOnUse">
                            <stop stopColor="#9DB8A0" />
                            <stop offset="1" stopColor="#7A9D7E" />
                        </linearGradient>
                    </defs>
                </svg>
            </div>
            <span
                className="text-white/90 font-medium text-center"
                style={{
                    fontSize: Math.max(10, size * 0.15),
                    textShadow: "0 1px 3px rgba(0,0,0,0.5)",
                }}
            >
                Archive
            </span>
        </div>
    );
}
