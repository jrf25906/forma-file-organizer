# Forma Website Redesign First-Pass Findings Template

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Developers | Designers | QA | Marketing

Use this template for the first website validation pass against the current build. Pair it with:

- `Docs/Testing/2026-03-05-website-redesign-validation-plan.md`
- `Docs/Testing/2026-03-05-website-redesign-current-build-capture-checklist.md`

## 1. Run Metadata

| Field | Value |
| --- | --- |
| Validation date | |
| Reviewer | |
| Build URL | `http://localhost:3000` |
| Branch | |
| Commit SHA | |
| Browser | |
| Notes | |

## 2. Evidence Manifest

| Artifact | Location | Notes |
| --- | --- | --- |
| Screenshot root | | |
| Desktop scroll recording | | |
| Mobile scroll recording | | |
| Before / after baseline pairs | | |
| Route snapshots | | |

## 3. Criteria Summary

Record pass or fail for every mandatory and quality criterion before writing the detailed findings.

| Criterion | Result | Evidence | Notes |
| --- | --- | --- | --- |
| `C1 - First-screen comprehension` | | | |
| `C2 - Proof before price` | | | |
| `C3 - CTA visibility` | | | |
| `C4 - Screenshot effectiveness` | | | |
| `C5 - Route consistency` | | | |
| `Q1 - Responsive integrity` | | | |
| `Q2 - Light-mode readability` | | | |
| `Q3 - Narrative continuity` | | | |

## 4. Severity Summary

| Severity | Count |
| --- | --- |
| Critical | |
| High | |
| Medium | |
| Low | |

## 5. Findings Log

Use one row per issue.

| ID | Severity | Surface | Evidence | Failed criterion | Finding | Required fix | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `WEB-001` | | | | | | | | `Open` |
| `WEB-002` | | | | | | | | `Open` |
| `WEB-003` | | | | | | | | `Open` |
| `WEB-004` | | | | | | | | `Open` |
| `WEB-005` | | | | | | | | `Open` |
| `WEB-006` | | | | | | | | `Open` |
| `WEB-007` | | | | | | | | `Open` |
| `WEB-008` | | | | | | | | `Open` |
| `WEB-009` | | | | | | | | `Open` |
| `WEB-010` | | | | | | | | `Open` |

## 6. Current-Build Prompts

Use these prompts to keep the first pass focused on the most likely failure points in the current build.

### Homepage

- Does the hero explain the product fast enough without relying on the user to interpret the screenshot alone?
- Does the trust line do real proof work, or is it just a decorative reassurance strip?
- Do the features blocks explain actual product behavior, or are they stylized fragments standing in for proof?
- Does the before / after block prove a meaningful transformation, or does it feel like a placeholder?
- Is the mid-page CTA appearing after enough proof to be persuasive?
- Does the pricing block land as a close, or does it arrive before the site has earned trust?

### Blog

- Does `/blog` feel like the same product and brand system as the homepage?
- Does `/blog/organize-mac-files` keep the same CTA weight and visual rhythm as the homepage?
- Is the inline blog CTA strong enough to feel intentional rather than bolted on?

### Support and Get Forma

- Do `/support` and `/get-forma` feel visually related to the homepage, or do they read as simpler utility pages from another system?
- Are the hard-coded grays on these pages breaking contrast or brand consistency?
- Are the primary actions on these routes obvious without scanning?

### For Agents

- Does `/for-agents` still feel like Forma rather than a generic docs page?
- Is the endpoint table usable at `390` without awkward clipping or hidden meaning?
- Does the route feel intentionally secondary, or simply underdesigned?

## 7. Sign-Off Decision

| Decision | Value | Notes |
| --- | --- | --- |
| Ready for redesign sign-off | | |
| Mandatory criteria passed | | |
| Number of blocking issues | | |
| Next action | | |
