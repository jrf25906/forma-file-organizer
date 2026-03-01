import type { Metadata } from "next";
import Link from "next/link";
import { TrackedMailtoLink } from "@/components/TrackedMailtoLink";
import { SUPPORT_EMAIL } from "@/lib/site";

export const metadata: Metadata = {
  title: "Support",
  description:
    "Get help with Forma setup, permissions, and organization workflows.",
  alternates: {
    canonical: "https://formafiles.com/support",
  },
};

export default function SupportPage() {
  return (
    <main id="main-content" className="bg-[#FAFAF8] py-14 md:py-20">
      <div className="site-container mx-auto max-w-4xl">
        <div className="rounded-2xl border border-[#E5E7EB] bg-[#F2F2F0] p-7 md:p-10">
          <h1 className="mb-4 text-4xl font-semibold tracking-[-0.02em] text-[#1C1C1E] md:text-5xl">
            Support
          </h1>
          <p className="mb-8 text-[16px] leading-relaxed text-[#555555]">
            Need help with Forma? Email us with your macOS version, what you
            expected, and what happened.
          </p>

          <div className="space-y-6 text-[16px] leading-relaxed text-[#555555]">
            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                Contact
              </h2>
              <p>
                <TrackedMailtoLink
                  email={SUPPORT_EMAIL}
                  location="support_page"
                  className="text-[#4A6B88] transition-opacity hover:opacity-80"
                >
                  {SUPPORT_EMAIL}
                </TrackedMailtoLink>
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                Quick fixes
              </h2>
              <ul className="list-disc pl-5 space-y-2">
                <li>
                  If a folder is not scanning, remove it and add it again in
                  Forma, then confirm access in macOS settings.
                </li>
                <li>
                  If a move fails, confirm the destination folder is available
                  and has enough free space.
                </li>
                <li>
                  If results look off, run preview again and adjust your rule
                  before approving changes.
                </li>
              </ul>
            </section>

            <section className="space-y-3">
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[#1C1C1E]">
                Guides
              </h2>
              <ul className="list-disc pl-5 space-y-2">
                <li>
                  <Link
                    href="/blog/organize-mac-files"
                    className="text-[#4A6B88] transition-opacity hover:opacity-80"
                  >
                    How to Organize Mac Files
                  </Link>
                </li>
                <li>
                  <Link
                    href="/blog/organize-downloads-folder-mac"
                    className="text-[#4A6B88] transition-opacity hover:opacity-80"
                  >
                    Organize Downloads Folder on Mac
                  </Link>
                </li>
                <li>
                  <Link
                    href="/blog/organize-desktop-files-mac"
                    className="text-[#4A6B88] transition-opacity hover:opacity-80"
                  >
                    Organize Desktop Files on Mac
                  </Link>
                </li>
              </ul>
            </section>
          </div>

          <div className="mt-12 border-t border-[#D9DDE2] pt-8">
            <Link
              href="/"
              className="text-sm text-[#646A75] transition-colors hover:text-[#4C5463]"
            >
              &larr; Back to home
            </Link>
          </div>
        </div>
      </div>
    </main>
  );
}
