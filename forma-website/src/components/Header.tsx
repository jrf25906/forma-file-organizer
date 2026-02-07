"use client";

import { useRef, useEffect, useState, useCallback, type ReactNode } from "react";
import { Menu, X, ArrowUpRight } from "lucide-react";
import { gsap, useGSAP, useLenisScroll, formaReveal, formaDuration } from "@/lib/animation";
import MagneticButton from "@/components/animation/MagneticButton";
import { cn } from "@/lib/utils";
import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";

/* ═══════════════════════════════════════════════════════════════════════════
   GRID LOGO
   3x3 dot grid with descending row opacity: 1 / 0.7 / 0.4
   ═══════════════════════════════════════════════════════════════════════════ */

interface GridLogoProps {
  size?: number;
  gap?: number;
  className?: string;
}

function GridLogo({ size = 4, gap = 2.5, className }: GridLogoProps) {
  const opacities = [1, 1, 1, 0.7, 0.7, 0.7, 0.4, 0.4, 0.4];

  return (
    <div
      className={cn("grid grid-cols-3", className)}
      style={{ gap: `${gap}px` }}
      aria-hidden="true"
    >
      {opacities.map((opacity, i) => (
        <span
          key={i}
          className="forma-logo-dot rounded-full"
          style={{
            width: `${size}px`,
            height: `${size}px`,
            opacity,
          }}
        />
      ))}
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   SMOOTH SCROLL LINK
   Intercepts click to scroll via Lenis instead of native jump
   ═══════════════════════════════════════════════════════════════════════════ */

interface SmoothScrollLinkProps {
  href: string;
  children: ReactNode;
  className?: string;
  onClick?: () => void;
}

function SmoothScrollLink({
  href,
  children,
  className,
  onClick,
}: SmoothScrollLinkProps) {
  const lenis = useLenisScroll();

  const handleClick = useCallback(
    (e: React.MouseEvent<HTMLAnchorElement>) => {
      // Only intercept anchor links
      if (!href.startsWith("#")) return;

      e.preventDefault();
      const target = document.querySelector(href);
      if (!target) return;

      if (lenis) {
        lenis.scrollTo(target as HTMLElement, {
          offset: -120,
          duration: 1.2,
        });
      } else {
        target.scrollIntoView({ behavior: "smooth", block: "start" });
      }

      onClick?.();
    },
    [href, lenis, onClick]
  );

  return (
    <a href={href} onClick={handleClick} className={className}>
      {children}
    </a>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   MOBILE MENU
   Full-screen overlay with GSAP-driven slide/stagger animations
   ═══════════════════════════════════════════════════════════════════════════ */

interface MobileMenuProps {
  isOpen: boolean;
  onClose: () => void;
  navLinks: { label: string; href: string }[];
}

function MobileMenu({ isOpen, onClose, navLinks }: MobileMenuProps) {
  const overlayRef = useRef<HTMLDivElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);
  const itemsRef = useRef<HTMLDivElement>(null);
  const timeline = useRef<gsap.core.Timeline | null>(null);

  // Prevent body scroll when menu is open
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [isOpen]);

  // Close on Escape key
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [isOpen, onClose]);

  // GSAP enter/exit animation
  useGSAP(() => {
    if (!overlayRef.current || !panelRef.current || !itemsRef.current) return;

    const items = itemsRef.current.children;

    if (timeline.current) {
      timeline.current.kill();
    }

    if (isOpen) {
      timeline.current = gsap.timeline();

      timeline.current
        .fromTo(
          overlayRef.current,
          { opacity: 0 },
          { opacity: 1, duration: 0.3, ease: "power2.out" }
        )
        .fromTo(
          panelRef.current,
          { x: "100%" },
          { x: "0%", duration: 0.5, ease: formaReveal },
          "-=0.15"
        )
        .fromTo(
          items,
          { opacity: 0, x: 30 },
          {
            opacity: 1,
            x: 0,
            duration: 0.4,
            ease: formaReveal,
            stagger: 0.08,
          },
          "-=0.25"
        );
    } else {
      timeline.current = gsap.timeline();

      timeline.current
        .to(items, {
          opacity: 0,
          x: 20,
          duration: 0.2,
          ease: "power2.in",
          stagger: 0.04,
        })
        .to(
          panelRef.current,
          { x: "100%", duration: 0.35, ease: "power2.in" },
          "-=0.1"
        )
        .to(
          overlayRef.current,
          { opacity: 0, duration: 0.25, ease: "power2.in" },
          "-=0.15"
        );
    }
  }, [isOpen]);

  return (
    <div
      className={cn(
        "fixed inset-0 z-[90] md:hidden",
        !isOpen && "pointer-events-none"
      )}
      aria-hidden={!isOpen}
    >
      {/* Overlay backdrop */}
      <div
        ref={overlayRef}
        className="absolute inset-0 bg-forma-obsidian/60 backdrop-blur-sm opacity-0"
        onClick={onClose}
        aria-label="Close menu"
      />

      {/* Slide-in panel */}
      <div
        ref={panelRef}
        className="absolute top-0 right-0 h-full w-[80%] max-w-[320px] translate-x-full
                   bg-white/95 backdrop-blur-2xl border-l border-black/[0.06]
                   shadow-2xl flex flex-col"
        role="dialog"
        aria-modal="true"
        aria-label="Navigation menu"
      >
        {/* Panel header */}
        <div className="flex items-center justify-between px-6 py-5 border-b border-black/[0.06]">
          <div className="flex items-center gap-2.5">
            <GridLogo size={3.5} gap={2} />
            <span className="text-sm font-semibold tracking-tight text-forma-obsidian font-display">
              Forma
            </span>
          </div>
          <button
            onClick={onClose}
            className="flex items-center justify-center w-9 h-9 rounded-full
                       bg-black/[0.04] hover:bg-black/[0.08] transition-colors duration-200"
            aria-label="Close navigation menu"
          >
            <X size={18} strokeWidth={2} className="text-forma-obsidian/70" />
          </button>
        </div>

        {/* Nav items */}
        <nav className="flex-1 px-6 py-6">
          <div ref={itemsRef} className="flex flex-col gap-1">
            {navLinks.map((link) => (
              <SmoothScrollLink
                key={link.href}
                href={link.href}
                onClick={onClose}
                className="group flex items-center justify-between px-3 py-3.5
                           rounded-xl text-[15px] font-medium text-forma-obsidian/80
                           hover:bg-black/[0.04] hover:text-forma-obsidian
                           transition-colors duration-200"
              >
                {link.label}
                <ArrowUpRight
                  size={14}
                  className="text-forma-obsidian/30 group-hover:text-forma-steel-blue
                             transition-colors duration-200"
                />
              </SmoothScrollLink>
            ))}

            {/* Mobile CTA */}
            <div className="mt-6 pt-6 border-t border-black/[0.06]">
              <a
                href={MAC_APP_STORE_URL}
                {...MAC_APP_STORE_LINK_PROPS}
                onClick={onClose}
                className="flex items-center justify-center gap-2 w-full px-5 py-3
                           rounded-xl dark-button text-[14px] font-semibold
                           tracking-[-0.01em] hover:bg-forma-obsidian/90
                           transition-colors duration-200 font-display"
              >
                Download for Mac
              </a>
            </div>
          </div>
        </nav>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   NAV LINKS DATA
   ═══════════════════════════════════════════════════════════════════════════ */

const NAV_LINKS = [
  { label: "Features", href: "#features" },
  { label: "Pricing", href: "#pricing" },
  { label: "FAQ", href: "#faq" },
] as const;

/* ═══════════════════════════════════════════════════════════════════════════
   HEADER (main export)
   Floating island navigation with glass morphism
   ═══════════════════════════════════════════════════════════════════════════ */

export function Header() {
  const headerRef = useRef<HTMLElement>(null);
  const islandRef = useRef<HTMLDivElement>(null);

  const [isScrolled, setIsScrolled] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  // ── Scroll state listener ──────────────────────────────────────────────
  useEffect(() => {
    const SCROLL_THRESHOLD = 20;

    const handleScroll = () => {
      const y = window.scrollY;
      setIsScrolled(y > SCROLL_THRESHOLD);
    };

    // Initial check
    handleScroll();

    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  // ── Entrance animation ─────────────────────────────────────────────────
  useGSAP(() => {
    if (!islandRef.current) return;

    gsap.fromTo(
      islandRef.current,
      { opacity: 0, y: -20 },
      {
        opacity: 1,
        y: 0,
        duration: formaDuration.normal,
        ease: formaReveal,
        delay: 0.3,
      }
    );
  }, []);

  const closeMobileMenu = useCallback(() => {
    setIsMobileMenuOpen(false);
  }, []);

  const toggleMobileMenu = useCallback(() => {
    setIsMobileMenuOpen((prev) => !prev);
  }, []);

  return (
    <>
      <header
        ref={headerRef}
        className="fixed top-0 left-0 right-0 z-[100] flex justify-center
                   px-4 pt-5 md:pt-6 pointer-events-none"
      >
        <div
          ref={islandRef}
          className={cn(
            "header-glass pointer-events-auto opacity-0",
            "flex items-center gap-1.5 px-2.5 py-2.5 md:px-3.5 md:py-2.5",
            "rounded-full border transition-all duration-500 ease-out",
            // Glass morphism base
            "bg-white/80 backdrop-blur-xl",
            "shadow-[0_1px_3px_rgba(0,0,0,0.04),0_8px_24px_rgba(0,0,0,0.06)]",
            // Adaptive border based on scroll
            isScrolled
              ? "border-black/[0.08] shadow-[0_2px_8px_rgba(0,0,0,0.06),0_12px_32px_rgba(0,0,0,0.08)]"
              : "border-black/[0.04]"
          )}
        >
          {/* ── Logo ────────────────────────────────────────────────── */}
          <SmoothScrollLink
            href="#top"
            className="flex items-center gap-2.5 pl-3 pr-3.5 py-2 rounded-full
                       hover:bg-black/[0.03] transition-colors duration-200 shrink-0"
          >
            <GridLogo size={4.5} gap={2.5} />
            <span className="text-[15.5px] font-semibold tracking-tight text-forma-obsidian font-display">
              Forma
            </span>
          </SmoothScrollLink>

          {/* ── Desktop navigation ──────────────────────────────────── */}
          <nav
            className="hidden md:flex items-center gap-0.5"
            aria-label="Main navigation"
          >
            {NAV_LINKS.map((link) => (
              <MagneticButton
                key={link.href}
                strength={0.2}
                className="inline-flex"
              >
                <SmoothScrollLink
                  href={link.href}
                  className={cn(
                    "px-4 py-2 rounded-full text-[13.5px] font-medium",
                    "text-forma-obsidian/60 hover:text-forma-obsidian",
                    "hover:bg-black/[0.04] transition-all duration-200",
                    "tracking-[-0.01em]"
                  )}
                >
                  {link.label}
                </SmoothScrollLink>
              </MagneticButton>
            ))}
          </nav>

          {/* ── Desktop CTA ─────────────────────────────────────────── */}
          <a
            href={MAC_APP_STORE_URL}
            {...MAC_APP_STORE_LINK_PROPS}
            className="hidden md:inline-flex items-center justify-center shrink-0
                       h-9 rounded-full dark-button
                       text-[12.5px] font-semibold tracking-[-0.01em]
                       hover:bg-forma-obsidian/90 active:scale-[0.97]
                       transition-all duration-200 whitespace-nowrap
                       px-5 font-display"
          >
            Download for Mac
          </a>

          {/* ── Mobile hamburger toggle ─────────────────────────────── */}
          <button
            onClick={toggleMobileMenu}
            className={cn(
              "md:hidden flex items-center justify-center",
              "w-9 h-9 rounded-full shrink-0",
              "hover:bg-black/[0.04] active:bg-black/[0.06]",
              "transition-colors duration-200"
            )}
            aria-label={isMobileMenuOpen ? "Close menu" : "Open menu"}
            aria-expanded={isMobileMenuOpen}
          >
            {isMobileMenuOpen ? (
              <X size={18} strokeWidth={2} className="text-forma-obsidian/70" />
            ) : (
              <Menu
                size={18}
                strokeWidth={2}
                className="text-forma-obsidian/70"
              />
            )}
          </button>
        </div>
      </header>

      {/* ── Mobile menu (portal-like, outside header for z-index) ── */}
      <MobileMenu
        isOpen={isMobileMenuOpen}
        onClose={closeMobileMenu}
        navLinks={[...NAV_LINKS]}
      />
    </>
  );
}

export default Header;
