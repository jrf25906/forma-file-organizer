# Forma Website Redesign Second-Pass Findings

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Developers | Designers | QA | Marketing

This is the post-redesign rerun against the current local build after the March 5, 2026 implementation passes. Read it alongside the baseline report in `Docs/Testing/2026-03-05-website-redesign-first-pass-findings.md`.

## 1. Run Metadata

| Field | Value |
| --- | --- |
| Validation date | 2026-03-05 |
| Reviewer | Codex |
| Build URL | `http://localhost:3000` |
| Branch | `main` |
| Commit SHA | `3f200b5` |
| Browser | Playwright Chromium, light mode |
| Notes | Rerun covered the redesigned homepage, blog routes, `/support`, `/get-forma`, `/for-agents`, `/privacy`, and `/terms`. Current-build desktop and mobile scroll recordings were not recaptured in this pass; current viewport and full-page captures were used instead. |

## 2. Evidence Manifest

| Artifact | Location | Notes |
| --- | --- | --- |
| Screenshot root | Local Playwright rerun capture set from 2026-03-05 | Included homepage desktop/mobile and full-page, blog index, blog post, support, get-forma, for-agents, privacy desktop/mobile, and terms desktop |
| Desktop scroll recording | Not recaptured in this rerun | Homepage full-page capture plus direct route inspection used instead |
| Mobile scroll recording | Not recaptured in this rerun | Mobile viewport captures used instead |
| Before / after baseline pairs | Compared against `Docs/Testing/2026-03-05-website-redesign-first-pass-findings.md` and same-day baseline capture notes | Used to confirm closure of `WEB-001` through `WEB-008` |
| Route snapshots | Local Playwright rerun capture set from 2026-03-05 | `/`, `/blog`, `/blog/organize-downloads-folder-mac`, `/support`, `/get-forma`, `/for-agents`, `/privacy`, `/terms` |

## 3. Criteria Summary

| Criterion | Result | Evidence | Notes |
| --- | --- | --- | --- |
| `C1 - First-screen comprehension` | Pass | Homepage desktop/mobile captures; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L280) | The hero plus immediate proof rail now answer what Forma is, why it is different, whether it is safe, and how much it costs. |
| `C2 - Proof before price` | Pass | Homepage full-page capture; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L352), [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L382) | Real workflow proof and transformation evidence appear before the pricing section. |
| `C3 - CTA visibility` | Pass | Homepage desktop/mobile captures; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L299), [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L422), [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L505) | Primary CTA placement is visible at the hero, after proof, and in pricing. |
| `C4 - Screenshot effectiveness` | Pass | Homepage desktop/full-page captures; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L331), [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L365), [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L432) | Each homepage screenshot now teaches a clear behavior: review queue, workflow proof, or before/after transformation. |
| `C5 - Route consistency` | Pass | Blog, support, get-forma, for-agents, privacy, and terms captures; [blog/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/blog/page.tsx#L42), [blog/[slug]/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/blog/%5Bslug%5D/page.tsx#L156), [support/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/support/page.tsx#L17), [get-forma/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/get-forma/page.tsx#L18), [for-agents/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/for-agents/page.tsx#L65), [privacy/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/privacy/page.tsx#L62), [terms/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/terms/page.tsx#L52) | Core marketing routes now share one typography rhythm, surface language, CTA treatment, and footer/header shell. |
| `Q1 - Responsive integrity` | Pass | Homepage mobile capture, `/for-agents` mobile capture, `/privacy` mobile capture; [for-agents/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/for-agents/page.tsx#L146) | No clipped first-view table, collapsed CTA, or broken hierarchy remained in the reviewed mobile states. |
| `Q2 - Light-mode readability` | Pass | All reviewed route captures; [globals.css](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/globals.css#L549) | Light-mode contrast and supporting text remain readable across homepage, guides, utilities, and legal pages. |
| `Q3 - Narrative continuity` | Pass | Homepage full-page capture; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L352), [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L382), [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L471) | The homepage now reads as one argument: thesis, workflow proof, transformation, use cases, then pricing and FAQ. |

## 4. Severity Summary

| Severity | Count |
| --- | --- |
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |

## 5. Findings Log

| ID | Severity | Surface | Evidence | Failed criterion | Finding | Required fix | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `WEB-001` | Critical | Homepage hero + first proof | Current homepage desktop/mobile captures; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L280) | `C1` | Baseline issue closed. Hero copy, trust chips, and the adjacent proof state now make the product’s category, difference, safety, and price legible within the first two sections. | None in this pass. | Marketing site | `Fixed` |
| `WEB-002` | Critical | Homepage proof architecture | Current homepage full-page capture; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L352), [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L382) | `C2`, `C4` | Baseline issue closed. Real workflow screenshots and a transformation state now replace the synthetic proof run before pricing. | None in this pass. | Marketing site | `Fixed` |
| `WEB-003` | High | Homepage narrative flow | Current homepage full-page capture; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L352), [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L471) | `Q3` | Baseline issue closed. The page now escalates through workflow proof, transformation, use cases, and pricing instead of flattening into brochure sections. | None in this pass. | Marketing site | `Fixed` |
| `WEB-004` | High | Support route | Current `/support` capture; [support/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/support/page.tsx#L17) | `C5` | Baseline issue closed. `/support` now uses the shared route shell, consistent card surfaces, and the same plainspoken CTA rhythm as the rest of the site. | None in this pass. | Marketing site | `Fixed` |
| `WEB-005` | High | Get Forma route | Current `/get-forma` capture; [get-forma/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/get-forma/page.tsx#L18) | `C5` | Baseline issue closed. `/get-forma` now reads as a proper conversion route with price context, support linkage, and product-proof language. | None in this pass. | Marketing site | `Fixed` |
| `WEB-006` | High | Screenshot strategy | Current homepage and blog captures; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L331), [blog/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/blog/page.tsx#L42), [blog/[slug]/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/blog/%5Bslug%5D/page.tsx#L156) | `C4` | Baseline issue closed. Screenshots now carry explicit jobs across homepage and guides instead of functioning as decorative filler. | None in this pass. | Marketing site | `Fixed` |
| `WEB-007` | Medium | For Agents mobile table | Current `/for-agents` mobile capture; [for-agents/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/for-agents/page.tsx#L146) | `Q1` | Baseline issue closed. The small-screen route now opens with scanable endpoint cards instead of a clipped desktop table. | None in this pass. | Marketing site | `Fixed` |
| `WEB-008` | Medium | Blog product carry-through | Current `/blog` and `/blog/organize-downloads-folder-mac` captures; [blog/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/blog/page.tsx#L42), [blog/[slug]/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/blog/%5Bslug%5D/page.tsx#L156), [organize-downloads-folder-mac.mdx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/content/blog/organize-downloads-folder-mac.mdx#L1) | `C5`, `Q3` | Baseline issue closed. Blog routes now bridge directly into the product above the fold, keep article bodies inside the shared content system, and no longer display future-dated posts after March 5, 2026. | None in this pass. | Marketing site | `Fixed` |

## 6. Sign-Off Decision

| Decision | Value | Notes |
| --- | --- | --- |
| Ready for redesign sign-off | Yes | All mandatory and quality criteria passed in this rerun. |
| Mandatory criteria passed | `5 / 5` | `C1` through `C5` all passed. |
| Number of blocking issues | `0` | No blocking website issues remained in this pass. |
| Next action | Use this rerun as the current website validation baseline and shift the validation loop to the app polish pass. | If an external review package is needed, add fresh desktop and mobile homepage scroll recordings to supplement this screenshot-backed rerun. |
