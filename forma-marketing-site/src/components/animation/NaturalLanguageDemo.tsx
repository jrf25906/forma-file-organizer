"use client";

import React, { useRef } from "react";
import { Image, Folder, ChevronRight, Check } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation/gsap-config";
import {
    formaMagnetic,
    formaExit,
    formaSettle,
    formaSnap
} from "@/lib/animation/ease-curves";
import LottieAnimation from "@/components/animation/LottieAnimation";

// Placeholder path - user will need to add this file
const LOTTIE_PATH = "/animations/natural-language-demo.json";

interface NaturalLanguageDemoProps {
    reducedMotion?: boolean;
    useLottie?: boolean;
    className?: string;
    accent?: string; // Supporting the prop mentioned in user request
}

export default function NaturalLanguageDemo({
    reducedMotion = false,
    useLottie = false,
    className = "",
    accent
}: NaturalLanguageDemoProps) {
    const containerRef = useRef<HTMLDivElement>(null);

    // Refs for GSAP
    const card1Ref = useRef<HTMLDivElement>(null);
    const card2Ref = useRef<HTMLDivElement>(null);
    const folderRef = useRef<HTMLDivElement>(null);
    const badgeRef = useRef<HTMLDivElement>(null);
    const destinationGlowRef = useRef<HTMLDivElement>(null);

    // --- GSAP Implementation ---
    useGSAP(() => {
        if (useLottie || reducedMotion) return;

        const tl = gsap.timeline({
            repeat: -1,
            repeatDelay: 2,
            defaults: { ease: "power2.out" }
        });

        // Initial State
        tl.set(card1Ref.current, { x: -80, y: 0, scale: 1, opacity: 1, zIndex: 2 })
            .set(card2Ref.current, { x: -60, y: 10, scale: 0.95, opacity: 0.9, zIndex: 1 })
            .set(folderRef.current, { scale: 1, opacity: 1 })
            .set(badgeRef.current, { scale: 0, opacity: 0 })
            .set(destinationGlowRef.current, { opacity: 0 });

        // Phase 1: Anticipation
        tl.to([card1Ref.current, card2Ref.current], {
            x: "-=10",
            duration: 0.1,
            ease: formaMagnetic
        });

        // Phase 2: Slide to Archive
        tl.to(card1Ref.current, {
            x: 100,
            scale: 0.2,
            opacity: 0,
            duration: 0.35,
            ease: formaExit
        }, ">");

        tl.to(card2Ref.current, {
            x: 100,
            scale: 0.2,
            opacity: 0,
            duration: 0.35,
            ease: formaExit
        }, "<0.05");

        tl.to(destinationGlowRef.current, {
            opacity: 0.6,
            duration: 0.2,
            yoyo: true,
            repeat: 1
        }, "<0.2");

        // Phase 3: Folder Reveal
        tl.to(folderRef.current, {
            scale: 1.1,
            duration: 0.1,
            ease: "power2.out"
        }, "-=0.1")
            .to(folderRef.current, {
                scale: 1,
                duration: 0.2,
                ease: formaSettle
            });

        // Phase 4: Badge Pop
        tl.to(badgeRef.current, {
            scale: 1,
            opacity: 1,
            duration: 0.3,
            ease: formaSnap
        }, "-=0.1");

        tl.to(destinationGlowRef.current, {
            opacity: 0,
            duration: 0.5
        }, "<");

    }, { scope: containerRef, dependencies: [reducedMotion, useLottie] });

    // --- Render Lottie ---
    if (useLottie) {
        return (
            <div className={`relative w-full h-full ${className}`}>
                <LottieAnimation
                    animationPath={LOTTIE_PATH}
                    loop={true}
                    autoplay={!reducedMotion}
                    ariaLabel="Natural Language Processing Demo"
                />
            </div>
        );
    }

    // --- Render GSAP ---
    return (
        <div
            ref={containerRef}
            className={`relative flex items-center justify-center w-[500px] h-[300px] bg-neutral-900 rounded-3xl overflow-hidden border border-white/5 ${className}`}
        >
            <div className="absolute inset-0 bg-gradient-to-tr from-forma-steel-blue/5 to-transparent pointer-events-none" />

            {/* Files */}
            <div className="absolute" style={{ left: "30%", top: "50%", transform: "translate(-50%, -50%)" }}>
                <FileCard ref={card2Ref} name="Screenshot 2...png" color="rgba(255,255,255,0.1)" />
                <FileCard ref={card1Ref} name="Screenshot 1...png" color="rgba(255,255,255,0.1)" />
            </div>

            {/* Folder */}
            <div className="absolute" style={{ left: "70%", top: "50%", transform: "translate(-50%, -50%)" }}>
                <div
                    ref={destinationGlowRef}
                    className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-24 h-24 bg-forma-steel-blue/40 blur-2xl rounded-full"
                    style={{ opacity: 0 }}
                />
                <div ref={folderRef} className="relative z-10">
                    <Folder className="w-16 h-16 text-forma-steel-blue fill-forma-steel-blue/20" strokeWidth={1.5} />
                </div>
                <div
                    ref={badgeRef}
                    className="absolute -top-2 -right-2 bg-forma-sage text-forma-bone text-[10px] font-bold px-2 py-0.5 rounded-full shadow-lg z-20 flex items-center gap-1"
                    style={{ opacity: 0 }}
                >
                    <span>2</span>
                </div>
            </div>
        </div>
    );
}

const FileCard = React.forwardRef<HTMLDivElement, { name: string; color: string }>(({ name, color }, ref) => {
    return (
        <div
            ref={ref}
            className="absolute flex items-center gap-3 w-[140px] h-[52px] bg-white/5 backdrop-blur-md border border-white/10 rounded-xl shadow-lg p-3"
            style={{ marginLeft: "-70px", marginTop: "-26px" }}
        >
            <div className="w-9 h-9 rounded-lg bg-white/10 flex items-center justify-center flex-shrink-0">
                <Image className="w-5 h-5 text-white/70" />
            </div>
            <div className="flex flex-col overflow-hidden">
                <span className="text-xs font-medium text-white/90 truncate">{name}</span>
                <span className="text-[10px] text-white/50">PNG Image</span>
            </div>
        </div>
    );
});
FileCard.displayName = "FileCard";
