"use client";

import { forwardRef, type ButtonHTMLAttributes, type AnchorHTMLAttributes } from "react";
import { cn } from "@/lib/utils";

// ═══════════════════════════════════════════════════════════════════════════
// BUTTON COMPONENT
// Unified button styling for consistent CTAs across the site
// ═══════════════════════════════════════════════════════════════════════════

type ButtonVariant = "primary" | "secondary" | "ghost";
type ButtonSize = "sm" | "md" | "lg";

interface ButtonBaseProps {
    variant?: ButtonVariant;
    size?: ButtonSize;
    className?: string;
    children: React.ReactNode;
}

type ButtonAsButton = ButtonBaseProps &
    Omit<ButtonHTMLAttributes<HTMLButtonElement>, keyof ButtonBaseProps> & {
        as?: "button";
        href?: never;
    };

type ButtonAsLink = ButtonBaseProps &
    Omit<AnchorHTMLAttributes<HTMLAnchorElement>, keyof ButtonBaseProps> & {
        as: "a";
        href: string;
    };

type ButtonProps = ButtonAsButton | ButtonAsLink;

const variantStyles: Record<ButtonVariant, string> = {
    primary: cn(
        "bg-forma-obsidian text-forma-bone",
        "shadow-lg hover:shadow-xl hover:shadow-forma-obsidian/20",
        "hover:scale-[1.02] active:scale-[0.98]"
    ),
    secondary: cn(
        "bg-transparent text-forma-obsidian/80",
        "border border-forma-obsidian/15",
        "hover:border-forma-obsidian/30 hover:text-forma-obsidian hover:bg-white/50",
        "hover:scale-[1.02] active:scale-[0.98]",
        "backdrop-blur-sm"
    ),
    ghost: cn(
        "bg-transparent text-forma-obsidian/85",
        "hover:text-forma-obsidian hover:bg-forma-obsidian/5",
        "active:bg-forma-obsidian/10"
    ),
};

const sizeStyles: Record<ButtonSize, string> = {
    sm: "px-4 py-2 text-sm gap-1.5",
    md: "px-6 py-3 text-base gap-2",
    lg: "px-8 py-4 text-lg gap-2",
};

const baseStyles = cn(
    "inline-flex items-center justify-center",
    "rounded-full font-medium",
    "transition-all duration-200 ease-out",
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forma-steel-blue focus-visible:ring-offset-2",
    "disabled:opacity-50 disabled:pointer-events-none"
);

export const Button = forwardRef<HTMLButtonElement | HTMLAnchorElement, ButtonProps>(
    ({ variant = "primary", size = "md", className, children, ...props }, ref) => {
        const combinedClassName = cn(
            baseStyles,
            variantStyles[variant],
            sizeStyles[size],
            className
        );

        if (props.as === "a") {
            const { as: _, ...linkProps } = props;
            return (
                <a
                    ref={ref as React.Ref<HTMLAnchorElement>}
                    className={combinedClassName}
                    {...linkProps}
                >
                    {children}
                </a>
            );
        }

        const { as: _, ...buttonProps } = props as ButtonAsButton;
        return (
            <button
                ref={ref as React.Ref<HTMLButtonElement>}
                className={combinedClassName}
                {...buttonProps}
            >
                {children}
            </button>
        );
    }
);

Button.displayName = "Button";

export default Button;
