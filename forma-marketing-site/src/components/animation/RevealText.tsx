"use client";

import { useRef } from "react";
import { gsap, ScrollTrigger, useGSAP } from "@/lib/animation/gsap-config";
import { cn } from "@/lib/utils";

interface RevealTextProps {
    children: string;
    className?: string;
    delay?: number;
    threshold?: number;
}

export function RevealText({
    children,
    className,
    delay = 0,
    threshold = 0.2,
}: RevealTextProps) {
    const containerRef = useRef<HTMLDivElement>(null);
    const words = children.split(" ");

    useGSAP(() => {
        const container = containerRef.current;
        if (!container) return;

        const wordElements = container.querySelectorAll(".word");

        gsap.fromTo(
            wordElements,
            {
                y: "100%",
                opacity: 0,
            },
            {
                y: "0%",
                opacity: 1,
                duration: 1.0,
                stagger: 0.04,
                ease: "power3.out",
                delay,
                scrollTrigger: {
                    trigger: container,
                    start: `top ${100 - threshold * 100}%`,
                    toggleActions: "play none none reverse",
                },
            }
        );
    }, { scope: containerRef });

    return (
        <div
            ref={containerRef}
            className={cn("flex flex-wrap gap-x-[0.25em] overflow-hidden pb-[0.2em] -mb-[0.2em]", className)}
            aria-label={children}
        >
            {words.map((word, i) => (
                <span key={i} className="relative overflow-hidden inline-block">
                    <span className="word inline-block relative translate-y-full opacity-0">
                        {word}
                    </span>
                </span>
            ))}
        </div>
    );
}
