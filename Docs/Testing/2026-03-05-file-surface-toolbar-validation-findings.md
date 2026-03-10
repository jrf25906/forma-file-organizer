# Forma File Surface + Toolbar Validation Findings

> Superseded for sign-off by [2026-03-05-file-surface-toolbar-second-pass-findings.md](2026-03-05-file-surface-toolbar-second-pass-findings.md). Keep this file as the first-pass baseline.

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Developers | Designers | QA | Product

This report covers the focused visual validation pass for the March 5 file-surface and toolbar refactor. It is narrower than the broader app-polish review and is intended to judge the new card/list/grid composition model plus the grouped center-pane toolbar.

## 1. Run Metadata

| Field | Value |
| --- | --- |
| Validation date | 2026-03-05 |
| Reviewer | Codex |
| Branch | `main` |
| Commit SHA | `f8d5803` |
| Build target | `Forma File Organizing` |
| Validation command | `FORMA_SCREENSHOT_OUTPUT_DIR="$PWD/Docs/Testing/Artifacts/file-surface-toolbar/2026-03-05-current-build" xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - UI" -destination 'platform=macOS' -derivedDataPath "$PWD/DerivedDataFileSurfaceToolbarValidation" -only-testing:"Forma File OrganizingUITests/FileSurfaceToolbarValidationTests/testCaptureFileSurfaceAndToolbarValidationShots"` |
| Notes | The first pass exposed stale UI-test assumptions around the grouped toolbar review-mode control. The final passing run uses the toolbar picker itself as the launch anchor and taps the review segments via picker coordinates. |

## 2. Evidence Manifest

| Artifact | Location | Notes |
| --- | --- | --- |
| Focused UI validation test | `Forma File OrganizingUITests/FileSurfaceToolbarValidationTests.swift` | Captures parity and toolbar screenshots for the refactor surfaces |
| UI test harness update | `Forma File OrganizingUITests/UITestHarness.swift` | The grouped review-mode picker is now the stable launch anchor for UI tests |
| Screenshot artifacts | `Docs/Testing/Artifacts/file-surface-toolbar/2026-03-05-current-build/` | Contains 6 light-mode screenshots exported from the UI test run |
| Validation plan | `Docs/plans/2026-03-05-file-surface-and-toolbar-refactor-plan.md` | Defines the targeted follow-up criteria for this pass |
| Relevant UI surfaces | `Forma File Organizing/Views/Components/FileRow.swift`, `Forma File Organizing/Components/FileListRow.swift`, `Forma File Organizing/Components/FileGridItem.swift`, `Forma File Organizing/Components/Shared/FileSurfaceComponents.swift`, `Forma File Organizing/Views/Components/UnifiedToolbar.swift` | Used to connect visual findings back to the implementation |

## 3. Captures Reviewed

- `file-surface-toolbar-01-pending-card-1440.png`
- `file-surface-toolbar-02-all-files-card-1440.png`
- `file-surface-toolbar-03-all-files-list-1440.png`
- `file-surface-toolbar-04-all-files-grid-1440.png`
- `file-surface-toolbar-05-all-files-list-1280.png`
- `file-surface-toolbar-06-all-files-list-1200.png`

## 4. Criteria Summary

| Criterion | Result | Evidence | Notes |
| --- | --- | --- | --- |
| `FS1 - Shared file identity contract` | Pass | `file-surface-toolbar-02-all-files-card-1440.png`, `file-surface-toolbar-03-all-files-list-1440.png`, `file-surface-toolbar-04-all-files-grid-1440.png` | All three views now tell the same story in the same order: file, state, destination, action. |
| `FS2 - Single dominant action at rest` | Pass | `file-surface-toolbar-01-pending-card-1440.png`, `file-surface-toolbar-02-all-files-card-1440.png` | Rest-state rows are substantially quieter and batch CTA ownership is no longer undermined by always-on row actions. |
| `FS3 - Cross-view visual parity` | Partial | `file-surface-toolbar-02-all-files-card-1440.png`, `file-surface-toolbar-03-all-files-list-1440.png`, `file-surface-toolbar-04-all-files-grid-1440.png` | Semantic parity is strong, but the grid view still lags visually. |
| `TB1 - Grouped toolbar hierarchy at full width` | Pass | `file-surface-toolbar-01-pending-card-1440.png`, `file-surface-toolbar-03-all-files-list-1440.png` | `Scope / Context / Arrange / Display` reads clearly at the standard width. |
| `TB2 - Toolbar compaction at narrower widths` | Partial | `file-surface-toolbar-05-all-files-list-1280.png`, `file-surface-toolbar-06-all-files-list-1200.png`, `Forma File Organizing/Forma_File_OrganizingApp.swift` | Narrow-width evidence is incomplete because the app still enforces a `minWidth`/`minHeight` root frame that prevents a materially smaller visual state. |

## 5. Severity Summary

| Severity | Count |
| --- | --- |
| Critical | 0 |
| High | 0 |
| Medium | 3 |
| Low | 0 |

## 6. Findings Log

| ID | Severity | Surface | Evidence | Finding | Required fix | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `FST-001` | Medium | Grid view | `file-surface-toolbar-04-all-files-grid-1440.png`; `Forma File Organizing/Components/FileGridItem.swift` | The grid view is now semantically aligned with card/list, but it is still the visually weakest surface. Tiles over-invest in the thumbnail area, the footer is too compressed, and longer names wrap awkwardly without enough room for destination context to breathe. | Reduce thumbnail dominance, rebalance tile height toward the footer, and give the metadata row more visual priority so grid becomes a credible scan surface instead of a fallback novelty view. | Open |
| `FST-002` | Medium | Card + list destination readability | `file-surface-toolbar-02-all-files-card-1440.png`; `file-surface-toolbar-03-all-files-list-1440.png`; `Forma File Organizing/Components/Shared/FileMetaStrip.swift` | Neutralizing destination styling fixed the false-link problem, but the destination line is now too quiet in several rows. In card view especially, destination can slip below quick scan value even though it is one of the four core answers the row needs to provide. | Raise destination contrast or weight slightly while keeping it passive, and tune card/list spacing so destination remains easy to scan without reading as an action. | Open |
| `FST-003` | Medium | Toolbar compact-state validation | `file-surface-toolbar-05-all-files-list-1280.png`; `file-surface-toolbar-06-all-files-list-1200.png`; `Forma File Organizing/Forma_File_OrganizingApp.swift` | The grouped toolbar is clearly better at full width, but this pass did not truly validate compact behavior. The app root still enforces `minWidth: 1200` and `minHeight: 800`, so the 1280 and 1200 captures land in nearly the same effective state and do not prove that the toolbar collapses gracefully under meaningful pressure. | Add a real narrow-state validation path by lowering the minimum debug/test window size or by adding a test-only center-pane width harness, then rerun compact-toolbar captures. | Open |

## 7. What Improved

- The list view is now the strongest surface in the product. It scans quickly, the hierarchy is cleaner, and the toolbar no longer feels like a row of unrelated controls.
- The card view is materially calmer than before. Removing the category rails and consolidating secondary actions into one overflow model was the right move.
- The pending-state toolbar now reads like a command surface rather than a stack of widgets: the mode toggle, context chip, arrange control, and display cluster all have a clearer job.

## 8. Sign-Off Decision

| Decision | Value | Notes |
| --- | --- | --- |
| File-surface composition direction | Approved | The shared identity/action model is the right architecture. |
| Toolbar grouping direction | Approved | The command-family structure is stronger than the previous flat strip. |
| Refactor fully visually closed | No | `FST-001` through `FST-003` remain open. |
| Next action | Run one follow-up polish pass focused on grid density, destination readability, and real compact-width validation. | Do this before declaring the card/toolbar work finished. |
