import type { Metadata } from "next";
import Link from "next/link";
import { HEADER_SHELL_LAYOUT } from "@/lib/header-shell-layout";
import { PUBLIC_API_VERSION, SITE_URL } from "@/lib/site";
import { formaShellCtaVariants } from "@/components/ui/forma-shell-cta";
import { cn } from "@/lib/utils";

export const metadata: Metadata = {
  title: "For Agents & Integrations",
  description:
    "Public machine-readable endpoints and usage guidance for AI agents and integrations.",
  alternates: {
    canonical: `${SITE_URL}/for-agents`,
  },
  robots: {
    index: true,
    follow: true,
  },
};

const endpoints = [
  {
    path: "/llms.txt",
    method: "GET",
    description: "Index of canonical resources for language models and agents.",
  },
  {
    path: "/api/public/product",
    method: "GET",
    description: "Current product summary, pricing, and download link.",
  },
  {
    path: "/api/public/faq",
    method: "GET",
    description: "FAQ collection with stable IDs and update timestamps.",
  },
  {
    path: "/api/public/faq/{id}",
    method: "GET",
    description: "Fetch one FAQ item by ID.",
  },
  {
    path: "/openapi.json",
    method: "GET",
    description: "OpenAPI schema for public endpoints.",
  },
  {
    path: "/api/newsletter",
    method: "POST",
    description: "Newsletter signup endpoint documented in OpenAPI.",
  },
];

const routeSignals = [
  "Public only",
  `Version ${PUBLIC_API_VERSION}`,
  "Canonical resources",
  "Stable endpoint surface",
] as const;

const usageGuardrails = [
  "Respect robots directives and page metadata.",
  "Use legal pages as the canonical policy source.",
  "Assume access to public marketing endpoints only.",
  "Do not send sensitive user data through third-party systems without explicit user consent.",
] as const;

export default function ForAgentsPage() {
  return (
    <main id="main-content" className={`relative ${HEADER_SHELL_LAYOUT.routeClearanceClassName}`}>
      <section className="mx-auto w-full max-w-[1200px] px-6">
        <header className="border-b border-[var(--rule-faint)] pb-12 md:pb-16">
          <div className="grid gap-10 lg:grid-cols-[1.05fr,0.95fr]">
            <div>
              <p className="eyebrow">For agents and integrations</p>
              <h1 className="display-lg mt-5 text-[var(--ink-primary)]">
                Stable public endpoints for agents that need the product truth
              </h1>
              <p className="prose-editorial mt-5">
                Machine-readable resources for crawlers, agents, and automation systems. This
                route exists so integrations can use current product and policy data without
                scraping guesswork.
              </p>

              <div className="mt-8 flex flex-wrap gap-2">
                {routeSignals.map((signal) => (
                  <span
                    key={signal}
                    className="rounded-full border border-[var(--rule-faint)] bg-[var(--canvas-bone)] px-3 py-1.5 text-xs font-medium text-[var(--ink-secondary)]"
                  >
                    {signal}
                  </span>
                ))}
              </div>

              <div className="mt-8 flex flex-col gap-3 sm:flex-row">
                <a
                  className={cn(formaShellCtaVariants({ variant: "primary" }), "h-11 px-5 text-sm")}
                  href={`${SITE_URL}/openapi.json`}
                >
                  Open schema
                </a>
                <Link
                  href="/"
                  className={cn(formaShellCtaVariants({ variant: "secondary" }), "h-11 px-5 text-sm")}
                >
                  See the product
                </Link>
              </div>
            </div>

            <aside className="rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] p-6">
              <p className="eyebrow">Route intent</p>
              <ul className="mt-4 space-y-3">
                <li className="text-sm leading-relaxed text-[var(--ink-secondary)]">
                  Pull stable product, FAQ, and schema data without parsing marketing layouts.
                </li>
                <li className="text-sm leading-relaxed text-[var(--ink-secondary)]">
                  Use current version metadata before caching public endpoint responses.
                </li>
                <li className="text-sm leading-relaxed text-[var(--ink-secondary)]">
                  Treat this surface as public-only documentation, not a private integration API.
                </li>
              </ul>
            </aside>
          </div>
        </header>

        <section className="mt-12 rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] p-6 md:p-8">
          <div className="flex flex-col gap-3 border-b border-[var(--rule-faint)] pb-5 md:flex-row md:items-end md:justify-between">
            <div>
              <h2 className="font-display text-[1.5rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
                Endpoint catalog
              </h2>
              <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--ink-secondary)]">
                Mobile gets scanable endpoint cards. Desktop keeps the full table for quick
                comparison.
              </p>
            </div>
            <p className="text-xs uppercase tracking-[0.14em] text-[var(--ink-faint)]">
              Current API version: {PUBLIC_API_VERSION}
            </p>
          </div>

          <div className="mt-5 grid gap-3 md:hidden">
            {endpoints.map((endpoint) => (
              <article
                key={endpoint.path}
                className="rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-paper)] p-5"
              >
                <div className="flex items-center justify-between gap-3">
                  <span className="rounded-full border border-[var(--rule-strong)] px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-forma-steel-blue">
                    {endpoint.method}
                  </span>
                  <span className="text-[11px] uppercase tracking-[0.14em] text-[var(--ink-faint)]">
                    Public
                  </span>
                </div>
                <code className="mt-4 block rounded-xl bg-[var(--canvas-bone)] px-3 py-3 text-[13px] leading-relaxed text-[var(--ink-primary)]">
                  {endpoint.path}
                </code>
                <p className="mt-3 text-sm leading-relaxed text-[var(--ink-secondary)]">
                  {endpoint.description}
                </p>
              </article>
            ))}
          </div>

          <div
            className="mt-5 hidden overflow-x-auto rounded-lg md:block"
            role="region"
            aria-label="Endpoint catalog table"
            tabIndex={0}
          >
            <table className="w-full min-w-[640px] text-left text-sm">
              <thead>
                <tr className="border-b border-[var(--rule-faint)] text-[var(--ink-faint)]">
                  <th className="py-2 pr-4 font-medium">Method</th>
                  <th className="py-2 pr-4 font-medium">Path</th>
                  <th className="py-2 font-medium">Description</th>
                </tr>
              </thead>
              <tbody>
                {endpoints.map((endpoint) => (
                  <tr key={endpoint.path} className="border-b border-[var(--rule-faint)]">
                    <td className="py-3 pr-4 text-[var(--ink-secondary)]">
                      {endpoint.method}
                    </td>
                    <td className="py-3 pr-4">
                      <code className="rounded-md bg-[var(--canvas-paper)] px-2 py-1 text-[var(--ink-primary)]">
                        {endpoint.path}
                      </code>
                    </td>
                    <td className="py-3 text-[var(--ink-secondary)]">
                      {endpoint.description}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <div className="mt-8 grid gap-6 lg:grid-cols-[0.92fr,1.08fr]">
          <section className="rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] p-6 md:p-7">
            <h2 className="font-display text-[1.5rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
              Usage guardrails
            </h2>
            <ul className="mt-4 space-y-3">
              {usageGuardrails.map((item) => (
                <li key={item} className="flex items-start gap-3">
                  <span className="mt-[6px] h-2 w-2 rounded-full bg-forma-sage" />
                  <span className="text-sm leading-relaxed text-[var(--ink-secondary)]">{item}</span>
                </li>
              ))}
            </ul>
          </section>

          <section className="rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] p-6 md:p-7">
            <h2 className="font-display text-[1.5rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
              Canonical resources
            </h2>
            <ul className="mt-4 space-y-4 text-sm">
              <li>
                <a className="text-forma-steel-blue hover:underline" href={`${SITE_URL}/llms.txt`}>
                  {SITE_URL}/llms.txt
                </a>
                <p className="mt-1 leading-relaxed text-[var(--ink-secondary)]">
                  Index of machine-readable site resources for language models and agents.
                </p>
              </li>
              <li>
                <a className="text-forma-steel-blue hover:underline" href={`${SITE_URL}/openapi.json`}>
                  {SITE_URL}/openapi.json
                </a>
                <p className="mt-1 leading-relaxed text-[var(--ink-secondary)]">
                  OpenAPI schema for the public endpoint surface documented on this page.
                </p>
              </li>
              <li>
                <Link className="text-forma-steel-blue hover:underline" href="/blog">
                  /blog
                </Link>
                <p className="mt-1 leading-relaxed text-[var(--ink-secondary)]">
                  Canonical guides for human-readable workflows and supporting product context.
                </p>
              </li>
            </ul>
          </section>
        </div>

        <div className="mt-10">
          <Link
            href="/"
            className="text-sm text-[var(--ink-faint)] transition-colors hover:text-[var(--ink-secondary)]"
          >
            &larr; Back to home
          </Link>
        </div>
      </section>
    </main>
  );
}
