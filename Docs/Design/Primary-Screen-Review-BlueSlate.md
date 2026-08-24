# Primary Screen Design Review - Combined Recommendations

**Date:** 2026-04-27
**Status:** Current review brief, pre-implementation
**Scope:** Native macOS app primary screens only
**Out of scope:** `forma-website/`, marketing pages, feature behavior, API behavior

This document combines the requested `gpt-taste`, `frontend-skill`, `high-end-visual-design`, `ui-ux-pro-max-skill`, and `interface-craft` lenses into one native-app design review for Forma.

The review is screenshot-grounded. It used a live Debug build of the app and current XCUITest screenshot captures, not only source-code inspection. The recommendation language below translates web-heavy skill advice into native macOS SwiftUI concerns: surface hierarchy, work density, accent discipline, reduced-motion-safe microinteractions, state clarity, and operational focus.

## Current Direction

The selected visual direction remains **Blue Slate**: darker slate anchors, clearer surface steps, stronger title jumps, darker text, and a more committed blue accent used sparingly.

The app is already coherent and native-feeling. The highest-impact problem is not missing polish; it is that too many panes, rows, controls, cards, badges, and footer states compete at nearly the same visual level. The next pass should make the product easier to read before it makes it more decorative.

## Evidence Reviewed

### Commands Run

- Debug build:
  - `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug -derivedDataPath /tmp/FormaTasteAuditDerivedData build`
  - Result: passed.
- Live app screenshot:
  - `python3 /Users/jamesfarmer/.codex/skills/screenshot/scripts/take_screenshot.py --app "Forma File Organizing" --mode temp`
  - Result: captured the running app window.
- Current primary-screen screenshot harness:
  - `FORMA_SCREENSHOT_OUTPUT_DIR=/tmp/forma-taste-audit-shots xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - UI" -destination 'platform=macOS' -derivedDataPath /tmp/FormaTasteAuditDerivedData -only-testing:"Forma File OrganizingUITests/AppStoreScreenshotTests/testCaptureAppStoreScreenshots"`
  - Result: passed.
- Exported XCUITest attachments:
  - `/tmp/forma-taste-audit-current-shots/light/`
  - `/tmp/forma-taste-audit-current-shots/dark/`

### Screens Reviewed

- Main review workspace, light and dark
- All Files list, light and dark
- Rule Builder, light and dark
- Smart Rules empty state, light and dark
- Analytics / Productivity Health, light and dark
- Settings / General, light and dark

### Evidence Caveats

- The current review screenshots were exported to `/tmp` for inspection and were not added to the repository.
- The durable screenshot naming contract is the App Store screenshot harness under `Docs/Marketing/Screenshots/AppStore/`.
- A few screenshot captures show hover tooltip or sidebar hover artifacts from the test cursor. Treat those as capture artifacts, not product findings.
- The XCUITest harness did not capture the File Inspector after selecting the first file because the inspector probe did not appear; the test continued and passed. That is a product-state signal worth following up during the right-rail pass.

## Skill Synthesis

| Lens | What It Contributed | Native App Translation |
| --- | --- | --- |
| `frontend-skill` | App UI should prioritize primary workspace, navigation, secondary context, and one clear accent. | Treat Forma as an operational Mac tool, not a landing page. No hero sections, card mosaics, or decorative gradients behind routine data. |
| `gpt-taste` | Strong hierarchy, wide type rhythm, no cheap labels, no generic card sprawl, intentional motion. | Avoid narrow stacked control islands and equally weighted panels. Use motion to clarify state changes, not to perform. GSAP/AIDA rules do not apply to this native app. |
| `high-end-visual-design` | Premium surface ladder, haptic interaction, restrained shadows, physical depth. | Create a native surface ladder with semantic materials and tokens. Use nested elevation sparingly for primary command surfaces, not every card. |
| `ui-ux-pro-max-skill` | SwiftUI accessibility and UX rules: reduced motion, consistent type scale, loading feedback, contrast, 150-300ms microinteractions. | Gate motion with `accessibilityReduceMotion`, keep focus rings visible, improve light-mode contrast, and keep animations fast. |
| `interface-craft` | Context-first critique: first impressions, visual design, interface design, consistency, user context, top opportunities. | Frame recommendations around the user's file-review mindset: focused, trust-seeking, and trying to reduce clutter without fear of irreversible actions. |

## Context

Forma is a high-trust file organization app. The user is not browsing; they are making decisions about files, rules, destinations, permissions, and automation. The interface should feel calm, but it also has to be decisive. Softness helps only until it starts obscuring what is active, what is safe, and what happens next.

## First Impression

The app looks more mature than a typical utility app, but it still reads as a set of visually polished regions rather than a strict operating surface. The main window has a strong shell, yet the toolbar, rows, right rail, floating action bar, and ambient material all ask for attention at once. In light mode, the same issue becomes paleness: many surfaces are pleasant, but too few are authoritative.

## Ranked Recommendations

Freshness correction: several recommendations are already partially or mostly implemented in the current app. The table below keeps the recommendation only where there is still implementation value, and calls out rows that should be treated as verification or polish rather than new work.

| Priority | Current Status | Recommendation | Expected User Impact | Cost | Primary Anchors |
| --- | --- | --- | --- | --- | --- |
| P0 | Partially landed | Keep the three-tier surface ladder, but audit where dense scrollable data still sits over ambient material. The app already has `FormaMaterialTier` plus `formaSurfaceAnchor`, `formaSurfaceWork`, `formaSurfaceChrome`, and `formaSurfaceFloating`; the remaining work is mostly reducing active gradients/material behind the center file surface where screenshots still read soft. | Faster first read; stronger contrast in light mode; less "washed together" feeling. | S-M | `Forma File Organizing/DesignSystem/FormaColors.swift`, `Forma File Organizing/DesignSystem/FormaMaterialTiers.swift`, `Forma File Organizing/Views/Components/PrimaryBackgroundView.swift`, `Forma File Organizing/Views/MainContentView.swift` |
| P0 | Mostly landed | Treat toolbar consolidation as a verification/polish item, not a rebuild. `UnifiedToolbar` already consolidates scope, context, arrange, view mode, and inspector toggle into one rhythm; the remaining question is whether screenshots still show too many equal chrome islands in narrow widths. | Reduces top-chrome scan cost and makes the workspace state clearer. | S-M | `Forma File Organizing/Views/Components/UnifiedToolbar.swift`, `Forma File Organizing/Views/MainContentView.swift`, `Forma File Organizing/Views/DashboardView.swift` |
| P0 | Partially landed | Keep the contextual floating action bar, but tune review-mode prominence and label sizing. The bar is already contextual for selection/review states and uses shorter labels like "Organize Ready"; it may still read too dominant when shown for an ordinary review pass. | Removes the competing "second hero" at the bottom of the screen and makes actions feel causally tied to selection. | S-M | `Forma File Organizing/Components/FloatingActionBar.swift`, `Forma File Organizing/Views/MainContentView.swift`, `Forma File Organizing/ViewModels/SelectionViewModel.swift`, `Forma File Organizing/ViewModels/BulkOperationViewModel.swift` |
| P1 | Partially landed | Recommit the blue accent to only primary actions, active selections, focus, and current-state indicators. Current code has stronger Blue Slate tokens, but many badges, links, and secondary controls still use blue enough that the accent can lose command meaning. | Color regains meaning; users can identify what is actionable without decoding every blue object. | S-M | `Forma File Organizing/DesignSystem/FormaColors.swift`, `Forma File Organizing/DesignSystem/Components/FormaBadges.swift`, `Forma File Organizing/DesignSystem/Components/FormaStatusPill.swift`, `Forma File Organizing/DesignSystem/Components/FormaButtons.swift` |
| P1 | Structurally landed, visually open | Treat the right rail command-state model as structurally done. `PanelStateManager.RightPanelMode` already makes default, inspector, rules, rule builder, celebration, and analytics mutually exclusive; remaining work is visual hierarchy inside the default panel and inspector reliability from the screenshot harness caveat. | The right rail becomes a decision surface instead of a stack of useful but equal modules. | M | `Forma File Organizing/Views/RightPanelView.swift`, `Forma File Organizing/Views/DefaultPanelView.swift`, `Forma File Organizing/Views/FileInspectorView.swift`, `Forma File Organizing/Views/InlineRuleBuilderView.swift` |
| P1 | Mostly landed | Downgrade Rule Builder to polish. `InlineRuleBuilderView` already uses a guided card with name, numbered `When`, `Then`, and review/preview sections, inline validation, impact preview, and overlap handling. Remaining work should be small visual simplification only. | Keeps rule creation feeling guided without reworking working structure. | S | `Forma File Organizing/Views/RuleEditorView.swift`, `Forma File Organizing/Views/InlineRuleBuilderView.swift`, `Forma File Organizing/Views/Components/RuleConditionBuilder.swift`, `Forma File Organizing/Views/Components/RuleDestinationPicker.swift`, `Forma File Organizing/Views/Components/RuleEditorHeaderConfig.swift` |
| P1 | Partially landed | Rework Smart Rules empty-state emphasis, not its existence. Starter templates already exist and open directly in the builder; the remaining issue is that the intro band and `Create Rule` action still precede the templates and can dominate the first read. | Empty state feels immediately useful; users get a first successful action without hunting. | S | `Forma File Organizing/Views/RulesManagementView.swift`, `Forma File Organizing/Components/RuleManagementCard.swift`, `Forma File Organizing/Views/TemplateSelectionView.swift`, `Forma File Organizing/DesignSystem/Components/FormaEmptyStates.swift` |
| P2 | Partially landed | Finish Analytics low-data tone. `ProductivityReportView` already has no-data guidance and a getting-started checklist; the remaining issue is the fallback `Organization Score` grade still saying "Needs Work" for very low scores, plus chart sizing in sparse states. | Reduces discouragement and makes analytics understandable before the user has meaningful history. | S-M | `Forma File Organizing/Views/ProductivityReportView.swift`, `Forma File Organizing/Components/AnalyticsStatCard.swift`, `Forma File Organizing/Components/ImpactMetricCard.swift`, `Forma File Organizing/Components/StackedAreaChart.swift`, `Forma File Organizing/Components/CalendarHeatmap.swift` |
| P2 | Mostly landed | Treat Settings as Blue Slate tuning. `SettingsTabShell` and `SettingsSection` already use the app surface ladder and `formaSteelBlue` tint; remaining work is tab icon weight/native preference polish rather than a full restyle. | Settings stops feeling like a separate app surface. | S | `Forma File Organizing/Views/Settings/SettingsView.swift`, `Forma File Organizing/Views/Settings/SettingsComponents.swift`, `Forma File Organizing/Views/Settings/GeneralSettingsSection.swift`, `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift` |
| P2 | Partially landed | Run a targeted microinteraction audit rather than creating the motion system from scratch. The app already has `FormaAnimation`, `FormaMicroanimations`, `FormaEasing`, and broad `accessibilityReduceMotion` usage; remaining work is to find unguarded animations and decorative row motion. | Interactions feel responsive and intentional without adding visual noise or accessibility risk. | S | `Forma File Organizing/DesignSystem/FormaEasing.swift`, `Forma File Organizing/DesignSystem/FormaMicroanimations.swift`, `Forma File Organizing/DesignSystem/FormaAnimation.swift` |

## Screen Notes

### Main Review Workspace

**What is working:** The three-column architecture is right for the product: navigation, working queue, and secondary command context. The file rows have useful metadata, and the right rail has the right ingredients for trust.

**What is not yet resolved:** The toolbar has already been unified in code, but screenshots should still verify whether its clusters feel too equally weighted in narrow widths. The file queue, right rail, and bottom action bar can still compete for primary status. The ambient backdrop gives the screen atmosphere but makes the dense file list feel less anchored.

**Recommendation:** Start the next implementation pass here, but avoid rebuilding already-landed toolbar structure. Focus on material quieting, bottom-bar prominence, right-rail hierarchy, and accent discipline.

### Light Mode

**What is working:** The app feels open and friendly.

**What is not yet resolved:** The light-mode surface system is too soft. Rows, metadata, right-rail cards, and disabled/passive states blend together. The solution is not simply a darker hue; it is a stronger semantic contrast ladder.

**Recommendation:** Audit token pairs against actual material backgrounds before changing the palette. Killing or reducing material behind dense data will likely fix much of the paleness without a broad recolor.

### Rule Builder

**What is working:** The form already has good primitives: rule name, draft prompt, conditions, actions, validation, and persistent save state.

**What is already done:** The inline builder already has a guided form with the main sequence users need: name the rule, define `When`, choose `Then`, review preview/impact, and save. Validation, overlap detection, and impact preview already exist.

**Recommendation:** Do not rebuild this flow. Keep future work to visual compression, badge/accent restraint, and making validation feel subordinate to the main path.

### Smart Rules

**What is working:** Starter templates are concrete and useful.

**What is already done:** The empty state includes starter templates and each template opens the builder directly.

**Recommendation:** Let templates be the primary empty-state content. Keep Create Rule present, but tune the intro band so it does not drown out faster choices.

### Analytics

**What is working:** Productivity Health has a clear headline, period selector, KPI row, and chart areas.

**What is already done:** The low/no-data path now includes explicit guidance and a getting-started checklist.

**Recommendation:** Finish the tone pass by replacing punitive low-score labels such as "Needs Work" in sparse-data contexts and shrinking or replacing chart containers when they do not yet have useful signal.

### Settings

**What is working:** The Settings window follows familiar macOS preferences behavior.

**What is already done:** Settings now uses Blue Slate-adjacent shells, work surfaces, and the app accent tint.

**Recommendation:** Keep native preferences conventions. Treat remaining work as small tab/icon/card tuning, not a full settings redesign.

## Implementation Sequencing

This review is not an implementation plan, but the order matters:

1. Surface ladder verification and ambient material quieting.
2. Bottom action bar review-mode prominence and label sizing.
3. Right rail default-panel hierarchy plus inspector reliability.
4. Accent discipline sweep across badges, passive links, and secondary controls.
5. Smart Rules empty-state emphasis and Analytics low-data tone.
6. Settings tab polish and motion/reduced-motion audit.

Do not bundle all recommendations into one branch. The first branch should not rebuild the toolbar or Rule Builder from scratch; those are already mostly landed. It should focus on current visual evidence: material softness, action-bar prominence, right-rail hierarchy, and accent discipline.

## Validation Checklist

Run visual validation against light and dark mode after each implementation slice.

- Main review screen: hierarchy is clear in the first two seconds; bottom action bar appears only when causally relevant.
- File surfaces: filenames and destinations read before badges and row actions; card/list/grid parity remains intact.
- Right rail: there is exactly one primary "now" state at a time; file selection reliably opens or updates the inspector.
- Rule Builder: `Name`, `When`, `Then`, and preview form the main path; validation stays near the failing input.
- Smart Rules: templates are visible and actionable in the first viewport.
- Analytics: low-data states are instructional, not punitive.
- Settings: preferences remain native, but surfaces and accent usage match the main app.
- Accessibility: focus rings remain visible, increased contrast remains legible, and Reduce Motion disables nonessential animation.
- Material: dense data screens remain readable when Reduce Transparency is enabled.
- Screenshot harness: rerun `AppStoreScreenshotTests` and confirm the captured surfaces do not include accidental hover artifacts before using them as marketing evidence.

## Non-Goals

- This is not a website review.
- This is not a code implementation plan.
- This does not authorize touching `forma-website/`.
- This does not require `TODO.md`, `CHANGELOG.md`, or `API_REFERENCE.md` changes because no behavior, API, or workflow has changed.
- This does not mandate new token names. A later implementation plan may propose token additions or retuned values, but it should justify them against the current design-system anchors.
