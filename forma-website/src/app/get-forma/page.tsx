import type { Metadata } from "next";
import Link from "next/link";
import { MAC_APP_STORE_URL } from "@/lib/links";

export const metadata: Metadata = {
  title: "Get Forma",
  description:
    "Download Forma for Mac and get support with setup if needed.",
  alternates: {
    canonical: "https://formafiles.com/get-forma",
  },
};

export default function GetFormaPage() {
  const liveMacAppStoreUrl = MAC_APP_STORE_URL;

  return (
    <main id="main-content" className="bg-[#FAFAF8] py-14 md:py-20">
      <div className="site-container mx-auto max-w-4xl">
        <div className="rounded-2xl border border-[#E5E7EB] bg-[#F2F2F0] p-7 md:p-10">
          <h1 className="text-4xl font-semibold tracking-[-0.02em] text-[#1C1C1E] md:text-5xl">
            Download Forma for Mac
          </h1>
          <p className="mt-4 max-w-2xl text-[16px] leading-relaxed text-[#555555]">
            Forma is a native macOS file organizer for macOS 15 or later.
            Download it from the Mac App Store. Need help before or after installing?
            Contact support.
          </p>

          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <a
              href={liveMacAppStoreUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center rounded-[10px] bg-[#1C1C1E] px-6 py-3 text-sm font-semibold text-white transition-colors hover:bg-[#2A2A2D]"
            >
              Open Mac App Store
            </a>

            <Link
              href="/support"
              className="inline-flex items-center justify-center rounded-[10px] border border-[#D2D6DC] bg-[#F9F9F8] px-6 py-3 text-sm font-medium text-[#555555] transition-colors hover:border-[#BCC2CC] hover:text-[#1A1A1A]"
            >
              Contact Support
            </Link>
          </div>

          <div className="mt-10 border-t border-[#D9DDE2] pt-6">
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
