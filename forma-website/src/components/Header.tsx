import Link from "next/link";
import { FormaLogoImage } from "@/components/icons";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";

const NAV_LINKS = [
  { label: "Features", href: "/#features" },
  { label: "Pricing", href: "/#pricing" },
  { label: "Blog", href: "/blog" },
] as const;

export function Header() {
  return (
    <header
      role="banner"
      className="w-full border-b border-[#E5E5EA] bg-[#FAFAF8]"
    >
      <div className="mx-auto flex h-[73px] w-full max-w-[1440px] items-center justify-between px-5 sm:px-8 lg:px-20">
        <Link
          href="/#top"
          className="inline-flex items-center gap-[10px] text-[#1A1A1A]"
          aria-label="Forma home"
        >
          <FormaLogoImage size={22} />
          <span className="text-[17px] leading-5 tracking-[-0.02em] font-[650]">
            Forma
          </span>
        </Link>

        <div className="flex items-center gap-4 sm:gap-7">
          <nav className="hidden items-center gap-7 md:flex" aria-label="Main navigation">
            {NAV_LINKS.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="text-[13px] font-medium leading-4 text-[#555555] transition-colors hover:text-[#1A1A1A]"
              >
                {link.label}
              </Link>
            ))}
          </nav>

          <TrackedAppStoreLink
            location="header_desktop"
            className="inline-flex items-center rounded-[8px] bg-[#1C1C1E] px-4 py-2 text-[13px] font-medium leading-4 text-white transition-colors hover:bg-[#2A2A2D]"
          >
            Download for Mac
          </TrackedAppStoreLink>
        </div>
      </div>
    </header>
  );
}

export default Header;
