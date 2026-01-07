"use client";

import { ReactNode } from "react";

// ═══════════════════════════════════════════════════════════════════════════
// MACBOOK PRO FRAME
// CSS-only MacBook Pro 14" Frame
// ═══════════════════════════════════════════════════════════════════════════

interface MacbookProFrameProps {
  children: ReactNode;
  className?: string;
}

export default function MacbookProFrame({ children, className = "" }: MacbookProFrameProps) {
  return (
    <div className={`relative mx-auto ${className}`}>
      {/* Lid (Screen Bezel) */}
      <div 
        className="relative bg-[#0d0d0d] rounded-[20px] p-[12px] shadow-2xl ring-1 ring-white/10"
        style={{
          boxShadow: `
            0 0 0 1px rgba(255,255,255,0.1),
            0 20px 50px -12px rgba(0,0,0,0.5),
            0 0 0 1px #000
          `
        }}
      >
        {/* Camera Notch */}
        <div className="absolute top-[12px] left-1/2 -translate-x-1/2 w-[120px] h-[18px] bg-[#0d0d0d] rounded-b-[10px] z-20 flex justify-center">
            {/* Camera Lens */}
            <div className="w-2 h-2 rounded-full bg-[#1a1a1a] mt-1.5 flex items-center justify-center">
                <div className="w-1 h-1 rounded-full bg-[#0a0a2a] opacity-80 shadow-[inset_0_0_2px_rgba(255,255,255,0.2)]" />
            </div>
        </div>

        {/* Screen Content Area */}
        <div className="relative bg-black rounded-[10px] overflow-hidden aspect-[16/10] w-full">
          {children}
        </div>
      </div>

      {/* Base (Bottom Case - Top Edge) */}
      <div className="relative h-[14px] bg-[#e3e3e3] rounded-b-[16px] mx-[2%] shadow-[inset_0_2px_4px_rgba(0,0,0,0.3)] flex justify-center">
         {/* Thumb Scoop */}
         <div className="w-[120px] h-[6px] bg-[#d1d1d1] rounded-b-[8px] opacity-60 mt-0.5" />
      </div>
    </div>
  );
}
