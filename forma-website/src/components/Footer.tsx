"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { FormaLogoImage } from "@/components/icons";
import { SUPPORT_EMAIL } from "@/lib/site";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";

interface SmoothScrollLinkProps {
  href: string;
  className?: string;
  children: ReactNode;
}

function SmoothScrollLink({ href, className, children }: SmoothScrollLinkProps) {
  const handleClick = (e: React.MouseEvent<HTMLAnchorElement>) => {
    if (!href.startsWith("#")) return;

    e.preventDefault();
    const target = document.querySelector(href);
    if (target) {
      const y = target.getBoundingClientRect().top + window.scrollY - 100;
      window.scrollTo({ top: y, behavior: "smooth" });
      return;
    }

    const destination = href === "#top" ? "/" : `/${href}`;
    window.location.assign(destination);
  };

  return (
    <a href={href} className={className} onClick={handleClick}>
      {children}
    </a>
  );
}

const productLinks = [
  { label: "How it works", href: "#how-it-works" },
  { label: "Pricing", href: "#pricing" },
  { label: "FAQ", href: "#faq" },
  { label: "Guides", href: "/blog" },
] as const;

const legalLinks = [
  { label: "Privacy", href: "/privacy" },
  { label: "Terms", href: "/terms" },
  { label: "Support", href: "/support" },
  { label: "For Agents", href: "/for-agents" },
] as const;

export default function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-[var(--footer-bg)] border-t border-[var(--border-subtle)]" role="contentinfo">
      <div className="site-container py-12 md:py-16">
        <div className="grid gap-10 md:grid-cols-[1.4fr_1fr_auto] md:items-start">
          {/* Left: Logo + founder story */}
          <div className="flex items-start gap-4">
            <FormaLogoImage size={32} className="flex-shrink-0" />
            <p className="max-w-sm text-sm leading-relaxed text-[var(--text-secondary)]">
              Built by someone who got tired of seeing{" "}
              <span className="font-mono text-[var(--text-muted)]">
                Screenshot 2024-01-15 at 3.42.17 PM.png
              </span>{" "}
              fifty times on their desktop.
            </p>
          </div>

          {/* Center: Link columns */}
          <div className="grid grid-cols-2 gap-10 sm:max-w-sm">
            <nav aria-label="Product">
              <p className="mb-3 text-xs font-semibold uppercase tracking-[0.12em] text-[var(--text-muted)]">
                Product
              </p>
              <ul className="space-y-1">
                {productLinks.map(({ label, href }) => (
                  <li key={href}>
                    <SmoothScrollLink
                      href={href}
                      className="inline-block py-1.5 text-sm text-[var(--text-secondary)] transition-colors duration-200 hover:text-[var(--text-primary)]"
                    >
                      {label}
                    </SmoothScrollLink>
                  </li>
                ))}
              </ul>
            </nav>

            <nav aria-label="Legal">
              <p className="mb-3 text-xs font-semibold uppercase tracking-[0.12em] text-[var(--text-muted)]">
                Legal
              </p>
              <ul className="space-y-1">
                {legalLinks.map(({ label, href }) => (
                  <li key={href}>
                    <Link
                      href={href}
                      className="inline-block py-1.5 text-sm text-[var(--text-secondary)] transition-colors duration-200 hover:text-[var(--text-primary)]"
                    >
                      {label}
                    </Link>
                  </li>
                ))}
              </ul>
            </nav>
          </div>

          {/* Right: Contact + copyright */}
          <div className="flex flex-col gap-3 md:items-end">
            <TrackedMailtoLink
              email={SUPPORT_EMAIL}
              location="footer"
              className="text-sm text-[var(--text-secondary)] transition-colors duration-200 hover:text-[var(--text-primary)]"
            >
              {SUPPORT_EMAIL}
            </TrackedMailtoLink>
            <p className="text-xs text-[var(--text-muted)]">
              &copy; {currentYear} Forma. macOS app.
            </p>
          </div>
        </div>
      </div>
    </footer>
  );
}
