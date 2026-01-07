"use client";

import { ReactNode } from "react";

interface MacWindowFrameProps {
  children: ReactNode;
  className?: string;
  active?: boolean;
}

export default function MacWindowFrame({ children, className = "", active = true }: MacWindowFrameProps) {
  return (
    <div 
      className={`relative rounded-[12px] overflow-hidden bg-[#ffffff] shadow-2xl transition-all duration-500 ${className}`}
      style={{
        boxShadow: `
          0 0 0 0.5px rgba(0,0,0,0.15), 
          0 2px 4px rgba(0,0,0,0.05),
          0 12px 24px rgba(0,0,0,0.05),
          0 32px 64px -12px rgba(0,0,0,0.2)
        `
      }}
    >
      {/* macOS Sequoia style Unified Toolbar */}
      <div className="h-[52px] bg-[#f6f6f6] border-b border-[#e5e5e5] flex items-center px-[16px] w-full select-none">
        {/* Traffic Lights */}
        <div className="flex space-x-[8px] mr-4">
          <div className="w-[12px] h-[12px] rounded-full bg-[#FF5F57] border-[0.5px] border-[#e1483f]" />
          <div className="w-[12px] h-[12px] rounded-full bg-[#FEBC2E] border-[0.5px] border-[#d89e24]" />
          <div className="w-[12px] h-[12px] rounded-full bg-[#28C840] border-[0.5px] border-[#20a032]" />
        </div>
        
        {/* Toolbar Icons (Visual Polish) */}
        <div className="flex-1 flex items-center justify-between">
            <div className="flex items-center space-x-4">
                <div className="w-5 h-5 rounded-md bg-black/[0.05]" />
                <div className="w-5 h-5 rounded-md bg-black/[0.05]" />
            </div>
            <div className="text-[13px] font-medium text-black/[0.7] tracking-tight">Forma</div>
            <div className="flex items-center space-x-4">
                <div className="w-5 h-5 rounded-md bg-black/[0.05]" />
                <div className="w-12 h-5 rounded-md bg-black/[0.05]" />
            </div>
        </div>
      </div>

      {/* Window Content */}
      <div className="relative flex min-h-[400px]">
        {children}
      </div>
    </div>
  );
}