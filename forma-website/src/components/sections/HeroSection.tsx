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
    <section className="relative pb-18 pt-18 md:pb-22 md:pt-22">
      <div className="pointer-events-none absolute inset-0" aria-hidden="true">
        <div
          className="absolute left-[-10%] top-[6%] h-[620px] w-[620px] rounded-full blur-[120px] opacity-10"
          style={{
            background:
              "radial-gradient(circle, rgba(91, 124, 153, 0.38) 0%, transparent 72%)",
          }}
        />
        <div
          className="absolute right-[-8%] top-[25%] h-[460px] w-[460px] rounded-full blur-[110px] opacity-8"
          style={{
            background:
              "radial-gradient(circle, rgba(122, 157, 126, 0.35) 0%, transparent 72%)",
          }}
        />
      </div>

      <div className="site-container relative">
        <div className="mx-auto max-w-[860px] text-center">
          <p className="mx-auto mb-7 inline-flex rounded-full border border-black/[0.08] bg-white/80 px-4 py-1.5 text-xs uppercase tracking-[0.08em] text-forma-obsidian/70">
            Built for messy desktops
          </p>

          <h1 className="mx-auto max-w-[760px] font-display text-[2.45rem] leading-[1.08] tracking-tight text-forma-obsidian sm:text-[2.95rem] lg:text-[3.45rem]">
            A file organizer for people who gave up on file organizers.
          </h1>

          <p className="mx-auto mt-7 max-w-[760px] text-lg leading-relaxed text-forma-obsidian/78 md:text-xl">
            Your desktop is a dumping ground. Your Downloads folder is worse.
            You&apos;ve tried to fix it before.
          </p>

          <p className="mx-auto mt-4 max-w-[760px] text-base leading-relaxed text-forma-obsidian/72 md:text-lg">
            You make rules. Forma follows them. Preview what&apos;s about to
            happen, approve it, and it&apos;s done. If you don&apos;t like it,
            undo it.
          </p>

          <div className="mt-10 flex flex-col items-center justify-center gap-3.5 sm:flex-row">
            <a
              href={MAC_APP_STORE_URL}
              {...MAC_APP_STORE_LINK_PROPS}
              className="inline-flex items-center gap-2.5 rounded-xl bg-forma-obsidian px-8 py-3.5 text-base font-semibold text-forma-bone shadow-lg shadow-black/10 transition-colors hover:bg-forma-obsidian/90"
            >
              <AppleLogo className="h-[17px] w-[14px]" />
              <span>Download for Mac</span>
            </a>

            <a
              href="#features"
              className="inline-flex items-center gap-2 rounded-xl border border-black/[0.12] bg-white/70 px-8 py-3.5 text-base font-medium text-forma-obsidian/85 transition-colors hover:bg-white hover:text-forma-obsidian"
            >
              See how it works
            </a>
          </div>
        </div>

        <div className="mx-auto mt-11 max-w-[1080px] rounded-[28px] border border-black/[0.08] bg-white/85 p-2 shadow-[0_20px_54px_rgba(0,0,0,0.09)] backdrop-blur-sm md:mt-13 md:p-3">
          <MacWindowFrame className="w-full">
            <AppScreenshot />
          </MacWindowFrame>
        </div>
      </div>
    </section>
  );
}
