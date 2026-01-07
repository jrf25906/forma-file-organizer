"use client";

import { useRef, useCallback, useEffect } from "react";
import { gsap } from "@/lib/animation/gsap-config";
import { formaMagnetic, formaReveal, formaDuration } from "@/lib/animation/ease-curves";
import { useReducedMotion } from "@/hooks/use-reduced-motion";
import { cn } from "@/lib/utils";

interface InteractiveCardProps extends React.HTMLAttributes<HTMLDivElement> {
    /** Maximum rotation angle in degrees (default 10) */
    maxRotation?: number;
    /** Scale on hover (default 1.02) */
    scale?: number;
    /** Color of the glow effect */
    glowColor?: string;
}

export function InteractiveCard({
    children,
    className,
    maxRotation = 10,
    scale = 1.02,
    glowColor = "rgba(255, 255, 255, 0.1)",
    ...props
}: InteractiveCardProps) {
    const cardRef = useRef<HTMLDivElement>(null);
    const glowRef = useRef<HTMLDivElement>(null);
    const reducedMotion = useReducedMotion();

    // GSAP Context cleanup
    useEffect(() => {
        return () => {
            gsap.killTweensOf([cardRef.current, glowRef.current]);
        };
    }, []);

    const handleMouseMove = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
        const card = cardRef.current;
        const glow = glowRef.current;
        if (!card || !glow || reducedMotion) return;

        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        // Calculate normalized position (-1 to 1) for tilt
        const normalizedX = (x / rect.width) * 2 - 1;
        const normalizedY = (y / rect.height) * 2 - 1;

        // Calculate rotation
        const rotateX = -normalizedY * maxRotation;
        const rotateY = normalizedX * maxRotation;

        // Animate Tilt
        gsap.to(card, {
            rotateX,
            rotateY,
            scale: scale,
            duration: formaDuration.normal * 0.5,
            ease: formaMagnetic,
            overwrite: "auto",
        });

        // Animate Glow Position (Synchronized with Tilt)
        // We use a radial gradient, so we update the position
        gsap.to(glow, {
            opacity: 1,
            background: `radial-gradient(600px circle at ${x}px ${y}px, ${glowColor}, transparent 40%)`,
            duration: formaDuration.normal * 0.5,
            ease: formaMagnetic,
            overwrite: "auto",
        });

    }, [maxRotation, scale, glowColor, reducedMotion]);

    const handleMouseLeave = useCallback(() => {
        const card = cardRef.current;
        const glow = glowRef.current;
        if (!card || !glow) return;

        // Reset Tilt
        gsap.to(card, {
            rotateX: 0,
            rotateY: 0,
            scale: 1,
            duration: formaDuration.normal,
            ease: formaReveal,
            overwrite: "auto",
        });

        // Fade out Glow
        gsap.to(glow, {
            opacity: 0,
            duration: formaDuration.normal,
            ease: formaReveal,
            overwrite: "auto",
        });
    }, []);

    const handleMouseEnter = useCallback(() => {
        // Prepare for 3D
        if (cardRef.current && !reducedMotion) {
            gsap.set(cardRef.current, {
                transformPerspective: 1000,
                transformStyle: "preserve-3d",
            });
        }
    }, [reducedMotion]);

    return (
        <div
            className={cn(
                "relative",
                !reducedMotion && "[perspective:1000px]",
                className
            )}
            onMouseMove={handleMouseMove}
            onMouseLeave={handleMouseLeave}
            onMouseEnter={handleMouseEnter}
            {...props}
        >
            {/* Card Surface (Tilts) */}
            <div
                ref={cardRef}
                className={cn(
                    "relative rounded-3xl w-full h-full",
                    !reducedMotion && "will-change-transform" // Hint to browser
                )}
            >
                {/* Content - Relative & In Flow */}
                <div className="relative z-10 h-full">{children}</div>

                {/* Background & Glow Container - Absolute Overlay */}
                <div className="absolute inset-0 rounded-3xl overflow-hidden pointer-events-none z-20">
                    {/* Glow Layer */}
                    <div
                        ref={glowRef}
                        className="absolute inset-0 opacity-0 will-change-[background,opacity]"
                        style={{
                            background: `radial-gradient(600px circle at 50% 50%, ${glowColor}, transparent 40%)`,
                        }}
                    />
                </div>
            </div>
        </div>
    );
}
