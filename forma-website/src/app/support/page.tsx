import type { Metadata } from "next";
import Link from "next/link";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import { FormaShellCard } from "@/components/ui/forma-shell-card";
import { formaShellCtaVariants } from "@/components/ui/forma-shell-cta";
import { HEADER_SHELL_LAYOUT } from "@/lib/header-shell-layout";
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
      className={`relative ${HEADER_SHELL_LAYOUT.routeClearanceClassName}`}
    >
      <section className="mx-auto w-full max-w-[1100px] px-6">
        <header className="space-y-4 border-b border-[var(--rule-faint)] pb-10">
          <p className="eyebrow">Support</p>
          <h1 className="display-lg text-[var(--ink-primary)] max-w-3xl">Support without a ticket maze</h1>
          <p className="prose-editorial max-w-2xl">
            Send what happened, what you expected, and your macOS version. We will help you get unstuck without making you fight the website first.
          </p>
        </header>

        <div className="mt-10 grid gap-6 lg:grid-cols-[0.92fr,1.08fr]">
          <FormaShellCard className="p-6 md:p-7">
            <h2 className="font-display text-[1.5rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
              Contact
            </h2>
            <p className="mt-3 max-w-sm text-[15px] leading-relaxed text-[var(--ink-secondary)]">
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
            <h2 className="font-display text-[1.5rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
              Quick fixes
            </h2>
            <ul className="mt-5 space-y-4 text-[15px] leading-relaxed text-[var(--ink-secondary)]">
              {quickFixes.map((item) => (
                <li
                  key={item}
                  className="border-t border-[var(--rule-faint)] pt-4 first:border-t-0 first:pt-0"
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
              <h2 className="font-display text-[1.5rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
                Guides
              </h2>
              <p className="mt-3 max-w-2xl text-[15px] leading-relaxed text-[var(--ink-secondary)]">
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
                  className="block rounded-xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] px-4 py-4 text-[15px] font-medium leading-relaxed text-[var(--ink-primary)] transition-colors hover:bg-[var(--canvas-parchment)]"
                >
                  {guide.label}
                </Link>
              </li>
            ))}
          </ul>
        </FormaShellCard>
      </section>
    </main>
  );
}
