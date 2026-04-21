"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
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
import { useHeaderShellMode } from "@/hooks/use-header-shell-mode";
import { HEADER_SHELL_LAYOUT } from "@/lib/header-shell-layout";
import { cn } from "@/lib/utils";

const NAV_LINKS = [
  { label: "How it works", href: "/#how-it-works" },
  { label: "Pricing", href: "/#pricing" },
  { label: "Blog", href: "/blog" },
] as const;

export function Header() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const pathname = usePathname();
  const homeShellMode = useHeaderShellMode(HEADER_SHELL_LAYOUT.scrollThreshold);
  const shellMode =
    pathname === "/"
      ? homeShellMode
      : HEADER_SHELL_LAYOUT.scrolledMode;
  const desktopNavVisible = shellMode === HEADER_SHELL_LAYOUT.scrolledMode;

  return (
    <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
      <header
        role="banner"
        data-header-shell="floating"
        data-header-shell-mode={shellMode}
        className="fixed inset-x-0 top-0 z-50 pointer-events-none"
      >
        <div className={`site-container pointer-events-auto ${HEADER_SHELL_LAYOUT.topInsetClassName}`}>
          <FormaShellCard
            tone="floating"
            data-shell-mode={shellMode}
            className={cn(
              HEADER_SHELL_LAYOUT.baseShellClassName,
              HEADER_SHELL_LAYOUT.cardHeightClassName,
              shellMode === HEADER_SHELL_LAYOUT.topMode
                ? HEADER_SHELL_LAYOUT.topStateShellClassName
                : HEADER_SHELL_LAYOUT.scrolledStateShellClassName
            )}
          >
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

            <nav
              aria-label="Main navigation"
              className={cn(
                HEADER_SHELL_LAYOUT.desktopNavClassName,
                desktopNavVisible
                  ? HEADER_SHELL_LAYOUT.desktopNavVisibleClassName
                  : HEADER_SHELL_LAYOUT.desktopNavHiddenClassName
              )}
            >
              {NAV_LINKS.map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  className="rounded-full px-3 py-2 text-[13px] font-medium leading-4 text-[var(--text-secondary)] transition-colors hover:bg-[var(--header-shell-surface-strong)] hover:text-[var(--text-primary)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forma-steel-blue focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--header-shell-surface)]"
                >
                  {link.label}
                </Link>
              ))}
            </nav>

            <div className="flex items-center justify-end gap-2 sm:gap-3">
              <TrackedAppStoreLink
                location="header_desktop"
                className={cn(
                  formaShellCtaVariants({ variant: "primary" }),
                  "h-10 px-4 text-[13px] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forma-steel-blue focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--header-shell-surface)] sm:px-5"
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
                  className="h-10 w-10 border border-[var(--header-shell-border)] bg-[var(--header-shell-surface-muted)] text-[var(--text-primary)] hover:bg-[var(--header-shell-surface-strong)] md:hidden"
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
