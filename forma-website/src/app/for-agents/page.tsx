import type { Metadata } from "next";
import Link from "next/link";
import { HEADER_SHELL_LAYOUT } from "@/lib/header-shell-layout";
import { PUBLIC_API_VERSION, SITE_URL } from "@/lib/site";

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
      <div className="site-container mx-auto max-w-5xl">
        <header className="overflow-hidden rounded-[2rem] border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-7 md:p-10">
          <div className="grid gap-8 lg:grid-cols-[1.05fr,0.95fr]">
            <div>
              <p className="mb-3 text-xs uppercase tracking-[0.14em] text-forma-steel-blue">
                For agents and integrations
              </p>
              <h1 className="text-4xl font-semibold tracking-[-0.03em] text-[var(--text-primary)] md:text-5xl">
                Stable public endpoints for agents that need the product truth
              </h1>
              <p className="mt-4 max-w-3xl text-base leading-relaxed text-[var(--text-secondary)]">
                Machine-readable resources for crawlers, agents, and automation systems. This
                route exists so integrations can use current product and policy data without
                scraping guesswork.
              </p>

              <div className="mt-6 flex flex-wrap gap-2">
                {routeSignals.map((signal) => (
                  <span
                    key={signal}
                    className="rounded-full border border-[var(--border-medium)] bg-[var(--surface-glass)] px-3 py-1.5 text-xs font-medium text-[var(--text-secondary)]"
                  >
                    {signal}
                  </span>
                ))}
              </div>

              <div className="mt-6 flex flex-col gap-3 sm:flex-row">
                <a
                  className="inline-flex items-center justify-center rounded-xl bg-[var(--cta-bg)] px-5 py-3 text-sm font-semibold text-[var(--cta-text)] transition-colors hover:bg-[var(--cta-bg-hover)]"
                  href={`${SITE_URL}/openapi.json`}
                >
                  Open schema
                </a>
                <Link
                  href="/"
                  className="inline-flex items-center justify-center rounded-xl border border-[var(--border-medium)] px-5 py-3 text-sm font-semibold text-[var(--text-primary)] transition-colors hover:border-[var(--border-strong)] hover:bg-[var(--surface-glass)]"
                >
                  See the product
                </Link>
              </div>
            </div>

            <section className="rounded-[1.5rem] border border-[var(--border-subtle)] bg-[var(--surface-glass)] p-6">
              <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-forma-steel-blue">
                Route intent
              </p>
              <ul className="mt-4 space-y-3">
                <li className="text-sm leading-relaxed text-[var(--text-secondary)]">
                  Pull stable product, FAQ, and schema data without parsing marketing layouts.
                </li>
                <li className="text-sm leading-relaxed text-[var(--text-secondary)]">
                  Use current version metadata before caching public endpoint responses.
                </li>
                <li className="text-sm leading-relaxed text-[var(--text-secondary)]">
                  Treat this surface as public-only documentation, not a private integration API.
                </li>
              </ul>
            </section>
          </div>
        </header>

        <section className="mt-8 rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-6 md:p-7">
          <div className="flex flex-col gap-3 border-b border-[var(--border-subtle)] pb-5 md:flex-row md:items-end md:justify-between">
            <div>
              <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
                Endpoint catalog
              </h2>
              <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--text-secondary)]">
                Mobile gets scanable endpoint cards. Desktop keeps the full table for quick
                comparison.
              </p>
            </div>
            <p className="text-xs uppercase tracking-[0.14em] text-[var(--text-muted)]">
              Current API version: {PUBLIC_API_VERSION}
            </p>
          </div>

          <div className="mt-5 grid gap-3 md:hidden">
            {endpoints.map((endpoint) => (
              <article
                key={endpoint.path}
                className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--surface-glass)] p-5"
              >
                <div className="flex items-center justify-between gap-3">
                  <span className="rounded-full border border-[var(--border-medium)] px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-forma-steel-blue">
                    {endpoint.method}
                  </span>
                  <span className="text-[11px] uppercase tracking-[0.14em] text-[var(--text-muted)]">
                    Public
                  </span>
                </div>
                <code className="mt-4 block rounded-xl bg-[var(--surface-glass)] px-3 py-3 text-[13px] leading-relaxed text-[var(--text-primary)]">
                  {endpoint.path}
                </code>
                <p className="mt-3 text-sm leading-relaxed text-[var(--text-secondary)]">
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
                <tr className="border-b border-[var(--border-subtle)] text-[var(--text-muted)]">
                  <th className="py-2 pr-4 font-medium">Method</th>
                  <th className="py-2 pr-4 font-medium">Path</th>
                  <th className="py-2 font-medium">Description</th>
                </tr>
              </thead>
              <tbody>
                {endpoints.map((endpoint) => (
                  <tr key={endpoint.path} className="border-b border-[var(--border-subtle)]">
                    <td className="py-3 pr-4 text-[var(--text-secondary)]">
                      {endpoint.method}
                    </td>
                    <td className="py-3 pr-4">
                      <code className="rounded-md bg-[var(--surface-glass)] px-2 py-1 text-[var(--text-primary)]">
                        {endpoint.path}
                      </code>
                    </td>
                    <td className="py-3 text-[var(--text-secondary)]">
                      {endpoint.description}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <div className="mt-8 grid gap-6 lg:grid-cols-[0.92fr,1.08fr]">
          <section className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-6 md:p-7">
            <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
              Usage guardrails
            </h2>
            <ul className="mt-4 space-y-3">
              {usageGuardrails.map((item) => (
                <li key={item} className="flex items-start gap-3">
                  <span className="mt-[6px] h-2 w-2 rounded-full bg-forma-sage" />
                  <span className="text-sm leading-relaxed text-[var(--text-secondary)]">{item}</span>
                </li>
              ))}
            </ul>
          </section>

          <section className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-6 md:p-7">
            <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
              Canonical resources
            </h2>
            <ul className="mt-4 space-y-4 text-sm">
              <li>
                <a className="text-forma-steel-blue hover:underline" href={`${SITE_URL}/llms.txt`}>
                  {SITE_URL}/llms.txt
                </a>
                <p className="mt-1 leading-relaxed text-[var(--text-secondary)]">
                  Index of machine-readable site resources for language models and agents.
                </p>
              </li>
              <li>
                <a className="text-forma-steel-blue hover:underline" href={`${SITE_URL}/openapi.json`}>
                  {SITE_URL}/openapi.json
                </a>
                <p className="mt-1 leading-relaxed text-[var(--text-secondary)]">
                  OpenAPI schema for the public endpoint surface documented on this page.
                </p>
              </li>
              <li>
                <Link className="text-forma-steel-blue hover:underline" href="/blog">
                  /blog
                </Link>
                <p className="mt-1 leading-relaxed text-[var(--text-secondary)]">
                  Canonical guides for human-readable workflows and supporting product context.
                </p>
              </li>
            </ul>
          </section>
        </div>

        <div className="mt-10">
          <Link
            href="/"
            className="text-sm text-[var(--text-muted)] transition-colors hover:text-[var(--text-secondary)]"
          >
            &larr; Back to home
          </Link>
        </div>
      </div>
    </main>
  );
}
