"use client";

import { useMemo } from "react";

// ═══════════════════════════════════════════════════════════════════════════
// AURORA BACKGROUND
// A high-performance, GPU-accelerated CSS gradient mesh.
// Provides organic depth and movement without the overhead of WebGL.
// ═══════════════════════════════════════════════════════════════════════════

export default function AuroraBackground() {
  return (
    <div className="absolute inset-0 -z-10 overflow-hidden pointer-events-none bg-forma-bone">
      {/* Moving Gradient Orbs */}
      <div className="absolute inset-0 opacity-40 mix-blend-multiply">
        {/* Orb 1: Steel Blue */}
        <div 
          className="absolute top-[-10%] -left-[10%] w-[70%] h-[70%] rounded-full blur-[120px] animate-aurora-1"
          style={{ background: 'radial-gradient(circle, #5B7C99 0%, transparent 70%)' }}
        />
        
        {/* Orb 2: Sage */}
        <div 
          className="absolute bottom-[-10%] -right-[10%] w-[60%] h-[60%] rounded-full blur-[100px] animate-aurora-2"
          style={{ background: 'radial-gradient(circle, #7A9D7E 0%, transparent 70%)' }}
        />
        
        {/* Orb 3: Warm Orange (Accent) */}
        <div 
          className="absolute top-[20%] right-[10%] w-[40%] h-[40%] rounded-full blur-[80px] animate-aurora-3"
          style={{ background: 'radial-gradient(circle, #C97E66 0%, transparent 70%)' }}
        />
      </div>

      {/* Static noise overlay for texture (matches page noise) */}
      <div 
        className="absolute inset-0 opacity-[0.015] pointer-events-none"
        style={{
          backgroundImage: 'url(/noise.png)',
          backgroundRepeat: 'repeat',
        }}
      />

      {/* Vignette to focus attention */}
      <div className="absolute inset-0 shadow-[inset_0_0_150px_rgba(0,0,0,0.02)]" />
      
      <style jsx global>{`
        @keyframes aurora-1 {
          0%, 100% { transform: translate(0, 0) scale(1); }
          33% { transform: translate(10%, 5%) scale(1.1); }
          66% { transform: translate(-5%, 15%) scale(0.9); }
        }
        @keyframes aurora-2 {
          0%, 100% { transform: translate(0, 0) scale(1); }
          33% { transform: translate(-15%, -10%) scale(0.9); }
          66% { transform: translate(5%, -5%) scale(1.1); }
        }
        @keyframes aurora-3 {
          0%, 100% { transform: translate(0, 0) scale(1.2); }
          50% { transform: translate(-20%, 10%) scale(1); }
        }
        .animate-aurora-1 { animation: aurora-1 20s ease-in-out infinite; }
        .animate-aurora-2 { animation: aurora-2 25s ease-in-out infinite; }
        .animate-aurora-3 { animation: aurora-3 18s ease-in-out infinite; }
      `}</style>
    </div>
  );
}
