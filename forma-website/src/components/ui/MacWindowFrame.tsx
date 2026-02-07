"use client";

import { type ReactNode } from "react";
import { cn } from "@/lib/utils";

interface MacWindowFrameProps {
  /** Content rendered inside the window body */
  children: ReactNode;
  /** Additional CSS classes for the outer container */
  className?: string;
  /** Whether the window appears active (affects traffic light vibrancy) */
  active?: boolean;
  /** Custom title text in the toolbar center (default "Forma") */
  title?: string;
}

/**
 * MacWindowFrame - macOS Sequoia-style window chrome
 *
 * Renders a realistic macOS window with:
 * - 52px unified toolbar with #f6f6f6 background
 * - Traffic lights: red (#FF5F57), yellow (#FEBC2E), green (#28C840)
 * - "Forma" title centered in the toolbar
 * - 12px rounded corners with layered shadow
 * - Children rendered as the main content area
 *
 * @example
 * ```tsx
 * <MacWindowFrame>
 *   <div className="p-6">Window content here</div>
 * </MacWindowFrame>
 *
 * <MacWindowFrame title="Settings" active={false}>
 *   <SettingsPanel />
 * </MacWindowFrame>
 * ```
 */
export default function MacWindowFrame({
  children,
  className = "",
  active = true,
  title = "Forma",
}: MacWindowFrameProps) {
  return (
    <div
      className={cn(
        "relative rounded-[12px] overflow-hidden bg-[#ffffff] shadow-2xl transition-all duration-500",
        className
      )}
      style={{
        boxShadow: `
          0 0 0 0.5px rgba(0,0,0,0.15),
          0 2px 4px rgba(0,0,0,0.05),
          0 12px 24px rgba(0,0,0,0.05),
          0 32px 64px -12px rgba(0,0,0,0.2)
        `,
      }}
    >
      {/* macOS Sequoia style Unified Toolbar */}
      <div className="h-[52px] bg-[#f6f6f6] border-b border-[#e5e5e5] flex items-center px-[16px] w-full select-none">
        {/* Traffic Lights */}
        <div className="flex space-x-[8px] mr-4">
          <div
            className={cn(
              "w-[12px] h-[12px] rounded-full border-[0.5px]",
              active
                ? "bg-[#FF5F57] border-[#e1483f]"
                : "bg-[#FF5F57]/40 border-[#e1483f]/40"
            )}
          />
          <div
            className={cn(
              "w-[12px] h-[12px] rounded-full border-[0.5px]",
              active
                ? "bg-[#FEBC2E] border-[#d89e24]"
                : "bg-[#FEBC2E]/40 border-[#d89e24]/40"
            )}
          />
          <div
            className={cn(
              "w-[12px] h-[12px] rounded-full border-[0.5px]",
              active
                ? "bg-[#28C840] border-[#20a032]"
                : "bg-[#28C840]/40 border-[#20a032]/40"
            )}
          />
        </div>

        {/* Toolbar Layout */}
        <div className="flex-1 flex items-center justify-between">
          {/* Left toolbar icons (decorative) */}
          <div className="flex items-center space-x-4">
            <div className="w-5 h-5 rounded-md bg-black/[0.05]" />
            <div className="w-5 h-5 rounded-md bg-black/[0.05]" />
          </div>

          {/* Window Title */}
          <div className="text-[13px] font-medium text-black/[0.7] tracking-tight">
            {title}
          </div>

          {/* Right toolbar icons (decorative) */}
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
