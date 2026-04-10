# Forma Native App Overnight QA First-Pass Findings

**Status:** Current
**Last Updated:** 2026-04-09
**Audience:** Developers | Designers | QA | Product

## 1. Run Metadata

| Field | Value |
| --- | --- |
| Validation date | 2026-04-09 |
| Reviewer | Codex overnight coordinator |
| Build target | `Forma File Organizing` |
| Branch | `codex/overnight-qa-20260409` |
| Commit SHA | `0048613` |
| Evidence basis | Repo-declared build/test commands, targeted UI automation, existing artifact review, code inspection, and performance harness output |
| Notes | Preserved pre-existing local doc edits in the worktree. Primary shipped fix this pass was file-surface parity for no-destination recovery in grid view. |

## 2. Evidence Manifest

| Artifact | Location | Notes |
| --- | --- | --- |
| Screenshot root | `Docs/Testing/Artifacts/file-surface-toolbar/2026-03-05-current-build/` | Existing card/list/grid parity captures used for baseline comparison. |
| Interaction recording | None | No new recording captured during this overnight pass. |
| Light-mode baseline set | `Docs/Testing/Artifacts/app-polish/2026-03-05-current-build/` | Existing light-mode evidence used for shell/onboarding/dashboard review. |
| Dark-mode spot checks | Not captured | Remains an open coverage gap. |
| Supplemental runtime captures | `Test-Forma File Organizing-2026.04.09_23-17-05--0700.xcresult` | Contains the passing targeted grid parity UI verification. |
| Code-backed source review | `FileGridItem.swift`, `FileSurfaceComponents.swift`, onboarding/rule-builder/inspector sources, `AppStoreScreenshotTests.swift` | Used where runtime coverage was missing or flaky. |

## 3. Criteria Summary

| Criterion | Result | Evidence | Notes |
| --- | --- | --- | --- |
| `C1 - Shell hierarchy` | Mixed | Existing March 5 captures + `AppStoreScreenshotTests` failure | Main workspace still reads coherently, but screenshot automation no longer matches current sidebar expectations. |
| `C2 - Review workflow clarity` | Pass | `FileRowTests`, `DashboardViewModelTests`, targeted grid parity UI test | Current pass ordering and recovery actions are now aligned across card/list/grid for the no-destination case. |
| `C3 - Rule-builder authority` | Partial | `RuleEditingWorkflowUITests` pass + code review | Layout is covered, but validation clarity still lacks direct runtime verification. |
| `C4 - Operational secondary surfaces` | Partial | Code inspection + `AppStoreScreenshotTests` failure | Right-panel/secondary-surface screenshot coverage is stale against current IA. |
| `C5 - Cross-view parity` | Pass after fix | Existing parity captures + `testGridViewKeepsChooseDestinationPrimaryActionVisibleWithoutHover` | Grid now exposes the same destination-recovery affordance as card/list without requiring hover. |
| `C6 - Native cohesion` | Partial | Existing captures + screenshot-suite failures | Product direction is coherent, but automation baselines for current shell/sidebar composition need refresh. |
| `Q1 - Visual density and contrast` | Partial | Existing light-mode artifacts | Dark mode and inactive/a11y reruns still missing. |
| `Q2 - State resilience` | Partial | Build/test results + flaky relaunch evidence | Core non-UI state paths passed, but inspector relaunch and screenshot UI harnesses remain unstable. |
| `Q3 - Brand cohesion` | Partial | Existing captures + code review | No new visual polish regressions found in the touched file-surface work. |
| `Q4 - Capture completeness` | Fail | Existing artifacts + failing screenshot suites | Required current-build runtime coverage is incomplete. |

## 4. Severity Summary

| Severity | Count |
| --- | --- |
| Critical | 0 |
| High | 1 |
| Medium | 5 |
| Low | 1 |

## 5. Findings Log

| ID | Severity | Surface | Evidence | Failed criterion | Finding | Required fix | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `APP-001` | High | File-surface parity | Existing card/list/grid captures plus passing `FileSurfaceToolbarValidationTests.testGridViewKeepsChooseDestinationPrimaryActionVisibleWithoutHover` | `C5` | Grid view previously hid the no-destination recovery action behind hover/focus, unlike card/list. | Keep `Choose Destination` visible in grid for files that still need setup, and pin the behavior with UI automation. | Coordinator | `Fixed` |
| `APP-002` | Medium | App Store screenshot suite | `AppStoreScreenshotTests.testCaptureAppStoreScreenshots` failed on `New Rule sidebar item should exist` during the full default run on 2026-04-09 | `C6`, `Q4` | The screenshot automation still expects a sidebar affordance that no longer exists in the current product structure. | Update the screenshot suite to target current inspector/sidebar affordances or restore the intended entry point. | UI/QA | `Open` |
| `APP-003` | Medium | File-surface screenshot capture suite | `FileSurfaceToolbarValidationTests.testCaptureFileSurfaceAndToolbarValidationShots` failed waiting for `mainContent_viewMode` to contain `card` during the full default run on 2026-04-09 | `Q4` | The broader screenshot capture path is not deterministic when switching back to card mode, even though the focused grid parity assertion now passes. | Stabilize view-mode selection in the capture suite before using it as a visual sign-off source. | UI/QA | `Open` |
| `APP-004` | Medium | Inspector persistence verification | Prior targeted UI attempt failed relaunch activation in `Forma_File_OrganizingUITests.testInspectorVisibilityPersistsAcrossRelaunches` | `Q2` | Inspector visibility persistence still lacks trustworthy runtime confirmation because relaunch activation is flaky. | Harden relaunch handling or add an alternate persistence verification path. | QA | `Blocked` |
| `APP-005` | Medium | Onboarding end-to-end coverage | Existing onboarding evidence is limited to welcome-state artifacts; `FolderSelectionStepView.swift` exists but is not referenced from `OnboardingFlowView.swift` | `C6`, `Q4` | Folder selection, permission denial/recovery, first scan, preview, and success were not directly re-verified in the current build. | Re-run onboarding coverage against the current flow and confirm whether the folder-selection step is intentionally inactive. | Product/UI | `Open` |
| `APP-006` | Medium | Accessibility and secondary-state coverage | Reduced-motion test is placeholder-only; dark mode, low-data analytics, and Smart Rules current-build captures were not refreshed | `Q1`, `Q4` | Coverage is still thin for dark mode, reduced motion, and low-data empty states on secondary surfaces. | Add targeted runtime captures and assertions for dark mode, reduced motion, Smart Rules, and Analytics empty/live states. | QA | `Open` |
| `APP-007` | Medium | Performance validation | `OptimizationBenchmarksTests` bootstrap failed in prior overnight run; `Scripts/signpost_harness_snapshot.sh` produced `0` harness samples for both tracked signposts | `Q2` | The perf harness is currently not producing usable regression data, so budgets in `Docs/PERFORMANCE_AUDIT.md` could not be checked. | Repair benchmark bootstrap and signpost export filtering before trusting perf sign-off. | Performance | `Blocked` |
| `APP-008` | Low | Non-UI regression signal | Earlier full non-UI xcresult showed a `FileScanPipelineTests` screenshot-tag crash, but isolated `FileScanPipelineTests` and the later full fallback run passed cleanly | `Q2` | The screenshot-tag failure was not reproducible after rerun, so it currently reads as suite instability rather than a confirmed product bug. | Monitor for recurrence; no code change justified from current evidence. | QA | `Monitor` |

## 6. Sign-Off Decision

| Decision | Value | Notes |
| --- | --- | --- |
| Ready for app polish sign-off | No | Screenshot automation and capture completeness still need follow-up. |
| Mandatory criteria passed | Partial | Review-flow parity improved, but evidence completeness remains below sign-off bar. |
| Number of blocking issues | 2 | Inspector persistence verification and performance harness validation remain blocked. |
| Next action | Refresh screenshot/UI harness expectations, then rerun onboarding + secondary-surface coverage | Highest-leverage remaining work is QA harness stabilization rather than more product code churn. |
