# Forma App Polish First-Pass Findings

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Developers | Designers | QA | Product

This is the populated first-pass review for the current macOS app build before the next app polish implementation loop. It is based on direct visual inspection of the current screenshot set plus code-backed surface review.

Follow-up: the post-polish rerun is documented in `Docs/Testing/2026-03-05-app-polish-second-pass-findings.md`.

## 1. Run Metadata

| Field | Value |
| --- | --- |
| Validation date | 2026-03-05 |
| Reviewer | Codex |
| Build target | `Forma File Organizing` |
| Branch | Working tree used for documentation pass |
| Commit SHA | Not recorded in this pass |
| Evidence basis | Light-mode App Store screenshot set, dark-mode spot checks, and code-backed review of dashboard, inspector, rule builder, Smart Rules, Analytics, Settings, onboarding, and file-view parity surfaces |
| Notes | This baseline pass is screenshot-backed rather than runtime-capture complete. Grid view, inactive-window state, `Reduce Transparency`, onboarding capture, and a populated Smart Rules state still need supplemental evidence before final sign-off. |

## 2. Evidence Manifest

| Artifact | Location | Notes |
| --- | --- | --- |
| Screenshot root | `Docs/Marketing/Screenshots/AppStore/Upload/` | Reviewed light-mode dashboard, list, rule builder, Smart Rules, Analytics, and Settings screenshots |
| Interaction recording | Not captured in this pass | Flow validation still needs a live capture pass |
| Light-mode baseline set | `Docs/Marketing/Screenshots/AppStore/Upload/Light/forma-01-hero-main-window.png` through `forma-06-settings.png` | Core baseline evidence |
| Dark-mode spot checks | `Docs/Marketing/Screenshots/AppStore/Upload/Dark/forma-01-hero-main-window.png`, `forma-03-rule-builder.png`, `forma-05-analytics.png` | Used to confirm that the same hierarchy issues persist in dark mode |
| Supplemental runtime captures | Not yet produced | Missing grid, onboarding, inactive, Reduce Transparency, and populated rules captures |
| Code-backed source review | `Forma File Organizing/Views/DashboardView.swift`, `Views/SidebarView.swift`, `Views/MainContentView.swift`, `Views/RightPanelView.swift`, `Views/DefaultPanelView.swift`, `Views/InlineRuleBuilderView.swift`, `Views/RulesManagementView.swift`, `Views/ProductivityReportView.swift`, `Views/Settings/SettingsView.swift`, `Views/Settings/GeneralSettingsSection.swift`, `Views/Onboarding/WelcomeStepView.swift`, `Views/Components/PrimaryBackgroundView.swift`, `Views/Components/FileRow.swift`, `Components/FileListRow.swift`, `Components/FileGridItem.swift` | Used to separate direct visual evidence from inferred parity and state coverage issues |

## 3. Criteria Summary

| Criterion | Result | Evidence | Notes |
| --- | --- | --- | --- |
| `C1 - Shell hierarchy` | Fail | `forma-01-hero-main-window.png` light and dark; `DashboardView.swift`; `DefaultPanelView.swift`; `PrimaryBackgroundView.swift` | The split-view structure is strong, but the glass, tint, and soft separators still flatten the hierarchy and make the inspector feel quieter than its actual job. |
| `C2 - Review workflow clarity` | Pass | `forma-01-hero-main-window.png`; `forma-02-all-files-list.png`; `MainContentView.swift`; `UnifiedToolbar.swift` | The primary review model is clear: pending queue, all files, row actions, and sort controls generally point toward an obvious next step. |
| `C3 - Rule-builder authority` | Fail | `forma-03-rule-builder.png` light and dark; `RightPanelView.swift`; `InlineRuleBuilderView.swift` | The IA is better than before, but the panel still reads as a narrow side form rather than the product's power surface. |
| `C4 - Operational secondary surfaces` | Fail | `forma-04-smart-rules.png`; `forma-05-analytics.png` light and dark; `RulesManagementView.swift`; `ProductivityReportView.swift` | Smart Rules and Analytics are improved, but they still do not guide action strongly enough in empty or low-data states. |
| `C5 - Cross-view parity` | Fail | `MainContentView.swift`; `FileRow.swift`; `FileListRow.swift`; `FileGridItem.swift` | Card, list, and grid do not yet tell the same file story with the same weight or affordances. |
| `C6 - Native cohesion` | Pass | `forma-06-settings.png`; `SettingsView.swift`; `GeneralSettingsSection.swift`; `WelcomeStepView.swift` | Controls remain native and trustworthy, but visual voice drift still needs cleanup. |
| `Q1 - Visual density and contrast` | Pass | Light and dark screenshot spot checks | Text is readable in both modes, but readable is not the same as decisive. The density and contrast are acceptable, not yet premium. |
| `Q2 - State resilience` | Fail | `PrimaryBackgroundView.swift`; missing inactive / `Reduce Transparency` captures | The fallback logic exists in code, but the required visual evidence is incomplete and the current chrome treatment is still likely too heavy in these states. |
| `Q3 - Brand cohesion` | Fail | `forma-01-hero-main-window.png`; `forma-06-settings.png`; `WelcomeStepView.swift` | The app still shifts between soft onboarding, generic settings, and operational dashboard tones. |
| `Q4 - Capture completeness` | Fail | Screenshot inventory and missing runtime captures | The baseline set is useful, but it is not complete enough for a final polish sign-off. |

## 4. Severity Summary

| Severity | Count |
| --- | --- |
| Critical | 0 |
| High | 3 |
| Medium | 4 |
| Low | 0 |

## 5. Findings Log

| ID | Severity | Surface | Evidence | Failed criterion | Finding | Required fix | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `APP-001` | High | Dashboard shell + default inspector | `forma-01-hero-main-window.png` light and dark; `DashboardView.swift`; `DefaultPanelView.swift`; `PrimaryBackgroundView.swift`; `RightPanelView.swift` | `C1`, `Q3` | The app's shell is structurally good, but the work surface is still over-softened by glass, tint, and ambient treatment. The current task card and automation section do not carry enough authority relative to the center queue, so the inspector reads like a polite attachment rather than a control surface. | Reduce pane chrome intensity in content and inspector surfaces, raise contrast on task copy and section dividers, and make the default inspector's task hierarchy visibly stronger than its decorative atmosphere. | App UI | Open |
| `APP-002` | High | Inline rule builder | `forma-03-rule-builder.png` light and dark; `RightPanelView.swift`; `InlineRuleBuilderView.swift` | `C3` | The rule builder has clearer structure than an ordinary settings form, but it still feels cramped and sidebar-bound. Validation is present, yet the consequence of the rule is not promoted enough to make the surface feel safe and powerful. | Rebuild the panel around a clearer `When` / `Then` / `Impact` stack with stronger section contrast and a persistent impact summary or preview region. | App UI | Open |
| `APP-003` | High | Card / list / grid parity | `MainContentView.swift`; `Views/Components/FileRow.swift`; `Components/FileListRow.swift`; `Components/FileGridItem.swift` | `C5` | The three file views still expose different semantics. List includes rule actions and confidence treatment that do not carry through evenly, card emphasizes destination in a separate action zone, and grid compresses the story further. Switching views changes what the file appears to mean. | Create a shared file metadata strip and align status, destination, confidence, and primary action semantics across all three file-view components. | App UI | Open |
| `APP-004` | Medium | Smart Rules | `forma-04-smart-rules.png`; `RulesManagementView.swift` | `C4` | The empty state is cleaner than a blank admin screen and the starter templates help, but the surface still behaves more like a setup page than an operations page. It does not yet communicate rule health, urgency, or recent effectiveness. | Group live rules by operational status such as `Needs Access`, `Recently Triggered`, `Stable`, and `Disabled`, and keep the templates secondary once real rules exist. | App UI | Open |
| `APP-005` | Medium | Analytics | `forma-05-analytics.png` light and dark; `ProductivityReportView.swift` | `C4` | The analytics screen is readable and ambitious, but the current low-data presentation still reads like dashboard theater. Big metric cards and charts remain visible even when the insight payload is nearly empty, which undercuts credibility. | Add a stronger thresholded no-data mode that suppresses weak charts and promotes one concrete next step until the dataset is meaningful. | App UI | Open |
| `APP-006` | Medium | Settings + onboarding voice | `forma-06-settings.png`; `Views/Settings/SettingsView.swift`; `Views/Settings/GeneralSettingsSection.swift`; `Views/Onboarding/WelcomeStepView.swift` | `Q3` | Settings is clean but generic, onboarding is warm and trust-heavy, and the main workspace is operational. All three are individually competent, but the product voice shifts too much between them. | Unify tone, section framing, and supporting copy so onboarding trust, settings clarity, and main-workspace authority feel like one product family. | App UI | Open |
| `APP-007` | Medium | Validation coverage | Screenshot inventory under `Docs/Marketing/Screenshots/AppStore/Upload/`; missing runtime captures listed in the capture checklist | `Q2`, `Q4` | The current evidence set is enough to identify the main polish problems, but not enough to declare the app visually signed off. Grid view, inactive-window state, `Reduce Transparency`, onboarding, and a populated Smart Rules state still need direct capture. | Produce the missing runtime capture set before the post-polish rerun so hierarchy and parity claims are evidence-backed rather than inferred. | Product design / QA | Open |

## 6. Sign-Off Decision

| Decision | Value | Notes |
| --- | --- | --- |
| Ready for app polish sign-off | No | The app has a strong native foundation, but the first polish pass still surfaces unresolved hierarchy, parity, and cohesion issues. |
| Mandatory criteria passed | `2 / 6` | `C2 - Review workflow clarity` and `C6 - Native cohesion` passed. |
| Number of blocking issues | 6 | `APP-001` through `APP-006` should be treated as the first app polish wave. |
| Next action | Implement the first app polish wave, then rerun the validation plan with the missing runtime captures included. | Start with shell hierarchy, rule-builder authority, and card / list / grid parity. |
