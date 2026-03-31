import type { Metadata } from "next";
import Link from "next/link";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import { FormaShellCard } from "@/components/ui/forma-shell-card";
import { formaShellCtaVariants } from "@/components/ui/forma-shell-cta";
import { SUPPORT_EMAIL } from "@/lib/site";
import { cn } from "@/lib/utils";

export const metadata: Metadata = {
  title: "Support",
  description:
    "Get help with Forma setup, permissions, and organization workflows.",
  alternates: {
    canonical: "https://formafiles.com/support",
  },
};

const quickFixes = [
  "If a folder is not scanning, remove it and add it again in Forma, then confirm access in macOS settings.",
  "If a move fails, confirm the destination folder is available and has enough free space.",
  "If results look off, run preview again and adjust your rule before approving changes.",
] as const;

const guides = [
  {
    href: "/blog/organize-mac-files",
    label: "How to Organize Mac Files",
  },
  {
    href: "/blog/organize-downloads-folder-mac",
    label: "Organize Downloads Folder on Mac",
  },
  {
    href: "/blog/organize-desktop-files-mac",
    label: "Organize Desktop Files on Mac",
  },
] as const;

export default function SupportPage() {
  return (
    <main
      id="main-content"
      className="relative border-y border-[var(--shell-border)] bg-[var(--bg-secondary)] py-20 md:py-24"
    >
      <div className="site-container mx-auto max-w-5xl">
        <div className="rounded-[2rem] border border-[var(--shell-border)] bg-[var(--shell-surface-muted)] p-5 shadow-[var(--shell-shadow-soft)] md:p-6">
          <header className="border-b border-[var(--shell-border)] pb-8 md:pb-10">
            <div className="max-w-3xl space-y-3">
              <p className="text-[11px] font-semibold tracking-[0.15em] uppercase text-forma-steel-blue">
                Support
              </p>
              <h1 className="font-display text-[1.875rem] leading-[1.1] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem]">
                Support without a ticket maze
              </h1>
              <p className="max-w-2xl text-[15px] leading-relaxed text-[var(--text-secondary)]">
                Send what happened, what you expected, and your macOS version. We will help you get
                unstuck without making you fight the website first.
              </p>
            </div>
          </header>

          <div className="mt-6 grid gap-5 lg:grid-cols-[0.92fr,1.08fr]">
            <FormaShellCard className="p-6 md:p-7">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
                Contact
              </h2>
              <p className="mt-3 max-w-sm text-[15px] leading-relaxed text-[var(--text-secondary)]">
                Include the folder involved, what rule or action you ran, and whether the issue is
                repeatable.
              </p>
              <p className="mt-6">
                <TrackedMailtoLink
                  email={SUPPORT_EMAIL}
                  location="support_page"
                  className={cn(
                    formaShellCtaVariants({ variant: "secondary" }),
                    "h-auto min-h-11 px-4 py-3 text-[15px]"
                  )}
                >
                  {SUPPORT_EMAIL}
                </TrackedMailtoLink>
              </p>
            </FormaShellCard>

            <FormaShellCard className="p-6 md:p-7">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
                Quick fixes
              </h2>
              <ul className="mt-5 space-y-4 text-[15px] leading-relaxed text-[var(--text-secondary)]">
                {quickFixes.map((item) => (
                  <li
                    key={item}
                    className="border-t border-[var(--shell-border)] pt-4 first:border-t-0 first:pt-0"
                  >
                    {item}
                  </li>
                ))}
              </ul>
            </FormaShellCard>
          </div>

          <FormaShellCard className="mt-5 p-6 md:p-7">
            <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
              <div>
                <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
                  Guides
                </h2>
                <p className="mt-3 max-w-2xl text-[15px] leading-relaxed text-[var(--text-secondary)]">
                  If you want the workflow behind the product instead of just the fix, start here.
                </p>
              </div>

              <Link
                href="/"
                className={cn(
                  formaShellCtaVariants({ variant: "ghost" }),
                  "h-11 px-0 text-[14px] lg:px-4"
                )}
              >
                &larr; Back to home
              </Link>
            </div>

            <ul className="mt-6 grid gap-3 md:grid-cols-3">
              {guides.map((guide) => (
                <li key={guide.href}>
                  <Link
                    href={guide.href}
                    className="block rounded-xl border border-[var(--shell-border)] bg-[var(--shell-surface-muted)] px-4 py-4 text-[15px] font-medium leading-relaxed text-[var(--text-primary)] transition-colors hover:bg-[var(--shell-surface)]"
                  >
                    {guide.label}
                  </Link>
                </li>
              ))}
            </ul>
          </FormaShellCard>
        </div>
      </div>
    </main>
  );
}
