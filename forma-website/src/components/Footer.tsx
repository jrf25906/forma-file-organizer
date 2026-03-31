"use client";

import Link from "next/link";
import type { MouseEvent, ReactNode } from "react";
import { FormaLogoImage } from "@/components/icons";
import { SUPPORT_EMAIL } from "@/lib/site";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import { FormaShellCard } from "@/components/ui/forma-shell-card";
import { formaShellCtaVariants } from "@/components/ui/forma-shell-cta";
import { cn } from "@/lib/utils";

interface SmoothScrollLinkProps {
  href: string;
  className?: string;
  children: ReactNode;
}

function SmoothScrollLink({ href, className, children }: SmoothScrollLinkProps) {
  const handleClick = (e: MouseEvent<HTMLAnchorElement>) => {
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
    <footer
      className="border-t border-[var(--shell-border)] bg-[var(--bg-secondary)]"
      role="contentinfo"
    >
      <div className="site-container py-12 md:py-16">
        <FormaShellCard className="p-6 md:p-8 lg:p-10">
          <div className="grid gap-10 md:grid-cols-[1.25fr_1fr_auto] md:items-start">
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
                        className="inline-flex rounded-lg px-2 py-1.5 text-sm text-[var(--text-secondary)] transition-colors duration-200 hover:bg-[var(--shell-surface-muted)] hover:text-[var(--text-primary)]"
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
                        className="inline-flex rounded-lg px-2 py-1.5 text-sm text-[var(--text-secondary)] transition-colors duration-200 hover:bg-[var(--shell-surface-muted)] hover:text-[var(--text-primary)]"
                      >
                        {label}
                      </Link>
                    </li>
                  ))}
                </ul>
              </nav>
            </div>

            <div className="flex flex-col gap-3 md:items-end">
              <TrackedMailtoLink
                email={SUPPORT_EMAIL}
                location="footer"
                className={cn(
                  formaShellCtaVariants({ variant: "secondary" }),
                  "h-10 px-4 text-[13px] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forma-steel-blue focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--shell-surface)]"
                )}
              >
                {SUPPORT_EMAIL}
              </TrackedMailtoLink>
              <p className="text-xs text-[var(--text-muted)]">
                &copy; {currentYear} Forma. macOS app.
              </p>
            </div>
          </div>
        </FormaShellCard>
      </div>
    </footer>
  );
}
