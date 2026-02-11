# Website SEO + AI Surface

**Last Updated:** February 11, 2026

## Overview

The `forma-website` project now exposes a broader SEO and AI-consumption surface focused on organic signup growth.

## Implemented capabilities

1. Expanded homepage schema graph:
   - `SoftwareApplication`
   - `Organization`
   - `WebSite`
   - `FAQPage`
2. Stable crawl endpoints:
   - `robots.txt` with explicit AI/search bot directives
   - `sitemap.xml` including blog and agent pages
3. In-repo MDX content pipeline:
   - `/blog`
   - `/blog/[slug]`
4. Public machine-readable routes:
   - `/llms.txt`
   - `/for-agents`
   - `/api/public/product`
   - `/api/public/faq`
   - `/api/public/faq/[id]`
   - `/openapi.json`
5. Privacy-first event tracking hooks:
   - `download_click`
   - `newsletter_submit_success`
   - `support_contact_click`
   - `blog_cta_click`

## Data sources

- FAQ content source: `src/lib/faq.ts`
- Blog content source: `src/content/blog/*.mdx`
- Public API payload source: `src/lib/public-data.ts`

## Notes

- Full remote MCP server implementation is intentionally deferred.
- Machine-readable metadata and read-only APIs form the current integration baseline.

