"use client";

import { Monitor, Shield, RotateCcw } from "lucide-react";
import { ScrollReveal } from "@/components/animation/ScrollReveal";

export default function CredibilityStrip() {
  return (
    <section
      id="credibility"
      className="py-4 md:py-8"
      aria-label="Why trust Forma"
    >
      <div className="site-container">
        <ScrollReveal direction="up" distance={16} once>
          <div className="flex flex-wrap items-center justify-center gap-x-7 gap-y-2.5 text-[13px] text-[var(--text-secondary)] md:text-sm">
            <span className="flex items-center gap-2">
              <Monitor size={15} className="text-[var(--accent-steel-blue)]" />
              Built natively for macOS
            </span>
            <span className="hidden sm:inline text-[var(--divider-color)]" aria-hidden="true">
              &middot;
            </span>
            <span className="flex items-center gap-2">
              <Shield size={15} className="text-[var(--accent-steel-blue)]" />
              Files never leave your Mac
            </span>
            <span className="hidden sm:inline text-[var(--divider-color)]" aria-hidden="true">
              &middot;
            </span>
            <span className="flex items-center gap-2">
              <RotateCcw size={15} className="text-[var(--accent-steel-blue)]" />
              Undo everything
            </span>
          </div>
        </ScrollReveal>
      </div>
    </section>
  );
}
