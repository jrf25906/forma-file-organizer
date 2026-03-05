# Forma Website Redesign Validation Plan

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Developers | Designers | QA | Marketing

This is the first validation pass for the redesign program. It applies to the website only. App validation is intentionally deferred until after the first website redesign implementation and fix loop.

Companion execution documents:

- `Docs/Testing/2026-03-05-website-redesign-current-build-capture-checklist.md`
- `Docs/Testing/2026-03-05-website-redesign-first-pass-findings-template.md`

## 1. Goals and Pass / Fail Criteria

### Primary goals

1. Confirm that a new visitor understands what Forma is, why it is different, whether it is safe, and how much it costs within the hero plus the next section.
2. Confirm that the homepage shows real product proof before pricing.
3. Confirm that CTA placement is visible and repeated without requiring users to hunt for the primary action.
4. Confirm that screenshots and demos explain behavior rather than decorate the page.
5. Confirm that all key marketing routes feel like one product and one brand system.
6. Confirm that the redesigned site holds up at `390`, `768`, `1280`, and `1440` in light mode.

### Mandatory pass criteria

- `C1 - First-screen comprehension`: Reviewers can answer all four questions - "what is this, why is it different, is it safe, how much is it?" - from the hero plus the next section alone.
- `C2 - Proof before price`: The homepage demonstrates rule creation, review-before-action, or undo before the pricing block appears.
- `C3 - CTA visibility`: A primary `Download for Mac` CTA is visible in the hero, after product proof, and at pricing.
- `C4 - Screenshot effectiveness`: Every homepage screenshot or demo has a clear job and teaches a product behavior.
- `C5 - Route consistency`: `/`, `/blog`, `/blog/[slug]`, `/support`, `/get-forma`, and `/for-agents` share one shell, typography rhythm, and surface logic.

### Quality pass criteria

- `Q1 - Responsive integrity`: No major hierarchy break, spacing collapse, or unusable interaction appears at `390`, `768`, `1280`, or `1440`.
- `Q2 - Light-mode readability`: Headings, body text, micro-labels, and CTA states remain readable and intentional in light mode.
- `Q3 - Narrative continuity`: The homepage scroll feels like one argument, not a pile of sections.

### Fail conditions

- Any failure of `C1` through `C5` blocks the redesign from being considered ready.
- More than three medium-severity issues across `Q1` through `Q3` block readiness.
- Any critical issue on mobile hero comprehension, pricing visibility, or CTA discoverability blocks readiness.

## 2. Screens / Routes to Capture

### Homepage surfaces

- Hero at page load
- Proof rail or hero-adjacent trust block
- Workflow demo section
- Before / after case-study section
- Pricing + FAQ section
- Footer state
- Header in both top-of-page and scrolled state

### Route snapshots

- `/`
- `/blog`
- `/blog/[slug]`
- `/support`
- `/get-forma`
- `/for-agents`

### Evidence requirements

- Capture a before/after screenshot pair for every required homepage surface and route snapshot listed above.
- Record one desktop homepage scroll and one mobile homepage scroll.
- Store a findings log with severity, evidence, and required fix for each issue discovered during review.

## 3. Screenshot Matrix by Breakpoint

Each required row below needs a baseline screenshot and a redesigned screenshot.

| Surface / Route | 390 | 768 | 1280 | 1440 | Notes |
| --- | --- | --- | --- | --- | --- |
| Homepage hero | Required | Required | Required | Required | Capture initial page load with header visible. |
| Homepage proof block | Required | Required | Required | Required | Must show the first post-hero trust / proof surface. |
| Homepage workflow demo | Required | Required | Required | Required | Capture the primary product-proof section. |
| Homepage before / after | Required | Required | Required | Required | Capture the transformation case. |
| Homepage pricing + FAQ | Required | Required | Required | Required | Capture the close and objection handling. |
| Homepage footer | Required | Required | Required | Required | Verify footer utility and brand continuity. |
| Header scrolled state | Required | Required | Required | Required | Capture after enough scroll to activate the compact header state, if present. |
| `/blog` | Required | Required | Required | Required | Above-the-fold plus first content cards. |
| `/blog/[slug]` | Required | Required | Required | Required | Above-the-fold plus inline CTA block. |
| `/support` | Required | Required | Required | Required | Above-the-fold and main support actions. |
| `/get-forma` | Required | Required | Required | Required | Above-the-fold and primary download action. |
| `/for-agents` | Required | Required | Required | Required | Above-the-fold and endpoint table state. |

## 4. Scroll-Recording Review Checklist

### Desktop recording

- Record the homepage at `1440` width.
- Start at the top of the page.
- Pause for 2 seconds on the hero.
- Scroll from top to footer in 15-20 seconds.
- Pause briefly at the workflow demo and pricing block.
- If the homepage contains hover-driven proof, include one interaction during the recording.

### Mobile recording

- Record the homepage at `390` width.
- Start at the top of the page.
- Pause for 2 seconds on the hero.
- Scroll from top to footer in 18-25 seconds.
- Pause briefly at the workflow demo and pricing block.

### Review checklist for both recordings

- [ ] By second 3, the page clearly states what Forma is.
- [ ] By second 8, the page has shown why Forma is different.
- [ ] Before pricing appears, the page has shown at least one real product-proof sequence.
- [ ] The primary CTA is visible without hunting at the hero, after proof, and near pricing.
- [ ] No section feels like dead air, filler, or a placeholder.
- [ ] The page feels like one argument from top to bottom.

## 5. Heuristic Review Tasks

### Task 1 - Five-second impression

- Open the homepage at `1440`.
- Look for 5 seconds only.
- Write one sentence answering: "What product is this?"
- Fail if the answer is vague, generic, or missing the preview-first / controlled-automation difference.

### Task 2 - Hero plus next section comprehension

- Read only the hero and the next section.
- Answer:
  - What is this?
  - Why is it different?
  - Is it safe?
  - How much is it?
- Fail if any answer requires scrolling deeper.

### Task 3 - Product proof audit

- Review every screenshot and demo on the homepage.
- For each asset, write the behavior it is explaining.
- Fail any asset that does not have a clear instructional job.

### Task 4 - CTA retrieval

- Starting from the hero, the workflow section, and the pricing section, note the nearest primary CTA.
- Fail if the CTA is weak, hidden, visually secondary, or absent.

### Task 5 - Route shell consistency

- Compare `/blog`, `/blog/[slug]`, `/support`, `/get-forma`, and `/for-agents` against the homepage.
- Check typography, header/footer treatment, CTA style, card surfaces, and spacing rhythm.
- Fail if any route looks like it belongs to a different product or design system.

### Task 6 - Responsive stress pass

- Review all required routes at `390`, `768`, `1280`, and `1440`.
- Fail on any breakpoint where hierarchy breaks, line lengths become clumsy, tables or cards become unusable, or the CTA is displaced.

### Task 7 - Light-mode contrast pass

- Check headings, body text, micro-labels, footer text, secondary CTAs, and data/table content.
- Fail if any label is technically present but visually timid, washed out, or unreadable at normal viewing distance.

## 6. Lightweight Conversion Experiments

These are low-overhead experiments for the first redesign cycle. If analytics instrumentation is unavailable, run them as structured design reviews or hallway tests and record the result manually.

### Experiment A - Hero asset type

- Variant A: Static screenshot with annotations.
- Variant B: Short inline workflow demo.
- Hypothesis: A real inline workflow demo will improve "why is it different?" comprehension and increase primary CTA confidence.
- Primary signal: Reviewer comprehension and hero CTA confidence.
- Secondary signal: Hero click-through to `Download for Mac`, if traffic data is available.

### Experiment B - Price visibility near first CTA

- Variant A: Price context near the hero CTA.
- Variant B: Price context only at the pricing section.
- Hypothesis: Early price visibility will reduce uncertainty for a one-time purchase utility.
- Primary signal: Reviewer ability to answer "how much is it?" within the first two sections.
- Secondary signal: Pricing-section reach and CTA click-through, if traffic data is available.

### Experiment C - Mid-page CTA strength

- Variant A: No dedicated mid-page CTA after proof.
- Variant B: Dedicated mid-page `Download for Mac` CTA after the workflow / transformation proof.
- Hypothesis: A post-proof CTA will capture high-intent users before they reach pricing.
- Primary signal: Reviewer expectation of where to click once convinced.
- Secondary signal: CTA click distribution by section, if traffic data is available.

## 7. Output Format for Findings

Use one findings log for each validation pass.

### Required fields

| Field | Description |
| --- | --- |
| ID | Short stable identifier, for example `WEB-001` |
| Severity | `Critical`, `High`, `Medium`, or `Low` |
| Surface | Route or section name |
| Evidence | Screenshot name, recording timestamp, or breakpoint |
| Failed criterion | Reference to `C1`-`C5` or `Q1`-`Q3` |
| Finding | Short description of what failed |
| Required fix | Clear change needed before the next pass |
| Owner | Person or area responsible |
| Status | `Open`, `In Progress`, `Fixed`, `Accepted` |

### Findings log template

| ID | Severity | Surface | Evidence | Failed criterion | Finding | Required fix | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| WEB-001 | High | Homepage hero | `1440 hero after redesign` | C1 | Visitors still cannot tell why Forma is safer than other organizers. | Make preview-first control explicit in hero-adjacent proof block. | Marketing site | Open |

### Severity definitions

- `Critical`: Blocks readiness and breaks core comprehension, CTA discovery, or route usability.
- `High`: Damages conversion or meaning substantially and must be fixed before sign-off.
- `Medium`: Weakens clarity or polish enough to matter, but does not break the core path alone.
- `Low`: Minor polish issue that can be batched after the core fix loop.
