"use client";

import Link from "next/link";

function GridLogo() {
  const opacities = [1, 1, 1, 0.7, 0.7, 0.7, 0.4, 0.4, 0.4];

  return (
    <div className="grid grid-cols-3 gap-[3px]">
      {opacities.map((opacity, i) => (
        <div
          key={i}
          className="forma-logo-dot h-[5px] w-[5px] rounded-full"
          style={{ opacity }}
        />
      ))}
    </div>
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
  return (
    <footer
      className="fixed inset-x-0 bottom-0 z-[-1] h-[220px] bg-forma-obsidian"
      role="contentinfo"
    >
      <div className="mx-auto flex h-full max-w-6xl items-center justify-between px-8">
        {/* Left: Logo + founder story */}
        <div className="flex items-start gap-5">
          <div className="mt-[3px]">
            <GridLogo />
          </div>
          <p className="max-w-[300px] text-[13px] leading-relaxed text-forma-bone/50">
            Built by someone who got tired of seeing{" "}
            <span className="font-mono text-forma-bone/50">
              Screenshot 2024-01-15 at 3.42.17 PM.png
            </span>{" "}
            fifty times on their desktop.
          </p>
        </div>

        {/* Center: Link columns */}
        <div className="flex gap-16">
          {/* Product links */}
          <nav aria-label="Product">
            <ul className="flex flex-col gap-2.5">
              {productLinks.map(({ label, href }) => (
                <li key={href}>
                  <a
                    href={href}
                    className="text-[13px] text-forma-bone/40 transition-colors duration-200 hover:text-forma-bone/60"
                  >
                    {label}
                  </a>
                </li>
              ))}
            </ul>
          </nav>

          {/* Legal links */}
          <nav aria-label="Legal">
            <ul className="flex flex-col gap-2.5">
              {legalLinks.map(({ label, href }) => (
                <li key={href}>
                  <Link
                    href={href}
                    className="text-[13px] text-forma-bone/40 transition-colors duration-200 hover:text-forma-bone/60"
                  >
                    {label}
                  </Link>
                </li>
              ))}
            </ul>
          </nav>
        </div>

        {/* Right: Contact + copyright */}
        <div className="flex flex-col items-end gap-3">
          <a
            href="mailto:hello@forma.app"
            className="text-[13px] text-forma-bone/40 transition-colors duration-200 hover:text-forma-bone/60"
          >
            hello@forma.app
          </a>
          <p className="text-[12px] text-forma-bone/40">
            &copy; 2026 Forma. macOS app.
          </p>
        </div>
      </div>
    </footer>
  );
}
