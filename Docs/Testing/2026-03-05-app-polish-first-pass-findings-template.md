# Forma App Polish First-Pass Findings Template

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Developers | Designers | QA | Product

Use this template for the first app visual-validation pass against the current build. Pair it with:

- `Docs/Testing/2026-03-05-app-polish-validation-plan.md`
- `Docs/Testing/2026-03-05-app-polish-current-build-capture-checklist.md`

## 1. Run Metadata

| Field | Value |
| --- | --- |
| Validation date | |
| Reviewer | |
| Build target | `Forma File Organizing` |
| Branch | |
| Commit SHA | |
| Evidence basis | |
| Notes | |

## 2. Evidence Manifest

| Artifact | Location | Notes |
| --- | --- | --- |
| Screenshot root | | |
| Interaction recording | | |
| Light-mode baseline set | | |
| Dark-mode spot checks | | |
| Supplemental runtime captures | | |
| Code-backed source review | | |

## 3. Criteria Summary

Record pass or fail for every mandatory and quality criterion before writing the detailed findings.

| Criterion | Result | Evidence | Notes |
| --- | --- | --- | --- |
| `C1 - Shell hierarchy` | | | |
| `C2 - Review workflow clarity` | | | |
| `C3 - Rule-builder authority` | | | |
| `C4 - Operational secondary surfaces` | | | |
| `C5 - Cross-view parity` | | | |
| `C6 - Native cohesion` | | | |
| `Q1 - Visual density and contrast` | | | |
| `Q2 - State resilience` | | | |
| `Q3 - Brand cohesion` | | | |
| `Q4 - Capture completeness` | | | |

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
| `APP-001` | | | | | | | | `Open` |
| `APP-002` | | | | | | | | `Open` |
| `APP-003` | | | | | | | | `Open` |
| `APP-004` | | | | | | | | `Open` |
| `APP-005` | | | | | | | | `Open` |
| `APP-006` | | | | | | | | `Open` |
| `APP-007` | | | | | | | | `Open` |
| `APP-008` | | | | | | | | `Open` |

## 6. Current-Build Prompts

Use these prompts to keep the first pass focused on the most likely failure points in the current build.

### Main workspace

- Does the default dashboard state make the next action obvious within two seconds?
- Does the inspector feel like a working surface, or like a quiet sidecar attached to the real screen?
- Are blur, tint, and ambient overlays making the queue look softer than it should?

### Rule builder

- Does the panel communicate impact and safety, or just expose fields?
- Are validation messages ranked visually high enough to guide creation?
- Does the header feel like a product tool or a generic sidebar form?

### Smart Rules and Analytics

- Does Smart Rules feel operational in empty and live states?
- Does Analytics earn its space when activity is near zero?
- Are these screens telling the user what to do next, or just showing interface chrome?

### Settings and onboarding

- Do the settings and onboarding screens feel like the same product as the main workspace?
- Are the controls native and trustworthy?
- Does the voice drift too far toward either generic utility or soft marketing?

### File-view parity

- When switching between card, list, and grid, do status, destination, confidence, and next action stay legible?
- Are any actions or semantics available in one mode but effectively hidden in another?

### State coverage

- Is the baseline evidence set complete enough to make a final polish call?
- Which critical states still need runtime capture before sign-off?

## 7. Sign-Off Decision

| Decision | Value | Notes |
| --- | --- | --- |
| Ready for app polish sign-off | | |
| Mandatory criteria passed | | |
| Number of blocking issues | | |
| Next action | | |
