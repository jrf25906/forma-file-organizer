"use client";

import Link from "next/link";
import type { MouseEvent, ReactNode } from "react";
import { FormaLogoImage } from "@/components/icons";
import { SUPPORT_EMAIL } from "@/lib/site";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
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
      className="border-t border-[var(--rule-faint)] bg-[var(--canvas-parchment)]"
      role="contentinfo"
    >
      <div className="site-container py-12 md:py-16">
        <div className="grid gap-10 md:grid-cols-[1.25fr_1fr_auto] md:items-start">
          <div className="flex items-start gap-4">
            <FormaLogoImage size={32} className="flex-shrink-0" />
            <p className="max-w-sm text-sm leading-relaxed text-[var(--ink-secondary)]">
              Built by someone who got tired of seeing{" "}
              <span className="font-mono text-[var(--ink-faint)]">
                Screenshot 2024-01-15 at 3.42.17 PM.png
              </span>{" "}
              fifty times on their desktop.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-10 sm:max-w-sm">
            <nav aria-label="Product">
              <p className="eyebrow mb-3">Product</p>
              <ul className="space-y-1">
                {productLinks.map(({ label, href }) => (
                  <li key={href}>
                    <SmoothScrollLink
                      href={href}
                      className="inline-flex rounded-lg px-2 py-1.5 text-sm text-[var(--ink-secondary)] transition-colors duration-200 hover:bg-[var(--rule-faint)] hover:text-[var(--ink-primary)]"
                    >
                      {label}
                    </SmoothScrollLink>
                  </li>
                ))}
              </ul>
            </nav>

            <nav aria-label="Legal">
              <p className="eyebrow mb-3">Legal</p>
              <ul className="space-y-1">
                {legalLinks.map(({ label, href }) => (
                  <li key={href}>
                    <Link
                      href={href}
                      className="inline-flex rounded-lg px-2 py-1.5 text-sm text-[var(--ink-secondary)] transition-colors duration-200 hover:bg-[var(--rule-faint)] hover:text-[var(--ink-primary)]"
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
                "h-10 px-4 text-[13px] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forma-steel-blue focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--canvas-parchment)]"
              )}
            >
              {SUPPORT_EMAIL}
            </TrackedMailtoLink>
            <p className="text-xs text-[var(--ink-faint)]">
              &copy; {currentYear} Forma. macOS app.
            </p>
          </div>
        </div>
      </div>
    </footer>
  );
}
