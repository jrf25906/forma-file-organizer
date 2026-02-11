"use client";

import { useEffect, useState, type ReactNode } from "react";
import Image from "next/image";
import { Menu, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";

interface SmoothScrollLinkProps {
  href: string;
  className?: string;
  onClick?: () => void;
  children: ReactNode;
  "aria-label"?: string;
}

function SmoothScrollLink({
  href,
  className,
  onClick,
  children,
  "aria-label": ariaLabel,
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
    <a href={href} className={className} onClick={handleClick} aria-label={ariaLabel}>
      {children}
    </a>
  );
}

const NAV_LINKS = [
  { label: "Features", href: "#features", ariaLabel: "Jump to features section" },
  { label: "Pricing", href: "#pricing", ariaLabel: "Jump to pricing section" },
  { label: "FAQ", href: "#faq", ariaLabel: "Jump to frequently asked questions" },
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
            ? "bg-[var(--bg-primary)]/90 backdrop-blur-xl border-[var(--border-medium)]"
            : "bg-[var(--bg-primary)]/80 backdrop-blur-lg border-[var(--border-subtle)]"
        )}
      >
        <div className="site-container flex h-16 items-center justify-between">
          <SmoothScrollLink
            href="#top"
            className="flex items-center gap-2.5 rounded-full px-2.5 py-1.5 text-[var(--text-primary)] hover:bg-[var(--surface-glass)] transition-colors"
            onClick={closeMobileMenu}
          >
            <Image
              src="/app-icon-1024.png"
              alt=""
              width={28}
              height={28}
              className="rounded-md"
            />
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
                aria-label={link.ariaLabel}
                className="rounded-full px-3.5 py-2 text-[13px] font-medium text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--surface-glass-hover)] transition-colors"
                onClick={closeMobileMenu}
              >
                {link.label}
              </SmoothScrollLink>
            ))}
          </nav>

          <div className="flex items-center gap-2">
            {/* Mobile compact CTA -- visible only below md */}
            <a
              href={MAC_APP_STORE_URL}
              {...MAC_APP_STORE_LINK_PROPS}
              className="inline-flex md:hidden h-8 items-center rounded-xl bg-[var(--cta-bg)] px-3.5 text-[11.5px] font-semibold text-[var(--cta-text)] hover:bg-[var(--cta-bg-hover)] transition-all hover:-translate-y-px hover:shadow-md"
            >
              Download
            </a>

            {/* Desktop CTA */}
            <a
              href={MAC_APP_STORE_URL}
              {...MAC_APP_STORE_LINK_PROPS}
              className="hidden md:inline-flex h-9 items-center rounded-xl bg-[var(--cta-bg)] px-4 text-[12.5px] font-semibold text-[var(--cta-text)] transition-all hover:bg-[var(--cta-bg-hover)] hover:-translate-y-px hover:shadow-md"
            >
              Download for Mac
            </a>

            <button
              onClick={() => setIsMobileMenuOpen((open) => !open)}
              className="inline-flex h-9 w-9 items-center justify-center rounded-full text-[var(--text-primary)] hover:bg-[var(--surface-glass)] transition-colors md:hidden"
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
          "fixed inset-0 z-[110] bg-[var(--overlay-scrim)] transition-opacity md:hidden",
          isMobileMenuOpen
            ? "pointer-events-auto opacity-100"
            : "pointer-events-none opacity-0"
        )}
        onClick={closeMobileMenu}
        aria-hidden="true"
      />

      <div
        className={cn(
          "fixed inset-x-0 top-16 z-[121] border-b border-[var(--border-medium)] bg-[var(--bg-primary)]/98 px-4 py-4 shadow-[0_18px_40px_var(--shadow-color)] backdrop-blur-xl md:hidden transition-all duration-200",
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
              aria-label={link.ariaLabel}
              onClick={closeMobileMenu}
              className="rounded-xl px-3 py-2.5 text-[15px] font-medium text-[var(--text-secondary)] hover:bg-[var(--surface-glass)]"
            >
              {link.label}
            </SmoothScrollLink>
          ))}
          <a
            href={MAC_APP_STORE_URL}
            {...MAC_APP_STORE_LINK_PROPS}
            onClick={closeMobileMenu}
            className="mt-1 inline-flex h-11 items-center justify-center rounded-xl bg-[var(--cta-bg)] px-4 text-[14px] font-semibold text-[var(--cta-text)] hover:bg-[var(--cta-bg-hover)] transition-colors"
          >
            Download for Mac
          </a>
        </nav>
      </div>
    </>
  );
}

export default Header;
