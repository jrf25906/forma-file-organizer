"use client";

import { useRef, useState, useEffect } from "react";
import { cn } from "@/lib/utils";

interface GlowCardProps extends React.HTMLAttributes<HTMLDivElement> {
    glowColor?: string;
}

export function GlowCard({
    children,
    className,
    glowColor = "rgba(255, 255, 255, 0.1)",
    ...props
}: GlowCardProps) {
    const cardRef = useRef<HTMLDivElement>(null);
    const [position, setPosition] = useState({ x: 0, y: 0 });
    const [opacity, setOpacity] = useState(0);

    useEffect(() => {
        const card = cardRef.current;
        if (!card) return;

        const handleMouseMove = (e: MouseEvent) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;

            setPosition({ x, y });
            setOpacity(1);
        };

        const handleMouseLeave = () => {
            setOpacity(0);
        };

        card.addEventListener("mousemove", handleMouseMove);
        card.addEventListener("mouseleave", handleMouseLeave);

        return () => {
            card.removeEventListener("mousemove", handleMouseMove);
            card.removeEventListener("mouseleave", handleMouseLeave);
        };
    }, []);

    return (
        <div
            ref={cardRef}
            className={cn("relative rounded-3xl", className)}
            {...props}
        >
            {/* Background & Glow Container - Absolute & Clipped */}
            <div className="absolute inset-0 rounded-3xl overflow-hidden bg-forma-obsidian/5 pointer-events-none">
                {/* Glow Effect */}
                <div
                    className="absolute -inset-px opacity-0 transition-opacity duration-300"
                    style={{
                        opacity,
                        background: `radial-gradient(600px circle at ${position.x}px ${position.y}px, ${glowColor}, transparent 40%)`,
                    }}
                />
            </div>

            {/* Content - Relative & In Flow */}
            <div className="relative z-10">{children}</div>
        </div>
    );
}
