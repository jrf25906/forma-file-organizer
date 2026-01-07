"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { Menu, X, MoveRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { gsap, useGSAP } from "@/lib/animation/gsap-config";
import { useLenisScroll } from "@/lib/animation/scroll-context";
import { MagneticButton } from "@/components/animation/MagneticButton";
import { Button } from "@/components/ui/Button";

// =============================================================================
// TYPES
// =============================================================================

interface NavLink {
  label: string;
  href: string;
}

const NAV_LINKS: NavLink[] = [
  { label: "Features", href: "#features" },
  { label: "How It Works", href: "#how-it-works" },
  { label: "Pricing", href: "#pricing" },
];

// =============================================================================
// GRID LOGO COMPONENT
// =============================================================================



export function GridLogo({ size = 24, className }: { size?: number; className?: string }) {
  const cellSize = size / 3.5;
  const gap = size / 14;

  return (
    <div
      className={cn("grid grid-cols-3", className)}
      style={{ gap: `${gap}px`, width: size, height: size }}
      aria-hidden="true"
    >
      {[1, 1, 1, 0.7, 0.7, 0.7, 0.4, 0.4, 0.4].map((opacity, i) => (
        <div
          key={i}
          className="bg-forma-obsidian rounded-[1px]"
          style={{
            width: cellSize,
            height: cellSize,
            opacity,
          }}
        />
      ))}
    </div>
  );
}

// =============================================================================
// SMOOTH SCROLL LINK
// =============================================================================

interface SmoothScrollLinkProps {
  href: string;
  children: React.ReactNode;
  className?: string;
  onClick?: () => void;
}

function SmoothScrollLink({ href, children, className, onClick }: SmoothScrollLinkProps) {
  const lenis = useLenisScroll();

  const handleClick = useCallback((e: React.MouseEvent<HTMLAnchorElement>) => {
    // Only handle internal anchor links
    if (href.startsWith("#")) {
      e.preventDefault();
      const target = document.querySelector(href);
      if (target && lenis) {
        lenis.scrollTo(target as HTMLElement, {
          offset: -80, // Account for fixed header height
          duration: 1.2,
        });
      } else if (target) {
        // Fallback for when Lenis isn't available
        target.scrollIntoView({ behavior: "smooth" });
      }
    }
    onClick?.();
  }, [href, lenis, onClick]);

  return (
    <a href={href} className={className} onClick={handleClick}>
      {children}
    </a>
  );
}

// =============================================================================
// MOBILE MENU
// =============================================================================

interface MobileMenuProps {
  isOpen: boolean;
  onClose: () => void;
  links: NavLink[];
}

function MobileMenu({ isOpen, onClose, links }: MobileMenuProps) {
  const menuRef = useRef<HTMLDivElement>(null);
  const overlayRef = useRef<HTMLDivElement>(null);

  // Animate menu open/close
  useGSAP(() => {
    if (!menuRef.current || !overlayRef.current) return;

    if (isOpen) {
      // Animate in
      gsap.to(overlayRef.current, {
        opacity: 1,
        duration: 0.3,
        ease: "power2.out",
      });
      gsap.fromTo(
        menuRef.current,
        { x: "100%" },
        { x: "0%", duration: 0.4, ease: "power3.out" }
      );
      // Stagger in menu items
      gsap.fromTo(
        menuRef.current.querySelectorAll("[data-menu-item]"),
        { opacity: 0, x: 20 },
        {
          opacity: 1,
          x: 0,
          duration: 0.4,
          stagger: 0.08,
          delay: 0.2,
          ease: "power2.out",
        }
      );
    } else {
      // Animate out
      gsap.to(overlayRef.current, {
        opacity: 0,
        duration: 0.25,
        ease: "power2.in",
      });
      gsap.to(menuRef.current, {
        x: "100%",
        duration: 0.3,
        ease: "power3.in",
      });
    }
  }, { dependencies: [isOpen] });

  // Close on escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === "Escape" && isOpen) {
        onClose();
      }
    };

    document.addEventListener("keydown", handleEscape);
    return () => document.removeEventListener("keydown", handleEscape);
  }, [isOpen, onClose]);

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

  return (
    <>
      {/* Overlay */}
      <div
        ref={overlayRef}
        className={cn(
          "fixed inset-0 bg-forma-obsidian/40 backdrop-blur-sm z-40",
          isOpen ? "pointer-events-auto" : "pointer-events-none opacity-0"
        )}
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Menu panel */}
      <div
        ref={menuRef}
        className={cn(
          "fixed top-0 right-0 bottom-0 w-[280px] bg-forma-bone z-50 shadow-2xl",
          "translate-x-full"
        )}
        role="dialog"
        aria-modal="true"
        aria-label="Navigation menu"
      >
        {/* Close button */}
        <div className="flex items-center justify-end p-4">
          <button
            onClick={onClose}
            className="p-2 rounded-lg text-forma-obsidian/85 hover:text-forma-obsidian hover:bg-forma-obsidian/5 transition-colors"
            aria-label="Close menu"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Navigation links */}
        <nav className="px-6 py-4">
          <ul className="space-y-1">
            {links.map((link) => (
              <li key={link.href} data-menu-item>
                <SmoothScrollLink
                  href={link.href}
                  onClick={onClose}
                  className="block py-3 px-4 text-lg font-body text-forma-obsidian/85 hover:text-forma-obsidian hover:bg-forma-obsidian/5 rounded-lg transition-colors"
                >
                  {link.label}
                </SmoothScrollLink>
              </li>
            ))}
          </ul>

          {/* CTA in mobile menu */}
          <div className="mt-8 pt-6 border-t border-forma-obsidian/10" data-menu-item>
            <a
              href="https://testflight.apple.com/join/YOUR_LINK"
              className="flex items-center justify-center gap-2 w-full py-4 bg-forma-obsidian text-forma-bone rounded-xl font-display text-base hover:shadow-lg transition-all duration-300"
              onClick={onClose}
            >
              Join the Beta
              <MoveRight className="w-4 h-4" />
            </a>
            <p className="mt-3 text-center text-xs text-forma-obsidian/40">
              Free during beta - macOS 14+
            </p>
          </div>
        </nav>
      </div>
    </>
  );
}

// =============================================================================
// MAIN HEADER COMPONENT
// =============================================================================

export function Header() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [isPastHero, setIsPastHero] = useState(false);
  const headerRef = useRef<HTMLElement>(null);

  // Track scroll position for styling changes
  useEffect(() => {
    const handleScroll = () => {
      const scrollY = window.scrollY;
      setIsScrolled(scrollY > 10);
      // Hero section is approximately 500vh, but becomes solid after ~80% (400vh)
      // We want to become more opaque after user scrolls past the initial view
      setIsPastHero(scrollY > window.innerHeight * 0.8);
    };

    handleScroll(); // Check initial state
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  // Scroll direction logic
  const [isVisible, setIsVisible] = useState(true);
  const lastScrollY = useRef(0);

  useEffect(() => {
    const handleScroll = () => {
      const currentScrollY = window.scrollY;

      // Determine visibility
      if (currentScrollY < 10) {
        setIsVisible(true);
      } else if (currentScrollY > lastScrollY.current && currentScrollY > 100) {
        // Scrolling down & past threshold -> Hide
        setIsVisible(false);
      } else if (currentScrollY < lastScrollY.current) {
        // Scrolling up -> Show
        setIsVisible(true);
      }

      lastScrollY.current = currentScrollY;
    };

    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  // GSAP scroll-triggered animations for header elements
  useGSAP(() => {
    if (!headerRef.current) return;

    // Subtle header entrance animation on page load
    gsap.fromTo(
      headerRef.current,
      { y: -20, opacity: 0 },
      { y: 0, opacity: 1, duration: 0.6, delay: 0.3, ease: "power2.out" }
    );
  }, { scope: headerRef });

  const openMobileMenu = useCallback(() => setIsMobileMenuOpen(true), []);
  const closeMobileMenu = useCallback(() => setIsMobileMenuOpen(false), []);

  return (
    <>
      <header
        ref={headerRef}
        className={cn(
          // Base styles - Floating Island
          "fixed top-4 inset-x-0 z-50 flex justify-center pointer-events-none",
          "transition-all duration-500 ease-out",
          // Visibility toggle
          !isVisible && "-translate-y-[150%]",
        )}
      >
        <div 
          className={cn(
            "mx-auto px-1.5 sm:px-2 rounded-full transition-all duration-500 pointer-events-auto",
            "bg-white/70 backdrop-blur-xl border border-white/20 shadow-sm",
            isScrolled ? "py-1.5 bg-white/80 shadow-md border-black/[0.03]" : "py-2.5 bg-white/60"
          )}
        >
          <div className="flex items-center gap-4 sm:gap-8 px-3">
            {/* Logo */}
            <MagneticButton strength={0.15}>
              <a
                href="/"
                className="flex items-center gap-2 group"
                aria-label="Forma - Home"
              >
                <GridLogo size={20} />
                <span
                  className="font-display text-[15px] text-forma-obsidian font-medium hidden sm:inline-block"
                >
                  Forma
                </span>
              </a>
            </MagneticButton>

            {/* Desktop Navigation */}
            <nav className="hidden md:flex items-center gap-1" aria-label="Main navigation">
              {NAV_LINKS.map((link) => (
                <MagneticButton key={link.href} strength={0.12}>
                  <SmoothScrollLink
                    href={link.href}
                    className={cn(
                      "px-4 py-1.5 text-[13px] font-medium rounded-full transition-colors duration-200",
                      "text-forma-obsidian/85 hover:text-forma-obsidian hover:bg-black/[0.03]"
                    )}
                  >
                    {link.label}
                  </SmoothScrollLink>
                </MagneticButton>
              ))}
            </nav>

            {/* Desktop CTA + Mobile Menu Toggle */}
            <div className="flex items-center gap-2">
              {/* Desktop CTA Button */}
              <MagneticButton strength={0.2} className="hidden md:block">
                <Button
                  as="a"
                  href="https://testflight.apple.com/join/YOUR_LINK"
                  variant="primary"
                  size="sm"
                  className="rounded-full font-medium h-8 px-4 text-xs"
                >
                  Join Beta
                </Button>
              </MagneticButton>

              {/* Mobile Menu Toggle */}
              <button
                onClick={openMobileMenu}
                className={cn(
                  "md:hidden p-2 rounded-full transition-colors",
                  "text-forma-obsidian/85 hover:text-forma-obsidian hover:bg-black/[0.05]"
                )}
                aria-label="Open menu"
                aria-expanded={isMobileMenuOpen}
                aria-controls="mobile-menu"
              >
                <Menu className="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Mobile Menu */}
      <MobileMenu
        isOpen={isMobileMenuOpen}
        onClose={closeMobileMenu}
        links={NAV_LINKS}
      />
    </>
  );
}

export default Header;
