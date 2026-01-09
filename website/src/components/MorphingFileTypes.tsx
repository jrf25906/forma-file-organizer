"use client";

import { motion, AnimatePresence } from "framer-motion";
import {
  FileImage,
  FileCode,
  FileXls,
  FileText,
  FileVideo,
  FileAudio,
  File,
  FileZip,
} from "@phosphor-icons/react";
import { useMemo } from "react";

interface MorphingFileTypesProps {
  fileTypes: string[];
  color: string;
  personaKey: string;
}

// Map file extensions to appropriate icons
const fileIconMap: Record<string, React.ComponentType<{ className?: string }>> = {
  // Design
  figma: FileImage,
  sketch: FileImage,
  psd: FileImage,
  ai: FileImage,
  // Development
  json: FileCode,
  sql: FileCode,
  log: FileText,
  zip: FileZip,
  // Photography
  raw: FileImage,
  cr3: FileImage,
  nef: FileImage,
  dng: FileImage,
  // Documents
  pdf: FileText,
  docx: FileText,
  xlsx: FileXls,
  csv: FileXls,
  pptx: FileText,
  bib: FileText,
  md: FileCode,
  txt: FileText,
  // Media
  mp4: FileVideo,
  mov: FileVideo,
  wav: FileAudio,
  mp3: FileAudio,
  png: FileImage,
  jpg: FileImage,
};

const getFileIcon = (type: string) => {
  const normalizedType = type.toLowerCase();
  return fileIconMap[normalizedType] || File;
};

// Color variants for different file types
const getTypeColor = (type: string): string => {
  const normalizedType = type.toLowerCase();
  if (["figma", "sketch", "psd", "ai", "raw", "cr3", "nef", "dng", "png", "jpg"].includes(normalizedType)) {
    return "forma-warm-orange";
  }
  if (["json", "sql", "log", "md", "code"].includes(normalizedType)) {
    return "forma-steel-blue";
  }
  if (["mp4", "mov", "wav", "mp3"].includes(normalizedType)) {
    return "forma-muted-blue";
  }
  if (["xlsx", "csv"].includes(normalizedType)) {
    return "forma-sage";
  }
  return "forma-bone";
};

export default function MorphingFileTypes({
  fileTypes,
  color,
  personaKey,
}: MorphingFileTypesProps) {
  // Create unique keys for each file type to enable proper animations
  const items = useMemo(
    () =>
      fileTypes.map((type, index) => ({
        type,
        key: `${personaKey}-${type}-${index}`,
        Icon: getFileIcon(type),
        color: getTypeColor(type),
      })),
    [fileTypes, personaKey]
  );

  return (
    <div className="flex flex-wrap gap-2 min-h-[36px]">
      <AnimatePresence mode="popLayout">
        {items.map((item, index) => (
          <motion.div
            key={item.key}
            layoutId={`filetype-${index}`}
            initial={{ opacity: 0, scale: 0.5, y: 10, rotate: -10 }}
            animate={{
              opacity: 1,
              scale: 1,
              y: 0,
              rotate: 0,
              transition: {
                delay: index * 0.08,
                type: "spring",
                stiffness: 400,
                damping: 20,
              },
            }}
            exit={{
              opacity: 0,
              scale: 0.3,
              y: -10,
              rotate: 10,
              transition: {
                duration: 0.2,
                delay: index * 0.03,
              },
            }}
            whileHover={{
              scale: 1.1,
              y: -2,
              transition: { duration: 0.2 },
            }}
            className="group relative"
          >
            <div
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white/5 border border-white/10
                hover:bg-white/10 hover:border-forma-${color}/30 transition-colors cursor-default`}
            >
              {/* Animated icon */}
              <motion.div
                initial={{ rotate: -180, scale: 0 }}
                animate={{ rotate: 0, scale: 1 }}
                transition={{
                  delay: 0.1 + index * 0.08,
                  type: "spring",
                  stiffness: 300,
                }}
              >
                <item.Icon className={`w-3 h-3 text-${item.color}/70 group-hover:text-${item.color}`} />
              </motion.div>

              {/* Extension text with morphing effect */}
              <motion.span
                className="text-xs text-forma-bone/60 font-medium group-hover:text-forma-bone/90"
                initial={{ opacity: 0, x: -5 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.15 + index * 0.08 }}
              >
                .{item.type.toLowerCase()}
              </motion.span>
            </div>

            {/* Glow effect on hover */}
            <motion.div
              className={`absolute inset-0 rounded-full bg-forma-${color}/20 blur-md -z-10`}
              initial={{ opacity: 0, scale: 0.8 }}
              whileHover={{ opacity: 1, scale: 1.2 }}
            />
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
