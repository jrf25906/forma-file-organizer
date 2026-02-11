import type { Metadata } from "next";
import Link from "next/link";
import { PUBLIC_API_VERSION, SITE_URL } from "@/lib/site";

export const metadata: Metadata = {
  title: "For Agents",
  description:
    "Machine-readable endpoints and usage guidance for AI agents and integrations.",
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
    description: "High-level index of canonical resources for language agents.",
  },
  {
    path: "/api/public/product",
    method: "GET",
    description: "Current product summary and purchase URL.",
  },
  {
    path: "/api/public/faq",
    method: "GET",
    description: "FAQ collection with stable IDs and timestamps.",
  },
  {
    path: "/api/public/faq/{id}",
    method: "GET",
    description: "Single FAQ item lookup by ID.",
  },
  {
    path: "/openapi.json",
    method: "GET",
    description: "OpenAPI schema for public machine-readable endpoints.",
  },
  {
    path: "/api/newsletter",
    method: "POST",
    description: "Newsletter signup contract documented in OpenAPI.",
  },
];

export default function ForAgentsPage() {
  return (
    <main id="main-content" className="relative py-20 md:py-24">
      <div className="site-container mx-auto max-w-4xl">
        <header className="mb-10 border-b border-[var(--border-subtle)] pb-8">
          <p className="mb-3 text-xs uppercase tracking-[0.14em] text-[var(--text-muted)]">
            AI + Integration Docs
          </p>
          <h1 className="font-display text-4xl text-[var(--text-primary)] md:text-5xl">
            Forma Machine-Readable Surface
          </h1>
          <p className="mt-4 max-w-3xl text-base leading-relaxed text-[var(--text-secondary)]">
            This page documents stable public endpoints for crawlers, agents,
            and automation systems. Current API version: {PUBLIC_API_VERSION}.
          </p>
        </header>

        <section className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-6">
          <h2 className="font-display text-2xl text-[var(--text-primary)]">
            Endpoint catalog
          </h2>
          <div className="mt-4 overflow-x-auto">
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

        <section className="mt-8 rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-6">
          <h2 className="font-display text-2xl text-[var(--text-primary)]">
            Usage and safety
          </h2>
          <ul className="mt-4 list-disc space-y-2 pl-5 text-[15px] leading-relaxed text-[var(--text-secondary)]">
            <li>Respect robots directives and page metadata.</li>
            <li>Use legal pages as canonical policy sources.</li>
            <li>Do not assume access beyond public marketing endpoints.</li>
            <li>
              Avoid sending sensitive user data through third-party systems
              without explicit user consent.
            </li>
          </ul>
        </section>

        <section className="mt-8 rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-6">
          <h2 className="font-display text-2xl text-[var(--text-primary)]">
            Canonical links
          </h2>
          <ul className="mt-4 space-y-2 text-sm">
            <li>
              <a className="text-forma-steel-blue hover:underline" href={`${SITE_URL}/llms.txt`}>
                {SITE_URL}/llms.txt
              </a>
            </li>
            <li>
              <a className="text-forma-steel-blue hover:underline" href={`${SITE_URL}/openapi.json`}>
                {SITE_URL}/openapi.json
              </a>
            </li>
            <li>
              <Link className="text-forma-steel-blue hover:underline" href="/blog">
                /blog
              </Link>
            </li>
          </ul>
        </section>
      </div>
    </main>
  );
}
