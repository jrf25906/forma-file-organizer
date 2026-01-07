"use client";

import { forwardRef, useImperativeHandle, useRef } from "react";
import FileIcon, { ArchiveFolder, FileType } from "./FileIcon";

// ═══════════════════════════════════════════════════════════════════════════
// DESKTOP LAYER
// The scattered files on the "macOS desktop" background.
// Files are positioned strategically to not overlap with the Forma window.
// ═══════════════════════════════════════════════════════════════════════════

export interface DesktopFile {
    id: string;
    type: FileType;
    label: string;
    x: number; // Percentage from left
    y: number; // Percentage from top
    rotation: number; // Slight rotation for organic feel
    size: number;
    /** If true, this file will fly to archive during animation */
    willFly: boolean;
}

// Scattered file positions - designed to frame the center Forma window
export const DESKTOP_FILES: DesktopFile[] = [
    // Left side - screenshots that will fly
    { id: "file-1", type: "screenshot", label: "Screenshot 2024-01-02", x: 8, y: 25, rotation: -3, size: 56, willFly: true },
    { id: "file-2", type: "screenshot", label: "Screenshot 2024-01-03", x: 12, y: 45, rotation: 2, size: 52, willFly: true },
    { id: "file-3", type: "screenshot", label: "Screen Recording", x: 6, y: 65, rotation: -1, size: 54, willFly: true },

    // Top area - mixed files
    { id: "file-4", type: "screenshot", label: "CleanShot", x: 25, y: 15, rotation: 4, size: 50, willFly: true },
    { id: "file-5", type: "pdf", label: "Invoice-2024.pdf", x: 75, y: 12, rotation: -2, size: 48, willFly: false },

    // Right side - more screenshots and other files
    { id: "file-6", type: "screenshot", label: "Screenshot 2024-01-05", x: 88, y: 28, rotation: 3, size: 54, willFly: true },
    { id: "file-7", type: "screenshot", label: "IMG_4521", x: 92, y: 48, rotation: -4, size: 52, willFly: true },
    { id: "file-8", type: "document", label: "Notes.docx", x: 85, y: 68, rotation: 1, size: 46, willFly: false },

    // Bottom area
    { id: "file-9", type: "screenshot", label: "Screenshot 2024-01-06", x: 15, y: 82, rotation: -2, size: 50, willFly: true },
    { id: "file-10", type: "spreadsheet", label: "Budget.xlsx", x: 30, y: 88, rotation: 3, size: 44, willFly: false },
    { id: "file-11", type: "screenshot", label: "Capture-Final", x: 70, y: 85, rotation: -3, size: 52, willFly: true },
    { id: "file-12", type: "image", label: "Photo.jpg", x: 85, y: 90, rotation: 2, size: 48, willFly: false },
];

// Files that will animate (screenshots older than a week)
export const FLYING_FILES = DESKTOP_FILES.filter((f) => f.willFly);

interface DesktopLayerProps {
    className?: string;
    /** Animation phase for visibility control */
    phase?: "idle" | "typing" | "processing" | "success" | "flying" | "complete";
}

export interface DesktopLayerRef {
    getFileElements: () => Map<string, HTMLDivElement | null>;
    getArchiveElement: () => HTMLDivElement | null;
}

const DesktopLayer = forwardRef<DesktopLayerRef, DesktopLayerProps>(
    ({ className = "", phase = "idle" }, ref) => {
        const fileRefs = useRef<Map<string, HTMLDivElement | null>>(new Map());
        const archiveRef = useRef<HTMLDivElement | null>(null);

        // Expose refs to parent for GSAP animation
        useImperativeHandle(ref, () => ({
            getFileElements: () => fileRefs.current,
            getArchiveElement: () => archiveRef.current,
        }));

        const isFlying = phase === "flying" || phase === "complete";
        const isHighlighting = phase === "processing" || phase === "success";

        return (
            <div className={`absolute inset-0 pointer-events-none ${className}`}>
                {/* Archive Folder - destination for flying files */}
                <div
                    ref={archiveRef}
                    className="absolute"
                    style={{
                        right: "8%",
                        bottom: "15%",
                        transform: "translate(0, 0)",
                        zIndex: 5,
                        opacity: isHighlighting || isFlying ? 1 : 0.7,
                        transition: "opacity 0.5s ease",
                    }}
                >
                    <ArchiveFolder
                        id="archive-folder"
                        size={72}
                        isReceiving={isFlying}
                    />
                </div>

                {/* Scattered Desktop Files */}
                {DESKTOP_FILES.map((file) => {
                    const shouldHighlight = file.willFly && isHighlighting;
                    const shouldHide = file.willFly && phase === "complete";

                    return (
                        <div
                            key={file.id}
                            ref={(el) => {
                                fileRefs.current.set(file.id, el);
                            }}
                            className="absolute transition-all duration-500"
                            style={{
                                left: `${file.x}%`,
                                top: `${file.y}%`,
                                transform: `translate(-50%, -50%) rotate(${file.rotation}deg)`,
                                zIndex: file.willFly ? 10 : 1,
                                opacity: shouldHide ? 0 : 1,
                                filter: shouldHighlight
                                    ? "drop-shadow(0 0 12px rgba(91, 124, 153, 0.6))"
                                    : "none",
                            }}
                        >
                            <FileIcon
                                id={`icon-${file.id}`}
                                type={file.type}
                                size={file.size}
                                label={file.label}
                            />
                        </div>
                    );
                })}

                {/* Static folder icons in corners (for ambiance) */}
                <div
                    className="absolute opacity-50"
                    style={{ left: "5%", top: "8%" }}
                >
                    <FileIcon type="folder" size={40} label="Documents" />
                </div>
                <div
                    className="absolute opacity-50"
                    style={{ right: "5%", top: "8%" }}
                >
                    <FileIcon type="folder" size={40} label="Downloads" />
                </div>
            </div>
        );
    }
);

DesktopLayer.displayName = "DesktopLayer";
export default DesktopLayer;
