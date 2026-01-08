"use client";

import { motion, AnimatePresence } from "framer-motion";
import { ArrowDown, Sparkles, FolderOpen, FileText, Image, FileSpreadsheet, Music, Video, Archive, Clock } from "lucide-react";
import { useState, useEffect } from "react";

// File types for the animation
const scatteredFiles = [
  { id: 1, name: "IMG_2847.jpg", icon: Image, color: "warm-orange", x: -120, y: -80 },
  { id: 2, name: "report_final_v3.pdf", icon: FileText, color: "muted-blue", x: 80, y: -60 },
  { id: 3, name: "budget_2024.xlsx", icon: FileSpreadsheet, color: "soft-green", x: -60, y: 40 },
  { id: 4, name: "song_draft.mp3", icon: Music, color: "steel-blue", x: 100, y: 80 },
  { id: 5, name: "vacation_clip.mov", icon: Video, color: "warm-orange", x: -100, y: 100 },
  { id: 6, name: "project_backup.zip", icon: Archive, color: "sage", x: 60, y: -100 },
  { id: 7, name: "screenshot_423.png", icon: Image, color: "warm-orange", x: -40, y: -120 },
  { id: 8, name: "notes_meeting.pdf", icon: FileText, color: "muted-blue", x: 120, y: 20 },
];

const organizedFolders = [
  { name: "Photos", icon: Image, color: "warm-orange", files: [1, 7] },
  { name: "Documents", icon: FileText, color: "muted-blue", files: [2, 8] },
  { name: "Spreadsheets", icon: FileSpreadsheet, color: "soft-green", files: [3] },
  { name: "Music", icon: Music, color: "steel-blue", files: [4] },
  { name: "Videos", icon: Video, color: "warm-orange", files: [5] },
  { name: "Archives", icon: Archive, color: "sage", files: [6] },
];

export default function Hero() {
  const [animationPhase, setAnimationPhase] = useState<"scattered" | "scanning" | "organizing" | "organized">("scattered");
  const [cycleCount, setCycleCount] = useState(0);

  // Animation cycle
  useEffect(() => {
    const phases = [
      { phase: "scattered" as const, duration: 2000 },
      { phase: "scanning" as const, duration: 1500 },
      { phase: "organizing" as const, duration: 2000 },
      { phase: "organized" as const, duration: 3000 },
    ];

    let currentIndex = 0;
    let timeout: NodeJS.Timeout;

    const runPhase = () => {
      setAnimationPhase(phases[currentIndex].phase);
      timeout = setTimeout(() => {
        currentIndex = (currentIndex + 1) % phases.length;
        if (currentIndex === 0) {
          setCycleCount((c) => c + 1);
        }
        runPhase();
      }, phases[currentIndex].duration);
    };

    runPhase();

    return () => clearTimeout(timeout);
  }, []);

  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden pt-20">
      {/* Floating Orbs */}
      <div className="orb orb-blue w-96 h-96 -top-48 -left-48 animate-float-slow" />
      <div className="orb orb-sage w-72 h-72 top-1/4 -right-36 animate-float" />
      <div className="orb orb-orange w-64 h-64 bottom-1/4 left-1/4 animate-float-slower" />

      <div className="relative z-10 max-w-7xl mx-auto px-6 py-20">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-20 items-center">
          {/* Left Content */}
          <div className="text-center lg:text-left">
            {/* Badge */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ type: "spring", stiffness: 100, damping: 15 }}
              className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass-card mb-8"
            >
              <Sparkles className="w-4 h-4 text-forma-sage" />
              <span className="text-sm font-medium text-forma-bone/80">
                Preview-First Organization
              </span>
            </motion.div>

            {/* Headline */}
            <motion.h1
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ type: "spring", stiffness: 80, damping: 15, delay: 0.1 }}
              className="font-display font-bold text-5xl md:text-6xl lg:text-7xl leading-[1.1] mb-6"
            >
              Transform
              <br />
              <span className="gradient-text">Digital Chaos</span>
              <br />
              Into Clarity
            </motion.h1>

            {/* Trust Statement */}
            <motion.p
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ type: "spring", stiffness: 80, damping: 15, delay: 0.15 }}
              className="text-xl md:text-2xl font-display font-semibold text-forma-sage mb-4"
            >
              You approve. It executes.
            </motion.p>

            {/* Subheadline */}
            <motion.p
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ type: "spring", stiffness: 80, damping: 15, delay: 0.2 }}
              className="text-lg md:text-xl text-forma-bone/70 max-w-xl mx-auto lg:mx-0 mb-8"
            >
              Forma uses declarative rules you define to organize your files with
              your approval. Nothing moves without preview. Everything can be undone.
            </motion.p>

            {/* Time Comparison - NEW */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ type: "spring", stiffness: 100, damping: 15, delay: 0.25 }}
              className="flex items-center gap-4 justify-center lg:justify-start mb-10"
            >
              <div className="glass-card rounded-xl px-4 py-3 flex items-center gap-3">
                <Clock className="w-5 h-5 text-forma-bone/40" />
                <span className="text-forma-bone/50 line-through">2 hours</span>
                <motion.div
                  animate={{ x: [0, 5, 0] }}
                  transition={{ repeat: Infinity, duration: 1.5 }}
                  className="text-forma-sage"
                >
                  →
                </motion.div>
                <span className="text-forma-sage font-display font-bold text-xl">2 minutes</span>
              </div>
            </motion.div>

            {/* CTA Buttons */}
            <motion.div
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ type: "spring", stiffness: 100, damping: 15, delay: 0.3 }}
              className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start"
            >
              <motion.a
                href="#download"
                className="btn-primary text-forma-bone flex items-center justify-center gap-2 text-lg"
                whileHover={{ scale: 1.02, transition: { type: "spring", stiffness: 400, damping: 10 } }}
                whileTap={{ scale: 0.98 }}
              >
                <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
                </svg>
                Download for Mac
              </motion.a>
              <motion.a
                href="#features"
                className="btn-secondary text-forma-bone"
                whileHover={{ scale: 1.02, transition: { type: "spring", stiffness: 400, damping: 10 } }}
                whileTap={{ scale: 0.98 }}
              >
                See How It Works
              </motion.a>
            </motion.div>

            {/* Social Proof */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ type: "spring", stiffness: 100, damping: 20, delay: 0.5 }}
              className="mt-12 flex flex-col sm:flex-row items-center gap-6 justify-center lg:justify-start"
            >
              <div className="flex -space-x-3">
                {[1, 2, 3, 4, 5].map((i) => (
                  <div
                    key={i}
                    className="w-10 h-10 rounded-full bg-gradient-to-br from-forma-steel-blue/50 to-forma-sage/50 border-2 border-forma-obsidian flex items-center justify-center text-xs font-medium"
                  >
                    {String.fromCharCode(64 + i)}
                  </div>
                ))}
              </div>
              <div className="text-sm text-forma-bone/60">
                <span className="text-forma-bone font-semibold">2,000+</span>{" "}
                Mac users already organized
              </div>
            </motion.div>
          </div>

          {/* Right Content - Animated File Sorting Demo */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 40 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            transition={{ type: "spring", stiffness: 80, damping: 18, delay: 0.3 }}
            className="relative"
          >
            <div className="app-mockup-glow">
              {/* Demo Container */}
              <div className="glass-card-strong rounded-2xl overflow-hidden relative" style={{ minHeight: "400px" }}>
                {/* Phase Indicator */}
                <div className="absolute top-4 left-4 z-20">
                  <div className="glass-card rounded-full px-3 py-1.5 flex items-center gap-2">
                    <motion.div
                      animate={{
                        backgroundColor: animationPhase === "organized"
                          ? "rgb(122, 157, 126)"
                          : animationPhase === "scanning"
                            ? "rgb(91, 124, 153)"
                            : "rgb(201, 126, 102)",
                      }}
                      className="w-2 h-2 rounded-full"
                    />
                    <span className="text-xs font-medium text-forma-bone/70">
                      {animationPhase === "scattered" && "Messy Downloads folder"}
                      {animationPhase === "scanning" && "Matching patterns..."}
                      {animationPhase === "organizing" && "Organizing files..."}
                      {animationPhase === "organized" && "All organized!"}
                    </span>
                  </div>
                </div>

                {/* Scattered Files Phase */}
                <AnimatePresence mode="wait">
                  {(animationPhase === "scattered" || animationPhase === "scanning") && (
                    <motion.div
                      key={`scattered-${cycleCount}`}
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      className="absolute inset-0 flex items-center justify-center"
                    >
                      {/* Central chaos area */}
                      <div className="relative w-80 h-80">
                        {scatteredFiles.map((file, index) => (
                          <motion.div
                            key={file.id}
                            initial={{
                              x: file.x,
                              y: file.y,
                              rotate: Math.random() * 30 - 15,
                              scale: 0
                            }}
                            animate={{
                              x: file.x + (Math.random() * 10 - 5),
                              y: file.y + (Math.random() * 10 - 5),
                              rotate: Math.random() * 20 - 10,
                              scale: 1,
                            }}
                            transition={{
                              duration: 0.5,
                              delay: index * 0.1,
                              type: "spring",
                              stiffness: 200
                            }}
                            className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
                          >
                            <div className={`glass-card rounded-lg p-2 flex items-center gap-2 shadow-glass ${
                              animationPhase === "scanning" ? "animate-pulse" : ""
                            }`}>
                              <div className={`w-8 h-8 rounded-lg bg-forma-${file.color}/20 flex items-center justify-center`}>
                                <file.icon className={`w-4 h-4 text-forma-${file.color}`} />
                              </div>
                              <span className="text-xs text-forma-bone/70 max-w-[100px] truncate">
                                {file.name}
                              </span>
                            </div>

                            {/* Scanning Effect */}
                            {animationPhase === "scanning" && (
                              <motion.div
                                initial={{ opacity: 0, scale: 0.8 }}
                                animate={{ opacity: [0, 1, 0], scale: [0.8, 1.2, 0.8] }}
                                transition={{ duration: 1, repeat: Infinity, delay: index * 0.1 }}
                                className="absolute inset-0 rounded-lg border-2 border-forma-steel-blue/50"
                              />
                            )}
                          </motion.div>
                        ))}

                        {/* Scanning Line Effect */}
                        {animationPhase === "scanning" && (
                          <motion.div
                            initial={{ y: -150, opacity: 0 }}
                            animate={{ y: 150, opacity: [0, 1, 1, 0] }}
                            transition={{ duration: 1.5, repeat: Infinity }}
                            className="absolute left-0 right-0 h-1 bg-gradient-to-r from-transparent via-forma-steel-blue to-transparent"
                          />
                        )}
                      </div>
                    </motion.div>
                  )}

                  {/* Organizing/Organized Phase */}
                  {(animationPhase === "organizing" || animationPhase === "organized") && (
                    <motion.div
                      key={`organized-${cycleCount}`}
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      className="p-6 pt-14"
                    >
                      <div className="grid grid-cols-3 gap-3">
                        {organizedFolders.map((folder, folderIndex) => (
                          <motion.div
                            key={folder.name}
                            initial={{ opacity: 0, y: 20 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ delay: folderIndex * 0.1 }}
                            className="glass-card rounded-xl p-3"
                          >
                            <div className="flex items-center gap-2 mb-2">
                              <div className={`w-8 h-8 rounded-lg bg-forma-${folder.color}/20 flex items-center justify-center`}>
                                <FolderOpen className={`w-4 h-4 text-forma-${folder.color}`} />
                              </div>
                              <span className="text-sm font-medium text-forma-bone">{folder.name}</span>
                            </div>

                            {/* Files flying into folder */}
                            <div className="space-y-1">
                              {folder.files.map((fileId, fileIndex) => {
                                const file = scatteredFiles.find(f => f.id === fileId)!;
                                return (
                                  <motion.div
                                    key={fileId}
                                    initial={animationPhase === "organizing" ? {
                                      x: file.x - (folderIndex % 3) * 100,
                                      y: file.y - Math.floor(folderIndex / 3) * 100,
                                      opacity: 0,
                                      scale: 0.5
                                    } : { opacity: 1, x: 0, y: 0, scale: 1 }}
                                    animate={{
                                      x: 0,
                                      y: 0,
                                      opacity: 1,
                                      scale: 1
                                    }}
                                    transition={{
                                      duration: 0.6,
                                      delay: folderIndex * 0.15 + fileIndex * 0.1,
                                      type: "spring",
                                      stiffness: 100
                                    }}
                                    className="flex items-center gap-2 p-1.5 rounded-lg bg-white/5"
                                  >
                                    <file.icon className={`w-3 h-3 text-forma-${file.color}`} />
                                    <span className="text-xs text-forma-bone/60 truncate">
                                      {file.name}
                                    </span>
                                    {animationPhase === "organized" && (
                                      <motion.span
                                        initial={{ scale: 0 }}
                                        animate={{ scale: 1 }}
                                        transition={{ delay: 0.5 + fileIndex * 0.1 }}
                                        className="ml-auto text-forma-sage text-xs"
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

                      {/* Success Message */}
                      {animationPhase === "organized" && (
                        <motion.div
                          initial={{ opacity: 0, y: 10 }}
                          animate={{ opacity: 1, y: 0 }}
                          transition={{ delay: 0.8 }}
                          className="mt-4 text-center"
                        >
                          <div className="inline-flex items-center gap-2 glass-card rounded-full px-4 py-2">
                            <span className="text-forma-sage">✓</span>
                            <span className="text-sm text-forma-bone/70">
                              8 files organized into 6 folders
                            </span>
                          </div>
                        </motion.div>
                      )}
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </div>

            {/* Floating Rule Badge */}
            <motion.div
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ type: "spring", stiffness: 100, damping: 15, delay: 0.8 }}
              whileHover={{ scale: 1.05, transition: { type: "spring", stiffness: 400, damping: 10 } }}
              className="absolute -left-8 top-1/4 glass-card rounded-xl p-3 shadow-glass-lg"
            >
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-lg bg-forma-sage/20 flex items-center justify-center">
                  <Sparkles className="w-4 h-4 text-forma-sage" />
                </div>
                <div>
                  <div className="text-xs text-forma-bone/50">Rule Matched</div>
                  <div className="text-sm font-medium text-forma-bone">
                    Screenshots → Desktop
                  </div>
                </div>
              </div>
            </motion.div>

            {/* Stats Badge */}
            <motion.div
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ type: "spring", stiffness: 100, damping: 15, delay: 1 }}
              whileHover={{ scale: 1.05, transition: { type: "spring", stiffness: 400, damping: 10 } }}
              className="absolute -right-4 bottom-1/4 glass-card rounded-xl p-3 shadow-glass-lg"
            >
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-lg bg-forma-steel-blue/20 flex items-center justify-center text-forma-steel-blue font-bold text-sm">
                  ✓
                </div>
                <div>
                  <div className="text-xs text-forma-bone/50">Approved & moved</div>
                  <div className="text-sm font-medium text-forma-bone">
                    847 files this week
                  </div>
                </div>
              </div>
            </motion.div>
          </motion.div>
        </div>

        {/* Scroll Indicator */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ type: "spring", stiffness: 100, damping: 20, delay: 1.2 }}
          className="absolute bottom-8 left-1/2 -translate-x-1/2"
        >
          <motion.div
            animate={{ y: [0, 10, 0] }}
            transition={{ repeat: Infinity, duration: 2, type: "spring", stiffness: 100, damping: 10 }}
            className="flex flex-col items-center gap-2 text-forma-bone/40"
          >
            <span className="text-xs uppercase tracking-widest">Scroll</span>
            <ArrowDown className="w-4 h-4" />
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}
