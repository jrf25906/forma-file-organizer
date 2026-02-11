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
 * - 52px unified toolbar
 * - Traffic lights: red (#FF5F57), yellow (#FEBC2E), green (#28C840)
 * - "Forma" title centered in the toolbar
 * - 12px rounded corners with layered theme-aware shadow
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
        "relative overflow-hidden rounded-[12px] bg-[var(--mac-window-shell-bg)] shadow-2xl transition-all duration-500",
        className
      )}
      style={{
        boxShadow: `
          0 0 0 0.5px var(--mac-window-outline),
          0 2px 4px var(--mac-window-shadow-near),
          0 12px 24px var(--mac-window-shadow-mid),
          0 32px 64px -12px var(--mac-window-shadow-far)
        `,
      }}
    >
      {/* macOS Sequoia style Unified Toolbar */}
      <div className="flex h-[52px] w-full select-none items-center border-b border-[var(--mac-window-toolbar-border)] bg-[var(--mac-window-toolbar-bg)] px-[16px]">
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
            <div className="h-5 w-5 rounded-md bg-[var(--mac-window-control-muted)]" />
            <div className="h-5 w-5 rounded-md bg-[var(--mac-window-control-muted)]" />
          </div>

          {/* Window Title */}
          <div className="text-[13px] font-medium tracking-tight text-[var(--mac-window-title)]">
            {title}
          </div>

          {/* Right toolbar icons (decorative) */}
          <div className="flex items-center space-x-4">
            <div className="h-5 w-5 rounded-md bg-[var(--mac-window-control-muted)]" />
            <div className="h-5 w-12 rounded-md bg-[var(--mac-window-control-muted)]" />
          </div>
        </div>
      </div>

      {/* Window Content */}
      <div className="relative">
        {children}
      </div>
    </div>
  );
}
