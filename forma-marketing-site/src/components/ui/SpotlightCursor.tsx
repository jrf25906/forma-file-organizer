"use client";

import { useEffect, useRef, useState } from "react";

export function SpotlightCursor() {
    const cursorRef = useRef<HTMLDivElement>(null);
    const [position, setPosition] = useState({ x: 0, y: 0 });

    useEffect(() => {
        const handleMouseMove = (e: MouseEvent) => {
            // Use requestAnimationFrame for smoother performance
            requestAnimationFrame(() => {
                setPosition({ x: e.clientX, y: e.clientY });
            });
        };

        window.addEventListener("mousemove", handleMouseMove);

        return () => {
            window.removeEventListener("mousemove", handleMouseMove);
        };
    }, []);

    useEffect(() => {
        const cursor = cursorRef.current;
        if (cursor) {
            cursor.style.transform = `translate(${position.x}px, ${position.y}px)`;
        }
    }, [position]);

    return (
        <div
            ref={cursorRef}
            className="pointer-events-none fixed top-0 left-0 -mt-24 -ml-24 w-48 h-48 rounded-full bg-forma-steel-blue/20 blur-[80px] z-50 mix-blend-soft-light transition-transform duration-75 ease-out will-change-transform"
        />
    );
}
