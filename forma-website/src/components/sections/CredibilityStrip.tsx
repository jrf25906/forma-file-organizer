"use client";

import { Monitor, Shield, RotateCcw } from "lucide-react";
import { ScrollReveal } from "@/components/animation/ScrollReveal";

export default function CredibilityStrip() {
  return (
    <section
      id="credibility"
      className="py-6 md:py-8"
      aria-label="Why trust Forma"
    >
      <div className="site-container">
        <ScrollReveal direction="up" distance={16} once>
          <div className="flex flex-wrap items-center justify-center gap-x-8 gap-y-3 text-sm text-[var(--text-secondary)]">
            <span className="flex items-center gap-2">
              <Monitor size={15} className="text-[var(--accent-steel-blue)]" />
              Native Swift app
            </span>
            <span className="hidden sm:inline text-white/20" aria-hidden="true">
              &middot;
            </span>
            <span className="flex items-center gap-2">
              <Shield size={15} className="text-[var(--accent-steel-blue)]" />
              Files never leave your Mac
            </span>
            <span className="hidden sm:inline text-white/20" aria-hidden="true">
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
