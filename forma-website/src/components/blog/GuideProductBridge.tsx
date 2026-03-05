"use client";

import Image from "next/image";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";
import { cn } from "@/lib/utils";

const guideWorkflow = [
  "Write the rule in plain language.",
  "Review every proposed file move before it runs.",
  "Undo the whole batch if the result is wrong.",
] as const;

const proofChips = [
  "$29 once",
  "Local-only",
  "No account",
  "Preview-first",
] as const;

type GuideProductBridgeProps = {
  eyebrow: string;
  title: string;
  body: string;
  eventLocation: string;
  slug?: string;
  className?: string;
};

export default function GuideProductBridge({
  eyebrow,
  title,
  body,
  eventLocation,
  slug,
  className,
}: GuideProductBridgeProps) {
  return (
    <section
      className={cn(
        "overflow-hidden rounded-[2rem] border border-[var(--border-subtle)] bg-[linear-gradient(180deg,rgba(255,255,255,0.78)_0%,rgba(255,255,255,0.48)_100%)] p-6 shadow-[0_18px_40px_rgba(15,18,24,0.05)] md:p-8",
        className
      )}
    >
      <div className="grid items-center gap-8 lg:grid-cols-2 xl:grid-cols-[0.92fr,1.08fr]">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-forma-steel-blue">
            {eyebrow}
          </p>
          <h2 className="mt-4 text-3xl font-semibold tracking-[-0.03em] text-[var(--text-primary)] md:text-[3rem]">
            {title}
          </h2>
          <p className="mt-4 max-w-xl text-base leading-relaxed text-[var(--text-secondary)]">
            {body}
          </p>

          <ul className="mt-6 space-y-3">
            {guideWorkflow.map((item) => (
              <li key={item} className="flex items-start gap-3">
                <span className="mt-[6px] h-2 w-2 rounded-full bg-forma-sage" />
                <span className="text-sm leading-relaxed text-[var(--text-secondary)]">{item}</span>
              </li>
            ))}
          </ul>

          <div className="mt-6 flex flex-wrap gap-2">
            {proofChips.map((item) => (
              <span
                key={item}
                className="rounded-full border border-[var(--border-medium)] bg-[rgba(255,255,255,0.72)] px-3 py-1.5 text-xs font-medium text-[var(--text-secondary)]"
              >
                {item}
              </span>
            ))}
          </div>

          <div className="mt-6">
            <TrackedAppStoreLink
              location="blog_inline"
              extraEvents={[
                {
                  name: "blog_cta_click",
                  props: {
                    location: eventLocation,
                    ...(slug ? { slug } : {}),
                  },
                },
              ]}
              className="inline-flex items-center rounded-xl bg-[var(--cta-bg)] px-5 py-3 text-sm font-semibold text-[var(--cta-text)] transition-colors hover:bg-[var(--cta-bg-hover)]"
            >
              Download Forma for Mac
            </TrackedAppStoreLink>
          </div>
        </div>

        <div className="overflow-hidden rounded-[1.5rem] border border-[var(--border-medium)] bg-[var(--bg-secondary)] lg:justify-self-end">
          <Image
            src="/screenshots/story/forma-paper-03-preview.png"
            alt="Forma preview queue showing file moves before approval"
            width={1312}
            height={900}
            className="h-auto w-full"
          />
        </div>
      </div>
    </section>
  );
}
