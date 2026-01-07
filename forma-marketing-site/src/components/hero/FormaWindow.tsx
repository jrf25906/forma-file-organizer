"use client";

import { Search, CheckCircle2, Sparkles } from "lucide-react";
import { Button } from "@/components/ui/Button";
import MacWindowFrame from "@/components/ui/MacWindowFrame";

// ═══════════════════════════════════════════════════════════════════════════
// FORMA WINDOW
// The main Forma app window UI that appears in the hero.
// Designed to faithfully represent the real app's design language.
// ═══════════════════════════════════════════════════════════════════════════

export type AnimationStatus = "idle" | "typing" | "processing" | "success";

interface FormaWindowProps {
    /** Current animation status */
    status: AnimationStatus;
    /** Currently displayed command text */
    commandText: string;
    /** Number of files ready to organize (updates during animation) */
    filesReady?: number;
    /** Additional className for the container */
    className?: string;
}

export default function FormaWindow({
    status,
    commandText,
    filesReady = 847,
    className = "",
}: FormaWindowProps) {
    const showResults = status === "processing" || status === "success";

    return (
        <div className={`w-full max-w-[800px] ${className}`}>
            <MacWindowFrame className="w-full shadow-[0_50px_100px_-20px_rgba(0,0,0,0.5)] border border-white/10 ring-1 ring-black/20">
                <div className="flex w-full min-h-[460px]">
                    {/* ─────────────────────────────────────────────────────── */}
                    {/* SIDEBAR - Glassmorphic, matches real Forma sidebar */}
                    {/* ─────────────────────────────────────────────────────── */}
                    <div className="w-[200px] bg-[#fbfbfb]/90 backdrop-blur-xl border-r border-black/[0.06] p-3 flex flex-col">
                        {/* Library Section */}
                        <div className="text-[10px] font-bold text-black/40 uppercase tracking-wider px-2 mb-2 mt-1">
                            Library
                        </div>

                        <div className="space-y-0.5">
                            {[
                                { name: "All Actions", active: true },
                                { name: "Automation", active: false },
                                { name: "Recently Organized", active: false },
                                { name: "Trash", active: false },
                            ].map((item) => (
                                <div
                                    key={item.name}
                                    className={`px-2 py-1.5 rounded-[6px] text-[12px] flex items-center gap-2.5 ${
                                        item.active
                                            ? "bg-black/[0.06] text-black font-medium"
                                            : "text-black/70 hover:bg-black/[0.03]"
                                    }`}
                                >
                                    <div
                                        className={`w-3.5 h-3.5 rounded ${
                                            item.active ? "bg-forma-steel-blue" : "bg-black/20"
                                        }`}
                                    />
                                    {item.name}
                                </div>
                            ))}
                        </div>

                        {/* Smart Rules Section */}
                        <div className="text-[10px] font-bold text-black/40 uppercase tracking-wider px-2 mb-2 mt-6">
                            Smart Rules
                        </div>

                        <div className="space-y-0.5">
                            {["Screenshots", "Work Docs", "Invoices"].map((item) => (
                                <div
                                    key={item}
                                    className="px-2 py-1.5 rounded-[6px] text-[12px] text-black/70 flex items-center gap-2.5 hover:bg-black/[0.03]"
                                >
                                    <div className="w-1.5 h-1.5 rounded-full bg-forma-sage/60" />
                                    {item}
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* ─────────────────────────────────────────────────────── */}
                    {/* MAIN CONTENT AREA */}
                    {/* ─────────────────────────────────────────────────────── */}
                    <div className="flex-1 bg-white flex flex-col">
                        {/* Search/Command Header */}
                        <div className="px-5 py-5 border-b border-black/[0.04]">
                            <div className="flex items-center gap-3">
                                {/* Status Icon */}
                                <div className="flex-shrink-0">
                                    {status === "processing" ? (
                                        <div className="w-4 h-4 border-[1.5px] border-forma-steel-blue/30 border-t-forma-steel-blue rounded-full animate-spin" />
                                    ) : status === "success" ? (
                                        <CheckCircle2 className="w-4 h-4 text-forma-sage animate-scale-in" />
                                    ) : (
                                        <Sparkles className="w-4 h-4 text-forma-steel-blue/60" />
                                    )}
                                </div>

                                {/* Command Input */}
                                <div className="flex-1 text-left flex items-center overflow-hidden">
                                    <span className="text-[17px] text-black font-medium tracking-tight truncate">
                                        {commandText}
                                    </span>
                                    {status === "typing" && (
                                        <div className="w-[1.5px] h-5 bg-forma-steel-blue ml-0.5 animate-pulse" />
                                    )}
                                    {status === "idle" && !commandText && (
                                        <span className="text-[17px] text-black/25 font-medium tracking-tight">
                                            Type a command to organize...
                                        </span>
                                    )}
                                </div>
                            </div>
                        </div>

                        {/* Results List */}
                        <div className="flex-1 p-3">
                            <div
                                className={`transition-all duration-700 space-y-1 ${
                                    showResults
                                        ? "opacity-100"
                                        : "opacity-0 translate-y-2"
                                }`}
                            >
                                <div className="text-[10px] font-bold text-black/30 uppercase tracking-wider px-2 mb-2">
                                    Proposed Actions
                                </div>

                                {/* Result Card - Mimics real FileRow design */}
                                <div className="bg-forma-steel-blue/[0.03] border border-forma-steel-blue/10 rounded-lg p-3 flex items-center justify-between shadow-sm group cursor-default hover:bg-forma-steel-blue/[0.06] transition-colors">
                                    <div className="flex items-center gap-3">
                                        {/* Thumbnail with category border hint */}
                                        <div className="w-10 h-10 rounded-[10px] bg-white flex items-center justify-center border border-black/[0.04] shadow-sm relative overflow-hidden">
                                            {/* Category color accent (left edge) */}
                                            <div className="absolute left-0 top-0 bottom-0 w-1 bg-forma-steel-blue" />
                                            <Search className="w-5 h-5 text-forma-steel-blue" />
                                        </div>
                                        <div className="text-left">
                                            <div className="text-[13px] font-semibold text-black leading-tight mb-0.5">
                                                Organize 12 Screenshots
                                            </div>
                                            <div className="text-[11px] text-black/50">
                                                Moving to{" "}
                                                <span className="text-black/70 font-medium bg-forma-steel-blue/10 px-1.5 py-0.5 rounded-full">
                                                    Archive/Screenshots
                                                </span>
                                            </div>
                                        </div>
                                    </div>
                                    <Button
                                        variant="primary"
                                        size="sm"
                                        className="h-7 rounded-md px-3 text-[11px] font-medium shadow-sm"
                                    >
                                        Run Action
                                    </Button>
                                </div>
                            </div>
                        </div>

                        {/* Footer Status Bar */}
                        <div className="h-9 border-t border-black/[0.04] px-4 flex items-center justify-between bg-[#fbfbfb]">
                            <span className="text-[10px] font-medium text-black/40 flex items-center gap-1.5">
                                <div className="w-1.5 h-1.5 rounded-full bg-forma-sage animate-pulse" />
                                Ready to organize {filesReady.toLocaleString()} files
                            </span>
                        </div>
                    </div>
                </div>
            </MacWindowFrame>
        </div>
    );
}
