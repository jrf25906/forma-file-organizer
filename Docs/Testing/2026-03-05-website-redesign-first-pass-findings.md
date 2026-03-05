# Forma Website Redesign First-Pass Findings

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Developers | Designers | QA | Marketing

This is the populated first-pass review for the current website build before redesign implementation. It uses direct visual inspection of the local site plus code-backed route review.

Follow-up: the post-redesign rerun is documented in `Docs/Testing/2026-03-05-website-redesign-second-pass-findings.md`.

## 1. Run Metadata

| Field | Value |
| --- | --- |
| Validation date | 2026-03-05 |
| Reviewer | Codex |
| Build URL | `http://localhost:3000` |
| Branch | Working tree with local documentation changes and unrelated existing marketing/app-store asset work |
| Commit SHA | Not recorded in this pass |
| Browser | Playwright Chromium, light mode |
| Notes | Desktop and mobile evidence were captured from the current local build. The earlier March 5, 2026 website screen recording was also used for continuity checks. |

## 2. Evidence Manifest

| Artifact | Location | Notes |
| --- | --- | --- |
| Screenshot root | Local Playwright capture set from 2026-03-05 | Included homepage desktop/mobile, homepage full-page desktop/mobile, blog index, blog post, support, get-forma, for-agents desktop/mobile |
| Desktop scroll recording | March 5, 2026 website screen recording provided in thread | Used for narrative pacing cross-check |
| Mobile scroll recording | Not captured in this pass | Mobile evaluation used direct `390 x 844` Playwright captures instead |
| Before / after baseline pairs | Not yet produced | Current build was reviewed as a baseline state, not a redesign comparison |
| Route snapshots | Local Playwright capture set from 2026-03-05 | `/`, `/blog`, `/blog/organize-mac-files`, `/support`, `/get-forma`, `/for-agents` |

## 3. Criteria Summary

| Criterion | Result | Evidence | Notes |
| --- | --- | --- | --- |
| `C1 - First-screen comprehension` | Fail | Homepage viewport captures at `1440 x 900` and `390 x 844`; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L138) | The page states what Forma is, but the mobile hero plus next section still under-explains why it is safer and meaningfully different. |
| `C2 - Proof before price` | Fail | Homepage full-page captures; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L193) | The page shows stylized representations of behavior, not real product proof, before pricing. |
| `C3 - CTA visibility` | Pass | Homepage desktop/mobile captures; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L146) | Hero, mid-page, and pricing CTAs are present and visually discoverable. |
| `C4 - Screenshot effectiveness` | Fail | Homepage desktop/full-page captures; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L159) | Only the hero uses a real screenshot, and it is not annotated strongly enough; the rest of the page leans on fabricated fragments. |
| `C5 - Route consistency` | Fail | Blog, support, get-forma, and for-agents captures; [support/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/support/page.tsx#L17), [get-forma/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/get-forma/page.tsx#L18) | `/support` and `/get-forma` break away from the stronger tokenized route system used elsewhere. |
| `Q1 - Responsive integrity` | Fail | Homepage mobile capture; for-agents mobile capture; [for-agents/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/for-agents/page.tsx#L68) | Mobile hierarchy is not broken everywhere, but the homepage loses proof too low in the stack and `/for-agents` becomes immediately horizontal-scroll dependent. |
| `Q2 - Light-mode readability` | Pass | All reviewed route captures | Text remains readable, but parts of the system still look timid rather than intentionally high-contrast. |
| `Q3 - Narrative continuity` | Fail | Homepage full-page capture; March 5, 2026 website recording; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L193) | The homepage reads as a series of nice sections rather than one escalating product argument. |

## 4. Severity Summary

| Severity | Count |
| --- | --- |
| Critical | 2 |
| High | 4 |
| Medium | 2 |
| Low | 0 |

## 5. Findings Log

| ID | Severity | Surface | Evidence | Failed criterion | Finding | Required fix | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `WEB-001` | Critical | Homepage hero + first proof | Homepage viewport captures at `1440 x 900` and `390 x 844`; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L138) | `C1` | The hero establishes category, but the first-screen story still does not make the product feel decisively safer or more distinctive, especially on mobile where the trust strip and screenshot proof sit too low. | Replace the current trust line with a real proof rail directly tied to the hero, and make preview-first control plus undo safety explicit next to the main CTA. | Marketing site | Open |
| `WEB-002` | Critical | Homepage proof architecture | Homepage full-page captures; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L193) | `C2`, `C4` | The page reaches pricing after a run of synthetic proof: typed rule rows, grouping chips, faux preview chips, and a text-only before/after block. It still does not show the real product doing the real job. | Replace synthetic feature blocks with real screenshots or inline motion showing rule creation, preview review, and undo before pricing. | Marketing site | Open |
| `WEB-003` | High | Homepage narrative flow | Homepage full-page capture; March 5, 2026 website recording; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L300) | `Q3` | The homepage argument flattens after the hero. The sequence feels brochure-like rather than cumulative, so the mid-page CTA and pricing block arrive before the story has built conviction. | Reorder the homepage around thesis, trust, workflow proof, transformation, then pricing and FAQ. Remove any section that is not carrying proof or conversion weight. | Marketing site | Open |
| `WEB-004` | High | Support route | Support route desktop capture; [support/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/support/page.tsx#L17) | `C5` | `/support` drops into a hard-coded gray utility card that looks like a separate microsite. It loses the stronger tokenized shell, footer rhythm, and branded CTA handling used on the homepage, blog, and `/for-agents`. | Rebuild `/support` on the shared marketing shell and token system, and keep the same header/footer and CTA tone as the rest of the site. | Marketing site | Open |
| `WEB-005` | High | Get Forma route | Get Forma route desktop capture; [get-forma/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/get-forma/page.tsx#L18) | `C5` | `/get-forma` reads like a generic install helper instead of a premium close. The route is visually underpowered and does not reinforce price, trust, or product proof. | Reframe `/get-forma` as a proper conversion page with shared shell, price/trust context, support promise, and footer continuity. | Marketing site | Open |
| `WEB-006` | High | Screenshot strategy | Homepage desktop and full-page captures; [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L159), [page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/page.tsx#L227) | `C4` | The only real screenshot is in the hero, and it still asks the user to infer too much. The rest of the page substitutes simplified chips and text blocks where additional product states should exist. | Annotate the hero screenshot or swap it for a clearer real-state demo, then add at least two more real product states mid-page. | Marketing site | Open |
| `WEB-007` | Medium | For Agents mobile table | `/for-agents` mobile capture at `390 x 844`; [for-agents/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/for-agents/page.tsx#L75) | `Q1` | The endpoint table becomes horizontally clipped on first view and asks for lateral scrolling immediately. The helper copy explains this, but the first visible state still feels cramped and partially hidden. | Switch to a stacked card or row-detail pattern under small widths instead of shipping a clipped desktop table. | Marketing site | Open |
| `WEB-008` | Medium | Blog product carry-through | Blog index and blog post desktop captures; [blog/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/blog/page.tsx#L72), [blog/[slug]/page.tsx](/Users/jamesfarmer/Application%20Prototype/Forma/forma-website/src/app/blog/%5Bslug%5D/page.tsx#L158) | `C5`, `Q3` | The blog routes are structurally cleaner than support/get-forma, but the product connection is still too deferred. Above the fold, the pages feel like generic content pages with only a weak sense of the product they are meant to convert for. | Bring a smaller product proof module or tighter CTA bridge higher into the blog system so editorial pages still feel like part of the same product funnel. | Marketing site | Open |

## 6. Sign-Off Decision

| Decision | Value | Notes |
| --- | --- | --- |
| Ready for redesign sign-off | No | The current build fails 6 of 8 validation criteria, including 4 of the 5 mandatory criteria. |
| Mandatory criteria passed | `1 / 5` | Only `C3 - CTA visibility` passed in this baseline review. |
| Number of blocking issues | 6 | `WEB-001` through `WEB-006` should be treated as the first redesign wave. |
| Next action | Implement the website redesign against the March 5 master brief, then rerun the validation plan with before/after evidence. | Do not preserve the synthetic homepage proof blocks or the isolated support/get-forma route styling. |
