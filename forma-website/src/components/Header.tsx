"use client";

import { useState } from "react";
import Link from "next/link";
import { MenuIcon, XIcon } from "lucide-react";
import { FormaLogoImage } from "@/components/icons";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetClose,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import { FormaShellCard } from "@/components/ui/forma-shell-card";
import { formaShellCtaVariants } from "@/components/ui/forma-shell-cta";
import { cn } from "@/lib/utils";

const NAV_LINKS = [
  { label: "How it works", href: "/#how-it-works" },
  { label: "Pricing", href: "/#pricing" },
  { label: "Blog", href: "/blog" },
] as const;

export function Header() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
      <header
        role="banner"
        data-header-shell="floating"
        className="fixed inset-x-0 top-0 z-50 pointer-events-none"
      >
        <div className="site-container pointer-events-auto pt-4 md:pt-5">
          <FormaShellCard className="flex h-[72px] items-center justify-between gap-3 px-4 md:px-5">
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

            <div className="flex items-center gap-2 sm:gap-3">
              <nav
                className="hidden items-center gap-1 rounded-full border border-[var(--shell-border)] bg-[var(--shell-surface-muted)] p-1 md:flex"
                aria-label="Main navigation"
              >
                {NAV_LINKS.map((link) => (
                  <Link
                    key={link.href}
                    href={link.href}
                    className="rounded-full px-3.5 py-2 text-[13px] font-medium leading-4 text-[var(--text-secondary)] transition-colors hover:bg-[var(--shell-surface)] hover:text-[var(--text-primary)]"
                  >
                    {link.label}
                  </Link>
                ))}
              </nav>

              <TrackedAppStoreLink
                location="header_desktop"
                className={cn(
                  formaShellCtaVariants({ variant: "primary" }),
                  "h-11 px-4 text-[13px] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forma-steel-blue focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--shell-surface)] sm:px-5"
                )}
              >
                Get Forma
              </TrackedAppStoreLink>

              <SheetTrigger asChild>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  aria-label={mobileOpen ? "Close navigation menu" : "Open navigation menu"}
                  className="h-11 w-11 border border-[var(--shell-border)] bg-[var(--shell-surface-muted)] text-[var(--text-primary)] hover:bg-[var(--shell-surface)] md:hidden"
                >
                  {mobileOpen ? <XIcon /> : <MenuIcon />}
                </Button>
              </SheetTrigger>
            </div>
          </FormaShellCard>
        </div>
      </header>

      <SheetContent
        side="right"
        className="w-[min(22rem,calc(100vw-1rem))] border-l border-[var(--shell-border)] bg-[var(--shell-surface)] px-4 pb-4 pt-14 text-[var(--text-primary)] shadow-[var(--shell-shadow-strong)] sm:max-w-none"
      >
        <SheetHeader className="p-0">
          <SheetTitle className="sr-only">Main navigation</SheetTitle>
          <SheetDescription className="sr-only">
            Navigate to the main sections of Forma.
          </SheetDescription>
        </SheetHeader>

        <nav aria-label="Mobile navigation" className="mt-2">
          <ul className="space-y-2">
            {NAV_LINKS.map((link) => (
              <li key={link.href}>
                <SheetClose asChild>
                  <Link
                    href={link.href}
                    className="flex items-center rounded-xl border border-transparent px-4 py-3 text-[15px] font-medium text-[var(--text-primary)] transition-colors hover:border-[var(--shell-border)] hover:bg-[var(--shell-surface-muted)]"
                  >
                    {link.label}
                  </Link>
                </SheetClose>
              </li>
            ))}
          </ul>
        </nav>
      </SheetContent>
    </Sheet>
  );
}

export default Header;
