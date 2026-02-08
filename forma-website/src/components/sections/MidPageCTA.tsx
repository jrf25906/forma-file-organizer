"use client";

import { MAC_APP_STORE_LINK_PROPS, MAC_APP_STORE_URL } from "@/lib/links";
import { Button } from "@/components/ui/Button";

interface MidPageCTAProps {
  /** Centered prompt text above the button */
  heading: string;
}

/**
 * A lightweight centered CTA row used between major sections.
 * Not a full section -- just a compact prompt with a download button.
 */
export default function MidPageCTA({ heading }: MidPageCTAProps) {
  return (
    <div className="py-16 md:py-20">
      <div className="site-container">
        <div className="flex flex-col items-center gap-5 text-center">
          <p className="font-display text-xl md:text-2xl text-forma-obsidian tracking-tight">
            {heading}
          </p>
          <Button
            href={MAC_APP_STORE_URL}
            {...MAC_APP_STORE_LINK_PROPS}
            size="md"
            className="hover:-translate-y-0.5 hover:shadow-lg hover:shadow-black/10"
          >
            Download for Mac
          </Button>
        </div>
      </div>
    </div>
  );
}
