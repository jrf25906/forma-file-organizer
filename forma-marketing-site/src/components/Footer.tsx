"use client";

import { useRef } from "react";
import { GridLogo } from "@/components/Header";
import { MagneticButton } from "@/components/animation/MagneticButton";

export function Footer() {
    return (
        <footer
            className="fixed bottom-0 left-0 right-0 h-[220px] bg-forma-obsidian text-forma-bone z-0 flex flex-col justify-between p-6"
            style={{
                zIndex: -1, // Sits behind the main content
            }}
        >
            <div className="max-w-7xl mx-auto w-full flex justify-between items-start">
                <div className="space-y-4">
                    <div className="flex items-center gap-2">
                        {/* Simple SVG Logo for footer contrast */}
                        <GridLogo size={32} className="text-forma-bone" />
                        <span className="font-display text-2xl">Forma</span>
                    </div>
                    <p className="text-forma-bone/60 max-w-xs text-sm">
                        Intelligent file organization for creative professionals who refuse chaos.
                    </p>
                </div>

                <div className="flex gap-12 text-sm">
                    <div className="space-y-4">
                        <h4 className="font-medium text-forma-bone/40 uppercase tracking-wider text-xs">Product</h4>
                        <ul className="space-y-2">
                            <li><a href="#" className="hover:text-forma-steel-blue transition-colors">Features</a></li>
                            <li><a href="#" className="hover:text-forma-steel-blue transition-colors">Roadmap</a></li>
                            <li><a href="#" className="hover:text-forma-steel-blue transition-colors">Changelog</a></li>
                        </ul>
                    </div>
                    <div className="space-y-4">
                        <h4 className="font-medium text-forma-bone/40 uppercase tracking-wider text-xs">Legal</h4>
                        <ul className="space-y-2">
                            <li><a href="#" className="hover:text-forma-steel-blue transition-colors">Privacy</a></li>
                            <li><a href="#" className="hover:text-forma-steel-blue transition-colors">Terms</a></li>
                        </ul>
                    </div>
                </div>
            </div>

            <div className="max-w-7xl mx-auto w-full flex justify-between items-end border-t border-forma-bone/10 pt-8">
                <span className="text-forma-bone/20 text-xs">
                    © {new Date().getFullYear()} Forma Inc.
                </span>
                <span className="text-forma-bone/20 text-xs font-mono">
                    macOS 14+
                </span>
            </div>
        </footer>
    );
}
