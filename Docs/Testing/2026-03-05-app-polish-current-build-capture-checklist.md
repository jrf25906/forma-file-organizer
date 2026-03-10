# Forma App Polish Current-Build Capture Checklist

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Developers | Designers | QA | Product

Use this checklist to capture baseline evidence for the current macOS app build before the next app polish implementation pass changes the screens. This is the execution companion to `Docs/Testing/2026-03-05-app-polish-validation-plan.md`.

## 1. Scope

- App target: `Forma File Organizing`
- Validation focus: visual hierarchy, native-feeling behavior, and cross-view consistency
- Baseline evidence already available:
  - `Docs/Marketing/Screenshots/AppStore/Upload/Light/forma-01-hero-main-window.png`
  - `Docs/Marketing/Screenshots/AppStore/Upload/Light/forma-02-all-files-list.png`
  - `Docs/Marketing/Screenshots/AppStore/Upload/Light/forma-03-rule-builder.png`
  - `Docs/Marketing/Screenshots/AppStore/Upload/Light/forma-04-smart-rules.png`
  - `Docs/Marketing/Screenshots/AppStore/Upload/Light/forma-05-analytics.png`
  - `Docs/Marketing/Screenshots/AppStore/Upload/Light/forma-06-settings.png`
  - Matching dark-mode screenshots in `Docs/Marketing/Screenshots/AppStore/Upload/Dark/`
- Supplemental still captures completed on March 5, 2026:
  - `Docs/Testing/Artifacts/app-polish/2026-03-05-current-build/all-files-grid--light-active.png`
  - `Docs/Testing/Artifacts/app-polish/2026-03-05-current-build/dashboard-pending-card--light-inactive.png`
  - `Docs/Testing/Artifacts/app-polish/2026-03-05-current-build/dashboard-pending-card--light-reduce-transparency.png`
  - `Docs/Testing/Artifacts/app-polish/2026-03-05-current-build/onboarding-welcome--light-active.png`
- Optional follow-up evidence not required for `APP-007` closure:
  - Card / list / grid parity strip
- Supplemental runtime evidence now available:
  - `Docs/Testing/Captures/app-polish-2026-03-05-181649.mov`
  - This recording covers the dashboard list with active selection, a populated Smart Rules state, Analytics low-data/loading/populated states, and Settings → General.
  - The remaining state gaps from that recording are closed by the still captures in `Docs/Testing/Artifacts/app-polish/2026-03-05-current-build/`.

## 2. Preflight

- Launch the app from Xcode or a local build.
- Use one Mac display for the full pass.
- Set display scale and app zoom to default.
- Record the branch name and commit SHA before capture.
- Capture light mode first, then dark mode spot checks.
- For the state pass, disable all floating overlays that do not belong to the main app workflow.
- If a scan or dataset changes the visible file set mid-capture, restart that surface so evidence remains consistent.

## 3. Window Set

| Label | Width | Height | Purpose |
| --- | --- | --- | --- |
| Standard desktop | `1440` | `900` | Primary review state for the main workspace |
| Compact split view | `1280` | `800` | Check sidebar / content / inspector balance |
| Minimum supported | `1200` | `700` | Stress test crowded toolbar and inspector layouts |
| Settings window | `760` | `600` | Match `SettingsView` fixed size |

## 4. Artifact Naming and Storage

Use one evidence root for the baseline app pass:

- Suggested root: `Docs/Testing/Artifacts/app-polish/2026-03-05-current-build/`

Use these file-name patterns:

- Screenshots: `{surface}--{theme}--{state}.png`
- Interaction recording: `app-flow--desktop-standard.mp4`
- Findings log: `app-polish--first-pass-findings.md`

### Recommended labels

- Dashboard pending queue: `dashboard-pending-card`
- All Files list: `all-files-list`
- File grid: `all-files-grid`
- Rule builder: `rule-builder`
- Smart Rules empty: `smart-rules-empty`
- Smart Rules live: `smart-rules-live`
- Analytics low data: `analytics-low-data`
- Analytics populated: `analytics-populated`
- Settings general: `settings-general`
- Onboarding welcome: `onboarding-welcome`
- Parity strip: `file-view-parity`

### State labels

- Active light: `light-active`
- Active dark: `dark-active`
- Inactive: `light-inactive`
- Reduce Transparency: `light-reduce-transparency`

## 5. Core Still Captures

| Capture ID | Surface | State | File stem | What must be visible | Source reference |
| --- | --- | --- | --- | --- | --- |
| `APP-01` | Dashboard pending queue + default inspector | `light-active` | `dashboard-pending-card--light-active` | Pending / All Files control, top rows, current task copy, automation section, primary CTA ownership | `Forma File Organizing/Views/DashboardView.swift`, `Views/Components/UnifiedToolbar.swift`, `Views/DefaultPanelView.swift`, `Views/RightPanelView.swift` |
| `APP-02` | All Files list view | `light-active` | `all-files-list--light-active` | All Files mode, list rows, destination metadata, and row actions | `Forma File Organizing/Views/MainContentView.swift`, `Components/FileListRow.swift` |
| `APP-03` | File grid view | `light-active` | `all-files-grid--light-active` | Same file set as list if possible, including visible status and destination metadata | `Forma File Organizing/Views/MainContentView.swift`, `Components/FileGridItem.swift` |
| `APP-04` | Inline rule builder | `light-active` | `rule-builder--light-active` | `When`, `Then`, validation copy, and create / save affordance | `Forma File Organizing/Views/InlineRuleBuilderView.swift`, `Views/RightPanelView.swift` |
| `APP-05` | Smart Rules empty state | `light-active` | `smart-rules-empty--light-active` | Empty state hero, create CTA, starter templates | `Forma File Organizing/Views/RulesManagementView.swift` |
| `APP-06` | Smart Rules live or needs-access state | `light-active` | `smart-rules-live--light-active` | Header, search, any category tabs, needs-access banner or rule rows | `Forma File Organizing/Views/RulesManagementView.swift` |
| `APP-07` | Analytics low-data state | `light-active` | `analytics-low-data--light-active` | Header, metric cards, no-data guidance if present, first charts row | `Forma File Organizing/Views/ProductivityReportView.swift` |
| `APP-08` | Settings General | `light-active` | `settings-general--light-active` | Theme control, startup toggles, spacing rhythm, and native control styling | `Forma File Organizing/Views/Settings/SettingsView.swift`, `Views/Settings/GeneralSettingsSection.swift` |
| `APP-09` | Onboarding welcome | `light-active` | `onboarding-welcome--light-active` | Headline, subtitle, trust signals, primary and secondary CTA | `Forma File Organizing/Views/Onboarding/WelcomeStepView.swift` |
| `APP-10` | Card / list / grid parity strip | `light-active` | `file-view-parity--light-active` | Same file or same file set in all three view modes | `Forma File Organizing/Views/Components/FileRow.swift`, `Components/FileListRow.swift`, `Components/FileGridItem.swift` |

## 6. State and Theme Captures

| Capture ID | Surface | State | File stem | What must be visible | Why it matters |
| --- | --- | --- | --- | --- | --- |
| `STATE-01` | Dashboard pending queue | `dark-active` | `dashboard-pending-card--dark-active` | Same composition as `APP-01` | Confirms contrast and chrome balance in dark mode |
| `STATE-02` | Rule builder | `dark-active` | `rule-builder--dark-active` | Same composition as `APP-04` | Checks validation hierarchy in dark mode |
| `STATE-03` | Analytics low-data | `dark-active` | `analytics-low-data--dark-active` | Same composition as `APP-07` | Confirms charts and empty states do not flatten in dark mode |
| `STATE-04` | Dashboard pending queue | `light-inactive` | `dashboard-pending-card--light-inactive` | Main workspace with app backgrounded | Validates inactive-window hierarchy and blur behavior |
| `STATE-05` | Dashboard pending queue | `light-reduce-transparency` | `dashboard-pending-card--light-reduce-transparency` | Main workspace with system Reduce Transparency enabled | Validates accessibility fallback clarity |

## 7. Interaction Recording

- File name: `app-flow--desktop-standard.mp4`
- Window size: `1440 x 900`
- Recording steps:
  - Open the dashboard pending queue and pause for 2 seconds.
  - Open the rule builder and pause for 2 seconds.
  - Switch to Smart Rules and pause for 2 seconds.
  - Switch to Analytics and pause for 2 seconds.
  - Open Settings and pause for 2 seconds.
  - If possible, return to the main workspace and switch card -> list -> grid on the same file set.

## 8. Current-Build Watchpoints

These are the high-risk areas to verify while capturing the current build.

- The split-view shell is structurally strong, but blur and tint may still soften the content hierarchy too much.
- The right panel contains strategically important task and automation controls, but they may read as visually secondary.
- The inline rule builder has better information architecture than before, but may still feel cramped and side-sheet-like.
- Smart Rules starter templates improve the empty state, but do not yet prove operational triage quality.
- Analytics may still render too much dashboard chrome when the dataset is near empty.
- Settings remains clean and readable, but may feel generic relative to the rest of the product.
- Card, list, and grid likely communicate status and actions differently enough to create parity debt.
- The March 5 recording now covers Smart Rules live state and the Analytics transition from no-data guidance to populated metrics, so the remaining evidence gaps are narrower than the original baseline list.
- The March 5 still-capture follow-up closes the required grid, onboarding, inactive-window, and `Reduce Transparency` evidence gaps for final visual sign-off.

## 9. Completion Checklist

- [ ] Branch name and commit SHA recorded
- [ ] Existing light-mode screenshot set reviewed
- [ ] Existing dark-mode screenshot set spot-checked
- [x] Grid-view capture added
- [x] Smart Rules live-state capture added
- [x] Onboarding capture added
- [x] Inactive-window capture added
- [x] `Reduce Transparency` capture added
- [ ] Card / list / grid parity strip captured
- [x] Interaction recording captured
- [x] Findings log initialized from the first-pass template
