"use client";

import { useRef } from "react";
import { gsap, ScrollTrigger, useGSAP } from "@/lib/animation/gsap-config";
import { cn } from "@/lib/utils";

interface ParallaxSectionProps {
    children: React.ReactNode;
    className?: string;
    speed?: number; // 1 = normal scroll, >1 = faster, <1 = slower (parallax)
}

export function ParallaxSection({
    children,
    className,
    speed = 0.5,
}: ParallaxSectionProps) {
    const containerRef = useRef<HTMLDivElement>(null);
    const contentRef = useRef<HTMLDivElement>(null);

    useGSAP(() => {
        const container = containerRef.current;
        const content = contentRef.current;
        if (!container || !content) return;

        gsap.to(content, {
            y: (i, target) => -(target.offsetHeight * (1 - speed)),
            ease: "none",
            scrollTrigger: {
                trigger: container,
                start: "top bottom",
                end: "bottom top",
                scrub: true,
            },
        });
    }, { scope: containerRef });

    return (
        <div ref={containerRef} className={cn("relative", className)}>
            <div ref={contentRef} className="relative will-change-transform">
                {children}
            </div>
        </div>
    );
}
