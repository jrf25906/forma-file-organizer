"use client";

import { motion } from "framer-motion";
import { File, FolderOpen, ArrowRight, Undo2 } from "lucide-react";

// Each feature gets a unique mini-animation on hover
export function SmartRulesDemo() {
  return (
    <div className="relative h-12 w-full overflow-hidden">
      {/* File moving to folder */}
      <motion.div
        className="absolute left-2 top-1/2 -translate-y-1/2"
        initial={{ x: 0 }}
        animate={{ x: [0, 60, 60], opacity: [1, 1, 0] }}
        transition={{ duration: 1.5, repeat: Infinity, repeatDelay: 0.5 }}
      >
        <div className="w-6 h-7 rounded bg-forma-steel-blue/30 flex items-center justify-center">
          <File className="w-3 h-3 text-forma-steel-blue" />
        </div>
      </motion.div>

      <motion.div
        className="absolute left-12 top-1/2 -translate-y-1/2"
        initial={{ opacity: 0.3 }}
        animate={{ opacity: [0.3, 1, 0.3] }}
        transition={{ duration: 1.5, repeat: Infinity, repeatDelay: 0.5 }}
      >
        <ArrowRight className="w-4 h-4 text-forma-bone/40" />
      </motion.div>

      <motion.div
        className="absolute right-2 top-1/2 -translate-y-1/2"
        animate={{ scale: [1, 1.1, 1] }}
        transition={{ duration: 1.5, repeat: Infinity, repeatDelay: 0.5, times: [0, 0.6, 1] }}
      >
        <div className="w-8 h-8 rounded-lg bg-forma-sage/20 flex items-center justify-center">
          <FolderOpen className="w-4 h-4 text-forma-sage" />
        </div>
      </motion.div>
    </div>
  );
}

export function PatternMatchingDemo() {
  // Pattern matching visualization - files being categorized
  const patterns = [
    { ext: ".pdf", color: "bg-forma-steel-blue", x: 15 },
    { ext: ".jpg", color: "bg-forma-sage", x: 50 },
    { ext: ".pdf", color: "bg-forma-steel-blue", x: 85 },
  ];

  return (
    <div className="relative h-12 w-full overflow-hidden">
      {patterns.map((pattern, i) => (
        <motion.div
          key={i}
          className="absolute top-1/2 -translate-y-1/2"
          style={{ left: `${pattern.x}%`, transform: "translate(-50%, -50%)" }}
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: [0, 1, 1, 0], y: [-10, 0, 0, 10] }}
          transition={{
            duration: 2,
            repeat: Infinity,
            delay: i * 0.3,
          }}
        >
          <div className={`px-2 py-1 rounded ${pattern.color}/30 text-xs font-mono text-forma-bone/70`}>
            {pattern.ext}
          </div>
        </motion.div>
      ))}

      {/* Match indicator */}
      <motion.div
        className="absolute left-1/2 -translate-x-1/2 bottom-0"
        animate={{ opacity: [0, 1, 0] }}
        transition={{ duration: 2, repeat: Infinity, delay: 0.8 }}
      >
        <span className="text-xs text-forma-sage/60">matched</span>
      </motion.div>
    </div>
  );
}

export function StorageAnalyticsDemo() {
  const bars = [
    { height: 60, color: "bg-forma-steel-blue" },
    { height: 80, color: "bg-forma-sage" },
    { height: 45, color: "bg-forma-warm-orange" },
    { height: 90, color: "bg-forma-muted-blue" },
    { height: 70, color: "bg-forma-soft-green" },
  ];

  return (
    <div className="relative h-12 w-full flex items-end justify-center gap-1.5 px-4">
      {bars.map((bar, i) => (
        <motion.div
          key={i}
          className={`w-3 rounded-t ${bar.color}`}
          initial={{ height: 0 }}
          animate={{ height: `${bar.height}%` }}
          transition={{
            duration: 0.6,
            delay: i * 0.1,
            repeat: Infinity,
            repeatType: "reverse",
            repeatDelay: 1,
          }}
        />
      ))}
    </div>
  );
}

export function DuplicateDetectionDemo() {
  return (
    <div className="relative h-12 w-full overflow-hidden">
      {/* Two files merging into one */}
      <motion.div
        className="absolute left-4 top-1/2 -translate-y-1/2"
        animate={{ x: [0, 20], opacity: [1, 0] }}
        transition={{ duration: 1, repeat: Infinity, repeatDelay: 1 }}
      >
        <div className="w-6 h-7 rounded bg-forma-muted-blue/30 flex items-center justify-center">
          <File className="w-3 h-3 text-forma-muted-blue" />
        </div>
      </motion.div>

      <motion.div
        className="absolute right-4 top-1/2 -translate-y-1/2"
        animate={{ x: [0, -20], opacity: [1, 0] }}
        transition={{ duration: 1, repeat: Infinity, repeatDelay: 1 }}
      >
        <div className="w-6 h-7 rounded bg-forma-muted-blue/30 flex items-center justify-center">
          <File className="w-3 h-3 text-forma-muted-blue" />
        </div>
      </motion.div>

      {/* Merged file */}
      <motion.div
        className="absolute left-1/2 -translate-x-1/2 top-1/2 -translate-y-1/2"
        initial={{ scale: 0, opacity: 0 }}
        animate={{ scale: [0, 1.2, 1], opacity: [0, 1, 1, 0] }}
        transition={{ duration: 2, repeat: Infinity, times: [0, 0.4, 0.6, 1] }}
      >
        <div className="w-7 h-8 rounded bg-forma-sage/40 flex items-center justify-center">
          <File className="w-4 h-4 text-forma-sage" />
        </div>
      </motion.div>
    </div>
  );
}

export function InstantOrganizationDemo() {
  const files = [
    { delay: 0, startX: -30, startY: -10 },
    { delay: 0.15, startX: 30, startY: -15 },
    { delay: 0.3, startX: -20, startY: 10 },
  ];

  return (
    <div className="relative h-12 w-full overflow-hidden">
      {/* Central folder */}
      <div className="absolute left-1/2 -translate-x-1/2 top-1/2 -translate-y-1/2">
        <motion.div
          animate={{ scale: [1, 1.15, 1] }}
          transition={{ duration: 1.5, repeat: Infinity }}
          className="w-8 h-8 rounded-lg bg-forma-soft-green/20 flex items-center justify-center"
        >
          <FolderOpen className="w-4 h-4 text-forma-soft-green" />
        </motion.div>
      </div>

      {/* Flying files */}
      {files.map((file, i) => (
        <motion.div
          key={i}
          className="absolute left-1/2 top-1/2"
          initial={{ x: file.startX, y: file.startY, scale: 1, opacity: 1 }}
          animate={{
            x: [file.startX, 0],
            y: [file.startY, 0],
            scale: [1, 0],
            opacity: [1, 0],
          }}
          transition={{
            duration: 0.8,
            delay: file.delay,
            repeat: Infinity,
            repeatDelay: 0.7,
          }}
        >
          <div className="w-4 h-5 rounded bg-forma-bone/20 flex items-center justify-center">
            <File className="w-2 h-2 text-forma-bone/60" />
          </div>
        </motion.div>
      ))}
    </div>
  );
}

export function SafeReversibleDemo() {
  return (
    <div className="relative h-12 w-full flex items-center justify-center gap-3">
      {/* Shield with pulse */}
      <motion.div
        animate={{ scale: [1, 1.1, 1] }}
        transition={{ duration: 2, repeat: Infinity }}
        className="w-8 h-8 rounded-lg bg-forma-steel-blue/20 flex items-center justify-center"
      >
        <motion.div
          animate={{ rotate: [0, 0, -10, 10, 0] }}
          transition={{ duration: 2, repeat: Infinity, times: [0, 0.5, 0.6, 0.7, 1] }}
        >
          <Undo2 className="w-4 h-4 text-forma-steel-blue" />
        </motion.div>
      </motion.div>

      {/* Success checkmark appearing */}
      <motion.div
        initial={{ scale: 0, opacity: 0 }}
        animate={{ scale: [0, 1.2, 1], opacity: [0, 1, 1] }}
        transition={{ duration: 1, repeat: Infinity, repeatDelay: 1 }}
        className="text-forma-sage font-bold"
      >
        ✓
      </motion.div>
    </div>
  );
}

// Map feature titles to their demos
export const featureDemos: Record<string, React.FC> = {
  "Declarative Rule Builder": SmartRulesDemo,
  "Pattern Matching": PatternMatchingDemo,
  "Storage Analytics": StorageAnalyticsDemo,
  "Duplicate Detection": DuplicateDetectionDemo,
  "Instant Organization": InstantOrganizationDemo,
  "Safe & Reversible": SafeReversibleDemo,
};
