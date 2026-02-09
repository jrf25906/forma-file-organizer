"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { GridLogo } from "@/components/icons";

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
    if (!target) return;

    const y = target.getBoundingClientRect().top + window.scrollY - 100;
    window.scrollTo({ top: y, behavior: "smooth" });
  };

  return (
    <a href={href} className={className} onClick={handleClick}>
      {children}
    </a>
  );
}

const productLinks = [
  { label: "Features", href: "#features" },
  { label: "Pricing", href: "#pricing" },
  { label: "FAQ", href: "#faq" },
] as const;

const legalLinks = [
  { label: "Privacy", href: "/privacy" },
  { label: "Terms", href: "/terms" },
  { label: "Support", href: "/support" },
] as const;

export default function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-forma-obsidian border-t border-forma-bone/10" role="contentinfo">
      <div className="mx-auto max-w-6xl px-6 py-10 md:px-8 md:py-12">
        <div className="grid gap-10 md:grid-cols-[1.4fr_1fr_auto] md:items-start">
          {/* Left: Logo + founder story */}
          <div className="flex items-start gap-4">
            <GridLogo size={5} gap={3} />
            <p className="max-w-sm text-sm leading-relaxed text-[rgba(250,250,248,0.65)]">
              Built by someone who got tired of seeing{" "}
              <span className="font-mono text-[rgba(250,250,248,0.6)]">
                Screenshot 2024-01-15 at 3.42.17 PM.png
              </span>{" "}
              fifty times on their desktop.
            </p>
          </div>

          {/* Center: Link columns */}
          <div className="grid grid-cols-2 gap-10 sm:max-w-sm">
            <nav aria-label="Product">
              <p className="mb-3 text-xs uppercase tracking-[0.08em] text-[rgba(250,250,248,0.55)]">
                Product
              </p>
              <ul className="space-y-2.5">
                {productLinks.map(({ label, href }) => (
                  <li key={href}>
                    <SmoothScrollLink
                      href={href}
                      className="text-sm text-[rgba(250,250,248,0.65)] transition-colors duration-200 hover:text-[rgba(250,250,248,0.82)]"
                    >
                      {label}
                    </SmoothScrollLink>
                  </li>
                ))}
              </ul>
            </nav>

            <nav aria-label="Legal">
              <p className="mb-3 text-xs uppercase tracking-[0.08em] text-[rgba(250,250,248,0.55)]">
                Legal
              </p>
              <ul className="space-y-2.5">
                {legalLinks.map(({ label, href }) => (
                  <li key={href}>
                    <Link
                      href={href}
                      className="text-sm text-[rgba(250,250,248,0.65)] transition-colors duration-200 hover:text-[rgba(250,250,248,0.82)]"
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
            <a
              href="mailto:hello@forma.app"
              className="text-sm text-[rgba(250,250,248,0.65)] transition-colors duration-200 hover:text-[rgba(250,250,248,0.82)]"
            >
              hello@forma.app
            </a>
            <p className="text-xs text-[rgba(250,250,248,0.55)]">
              &copy; {currentYear} Forma. macOS app.
            </p>
          </div>
        </div>
      </div>
    </footer>
  );
}
