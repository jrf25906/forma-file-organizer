# Forma webMCP Readiness

**Last Updated:** February 11, 2026  
**Status:** Metadata + docs readiness (no remote MCP server yet)

---

## Goal

Prepare Forma's public website surface for AI agent retrieval now, while deferring full remote MCP server deployment to a later phase.

---

## Current public machine-readable surface

- `https://formafiles.com/llms.txt`
- `https://formafiles.com/for-agents`
- `https://formafiles.com/openapi.json`
- `https://formafiles.com/api/public/product`
- `https://formafiles.com/api/public/faq`
- `https://formafiles.com/api/public/faq/{id}`

These endpoints are read-only and contain no user-specific data.

---

## Planned MCP tool contracts (future)

The following contracts describe expected server tools for a future MCP implementation. These are design targets, not active endpoints.

### `get_product_overview`
- **Purpose:** Return current product summary and purchase link.
- **Input:** none.
- **Output:** `{ name, tagline, platform, price_usd, purchase_url, last_updated }`
- **Source of truth:** `/api/public/product`

### `list_faq`
- **Purpose:** Return all FAQ entries for support-oriented answering.
- **Input:** optional `category`.
- **Output:** `{ items: [{ id, question, answer, category, last_updated }] }`
- **Source of truth:** `/api/public/faq`

### `get_faq_item`
- **Purpose:** Return one FAQ by stable ID.
- **Input:** `{ id }`
- **Output:** `{ id, question, answer, category, last_updated }`
- **Source of truth:** `/api/public/faq/{id}`

### `list_guides`
- **Purpose:** Return blog guide metadata for retrieval and citation.
- **Input:** optional `tag`.
- **Output:** `{ items: [{ slug, title, description, publishedAt, updatedAt, canonical }] }`
- **Source of truth:** `/blog` + content index.

---

## Security constraints for future MCP server

1. **Read-only first:** no file operations, account mutations, or user-write actions in v1.
2. **No sensitive payloads:** never expose local filesystem paths, personal data, or private analytics.
3. **Strict allowlist:** only publish explicitly documented tools and arguments.
4. **Input validation:** reject unknown fields and oversized payloads.
5. **Rate limiting:** enforce per-client and per-IP quotas.
6. **Audit logging:** keep structured request logs for tool invocations and response statuses.
7. **Transport:** use secure HTTP transport with TLS; require trusted server identity checks.

---

## Decision log

- Full remote MCP server is intentionally deferred.
- Public API + OpenAPI + `llms.txt` surface is the current integration baseline.
- Scope remains US-English public marketing and support data.

