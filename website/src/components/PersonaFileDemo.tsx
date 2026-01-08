"use client";

import { motion, AnimatePresence } from "framer-motion";
import { useState, useEffect } from "react";
import {
  Image,
  FileText,
  FileSpreadsheet,
  Archive,
  FolderOpen,
  File,
  FileVideo,
  Presentation,
  Receipt,
  FileImage,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

// File configurations for each behavior-based persona
const personaFiles: Record<
  string,
  {
    files: Array<{
      id: number;
      name: string;
      icon: LucideIcon;
      color: string;
      x: number;
      y: number;
    }>;
    folders: Array<{
      name: string;
      icon: LucideIcon;
      color: string;
      files: number[];
    }>;
  }
> = {
  // Downloads Folder Hostage
  "downloads-chaos": {
    files: [
      { id: 1, name: "invoice_march.pdf", icon: FileText, color: "warm-orange", x: -80, y: -50 },
      { id: 2, name: "Screenshot 2024-03-15.png", icon: Image, color: "steel-blue", x: 60, y: -40 },
      { id: 3, name: "client_brief.pdf", icon: FileText, color: "warm-orange", x: -50, y: 30 },
      { id: 4, name: "installer.dmg", icon: Archive, color: "sage", x: 70, y: 50 },
      { id: 5, name: "receipt_amazon.pdf", icon: FileText, color: "muted-blue", x: -70, y: -70 },
      { id: 6, name: "photos.zip", icon: Archive, color: "steel-blue", x: 40, y: 70 },
    ],
    folders: [
      { name: "Invoices", icon: FolderOpen, color: "warm-orange", files: [1] },
      { name: "Screenshots/2024-03", icon: FolderOpen, color: "steel-blue", files: [2] },
      { name: "Projects/Client", icon: FolderOpen, color: "warm-orange", files: [3] },
      { name: "Applications", icon: FolderOpen, color: "sage", files: [4] },
      { name: "Receipts/2024", icon: FolderOpen, color: "muted-blue", files: [5] },
      { name: "Archives", icon: FolderOpen, color: "steel-blue", files: [6] },
    ],
  },

  // Final_v2_FINAL_FOR-REAL.mov
  "version-hell": {
    files: [
      { id: 1, name: "pitch_deck_v1.pptx", icon: Presentation, color: "steel-blue", x: -70, y: -60 },
      { id: 2, name: "pitch_deck_v2.pptx", icon: Presentation, color: "steel-blue", x: 55, y: -45 },
      { id: 3, name: "pitch_FINAL.pptx", icon: Presentation, color: "steel-blue", x: -55, y: 35 },
      { id: 4, name: "pitch_FINAL_v2.pptx", icon: Presentation, color: "steel-blue", x: 65, y: 55 },
      { id: 5, name: "pitch_FOR-REAL.pptx", icon: Presentation, color: "warm-orange", x: -75, y: 65 },
      { id: 6, name: "pitch_SEND-THIS.pptx", icon: Presentation, color: "warm-orange", x: 45, y: -70 },
    ],
    folders: [
      { name: "Pitch Deck/Current", icon: FolderOpen, color: "warm-orange", files: [6] },
      { name: "Pitch Deck/Archive", icon: FolderOpen, color: "steel-blue", files: [1, 2, 3, 4, 5] },
    ],
  },

  // Buried in PDFs (Researcher)
  "research-buried": {
    files: [
      { id: 1, name: "smith_2023_study.pdf", icon: FileText, color: "sage", x: -70, y: -50 },
      { id: 2, name: "data_export.csv", icon: FileSpreadsheet, color: "sage", x: 65, y: -45 },
      { id: 3, name: "chart_screenshot.png", icon: Image, color: "steel-blue", x: -55, y: 40 },
      { id: 4, name: "notes_interview.md", icon: FileText, color: "muted-blue", x: 70, y: 55 },
      { id: 5, name: "jones_2024.pdf", icon: FileText, color: "sage", x: -75, y: 70 },
      { id: 6, name: "literature_review.pdf", icon: FileText, color: "sage", x: 50, y: -70 },
    ],
    folders: [
      { name: "Research/Papers", icon: FolderOpen, color: "sage", files: [1, 5, 6] },
      { name: "Research/Data", icon: FolderOpen, color: "sage", files: [2] },
      { name: "Research/Figures", icon: FolderOpen, color: "steel-blue", files: [3] },
      { name: "Research/Notes", icon: FolderOpen, color: "muted-blue", files: [4] },
    ],
  },

  // 14 Pitch Decks, No Canonical (Founder)
  "pitch-deck-founder": {
    files: [
      { id: 1, name: "investor_deck.pptx", icon: Presentation, color: "muted-blue", x: -75, y: -55 },
      { id: 2, name: "board_deck.key", icon: Presentation, color: "muted-blue", x: 60, y: -40 },
      { id: 3, name: "team_overview.pdf", icon: FileText, color: "steel-blue", x: -60, y: 40 },
      { id: 4, name: "financials_q4.xlsx", icon: FileSpreadsheet, color: "sage", x: 70, y: 60 },
      { id: 5, name: "investor_deck_v2.pptx", icon: Presentation, color: "muted-blue", x: -70, y: -75 },
      { id: 6, name: "metrics_2024.pdf", icon: FileText, color: "warm-orange", x: 50, y: 75 },
    ],
    folders: [
      { name: "Decks/Current", icon: FolderOpen, color: "warm-orange", files: [1, 2] },
      { name: "Decks/Archive", icon: FolderOpen, color: "muted-blue", files: [5] },
      { name: "Board Materials", icon: FolderOpen, color: "steel-blue", files: [3, 6] },
      { name: "Financials", icon: FolderOpen, color: "sage", files: [4] },
    ],
  },

  // Attachment Avalanche
  "inbox-overflow": {
    files: [
      { id: 1, name: "contract_signed.pdf", icon: FileText, color: "warm-orange", x: -70, y: -55 },
      { id: 2, name: "receipt_0847.pdf", icon: Receipt, color: "sage", x: 65, y: -40 },
      { id: 3, name: "project_brief.docx", icon: FileText, color: "steel-blue", x: -55, y: 40 },
      { id: 4, name: "expense_report.xlsx", icon: FileSpreadsheet, color: "sage", x: 70, y: 55 },
      { id: 5, name: "invoice_vendor.pdf", icon: FileText, color: "warm-orange", x: -75, y: 65 },
      { id: 6, name: "meeting_notes.png", icon: Image, color: "muted-blue", x: 50, y: -70 },
    ],
    folders: [
      { name: "Contracts", icon: FolderOpen, color: "warm-orange", files: [1] },
      { name: "Expenses/Receipts", icon: FolderOpen, color: "sage", files: [2, 4] },
      { name: "Projects/Active", icon: FolderOpen, color: "steel-blue", files: [3] },
      { name: "Invoices/2024", icon: FolderOpen, color: "warm-orange", files: [5] },
      { name: "Notes/Meetings", icon: FolderOpen, color: "muted-blue", files: [6] },
    ],
  },

  // Screenshot Archaeologist
  "screenshot-graveyard": {
    files: [
      { id: 1, name: "Screenshot 2024-03-01 at 9.23.45 AM.png", icon: FileImage, color: "steel-blue", x: -75, y: -50 },
      { id: 2, name: "Screenshot 2024-03-01 at 2.14.33 PM.png", icon: FileImage, color: "steel-blue", x: 60, y: -45 },
      { id: 3, name: "IMG_4521.HEIC", icon: FileImage, color: "warm-orange", x: -60, y: 35 },
      { id: 4, name: "Screenshot 2024-02-28 at 11.05.12 AM.png", icon: FileImage, color: "steel-blue", x: 70, y: 60 },
      { id: 5, name: "design_ref.gif", icon: FileImage, color: "sage", x: -70, y: 70 },
      { id: 6, name: "bug_report.jpg", icon: FileImage, color: "warm-orange", x: 55, y: -70 },
    ],
    folders: [
      { name: "Screenshots/2024-03", icon: FolderOpen, color: "steel-blue", files: [1, 2] },
      { name: "Screenshots/2024-02", icon: FolderOpen, color: "steel-blue", files: [4] },
      { name: "Photos/2024", icon: FolderOpen, color: "warm-orange", files: [3] },
      { name: "References/Design", icon: FolderOpen, color: "sage", files: [5] },
      { name: "Work/Bug Reports", icon: FolderOpen, color: "warm-orange", files: [6] },
    ],
  },

  // Legacy fallback personas (in case old IDs are still referenced)
  designer: {
    files: [
      { id: 1, name: "hero_v3_final.fig", icon: File, color: "warm-orange", x: -80, y: -50 },
      { id: 2, name: "icons_draft.sketch", icon: File, color: "steel-blue", x: 60, y: -40 },
      { id: 3, name: "mockup_client.psd", icon: Image, color: "warm-orange", x: -50, y: 30 },
      { id: 4, name: "logo_export.ai", icon: File, color: "sage", x: 70, y: 50 },
      { id: 5, name: "wireframes.pdf", icon: FileText, color: "muted-blue", x: -70, y: -70 },
      { id: 6, name: "assets_v2.zip", icon: Archive, color: "steel-blue", x: 40, y: 70 },
    ],
    folders: [
      { name: "Figma Files", icon: FolderOpen, color: "warm-orange", files: [1] },
      { name: "Sketch", icon: FolderOpen, color: "steel-blue", files: [2] },
      { name: "Photoshop", icon: FolderOpen, color: "warm-orange", files: [3] },
      { name: "Illustrator", icon: FolderOpen, color: "sage", files: [4] },
      { name: "Documents", icon: FolderOpen, color: "muted-blue", files: [5] },
      { name: "Archives", icon: FolderOpen, color: "steel-blue", files: [6] },
    ],
  },
};

interface PersonaFileDemoProps {
  personaId: string;
  color: string;
}

export default function PersonaFileDemo({ personaId, color }: PersonaFileDemoProps) {
  const [phase, setPhase] = useState<"scattered" | "scanning" | "organizing" | "organized">("scattered");
  const [cycleKey, setCycleKey] = useState(0);

  const config = personaFiles[personaId] || personaFiles["downloads-chaos"];

  // Reset animation when persona changes
  useEffect(() => {
    setPhase("scattered");
    setCycleKey((k) => k + 1);
  }, [personaId]);

  // Animation cycle
  useEffect(() => {
    const phases: Array<{ phase: typeof phase; duration: number }> = [
      { phase: "scattered", duration: 1500 },
      { phase: "scanning", duration: 1200 },
      { phase: "organizing", duration: 1500 },
      { phase: "organized", duration: 2500 },
    ];

    let currentIndex = 0;
    let timeout: NodeJS.Timeout;

    const runPhase = () => {
      setPhase(phases[currentIndex].phase);
      timeout = setTimeout(() => {
        currentIndex = (currentIndex + 1) % phases.length;
        if (currentIndex === 0) {
          setCycleKey((k) => k + 1);
        }
        runPhase();
      }, phases[currentIndex].duration);
    };

    // Small delay before starting
    const startDelay = setTimeout(runPhase, 300);

    return () => {
      clearTimeout(timeout);
      clearTimeout(startDelay);
    };
  }, [personaId]);

  return (
    <div className="relative w-full h-64 overflow-hidden rounded-xl bg-gradient-to-br from-forma-obsidian/30 via-white/5 to-forma-obsidian/20 border border-white/5">
      {/* Phase indicator */}
      <div className="absolute top-3 left-3 z-20">
        <div className="glass-card rounded-full px-2.5 py-1 flex items-center gap-1.5">
          <motion.div
            animate={{
              backgroundColor:
                phase === "organized"
                  ? "rgb(122, 157, 126)"
                  : phase === "scanning"
                  ? "rgb(91, 124, 153)"
                  : "rgb(201, 126, 102)",
            }}
            className="w-1.5 h-1.5 rounded-full"
          />
          <span className="text-[10px] font-medium text-forma-bone/60">
            {phase === "scattered" && "Messy files"}
            {phase === "scanning" && "Analyzing..."}
            {phase === "organizing" && "Organizing"}
            {phase === "organized" && "Done!"}
          </span>
        </div>
      </div>

      <AnimatePresence mode="wait">
        {/* Scattered / Scanning Phase */}
        {(phase === "scattered" || phase === "scanning") && (
          <motion.div
            key={`scattered-${cycleKey}`}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.3 }}
            className="absolute inset-0 flex items-center justify-center"
          >
            <div className="relative w-64 h-48">
              {config.files.map((file, index) => (
                <motion.div
                  key={file.id}
                  initial={{
                    x: file.x,
                    y: file.y,
                    rotate: Math.random() * 20 - 10,
                    scale: 0,
                  }}
                  animate={{
                    x: file.x + (Math.random() * 8 - 4),
                    y: file.y + (Math.random() * 8 - 4),
                    rotate: Math.random() * 15 - 7.5,
                    scale: 1,
                  }}
                  transition={{
                    duration: 0.4,
                    delay: index * 0.08,
                    type: "spring",
                    stiffness: 200,
                  }}
                  className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
                >
                  <div
                    className={`glass-card rounded-md p-1.5 flex items-center gap-1.5 shadow-glass ${
                      phase === "scanning" ? "animate-pulse" : ""
                    }`}
                  >
                    <div
                      className={`w-6 h-6 rounded bg-forma-${file.color}/20 flex items-center justify-center`}
                    >
                      <file.icon className={`w-3 h-3 text-forma-${file.color}`} />
                    </div>
                    <span className="text-[9px] text-forma-bone/60 max-w-[70px] truncate">
                      {file.name}
                    </span>
                  </div>

                  {/* Scanning ring effect */}
                  {phase === "scanning" && (
                    <motion.div
                      initial={{ opacity: 0, scale: 0.8 }}
                      animate={{ opacity: [0, 1, 0], scale: [0.8, 1.2, 0.8] }}
                      transition={{ duration: 0.8, repeat: Infinity, delay: index * 0.1 }}
                      className="absolute inset-0 rounded-md border border-forma-steel-blue/50"
                    />
                  )}
                </motion.div>
              ))}

              {/* Scanning line */}
              {phase === "scanning" && (
                <motion.div
                  initial={{ y: -100, opacity: 0 }}
                  animate={{ y: 100, opacity: [0, 1, 1, 0] }}
                  transition={{ duration: 1, repeat: Infinity }}
                  className="absolute left-0 right-0 h-0.5 bg-gradient-to-r from-transparent via-forma-steel-blue to-transparent"
                />
              )}
            </div>
          </motion.div>
        )}

        {/* Organizing / Organized Phase */}
        {(phase === "organizing" || phase === "organized") && (
          <motion.div
            key={`organized-${cycleKey}`}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.3 }}
            className="p-4 pt-10"
          >
            <div className="grid grid-cols-3 gap-2">
              {config.folders.slice(0, 6).map((folder, folderIndex) => (
                <motion.div
                  key={folder.name}
                  initial={{ opacity: 0, y: 15 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: folderIndex * 0.08 }}
                  className="glass-card rounded-lg p-2"
                >
                  <div className="flex items-center gap-1.5 mb-1.5">
                    <div
                      className={`w-5 h-5 rounded bg-forma-${folder.color}/20 flex items-center justify-center`}
                    >
                      <FolderOpen className={`w-2.5 h-2.5 text-forma-${folder.color}`} />
                    </div>
                    <span className="text-[10px] font-medium text-forma-bone truncate">
                      {folder.name}
                    </span>
                  </div>

                  <div className="space-y-0.5">
                    {folder.files.slice(0, 2).map((fileId, fileIndex) => {
                      const file = config.files.find((f) => f.id === fileId);
                      if (!file) return null;
                      return (
                        <motion.div
                          key={fileId}
                          initial={
                            phase === "organizing"
                              ? {
                                  x: file.x - (folderIndex % 3) * 80,
                                  y: file.y - Math.floor(folderIndex / 3) * 60,
                                  opacity: 0,
                                  scale: 0.5,
                                }
                              : { opacity: 1, x: 0, y: 0, scale: 1 }
                          }
                          animate={{ x: 0, y: 0, opacity: 1, scale: 1 }}
                          transition={{
                            duration: 0.5,
                            delay: folderIndex * 0.1 + fileIndex * 0.08,
                            type: "spring",
                            stiffness: 120,
                          }}
                          className="flex items-center gap-1 p-1 rounded bg-white/5"
                        >
                          <file.icon className={`w-2 h-2 text-forma-${file.color}`} />
                          <span className="text-[8px] text-forma-bone/50 truncate flex-1">
                            {file.name}
                          </span>
                          {phase === "organized" && (
                            <motion.span
                              initial={{ scale: 0 }}
                              animate={{ scale: 1 }}
                              transition={{ delay: 0.3 + fileIndex * 0.1 }}
                              className="text-forma-sage text-[8px]"
                            >
                              ✓
                            </motion.span>
                          )}
                        </motion.div>
                      );
                    })}
                  </div>
                </motion.div>
              ))}
            </div>

            {/* Success message */}
            {phase === "organized" && (
              <motion.div
                initial={{ opacity: 0, y: 5 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.5 }}
                className="mt-3 text-center"
              >
                <div className="inline-flex items-center gap-1.5 glass-card rounded-full px-2.5 py-1">
                  <span className="text-forma-sage text-[10px]">✓</span>
                  <span className="text-[10px] text-forma-bone/60">
                    {config.files.length} files organized
                  </span>
                </div>
              </motion.div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
