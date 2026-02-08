"use client";

import { useEffect, useState, type ReactNode } from "react";
import { Menu, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";

interface GridLogoProps {
  size?: number;
  gap?: number;
  className?: string;
}

function GridLogo({ size = 4.5, gap = 2.5, className }: GridLogoProps) {
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
          style={{ width: `${size}px`, height: `${size}px`, opacity }}
        />
      ))}
    </div>
  );
}

interface SmoothScrollLinkProps {
  href: string;
  className?: string;
  onClick?: () => void;
  children: ReactNode;
}

function SmoothScrollLink({
  href,
  className,
  onClick,
  children,
}: SmoothScrollLinkProps) {
  const handleClick = (e: React.MouseEvent<HTMLAnchorElement>) => {
    if (!href.startsWith("#")) return;

    e.preventDefault();
    const target = document.querySelector(href);
    if (!target) return;

    const y = target.getBoundingClientRect().top + window.scrollY - 100;
    window.scrollTo({ top: y, behavior: "smooth" });
    onClick?.();
  };

  return (
    <a href={href} className={className} onClick={handleClick}>
      {children}
    </a>
  );
}

const NAV_LINKS = [
  { label: "Features", href: "#features" },
  { label: "Pricing", href: "#pricing" },
  { label: "FAQ", href: "#faq" },
] as const;

export function Header() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setIsScrolled(window.scrollY > 10);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const closeMobileMenu = () => setIsMobileMenuOpen(false);

  return (
    <>
      <header
        role="banner"
        className={cn(
          "sticky inset-x-0 top-0 z-[120] border-b transition-all duration-200",
          isScrolled
            ? "bg-white/96 backdrop-blur-xl border-black/[0.08]"
            : "bg-white/88 backdrop-blur-lg border-black/[0.05]"
        )}
      >
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
          <SmoothScrollLink
            href="#top"
            className="flex items-center gap-2.5 rounded-full px-2.5 py-1.5 text-forma-obsidian hover:bg-black/[0.04] transition-colors"
            onClick={closeMobileMenu}
          >
            <GridLogo />
            <span className="font-display text-[17px] leading-none tracking-tight">
              Forma
            </span>
          </SmoothScrollLink>

          <nav
            className="hidden items-center gap-1 md:flex"
            aria-label="Main navigation"
          >
            {NAV_LINKS.map((link) => (
              <SmoothScrollLink
                key={link.href}
                href={link.href}
                className="rounded-full px-3.5 py-2 text-[13px] font-medium text-forma-obsidian/70 hover:text-forma-obsidian hover:bg-black/[0.04] transition-colors"
                onClick={closeMobileMenu}
              >
                {link.label}
              </SmoothScrollLink>
            ))}
          </nav>

          <div className="flex items-center gap-2">
            <a
              href={MAC_APP_STORE_URL}
              {...MAC_APP_STORE_LINK_PROPS}
              className="hidden md:inline-flex h-9 items-center rounded-full bg-forma-obsidian px-4 text-[12.5px] font-semibold text-forma-bone hover:bg-forma-obsidian/90 transition-colors"
            >
              Download for Mac
            </a>

            <button
              onClick={() => setIsMobileMenuOpen((open) => !open)}
              className="inline-flex h-9 w-9 items-center justify-center rounded-full text-forma-obsidian hover:bg-black/[0.04] transition-colors md:hidden"
              aria-label={isMobileMenuOpen ? "Close menu" : "Open menu"}
              aria-expanded={isMobileMenuOpen}
            >
              {isMobileMenuOpen ? <X size={18} /> : <Menu size={18} />}
            </button>
          </div>
        </div>
      </header>

      <div
        className={cn(
          "fixed inset-0 z-[110] bg-black/20 transition-opacity md:hidden",
          isMobileMenuOpen
            ? "pointer-events-auto opacity-100"
            : "pointer-events-none opacity-0"
        )}
        onClick={closeMobileMenu}
        aria-hidden="true"
      />

      <div
        className={cn(
          "fixed inset-x-0 top-16 z-[121] border-b border-black/[0.08] bg-white/98 px-4 py-4 shadow-[0_18px_40px_rgba(0,0,0,0.10)] backdrop-blur-xl md:hidden transition-all duration-200",
          isMobileMenuOpen
            ? "translate-y-0 opacity-100"
            : "-translate-y-2 opacity-0 pointer-events-none"
        )}
      >
        <nav
          className="mx-auto flex max-w-6xl flex-col gap-1.5"
          aria-label="Mobile navigation"
        >
          {NAV_LINKS.map((link) => (
            <SmoothScrollLink
              key={link.href}
              href={link.href}
              onClick={closeMobileMenu}
              className="rounded-xl px-3 py-2.5 text-[15px] font-medium text-forma-obsidian/85 hover:bg-black/[0.04]"
            >
              {link.label}
            </SmoothScrollLink>
          ))}
          <a
            href={MAC_APP_STORE_URL}
            {...MAC_APP_STORE_LINK_PROPS}
            onClick={closeMobileMenu}
            className="mt-1 inline-flex h-11 items-center justify-center rounded-xl bg-forma-obsidian px-4 text-[14px] font-semibold text-forma-bone hover:bg-forma-obsidian/90 transition-colors"
          >
            Download for Mac
          </a>
        </nav>
      </div>
    </>
  );
}

export default Header;
