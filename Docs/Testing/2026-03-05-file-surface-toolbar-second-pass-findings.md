# Forma File Surface + Toolbar Validation Findings (Second Pass)

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Developers | Designers | QA | Product

This rerun closes the focused follow-up work for the March 5 file-surface and toolbar refactor. It validates the grid-density rebalance, stronger passive destination readability, and the new compact-width test harness after the initial pass documented in `2026-03-05-file-surface-toolbar-validation-findings.md`.

## 1. Run Metadata

| Field | Value |
| --- | --- |
| Validation date | 2026-03-05 |
| Reviewer | Codex |
| Branch | `main` |
| Commit SHA | `f8d5803` |
| Build target | `Forma File Organizing` |
| Validation command | `FORMA_SCREENSHOT_OUTPUT_DIR="$PWD/Docs/Testing/Artifacts/file-surface-toolbar/2026-03-05-current-build" xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - UI" -destination 'platform=macOS' -derivedDataPath "$PWD/DerivedDataFileSurfaceToolbarValidation" -only-testing:"Forma File OrganizingUITests/FileSurfaceToolbarValidationTests/testCaptureFileSurfaceAndToolbarValidationShots"` |
| Notes | The rerun uses explicit `mainContent_viewMode` state probes plus direct view-mode picker interaction, so the capture flow no longer depends on row-internal accessibility assumptions. Screenshot PNGs were exported from the passing `.xcresult` bundle into the repo artifact directory because direct runner writes remained unavailable. |

## 2. Evidence Manifest

| Artifact | Location | Notes |
| --- | --- | --- |
| Focused UI validation test | `Forma File OrganizingUITests/FileSurfaceToolbarValidationTests.swift` | Updated to drive view-mode changes through the toolbar picker and validate narrow-width captures at `1080x760` and `920x700` |
| UI test harness update | `Forma File OrganizingUITests/UITestHarness.swift` | Added stable toolbar view-mode interactions and `mainContent_viewMode` waits |
| View-mode state probe | `Forma File Organizing/Views/MainContentView.swift` | Exposes the current file-surface mode for validation without coupling to row internals |
| Screenshot artifacts | `Docs/Testing/Artifacts/file-surface-toolbar/2026-03-05-current-build/` | Contains the passing rerun screenshot set |
| First-pass baseline | `Docs/Testing/2026-03-05-file-surface-toolbar-validation-findings.md` | Superseded for sign-off by this rerun |

## 3. Captures Reviewed

- `file-surface-toolbar-01-pending-card-1440.png`
- `file-surface-toolbar-02-all-files-card-1440.png`
- `file-surface-toolbar-03-all-files-list-1440.png`
- `file-surface-toolbar-04-all-files-grid-1440.png`
- `file-surface-toolbar-05-all-files-list-1080.png`
- `file-surface-toolbar-06-all-files-list-920.png`

## 4. Criteria Summary

| Criterion | Result | Evidence | Notes |
| --- | --- | --- | --- |
| `FS1 - Shared file identity contract` | Pass | `file-surface-toolbar-02-all-files-card-1440.png`, `file-surface-toolbar-03-all-files-list-1440.png`, `file-surface-toolbar-04-all-files-grid-1440.png` | Card, list, and grid still answer the same four questions in the same order. |
| `FS2 - Single dominant action at rest` | Pass | `file-surface-toolbar-01-pending-card-1440.png`, `file-surface-toolbar-02-all-files-card-1440.png` | Batch CTA ownership remains clear and row-level actions stay quiet at rest. |
| `FS3 - Cross-view visual parity` | Pass | `file-surface-toolbar-02-all-files-card-1440.png`, `file-surface-toolbar-03-all-files-list-1440.png`, `file-surface-toolbar-04-all-files-grid-1440.png` | Grid now carries enough footer hierarchy and metadata weight to feel like a credible peer instead of a novelty fallback. |
| `TB1 - Grouped toolbar hierarchy at full width` | Pass | `file-surface-toolbar-01-pending-card-1440.png`, `file-surface-toolbar-03-all-files-list-1440.png` | `Scope / Context / Arrange / Display` remains clear at standard width. |
| `TB2 - Toolbar compaction at narrower widths` | Pass | `file-surface-toolbar-03-all-files-list-1440.png`, `file-surface-toolbar-05-all-files-list-1080.png`, `file-surface-toolbar-06-all-files-list-920.png` | The validation path is now real: narrow-width runs collapse context detail while preserving control grouping and interaction integrity. |

## 5. Severity Summary

| Severity | Count |
| --- | --- |
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |

## 6. Findings Closure

| ID | Previous finding | Rerun evidence | Resolution | Status |
| --- | --- | --- | --- | --- |
| `FST-001` | Grid over-weighted thumbnails and under-weighted footer hierarchy | `file-surface-toolbar-04-all-files-grid-1440.png`; `Forma File Organizing/Components/FileGridItem.swift`; `Forma File Organizing/Components/Shared/FileSurfaceComponents.swift` | The grid tile now devotes more vertical weight to the footer, longer names have more breathing room, and destination/status content reads before the tile drops below the fold. | Fixed |
| `FST-002` | Destination styling became too quiet in card/list | `file-surface-toolbar-02-all-files-card-1440.png`; `file-surface-toolbar-03-all-files-list-1440.png`; `Forma File Organizing/Components/Shared/FileMetaStrip.swift` | Destination remains passive, but the stronger label weight, subtle container treatment, and better path truncation restore scan readability without reintroducing link-like behavior. | Fixed |
| `FST-003` | Compact-toolbar validation was blocked by the app root `minWidth` / `minHeight` floor | `file-surface-toolbar-05-all-files-list-1080.png`; `file-surface-toolbar-06-all-files-list-920.png`; `Forma File Organizing/Forma_File_OrganizingApp.swift`; `Forma File OrganizingUITests/FileSurfaceToolbarValidationTests.swift` | UI tests now control the debug window minimum through `FORMA_WINDOW_SIZE`, and the rerun proves a real narrow-state toolbar capture path. | Fixed |

## 7. Residual Notes

- The `1080` and `920` runs both land in the compact family rather than producing dramatically different intermediate states. That is acceptable for sign-off because the blocking issue was the missing narrow-width validation path, not a requirement for three distinct compaction tiers.
- The list view remains the strongest file surface. That is fine as long as grid and card remain credible peers, which this rerun now confirms.

## 8. Sign-Off Decision

| Decision | Value | Notes |
| --- | --- | --- |
| File-surface composition direction | Approved | The shared identity/state/destination/action contract is visually closed for this pass. |
| Toolbar grouping direction | Approved | The grouped command model now has supporting compact-width evidence. |
| Refactor fully visually closed | Yes | No blocking or medium-severity issues remain in the focused refactor pass. |
| Next action | Fold these surfaces into release asset refresh and broader regression QA. | Use this rerun as the evidence baseline. |
