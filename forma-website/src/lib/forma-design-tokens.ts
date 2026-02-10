// ---------------------------------------------------------------------------
// Forma Design Tokens — shared types, category colors, and file data arrays
// Mirrors FormaColors.swift and FileTypeCategory.swift from the native app
// ---------------------------------------------------------------------------

export type FileCategory = "documents" | "images" | "videos" | "audio" | "archives";

export interface FormaFile {
  name: string;
  ext: string;
  category: FileCategory;
  age: string;         // e.g. "7d", "32d", "today"
  status: "ready" | "pending";
  destination?: string; // e.g. "Screenshots", "Documents"
}

// Category colors — from FileTypeCategory.swift → FormaColors.swift
export const categoryColors: Record<FileCategory, string> = {
  documents: "#6B8CA8",
  images:    "#C97E66",
  videos:    "#5B7C99",
  audio:     "#7A9D7E",
  archives:  "#8BA688",
};

// Card chrome tokens — from FormaColors.swift dark-mode values
export const cardTokens = {
  bg:            "#22252A",
  border:        "rgba(255,255,255,0.08)",
  railWidth:     2,
  statusReady:   "#7A9D7E",  // formaSage
  statusPending: "#FF9F0A",  // system orange (dark)
  labelPrimary:  "rgba(255,255,255,0.92)",
  labelSecondary:"rgba(255,255,255,0.55)",
  labelTertiary: "rgba(255,255,255,0.38)",
  pillBg:        "rgba(91,124,153,0.12)",  // steelBlue at light opacity
  pillBorder:    "rgba(91,124,153,0.20)",
  pillText:      "#5B7C99",
  font:          "-apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif",
};

// ---------------------------------------------------------------------------
// Hero files (8 cards, compact scale)
// ---------------------------------------------------------------------------
export const heroFiles: FormaFile[] = [
  { name: "Screenshot 2024-01-15.png",   ext: "PNG",  category: "images",    age: "7d",    status: "ready" },
  { name: "IMG_4829.HEIC",               ext: "HEIC", category: "images",    age: "3d",    status: "ready" },
  { name: "Document (3).pdf",            ext: "PDF",  category: "documents", age: "14d",   status: "ready" },
  { name: "final_v2_FINAL.docx",         ext: "DOCX", category: "documents", age: "32d",   status: "pending" },
  { name: "app_demo.mov",                ext: "MOV",  category: "videos",    age: "5d",    status: "ready" },
  { name: "podcast_ep12.mp3",            ext: "MP3",  category: "audio",     age: "1d",    status: "ready" },
  { name: "voice_memo.m4a",             ext: "M4A",  category: "audio",     age: "21d",   status: "pending" },
  { name: "tutorial.mp4",                ext: "MP4",  category: "videos",    age: "10d",   status: "ready" },
];

// ---------------------------------------------------------------------------
// Before/After files (6 cards, full scale with destination pills)
// ---------------------------------------------------------------------------
export const beforeAfterFiles: FormaFile[] = [
  { name: "Screenshot 2024-01-15 at 3.42.17 PM.png", ext: "PNG",  category: "images",    age: "7d",  status: "ready",   destination: "Screenshots" },
  { name: "IMG_4829.HEIC",                            ext: "HEIC", category: "images",    age: "3d",  status: "ready",   destination: "Screenshots" },
  { name: "Document (3).pdf",                          ext: "PDF",  category: "documents", age: "14d", status: "ready",   destination: "Documents" },
  { name: "final_FINAL_v2_actual_final.docx",          ext: "DOCX", category: "documents", age: "32d", status: "ready",   destination: "Documents" },
  { name: "Screen Recording 2024-02-01.mov",           ext: "MOV",  category: "videos",    age: "5d",  status: "ready",   destination: "Videos" },
  { name: "tutorial_export.mp4",                        ext: "MP4",  category: "videos",    age: "1d",  status: "pending", destination: "Videos" },
];

// Folder groupings for the before/after organized state
export const folderGroups = [
  { name: "Screenshots/", category: "images"    as FileCategory, fileCount: 2 },
  { name: "Documents/",   category: "documents" as FileCategory, fileCount: 2 },
  { name: "Videos/",      category: "videos"    as FileCategory, fileCount: 2 },
];
