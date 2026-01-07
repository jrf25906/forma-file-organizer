"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { gsap } from "@/lib/animation/gsap-config";
import { Button } from "@/components/ui/Button";
import { useReducedMotion } from "@/hooks/use-reduced-motion";
import { useMouseParallax, getParallaxTransform } from "@/hooks/useMouseParallax";
import MacbookProFrame from "@/components/ui/MacbookProFrame";
import ParallaxScene, { ParallaxLayer } from "./ParallaxScene";
import DesktopLayer, { FLYING_FILES, DesktopLayerRef } from "./DesktopLayer";
import FormaWindow, { AnimationStatus } from "./FormaWindow";

// ═══════════════════════════════════════════════════════════════════════════
// PRODUCT HERO (Raycast-Style 3D Parallax)
// High-fidelity device mockup with scattered desktop files that fly into
// folders when organized. Mouse-reactive parallax creates depth.
// ═══════════════════════════════════════════════════════════════════════════

type AnimationPhase = "idle" | "typing" | "processing" | "success" | "flying" | "complete";

export default function ProductHero() {
    const [commandText, setCommandText] = useState("");
    const [status, setStatus] = useState<AnimationStatus>("idle");
    const [phase, setPhase] = useState<AnimationPhase>("idle");
    const [filesReady, setFilesReady] = useState(847);

    const reducedMotion = useReducedMotion();
    const desktopLayerRef = useRef<DesktopLayerRef>(null);
    const timelineRef = useRef<gsap.core.Timeline | null>(null);

    // Parallax for different layers
    const windowParallax = useMouseParallax({ influence: 0.3, rotationInfluence: 3, smoothing: 0.08 });
    const desktopParallax = useMouseParallax({ influence: 0.15, rotationInfluence: 1, smoothing: 0.06 });

    const targetCommand = "Move screenshots older than a week to Archive";

    // ─────────────────────────────────────────────────────────────────────────
    // FILE FLIGHT ANIMATION
    // ─────────────────────────────────────────────────────────────────────────
    const animateFileFlight = useCallback(() => {
        const desktopLayer = desktopLayerRef.current;
        if (!desktopLayer) return;

        const fileElements = desktopLayer.getFileElements();
        const archiveElement = desktopLayer.getArchiveElement();

        if (!archiveElement) return;

        // Get archive folder position
        const archiveRect = archiveElement.getBoundingClientRect();
        const archiveCenterX = archiveRect.left + archiveRect.width / 2;
        const archiveCenterY = archiveRect.top + archiveRect.height / 2;

        // Animate each flying file
        FLYING_FILES.forEach((file, index) => {
            const fileEl = fileElements.get(file.id);
            if (!fileEl) return;

            const fileRect = fileEl.getBoundingClientRect();
            const fileCenterX = fileRect.left + fileRect.width / 2;
            const fileCenterY = fileRect.top + fileRect.height / 2;

            // Calculate delta for relative movement
            const deltaX = archiveCenterX - fileCenterX;
            const deltaY = archiveCenterY - fileCenterY;

            // Arc control point (above midpoint)
            const midX = deltaX / 2;
            const midY = Math.min(0, deltaY / 2) - 80; // Arc upward

            // Staggered delay with slight randomness
            const baseDelay = index * 0.12;
            const randomOffset = (Math.random() - 0.5) * 0.05;
            const delay = baseDelay + randomOffset;

            // Flight animation using keyframes for arc effect
            const duration = 0.8 + Math.random() * 0.2;

            gsap.to(fileEl, {
                keyframes: [
                    // Lift up phase (first 40% of animation)
                    {
                        x: midX * 0.5,
                        y: midY,
                        scale: 0.8,
                        rotation: file.rotation + 10,
                        duration: duration * 0.4,
                        ease: "power2.out",
                    },
                    // Fly to destination (remaining 60%)
                    {
                        x: deltaX,
                        y: deltaY,
                        scale: 0.3,
                        opacity: 0,
                        rotation: file.rotation + (Math.random() - 0.5) * 30,
                        duration: duration * 0.6,
                        ease: "power2.in",
                    },
                ],
                delay,
            });
        });

        // Folder receive pulse
        gsap.to(archiveElement, {
            scale: 1.15,
            duration: 0.3,
            delay: 0.5,
            ease: "power2.out",
            yoyo: true,
            repeat: 1,
        });
    }, []);

    // ─────────────────────────────────────────────────────────────────────────
    // RESET FILES TO ORIGINAL POSITIONS
    // ─────────────────────────────────────────────────────────────────────────
    const resetFiles = useCallback(() => {
        const desktopLayer = desktopLayerRef.current;
        if (!desktopLayer) return;

        const fileElements = desktopLayer.getFileElements();

        FLYING_FILES.forEach((file, index) => {
            const fileEl = fileElements.get(file.id);
            if (!fileEl) return;

            gsap.to(fileEl, {
                x: 0,
                y: 0,
                scale: 1,
                opacity: 1,
                rotation: file.rotation,
                duration: 0.4,
                delay: index * 0.05,
                ease: "power2.out",
            });
        });
    }, []);

    // ─────────────────────────────────────────────────────────────────────────
    // MAIN ANIMATION SEQUENCE
    // ─────────────────────────────────────────────────────────────────────────
    useEffect(() => {
        if (reducedMotion) {
            setCommandText(targetCommand);
            setStatus("success");
            setPhase("complete");
            return;
        }

        // Create master timeline
        const tl = gsap.timeline({
            delay: 1.5,
            onComplete: () => {
                // Pause, then reset and restart
                setTimeout(() => {
                    resetFiles();
                    setCommandText("");
                    setStatus("idle");
                    setPhase("idle");
                    setFilesReady(847);
                    setTimeout(() => {
                        tl.restart();
                    }, 500);
                }, 3000);
            },
        });

        timelineRef.current = tl;

        // Phase 1: Typing Animation
        tl.add("typing");
        tl.to(
            {},
            {
                duration: 2.2,
                onStart: () => {
                    setStatus("typing");
                    setPhase("typing");
                },
                onUpdate: function () {
                    const progress = this.progress();
                    const charCount = Math.floor(progress * targetCommand.length);
                    setCommandText(targetCommand.substring(0, charCount));
                },
            }
        );

        // Phase 2: Processing
        tl.add("processing");
        tl.to(
            {},
            {
                duration: 0.8,
                onStart: () => {
                    setStatus("processing");
                    setPhase("processing");
                },
            }
        );

        // Phase 3: Success
        tl.add("success");
        tl.to(
            {},
            {
                duration: 0.5,
                onStart: () => {
                    setStatus("success");
                    setPhase("success");
                },
            }
        );

        // Phase 4: File Flight
        tl.add("flying");
        tl.to(
            {},
            {
                duration: 1.5,
                onStart: () => {
                    setPhase("flying");
                    animateFileFlight();
                },
                onUpdate: function () {
                    // Update file count as files fly
                    const progress = this.progress();
                    const filesFlown = Math.floor(progress * 12);
                    setFilesReady(847 - filesFlown);
                },
            }
        );

        // Phase 5: Complete
        tl.add("complete");
        tl.to(
            {},
            {
                duration: 0.5,
                onStart: () => {
                    setPhase("complete");
                    setFilesReady(835);
                },
            }
        );

        return () => {
            tl.kill();
        };
    }, [reducedMotion, animateFileFlight, resetFiles]);

    return (
        <section className="relative pt-24 pb-8 md:pt-28 md:pb-12 px-6 overflow-hidden bg-forma-bone">
            {/* ─────────────────────────────────────────────────────────────── */}
            {/* BACKGROUND GRADIENTS */}
            {/* ─────────────────────────────────────────────────────────────── */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-full max-w-6xl pointer-events-none opacity-40">
                <div className="absolute top-[-10%] left-1/4 w-[600px] h-[600px] bg-forma-steel-blue/10 blur-[120px] rounded-full" />
                <div className="absolute top-[-5%] right-1/4 w-[500px] h-[500px] bg-forma-sage/10 blur-[100px] rounded-full" />
            </div>

            <div className="relative max-w-5xl mx-auto text-center z-10">
                {/* ─────────────────────────────────────────────────────────── */}
                {/* HEADLINE & CTA */}
                {/* ─────────────────────────────────────────────────────────── */}
                <h1 className="text-5xl md:text-7xl font-display text-forma-obsidian leading-[1.05] tracking-tight mb-6">
                    Chaos becomes <span className="italic">clarity.</span>
                </h1>

                <p className="text-lg md:text-xl text-forma-obsidian/85 max-w-xl mx-auto mb-10 leading-relaxed">
                    The macOS app that organizes your files automatically, so you never lose anything again.
                </p>

                <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-12">
                    <Button variant="primary" size="lg" className="px-8 shadow-xl shadow-forma-obsidian/10">
                        Download for Mac
                    </Button>
                    <Button variant="secondary" size="lg" className="px-8">
                        See how it works
                    </Button>
                </div>

                {/* ─────────────────────────────────────────────────────────── */}
                {/* 3D PARALLAX DEVICE MOCKUP */}
                {/* ─────────────────────────────────────────────────────────── */}
                <div className="relative mx-auto w-full max-w-5xl">
                    <ParallaxScene perspective={1200} className="w-full">
                        <div className="transform-gpu transition-all duration-700 ease-out">
                            <MacbookProFrame>
                                {/* Desktop Environment */}
                                <div
                                    className="relative w-full h-full overflow-hidden flex items-center justify-center"
                                    style={{
                                        background: `
                                            radial-gradient(ellipse 120% 80% at 20% 100%, #2D1B4E 0%, transparent 50%),
                                            radial-gradient(ellipse 100% 60% at 80% 90%, #1A3A4A 0%, transparent 45%),
                                            radial-gradient(ellipse 80% 50% at 60% 20%, #4A2D3D 0%, transparent 40%),
                                            radial-gradient(ellipse 60% 40% at 30% 30%, #2A4858 0%, transparent 35%),
                                            linear-gradient(160deg, #1A1A2E 0%, #0F0F1A 50%, #1A1A2E 100%)
                                        `,
                                    }}
                                >
                                    {/* Noise texture overlay */}
                                    <div
                                        className="absolute inset-0 opacity-[0.02]"
                                        style={{
                                            backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.8' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E")`,
                                        }}
                                    />

                                    {/* ─────────────────────────────────────────────── */}
                                    {/* MENU BAR */}
                                    {/* ─────────────────────────────────────────────── */}
                                    <div className="absolute top-0 left-0 right-0 h-7 bg-black/20 backdrop-blur-xl flex items-center px-4 justify-between z-20 border-b border-white/10 text-white/90 shadow-sm">
                                        <div className="flex gap-4 items-center">
                                            <span className="text-[14px] font-medium opacity-90 drop-shadow-sm"></span>
                                            <span className="font-bold text-[13px] tracking-wide opacity-90 drop-shadow-sm">
                                                Forma
                                            </span>
                                            <span className="text-[13px] font-medium hidden sm:inline opacity-80 drop-shadow-sm">
                                                File
                                            </span>
                                            <span className="text-[13px] font-medium hidden sm:inline opacity-80 drop-shadow-sm">
                                                Edit
                                            </span>
                                            <span className="text-[13px] font-medium hidden sm:inline opacity-80 drop-shadow-sm">
                                                View
                                            </span>
                                            <span className="text-[13px] font-medium hidden sm:inline opacity-80 drop-shadow-sm">
                                                Window
                                            </span>
                                        </div>
                                        <div className="flex gap-3.5 items-center">
                                            <div className="flex gap-3 mr-1 opacity-90">
                                                <div className="w-5 h-3 border border-white/50 rounded-[2px] relative">
                                                    <div className="absolute inset-[1px] bg-white/90 w-3/4" />
                                                    <div className="absolute -right-[3px] top-1/2 -translate-y-1/2 w-[2px] h-[3px] bg-white/50 rounded-r-[1px]" />
                                                </div>
                                            </div>
                                            <span className="text-[13px] font-medium tracking-tight opacity-90 drop-shadow-sm">
                                                Mon Jan 6
                                            </span>
                                            <span className="text-[13px] font-medium tracking-tight opacity-90 drop-shadow-sm">
                                                9:41 AM
                                            </span>
                                        </div>
                                    </div>

                                    {/* ─────────────────────────────────────────────── */}
                                    {/* DESKTOP FILES LAYER (with parallax) */}
                                    {/* ─────────────────────────────────────────────── */}
                                    <div
                                        className="absolute inset-0 mt-7"
                                        style={{
                                            transform: getParallaxTransform(desktopParallax.position, -50),
                                            transformStyle: "preserve-3d",
                                        }}
                                    >
                                        <DesktopLayer ref={desktopLayerRef} phase={phase} />
                                    </div>

                                    {/* ─────────────────────────────────────────────── */}
                                    {/* FORMA WINDOW (with parallax) */}
                                    {/* ─────────────────────────────────────────────── */}
                                    <div
                                        className="relative z-10 w-full max-w-[800px] px-6 mt-6"
                                        style={{
                                            transform: getParallaxTransform(windowParallax.position, 0),
                                            transformStyle: "preserve-3d",
                                        }}
                                    >
                                        <FormaWindow
                                            status={status}
                                            commandText={commandText}
                                            filesReady={filesReady}
                                        />
                                    </div>
                                </div>
                            </MacbookProFrame>
                        </div>
                    </ParallaxScene>
                </div>
            </div>
        </section>
    );
}
