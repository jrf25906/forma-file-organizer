"use client";

import { ReactNode, CSSProperties } from "react";
import { useMouseParallax, getParallaxTransform } from "@/hooks/useMouseParallax";
import { useReducedMotion } from "@/hooks/use-reduced-motion";

// ═══════════════════════════════════════════════════════════════════════════
// PARALLAX SCENE
// Container that provides 3D perspective and mouse-tracking context.
// Children use depth layers for parallax effect.
// ═══════════════════════════════════════════════════════════════════════════

interface ParallaxSceneProps {
    children: ReactNode;
    className?: string;
    /** Perspective distance in pixels. Lower = more dramatic 3D */
    perspective?: number;
}

export default function ParallaxScene({
    children,
    className = "",
    perspective = 1200,
}: ParallaxSceneProps) {
    const reducedMotion = useReducedMotion();

    return (
        <div
            className={`relative ${className}`}
            style={{
                perspective: reducedMotion ? "none" : `${perspective}px`,
                perspectiveOrigin: "center center",
            }}
        >
            <div
                className="relative w-full h-full"
                style={{
                    transformStyle: reducedMotion ? "flat" : "preserve-3d",
                }}
            >
                {children}
            </div>
        </div>
    );
}

// ═══════════════════════════════════════════════════════════════════════════
// PARALLAX LAYER
// Individual layer within the scene that responds to mouse movement.
// ═══════════════════════════════════════════════════════════════════════════

interface ParallaxLayerProps {
    children: ReactNode;
    /** Z-depth in pixels. Negative = further away, positive = closer */
    depth?: number;
    /** Movement influence (0-1). Higher = more movement */
    influence?: number;
    /** Rotation influence in degrees */
    rotationInfluence?: number;
    className?: string;
    style?: CSSProperties;
}

export function ParallaxLayer({
    children,
    depth = 0,
    influence = 0.3,
    rotationInfluence = 0,
    className = "",
    style = {},
}: ParallaxLayerProps) {
    const { position, isEnabled } = useMouseParallax({
        influence,
        rotationInfluence,
    });

    const reducedMotion = useReducedMotion();

    // Calculate transform based on parallax position
    const transform = isEnabled
        ? getParallaxTransform(position, depth)
        : `translateZ(${depth}px)`;

    return (
        <div
            className={`absolute inset-0 ${className}`}
            style={{
                ...style,
                transform,
                transformStyle: reducedMotion ? "flat" : "preserve-3d",
                willChange: isEnabled ? "transform" : "auto",
            }}
        >
            {children}
        </div>
    );
}

// ═══════════════════════════════════════════════════════════════════════════
// PARALLAX ELEMENT
// Individual element that can be positioned and animated within a layer.
// ═══════════════════════════════════════════════════════════════════════════

interface ParallaxElementProps {
    children: ReactNode;
    /** Position from left as percentage (0-100) */
    x: number;
    /** Position from top as percentage (0-100) */
    y: number;
    /** Additional z-offset from layer depth */
    zOffset?: number;
    className?: string;
    style?: CSSProperties;
    id?: string;
}

export function ParallaxElement({
    children,
    x,
    y,
    zOffset = 0,
    className = "",
    style = {},
    id,
}: ParallaxElementProps) {
    return (
        <div
            id={id}
            className={`absolute ${className}`}
            style={{
                left: `${x}%`,
                top: `${y}%`,
                transform: `translate(-50%, -50%) translateZ(${zOffset}px)`,
                ...style,
            }}
        >
            {children}
        </div>
    );
}
