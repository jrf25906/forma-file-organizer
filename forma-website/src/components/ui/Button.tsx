"use client";

import React, { forwardRef } from "react";
import { cn } from "@/lib/utils";

type ButtonVariant = "primary" | "secondary" | "ghost";
type ButtonSize = "sm" | "md" | "lg";

type ButtonBaseProps = {
  /** Visual variant (default "primary") */
  variant?: ButtonVariant;
  /** Size preset (default "md") */
  size?: ButtonSize;
  /** Additional CSS classes */
  className?: string;
  /** Render as anchor tag instead of button */
  href?: string;
  children?: React.ReactNode;
};

type ButtonAsButton = ButtonBaseProps &
  Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, keyof ButtonBaseProps> & {
    href?: undefined;
  };

type ButtonAsAnchor = ButtonBaseProps &
  Omit<React.AnchorHTMLAttributes<HTMLAnchorElement>, keyof ButtonBaseProps> & {
    href: string;
  };

type ButtonProps = ButtonAsButton | ButtonAsAnchor;

const variantStyles: Record<ButtonVariant, string> = {
  primary: cn(
    "bg-forma-obsidian text-forma-bone",
    "hover:bg-forma-obsidian/90 hover:-translate-y-px hover:shadow-lg hover:shadow-black/15",
    "active:bg-forma-obsidian/80 active:translate-y-0",
    "shadow-sm",
    "border border-transparent"
  ),
  secondary: cn(
    "bg-transparent text-forma-obsidian",
    "border border-forma-obsidian/15",
    "backdrop-blur-sm",
    "hover:bg-forma-obsidian/5 hover:border-forma-obsidian/25",
    "active:bg-forma-obsidian/10"
  ),
  ghost: cn(
    "bg-transparent text-forma-obsidian",
    "border border-transparent",
    "hover:bg-forma-obsidian/5",
    "active:bg-forma-obsidian/10"
  ),
};

const sizeStyles: Record<ButtonSize, string> = {
  sm: "px-4 py-2 text-sm rounded-lg gap-1.5",
  md: "px-6 py-3 text-base rounded-xl gap-2",
  lg: "px-8 py-4 text-lg rounded-xl gap-2.5",
};

/**
 * Button - Polymorphic button component
 *
 * Renders as a <button> by default or as an <a> when href is provided.
 * Supports three variants (primary, secondary, ghost) and three sizes
 * (sm, md, lg). Includes focus-visible ring styling for keyboard
 * accessibility.
 *
 * @example
 * ```tsx
 * // Primary button
 * <Button onClick={handleClick}>Get Started</Button>
 *
 * // Secondary link button
 * <Button variant="secondary" href="/about">Learn More</Button>
 *
 * // Ghost small button
 * <Button variant="ghost" size="sm">Cancel</Button>
 * ```
 */
export const Button = forwardRef<
  HTMLButtonElement | HTMLAnchorElement,
  ButtonProps
>(function Button(props, ref) {
  const {
    variant = "primary",
    size = "md",
    className,
    children,
    ...rest
  } = props;

  const combinedClassName = cn(
    // Base styles
    "inline-flex items-center justify-center",
    "font-medium whitespace-nowrap",
    "transition-all duration-300 ease-out",
    "cursor-pointer select-none",
    // Focus ring
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forma-steel-blue focus-visible:ring-offset-2",
    // Disabled state
    "disabled:opacity-50 disabled:pointer-events-none",
    // Variant and size
    variantStyles[variant],
    sizeStyles[size],
    className
  );

  // Render as anchor if href is provided
  if ("href" in props && props.href !== undefined) {
    const { href, variant: _v, size: _s, ...anchorProps } = props as ButtonAsAnchor;
    return (
      <a
        ref={ref as React.Ref<HTMLAnchorElement>}
        href={href}
        className={combinedClassName}
        {...anchorProps}
      >
        {children}
      </a>
    );
  }

  // Render as button -- rest already excludes variant/size/className/children
  return (
    <button
      ref={ref as React.Ref<HTMLButtonElement>}
      type="button"
      className={combinedClassName}
      {...(rest as Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, "className" | "children">)}
    >
      {children}
    </button>
  );
});

Button.displayName = "Button";

export default Button;
