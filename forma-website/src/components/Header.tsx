"use client";

import { useEffect, useState, type ReactNode } from "react";
import { Menu, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { FormaLogoImage } from "@/components/icons";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";

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
    if (!href.startsWith("#")) {
      onClick?.();
      return;
    }

    e.preventDefault();
    const target = document.querySelector(href);
    if (target) {
      const y = target.getBoundingClientRect().top + window.scrollY - 100;
      window.scrollTo({ top: y, behavior: "smooth" });
      onClick?.();
      return;
    }

    const destination = href === "#top" ? "/" : `/${href}`;
    window.location.assign(destination);
    onClick?.();
  };

  return (
    <a href={href} className={className} onClick={handleClick} aria-label={ariaLabel}>
      {children}
    </a>
  );
}

const NAV_LINKS = [
  {
    label: "Features",
    href: "#how-it-works",
    ariaLabel: "Jump to how it works section",
  },
  { label: "Pricing", href: "#pricing", ariaLabel: "Jump to pricing section" },
  { label: "FAQ", href: "#faq", ariaLabel: "Jump to frequently asked questions" },
  { label: "Guides", href: "/blog", ariaLabel: "Read organization guides" },
] as const;

export function Header() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setIsScrolled(window.scrollY > 24);
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
          "fixed inset-x-0 top-0 z-[120] transition-all duration-300",
          isScrolled
            ? "bg-transparent pt-2 md:pt-3"
            : "border-b border-[var(--border-subtle)] bg-[var(--bg-primary)]/80 backdrop-blur-lg"
        )}
      >
        <div className="site-container">
          <div
            className={cn(
              "mx-auto flex items-center justify-between transition-[height,background-color,box-shadow,border-color,width,max-width,transform,padding] duration-300",
              isScrolled
                ? "h-12 w-full md:w-[min(920px,calc(100%-1.5rem))] rounded-full border border-[var(--border-strong)] bg-[var(--bg-primary)]/98 px-3 shadow-[0_18px_44px_rgba(0,0,0,0.2)] ring-1 ring-[var(--border-medium)] backdrop-blur-2xl md:px-4"
                : "h-16 w-full"
            )}
          >
            <SmoothScrollLink
              href="#top"
              className="flex items-center gap-2.5 rounded-full px-2.5 py-1.5 text-[var(--text-primary)] hover:bg-[var(--surface-glass)] transition-colors"
              onClick={closeMobileMenu}
            >
              <FormaLogoImage size={isScrolled ? 24 : 28} />
              <span
                className={cn(
                  "font-display leading-none tracking-tight transition-all duration-300",
                  isScrolled ? "text-[16px]" : "text-[17px]"
                )}
              >
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
              <TrackedAppStoreLink
                location="header_mobile"
                className="inline-flex md:hidden h-8 items-center rounded-xl bg-[var(--cta-bg)] px-3.5 text-[11.5px] font-semibold text-[var(--cta-text)] hover:bg-[var(--cta-bg-hover)] transition-all hover:-translate-y-px hover:shadow-md"
              >
                Download
              </TrackedAppStoreLink>

              {/* Desktop CTA */}
              <TrackedAppStoreLink
                location="header_desktop"
                className={cn(
                  "hidden md:inline-flex items-center justify-center bg-[var(--cta-bg)] font-semibold text-[var(--cta-text)] transition-[height,padding,border-radius,background-color,transform,box-shadow] duration-300 hover:bg-[var(--cta-bg-hover)] hover:-translate-y-px",
                  isScrolled
                    ? "h-8 rounded-full px-3.5 text-[12px] shadow-[inset_0_0_0_1px_var(--border-subtle)]"
                    : "h-9 rounded-xl px-4 text-[12.5px] shadow-md"
                )}
              >
                Download for Mac
              </TrackedAppStoreLink>

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
          "fixed inset-x-0 z-[121] border-b border-[var(--border-medium)] bg-[var(--bg-primary)]/98 px-4 py-4 shadow-[0_18px_40px_var(--shadow-color)] backdrop-blur-xl md:hidden transition-all duration-200",
          isScrolled ? "top-14" : "top-16",
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
          <TrackedAppStoreLink
            location="header_menu"
            onClick={closeMobileMenu}
            className="mt-1 inline-flex h-11 items-center justify-center rounded-xl bg-[var(--cta-bg)] px-4 text-[14px] font-semibold text-[var(--cta-text)] hover:bg-[var(--cta-bg-hover)] transition-colors"
          >
            Download for Mac
          </TrackedAppStoreLink>
        </nav>
      </div>
    </>
  );
}

export default Header;
