"use client";

import { useState, useCallback, useEffect, useRef } from "react";
import Link from "next/link";
import { FormaLogoImage } from "@/components/icons";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";

const NAV_LINKS = [
  { label: "How it works", href: "/#how-it-works" },
  { label: "Pricing", href: "/#pricing" },
  { label: "Blog", href: "/blog" },
] as const;

export function Header() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const hamburgerRef = useRef<HTMLButtonElement>(null);
  const navRef = useRef<HTMLElement>(null);

  const closeMobile = useCallback(() => {
    setMobileOpen(false);
    hamburgerRef.current?.focus();
  }, []);

  // Close on Escape key
  useEffect(() => {
    if (!mobileOpen) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeMobile();
    };
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [mobileOpen, closeMobile]);

  // Close on route change (hash navigation)
  useEffect(() => {
    if (!mobileOpen) return;
    const onHashChange = () => closeMobile();
    window.addEventListener("hashchange", onHashChange);
    return () => window.removeEventListener("hashchange", onHashChange);
  }, [mobileOpen, closeMobile]);

  // Prevent scroll when mobile menu is open
  useEffect(() => {
    if (mobileOpen) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => { document.body.style.overflow = ""; };
  }, [mobileOpen]);

  // Move focus into nav when opened
  useEffect(() => {
    if (mobileOpen && navRef.current) {
      const firstLink = navRef.current.querySelector<HTMLElement>("a");
      firstLink?.focus();
    }
  }, [mobileOpen]);

  return (
    <header
      role="banner"
      className="w-full border-b border-[var(--border-subtle)] bg-[var(--bg-primary)]"
    >
      <div className="site-container flex h-[73px] items-center justify-between">
        <Link
          href="/#top"
          className="inline-flex items-center gap-[10px] text-[var(--text-primary)]"
          aria-label="Forma home"
        >
          <FormaLogoImage size={22} priority />
          <span className="text-[17px] leading-5 tracking-[-0.02em] font-[650]">
            Forma
          </span>
        </Link>

        <div className="flex items-center gap-4 sm:gap-7">
          {/* Desktop nav */}
          <nav className="hidden items-center gap-7 md:flex" aria-label="Main navigation">
            {NAV_LINKS.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="text-[14px] font-medium leading-4 text-[var(--text-secondary)] transition-colors hover:text-[var(--text-primary)]"
              >
                {link.label}
              </Link>
            ))}
          </nav>

          <TrackedAppStoreLink
            location="header_desktop"
            className="inline-flex items-center rounded-lg bg-gradient-to-br from-[#944A35] to-[#A86048] px-4 py-2 text-[13px] font-medium leading-4 text-white transition-[transform,box-shadow,filter] duration-200 ease-out will-change-transform hover:brightness-110 active:scale-[0.97] min-h-[44px]"
          >
            Download for Mac
          </TrackedAppStoreLink>

          {/* Mobile hamburger */}
          <button
            ref={hamburgerRef}
            onClick={() => setMobileOpen((prev) => !prev)}
            aria-expanded={mobileOpen}
            aria-controls="mobile-nav"
            aria-label={mobileOpen ? "Close menu" : "Open menu"}
            className="flex h-11 w-11 items-center justify-center rounded-lg transition-colors hover:bg-[var(--surface-glass-hover)] md:hidden"
          >
            <svg width="18" height="14" viewBox="0 0 18 14" fill="none" aria-hidden="true">
              <line
                x1="0" y1="1" x2="18" y2="1"
                stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"
                className="origin-center transition-transform duration-200"
                style={mobileOpen ? { transform: "translateY(6px) rotate(45deg)" } : undefined}
              />
              <line
                x1="0" y1="7" x2="18" y2="7"
                stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"
                className="transition-opacity duration-200"
                style={mobileOpen ? { opacity: 0 } : undefined}
              />
              <line
                x1="0" y1="13" x2="18" y2="13"
                stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"
                className="origin-center transition-transform duration-200"
                style={mobileOpen ? { transform: "translateY(-6px) rotate(-45deg)" } : undefined}
              />
            </svg>
          </button>
        </div>
      </div>

      {/* Mobile nav panel — always in DOM for aria-controls, hidden when closed */}
      <nav
        ref={navRef}
        id="mobile-nav"
        aria-label="Mobile navigation"
        hidden={!mobileOpen}
        className="border-t border-[var(--border-subtle)] bg-[var(--bg-primary)] px-5 pb-6 pt-4 md:hidden"
      >
        <ul className="flex flex-col gap-1">
          {NAV_LINKS.map((link) => (
            <li key={link.href}>
              <Link
                href={link.href}
                onClick={closeMobile}
                className="block rounded-lg px-3 py-2.5 text-[15px] font-medium text-[var(--text-secondary)] transition-colors hover:bg-[var(--surface-glass)] hover:text-[var(--text-primary)]"
              >
                {link.label}
              </Link>
            </li>
          ))}
        </ul>
      </nav>
    </header>
  );
}

export default Header;
