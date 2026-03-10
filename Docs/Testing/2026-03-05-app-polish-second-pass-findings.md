# Forma App Polish Second-Pass Findings

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Developers | Designers | QA | Product

This is the post-polish rerun after the March 5, 2026 app implementation pass. Read it alongside the baseline report in `Docs/Testing/2026-03-05-app-polish-first-pass-findings.md`.

## 1. Run Metadata

| Field | Value |
| --- | --- |
| Validation date | 2026-03-05 |
| Reviewer | Codex |
| Build target | `Forma File Organizing` |
| Branch | Working tree with app polish implementation plus existing local documentation changes |
| Commit SHA | Not recorded in this pass |
| Evidence basis | Debug build, non-UI `xcodebuild test` rerun, code-backed review of updated dashboard shell, inspector, rule builder, Smart Rules, Analytics, Settings, onboarding, and card/list/grid file surfaces, review of `Docs/Testing/Captures/app-polish-2026-03-05-181649.mov`, plus follow-up still captures in `Docs/Testing/Artifacts/app-polish/2026-03-05-current-build/` |
| Notes | The March 5 recording covers dashboard list selection, populated Smart Rules, Analytics low-data/loading/populated states, and Settings → General. Follow-up still captures close the remaining grid, onboarding, inactive-window, and `Reduce Transparency` gaps. `Reduce Transparency` was already enabled at the macOS system level during capture. |

## 2. Evidence Manifest

| Artifact | Location | Notes |
| --- | --- | --- |
| Debug build | `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build` | Passed on March 5, 2026 |
| Non-UI test suite | `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"` | Passed on March 5, 2026 with `519` XCTest cases plus `1` Swift Testing case |
| Desktop interaction recording | `Docs/Testing/Captures/app-polish-2026-03-05-181649.mov` | Reviewed against extracted frames at `0:00`, `0:12`, `0:24`, `0:36`, `0:44`, and `1:00`; covers dashboard list, live Smart Rules, analytics transitions, and Settings → General |
| Supplemental still captures | `Docs/Testing/Artifacts/app-polish/2026-03-05-current-build/` | Includes `all-files-grid--light-active.png`, `dashboard-pending-card--light-inactive.png`, `dashboard-pending-card--light-reduce-transparency.png`, and `onboarding-welcome--light-active.png` |
| Baseline visual comparison | `Docs/Testing/2026-03-05-app-polish-first-pass-findings.md` and `Docs/Marketing/Screenshots/AppStore/Upload/` | Used as the before-state reference for the implementation wave |
| Current implementation review | `Forma File Organizing/Views/Components/PrimaryBackgroundView.swift`, `Views/DefaultPanelView.swift`, `Views/RightPanelView.swift`, `Views/InlineRuleBuilderView.swift`, `Views/RulesManagementView.swift`, `Views/ProductivityReportView.swift`, `Views/Onboarding/WelcomeStepView.swift`, `Views/Settings/GeneralSettingsSection.swift`, `Views/Settings/SettingsComponents.swift`, `Views/Components/FileRow.swift`, `Components/FileListRow.swift`, `Components/FileGridItem.swift`, `Components/Shared/FileMetaStrip.swift`, `Components/RuleManagementCard.swift` | Used to confirm closure of the first-pass implementation findings |
| Remaining visual evidence gap | None | The March 5 still-capture follow-up closes the final runtime evidence requirement for visual sign-off |

## 3. Criteria Summary

| Criterion | Result | Evidence | Notes |
| --- | --- | --- | --- |
| `C1 - Shell hierarchy` | Pass | `PrimaryBackgroundView.swift`; `DefaultPanelView.swift`; `RightPanelView.swift`; successful debug build | Pane chrome intensity was reduced, the default inspector now uses stronger section cards, and the panel mode header reads more like an operational control surface. |
| `C2 - Review workflow clarity` | Pass | `FileRow.swift`; `FileListRow.swift`; `FileGridItem.swift`; `FileMetaStrip.swift`; passing tests | The core review model remains clear, and the shared metadata strip now keeps file context more stable while switching views. |
| `C3 - Rule-builder authority` | Pass | `InlineRuleBuilderView.swift`; successful debug build | The builder now has explicit `When`, `Then`, and `Impact` sections plus a persistent consequence bar, which closes the earlier “sidebar form” problem at the implementation level. |
| `C4 - Operational secondary surfaces` | Pass | `RulesManagementView.swift`; `RuleManagementCard.swift`; `ProductivityReportView.swift`; passing tests | Smart Rules now group around operational states, and Analytics now suppresses weak dashboard theater in low-data states. |
| `C5 - Cross-view parity` | Pass | `FileRow.swift`; `FileListRow.swift`; `FileGridItem.swift`; `FileMetaStrip.swift`; passing `FileRowTests` | Card, list, and grid now share the same destination/status/confidence story instead of drifting semantically. |
| `C6 - Native cohesion` | Pass | `WelcomeStepView.swift`; `GeneralSettingsSection.swift`; `SettingsComponents.swift`; successful debug build | Onboarding and settings now align more closely with the product’s preview-first, operational voice without breaking native controls. |
| `Q1 - Visual density and contrast` | Pass | `PrimaryBackgroundView.swift`; `DefaultPanelView.swift`; `SettingsComponents.swift`; successful debug build; March 5 still-capture set | The implementation materially reduces washed-out chrome and strengthens surface separation, and the follow-up still captures now back that up visually. |
| `Q2 - State resilience` | Pass | Desktop recording plus `dashboard-pending-card--light-inactive.png` and `dashboard-pending-card--light-reduce-transparency.png` | The app now has direct evidence for both the active workflow and the fallback resilience states. |
| `Q3 - Brand cohesion` | Pass | `WelcomeStepView.swift`; `DefaultPanelView.swift`; `InlineRuleBuilderView.swift`; `GeneralSettingsSection.swift` | The onboarding, settings, and main workspace tone are substantially closer after the copy and shell cleanup. |
| `Q4 - Capture completeness` | Pass | Desktop recording plus March 5 still-capture set in `Docs/Testing/Artifacts/app-polish/2026-03-05-current-build/` | The required grid, onboarding, inactive-window, and `Reduce Transparency` states are now directly evidenced. |

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
| `APP-001` | High | Dashboard shell + default inspector | `PrimaryBackgroundView.swift`; `DefaultPanelView.swift`; `RightPanelView.swift`; debug build | `C1`, `Q3` | Baseline issue closed in implementation. The dashboard shell is less over-softened, the inspector has stronger section hierarchy, and the panel header now reads as a real mode control instead of passive chrome. | None in this implementation pass. | App UI | `Fixed` |
| `APP-002` | High | Inline rule builder | `InlineRuleBuilderView.swift`; debug build | `C3` | Baseline issue closed in implementation. The builder now stages rule authoring around `When`, `Then`, and `Impact`, and the persistent action bar keeps consequence and match count visible. | None in this implementation pass. | App UI | `Fixed` |
| `APP-003` | High | Card / list / grid parity | `FileMetaStrip.swift`; `FileRow.swift`; `FileListRow.swift`; `FileGridItem.swift`; passing `FileRowTests` | `C5` | Baseline issue closed in implementation. File context is now shared across views through a single metadata strip, and the card view no longer diverges as sharply in primary-action semantics. | None in this implementation pass. | App UI | `Fixed` |
| `APP-004` | Medium | Smart Rules | `RulesManagementView.swift`; `RuleManagementCard.swift`; debug build | `C4` | Baseline issue closed in implementation. Smart Rules now prioritize operational groupings such as `Needs Attention`, `Recently Triggered`, `Stable`, and `Disabled`, with the warning state kept legible. | None in this implementation pass. | App UI | `Fixed` |
| `APP-005` | Medium | Analytics | `ProductivityReportView.swift`; non-UI test rerun | `C4` | Baseline issue closed in implementation. Low-data analytics now lead with guidance and a startup checklist instead of forcing thin charts and weak metric theater. | None in this implementation pass. | App UI | `Fixed` |
| `APP-006` | Medium | Settings + onboarding voice | `WelcomeStepView.swift`; `GeneralSettingsSection.swift`; `SettingsComponents.swift`; debug build | `Q3` | Baseline issue closed in implementation. The onboarding copy, settings framing, and settings shell now better match the app’s preview-first authority. | None in this implementation pass. | App UI | `Fixed` |
| `APP-007` | Medium | Validation coverage | `Docs/Testing/Captures/app-polish-2026-03-05-181649.mov`; `Docs/Testing/Artifacts/app-polish/2026-03-05-current-build/` | `Q2`, `Q4` | Baseline evidence gap closed. The recording plus the four March 5 still captures now cover grid view, onboarding, inactive-window behavior, and `Reduce Transparency`, so the app has the full post-polish runtime evidence set required by the validation plan. | None. | Product design / QA | `Fixed` |

## 6. Sign-Off Decision

| Decision | Value | Notes |
| --- | --- | --- |
| Ready for implementation sign-off | Yes | The first app polish wave is implemented, builds cleanly, and passes the non-UI test suite. |
| Ready for final visual sign-off | Yes | `APP-007` is closed by the March 5 still-capture follow-up. |
| Mandatory criteria passed | `6 / 6` | All mandatory implementation criteria passed in this rerun. |
| Number of blocking implementation issues | `0` | The first-pass implementation findings `APP-001` through `APP-006` were closed. |
| Next action | Treat this rerun as the current app-polish visual baseline. | Optional parity-strip or additional motion captures can be added later without reopening the sign-off decision. |
