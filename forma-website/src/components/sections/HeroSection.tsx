"use client";

import Image from "next/image";
import MacWindowFrame from "@/components/ui/MacWindowFrame";
import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";

function AppleLogo({ className = "" }: { className?: string }) {
  return (
    <svg
      className={className}
      width="14"
      height="17"
      viewBox="0 0 14 17"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <path d="M13.3 13.16c-.31.71-.67 1.36-1.09 1.96-.57.81-1.04 1.37-1.4 1.68-.56.51-1.16.77-1.8.79-.46 0-1.02-.13-1.67-.4-.65-.26-1.25-.4-1.8-.4-.57 0-1.19.14-1.84.4-.66.27-1.19.41-1.59.43-.62.03-1.23-.24-1.84-.82-.39-.34-.88-.92-1.47-1.75C.27 14.3-.12 13.43-.12 12.5c0-1.06.23-1.97.69-2.73a4.02 4.02 0 0 1 3.37-2.02c.49 0 1.13.15 1.93.44.8.3 1.31.44 1.53.44.17 0 .73-.17 1.68-.51.9-.32 1.65-.45 2.27-.4 1.68.14 2.94.81 3.78 2.02-1.5.91-2.24 2.19-2.22 3.82.02 1.27.47 2.33 1.37 3.16.41.39.86.69 1.37.9-.11.32-.23.62-.35.93zM10.2.34c0 1-.36 1.93-1.09 2.8-.87 1.03-1.93 1.62-3.07 1.53a3.1 3.1 0 0 1-.02-.37c0-.96.42-1.98 1.16-2.82.37-.42.84-.77 1.42-1.06.57-.28 1.11-.43 1.62-.46.01.13.02.25.02.38h-.04z" />
    </svg>
  );
}

function AppScreenshot() {
  return (
    <Image
      src="/screenshots/light/forma-01-hero-main-window.png"
      alt="Forma app main window showing file organization rules and preview"
      width={1280}
      height={800}
      className="w-full h-auto"
      priority
    />
  );
}

export default function HeroSection() {
  return (
    <section className="relative pt-16 pb-16 md:pt-20 md:pb-20">

      <div className="site-container relative">
        <div className="mx-auto max-w-[820px] text-center">
          <h1 className="mx-auto max-w-[720px] font-display text-[2.75rem] leading-[1.08] tracking-[-0.025em] text-forma-obsidian text-balance sm:text-[3.5rem] lg:text-[4.25rem]">
            A file organizer for people who gave up on file organizers.
          </h1>

          <p className="mx-auto mt-6 max-w-[580px] text-lg leading-relaxed text-forma-obsidian/60 md:text-[1.2rem]">
            You make rules. Forma follows them. Preview what happens,
            approve it, undo anything.
          </p>

          <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <a
              href={MAC_APP_STORE_URL}
              {...MAC_APP_STORE_LINK_PROPS}
              className="inline-flex items-center gap-2.5 rounded-xl bg-forma-obsidian px-8 py-3.5 text-[16px] font-semibold text-forma-bone shadow-lg shadow-black/10 transition-all duration-300 hover:bg-forma-obsidian/90 hover:-translate-y-px hover:shadow-xl hover:shadow-black/15 active:translate-y-0"
            >
              <AppleLogo className="h-[15px] w-[12px]" />
              <span>Download for Mac</span>
            </a>

            <a
              href="#features"
              className="inline-flex items-center gap-2 rounded-xl border border-black/[0.12] px-8 py-3.5 text-[16px] font-medium text-forma-obsidian/70 transition-colors hover:text-forma-obsidian hover:border-black/[0.22]"
            >
              See how it works
            </a>
          </div>

          <p className="mt-5 border-t border-black/[0.04] pt-3 text-[13px] text-forma-obsidian/50 inline-block">
            $29 once. macOS 14+. No subscription.
          </p>
        </div>

        <div className="relative app-mockup-glow mx-auto mt-14 max-w-[980px] rounded-2xl border border-black/[0.08] bg-white/80 p-1.5 shadow-[0_0_0_1px_rgba(0,0,0,0.03),0_2px_4px_rgba(0,0,0,0.04),0_12px_32px_rgba(0,0,0,0.08),0_32px_80px_rgba(0,0,0,0.12)] backdrop-blur-sm md:mt-16 md:rounded-[20px] md:p-2">
          <MacWindowFrame className="w-full">
            <AppScreenshot />
          </MacWindowFrame>
        </div>
      </div>
    </section>
  );
}
