"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { useReducedMotion } from "./use-reduced-motion";

interface ParallaxPosition {
    x: number;
    y: number;
    rotateX: number;
    rotateY: number;
}

interface UseMouseParallaxOptions {
    /** Movement influence multiplier (0-1). Higher = more movement */
    influence?: number;
    /** Rotation influence in degrees. Set to 0 to disable rotation */
    rotationInfluence?: number;
    /** Lerp smoothing factor (0.01-0.3). Lower = smoother/slower */
    smoothing?: number;
    /** Whether parallax is enabled */
    enabled?: boolean;
}

/**
 * Hook for creating smooth mouse-following parallax effects.
 * Uses lerp (linear interpolation) for buttery-smooth movement.
 *
 * @example
 * const { position, ref } = useMouseParallax({ influence: 0.3 });
 * // Apply to element:
 * style={{
 *   transform: `translate3d(${position.x}px, ${position.y}px, 0)
 *               rotateX(${position.rotateX}deg)
 *               rotateY(${position.rotateY}deg)`
 * }}
 */
export function useMouseParallax(options: UseMouseParallaxOptions = {}) {
    const {
        influence = 0.3,
        rotationInfluence = 3,
        smoothing = 0.08,
        enabled = true,
    } = options;

    const reducedMotion = useReducedMotion();
    const shouldAnimate = enabled && !reducedMotion;

    const [position, setPosition] = useState<ParallaxPosition>({
        x: 0,
        y: 0,
        rotateX: 0,
        rotateY: 0,
    });

    // Target values (where mouse is pointing)
    const targetRef = useRef({ x: 0, y: 0 });
    // Current interpolated values
    const currentRef = useRef({ x: 0, y: 0, rotateX: 0, rotateY: 0 });
    // Animation frame ID for cleanup
    const rafRef = useRef<number | undefined>(undefined);
    // Container ref for bounds calculation
    const containerRef = useRef<HTMLDivElement | null>(null);

    // Update target on mouse move
    const handleMouseMove = useCallback(
        (event: MouseEvent) => {
            if (!shouldAnimate) return;

            // Get container bounds if available, otherwise use window
            const container = containerRef.current;
            let normalizedX: number;
            let normalizedY: number;

            if (container) {
                const rect = container.getBoundingClientRect();
                // Normalize to -1 to 1 relative to container center
                normalizedX = ((event.clientX - rect.left) / rect.width - 0.5) * 2;
                normalizedY = ((event.clientY - rect.top) / rect.height - 0.5) * 2;
            } else {
                // Fallback to window-based calculation
                normalizedX = (event.clientX / window.innerWidth - 0.5) * 2;
                normalizedY = (event.clientY / window.innerHeight - 0.5) * 2;
            }

            // Clamp values to prevent extreme movement
            normalizedX = Math.max(-1, Math.min(1, normalizedX));
            normalizedY = Math.max(-1, Math.min(1, normalizedY));

            targetRef.current = {
                x: normalizedX,
                y: normalizedY,
            };
        },
        [shouldAnimate]
    );

    // Reset on mouse leave
    const handleMouseLeave = useCallback(() => {
        targetRef.current = { x: 0, y: 0 };
    }, []);

    // Animation loop with lerp
    useEffect(() => {
        if (!shouldAnimate) {
            setPosition({ x: 0, y: 0, rotateX: 0, rotateY: 0 });
            return;
        }

        const animate = () => {
            const current = currentRef.current;
            const target = targetRef.current;

            // Lerp toward target
            current.x += (target.x * influence * 30 - current.x) * smoothing;
            current.y += (target.y * influence * 20 - current.y) * smoothing;
            current.rotateX += (-target.y * rotationInfluence - current.rotateX) * smoothing;
            current.rotateY += (target.x * rotationInfluence - current.rotateY) * smoothing;

            // Only update state if values changed significantly (prevents unnecessary renders)
            const threshold = 0.01;
            if (
                Math.abs(current.x - position.x) > threshold ||
                Math.abs(current.y - position.y) > threshold ||
                Math.abs(current.rotateX - position.rotateX) > threshold ||
                Math.abs(current.rotateY - position.rotateY) > threshold
            ) {
                setPosition({
                    x: current.x,
                    y: current.y,
                    rotateX: current.rotateX,
                    rotateY: current.rotateY,
                });
            }

            rafRef.current = requestAnimationFrame(animate);
        };

        rafRef.current = requestAnimationFrame(animate);

        return () => {
            if (rafRef.current) {
                cancelAnimationFrame(rafRef.current);
            }
        };
    }, [shouldAnimate, influence, rotationInfluence, smoothing, position]);

    // Attach mouse listeners
    useEffect(() => {
        if (!shouldAnimate) return;

        window.addEventListener("mousemove", handleMouseMove, { passive: true });
        window.addEventListener("mouseleave", handleMouseLeave);

        return () => {
            window.removeEventListener("mousemove", handleMouseMove);
            window.removeEventListener("mouseleave", handleMouseLeave);
        };
    }, [shouldAnimate, handleMouseMove, handleMouseLeave]);

    return {
        position,
        containerRef,
        isEnabled: shouldAnimate,
    };
}

/**
 * Get transform style string from parallax position.
 * Includes translateZ for layer depth.
 */
export function getParallaxTransform(
    position: ParallaxPosition,
    depth: number = 0
): string {
    return `translate3d(${position.x}px, ${position.y}px, ${depth}px) rotateX(${position.rotateX}deg) rotateY(${position.rotateY}deg)`;
}
