"use client";

import { cn } from "@/lib/utils";

interface AuroraBackgroundProps {
  /** Additional CSS classes for the container */
  className?: string;
  /** Whether animations are enabled (default true) */
  enabled?: boolean;
  /** Children rendered on top of the aurora */
  children?: React.ReactNode;
}

/**
 * AuroraBackground - GPU-accelerated gradient mesh background
 *
 * Renders three animated gradient orbs (Steel Blue, Sage, Warm Orange)
 * that drift with long animation cycles (20-25s). Uses mix-blend-multiply,
 * blur ranges from 80px to 120px, and a static noise overlay for texture.
 *
 * All animations use CSS transforms and opacity for GPU acceleration.
 * Automatically pauses in prefers-reduced-motion mode.
 *
 * @example
 * ```tsx
 * <AuroraBackground className="min-h-screen">
 *   <HeroSection />
 * </AuroraBackground>
 * ```
 */
export function AuroraBackground({
  className,
  enabled = true,
  children,
}: AuroraBackgroundProps) {
  return (
    <div className={cn("relative overflow-hidden", className)}>
      {/* Aurora orbs */}
      {enabled && (
        <div className="absolute inset-0 overflow-hidden" aria-hidden="true">
          {/* Steel Blue orb */}
          <div
            className={cn(
              "absolute rounded-full mix-blend-screen",
              "blur-[100px] opacity-70",
              "animate-float-slower"
            )}
            style={{
              width: "40%",
              height: "40%",
              top: "10%",
              left: "15%",
              background:
                "radial-gradient(circle, var(--forma-steel-blue) 0%, transparent 70%)",
              animationDuration: "20s",
              animationDelay: "0s",
            }}
          />

          {/* Sage orb */}
          <div
            className={cn(
              "absolute rounded-full mix-blend-screen",
              "blur-[120px] opacity-65",
              "animate-float-slower"
            )}
            style={{
              width: "45%",
              height: "45%",
              top: "30%",
              right: "10%",
              background:
                "radial-gradient(circle, var(--forma-sage) 0%, transparent 70%)",
              animationDuration: "25s",
              animationDelay: "-8s",
            }}
          />

          {/* Warm Orange orb */}
          <div
            className={cn(
              "absolute rounded-full mix-blend-screen",
              "blur-[80px] opacity-55",
              "animate-float-slower"
            )}
            style={{
              width: "35%",
              height: "35%",
              bottom: "15%",
              left: "30%",
              background:
                "radial-gradient(circle, var(--forma-warm-orange) 0%, transparent 70%)",
              animationDuration: "22s",
              animationDelay: "-4s",
            }}
          />

          {/* Static noise overlay for texture */}
          <div
            className="absolute inset-0 opacity-[0.03] pointer-events-none mix-blend-overlay"
            style={{
              backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
            }}
          />
        </div>
      )}

      {/* Content layer */}
      {children && <div className="relative z-10">{children}</div>}
    </div>
  );
}

export default AuroraBackground;
