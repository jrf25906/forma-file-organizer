"use client";

import { motion, AnimatePresence } from "framer-motion";
import { useState, useEffect } from "react";
import {
  Image,
  FileText,
  FileSpreadsheet,
  Music,
  Video,
  Archive,
  Code,
  Database,
  FolderOpen,
  Camera,
  FileCode,
  File,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

// File configurations for each persona
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
  designer: {
    files: [
      { id: 1, name: "hero_v3_final.fig", icon: FileCode, color: "warm-orange", x: -80, y: -50 },
      { id: 2, name: "icons_draft.sketch", icon: FileCode, color: "steel-blue", x: 60, y: -40 },
      { id: 3, name: "mockup_client.psd", icon: Image, color: "warm-orange", x: -50, y: 30 },
      { id: 4, name: "logo_export.ai", icon: FileCode, color: "sage", x: 70, y: 50 },
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
  developer: {
    files: [
      { id: 1, name: "error_log_0847.txt", icon: FileText, color: "warm-orange", x: -70, y: -60 },
      { id: 2, name: "screenshot_423.png", icon: Image, color: "steel-blue", x: 55, y: -45 },
      { id: 3, name: "db_backup.sql", icon: Database, color: "sage", x: -55, y: 35 },
      { id: 4, name: "config_prod.json", icon: Code, color: "muted-blue", x: 65, y: 55 },
      { id: 5, name: "api_docs.pdf", icon: FileText, color: "steel-blue", x: -75, y: 65 },
      { id: 6, name: "node_modules.zip", icon: Archive, color: "warm-orange", x: 45, y: -70 },
    ],
    folders: [
      { name: "Logs", icon: FolderOpen, color: "warm-orange", files: [1] },
      { name: "Screenshots", icon: FolderOpen, color: "steel-blue", files: [2] },
      { name: "Database", icon: FolderOpen, color: "sage", files: [3] },
      { name: "Config", icon: FolderOpen, color: "muted-blue", files: [4] },
      { name: "Docs", icon: FolderOpen, color: "steel-blue", files: [5] },
      { name: "Backups", icon: FolderOpen, color: "warm-orange", files: [6] },
    ],
  },
  photographer: {
    files: [
      { id: 1, name: "DSC_0847.NEF", icon: Camera, color: "warm-orange", x: -75, y: -55 },
      { id: 2, name: "IMG_2841.CR3", icon: Camera, color: "warm-orange", x: 60, y: -40 },
      { id: 3, name: "_MG_9923.DNG", icon: Camera, color: "sage", x: -60, y: 40 },
      { id: 4, name: "DSC_0848.NEF", icon: Camera, color: "warm-orange", x: 70, y: 60 },
      { id: 5, name: "edit_final.psd", icon: Image, color: "steel-blue", x: -70, y: -75 },
      { id: 6, name: "lightroom_cat.lrcat", icon: Database, color: "muted-blue", x: 50, y: 75 },
    ],
    folders: [
      { name: "2024-03-15", icon: FolderOpen, color: "warm-orange", files: [1, 4] },
      { name: "2024-03-14", icon: FolderOpen, color: "warm-orange", files: [2] },
      { name: "2024-03-13", icon: FolderOpen, color: "sage", files: [3] },
      { name: "Edits", icon: FolderOpen, color: "steel-blue", files: [5] },
      { name: "Catalogs", icon: FolderOpen, color: "muted-blue", files: [6] },
    ],
  },
  researcher: {
    files: [
      { id: 1, name: "smith_2023.pdf", icon: FileText, color: "muted-blue", x: -70, y: -50 },
      { id: 2, name: "dataset_v3.csv", icon: FileSpreadsheet, color: "sage", x: 65, y: -45 },
      { id: 3, name: "analysis.xlsx", icon: FileSpreadsheet, color: "sage", x: -55, y: 40 },
      { id: 4, name: "notes_lit.docx", icon: FileText, color: "steel-blue", x: 70, y: 55 },
      { id: 5, name: "refs.bib", icon: File, color: "muted-blue", x: -75, y: 70 },
      { id: 6, name: "jones_2024.pdf", icon: FileText, color: "muted-blue", x: 50, y: -70 },
    ],
    folders: [
      { name: "Literature", icon: FolderOpen, color: "muted-blue", files: [1, 6] },
      { name: "Data", icon: FolderOpen, color: "sage", files: [2, 3] },
      { name: "Notes", icon: FolderOpen, color: "steel-blue", files: [4] },
      { name: "References", icon: FolderOpen, color: "muted-blue", files: [5] },
    ],
  },
  creator: {
    files: [
      { id: 1, name: "intro_take3.mp4", icon: Video, color: "warm-orange", x: -75, y: -50 },
      { id: 2, name: "b-roll_cafe.mov", icon: Video, color: "warm-orange", x: 60, y: -45 },
      { id: 3, name: "voiceover.wav", icon: Music, color: "steel-blue", x: -60, y: 35 },
      { id: 4, name: "thumbnail_v2.png", icon: Image, color: "sage", x: 70, y: 60 },
      { id: 5, name: "music_bg.mp3", icon: Music, color: "steel-blue", x: -70, y: 70 },
      { id: 6, name: "script_draft.docx", icon: FileText, color: "muted-blue", x: 55, y: -70 },
    ],
    folders: [
      { name: "Footage", icon: FolderOpen, color: "warm-orange", files: [1, 2] },
      { name: "Audio", icon: FolderOpen, color: "steel-blue", files: [3, 5] },
      { name: "Thumbnails", icon: FolderOpen, color: "sage", files: [4] },
      { name: "Scripts", icon: FolderOpen, color: "muted-blue", files: [6] },
    ],
  },
  writer: {
    files: [
      { id: 1, name: "ch3_draft_v2.docx", icon: FileText, color: "steel-blue", x: -70, y: -55 },
      { id: 2, name: "notes_research.md", icon: FileText, color: "sage", x: 65, y: -40 },
      { id: 3, name: "outline_final.txt", icon: FileText, color: "muted-blue", x: -55, y: 40 },
      { id: 4, name: "ch3_FINAL_v3.docx", icon: FileText, color: "steel-blue", x: 70, y: 55 },
      { id: 5, name: "feedback.pdf", icon: FileText, color: "warm-orange", x: -75, y: 65 },
      { id: 6, name: "ch3_old.docx", icon: FileText, color: "steel-blue", x: 50, y: -70 },
    ],
    folders: [
      { name: "Chapter 3", icon: FolderOpen, color: "steel-blue", files: [1, 4, 6] },
      { name: "Research", icon: FolderOpen, color: "sage", files: [2] },
      { name: "Outlines", icon: FolderOpen, color: "muted-blue", files: [3] },
      { name: "Feedback", icon: FolderOpen, color: "warm-orange", files: [5] },
    ],
  },
  student: {
    files: [
      { id: 1, name: "essay_bio101.docx", icon: FileText, color: "steel-blue", x: -70, y: -50 },
      { id: 2, name: "lecture_12.pdf", icon: FileText, color: "muted-blue", x: 60, y: -45 },
      { id: 3, name: "hw3_math.pdf", icon: FileText, color: "sage", x: -60, y: 35 },
      { id: 4, name: "project.pptx", icon: FileText, color: "warm-orange", x: 70, y: 55 },
      { id: 5, name: "notes_chem.docx", icon: FileText, color: "steel-blue", x: -75, y: 70 },
      { id: 6, name: "syllabus.pdf", icon: FileText, color: "muted-blue", x: 50, y: -70 },
    ],
    folders: [
      { name: "BIO 101", icon: FolderOpen, color: "sage", files: [1] },
      { name: "MATH 201", icon: FolderOpen, color: "steel-blue", files: [3] },
      { name: "CHEM 102", icon: FolderOpen, color: "warm-orange", files: [5] },
      { name: "Lectures", icon: FolderOpen, color: "muted-blue", files: [2, 6] },
      { name: "Projects", icon: FolderOpen, color: "warm-orange", files: [4] },
    ],
  },
  freelancer: {
    files: [
      { id: 1, name: "invoice_0847.pdf", icon: FileText, color: "sage", x: -70, y: -55 },
      { id: 2, name: "contract_acme.pdf", icon: FileText, color: "muted-blue", x: 65, y: -40 },
      { id: 3, name: "deliverable_v2.zip", icon: Archive, color: "steel-blue", x: -55, y: 40 },
      { id: 4, name: "brief_newclient.docx", icon: FileText, color: "warm-orange", x: 70, y: 55 },
      { id: 5, name: "receipt_adobe.pdf", icon: FileText, color: "sage", x: -75, y: 65 },
      { id: 6, name: "proposal_draft.docx", icon: FileText, color: "warm-orange", x: 50, y: -70 },
    ],
    folders: [
      { name: "Acme Corp", icon: FolderOpen, color: "steel-blue", files: [2, 3] },
      { name: "New Client", icon: FolderOpen, color: "warm-orange", files: [4, 6] },
      { name: "Invoices", icon: FolderOpen, color: "sage", files: [1] },
      { name: "Expenses", icon: FolderOpen, color: "sage", files: [5] },
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

  const config = personaFiles[personaId] || personaFiles.designer;

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
