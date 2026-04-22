# Dashboard Layout State Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved dashboard root-state contract so `Home` launches in the intended three-area workspace, left-sidebar `Analytics` and `Smart Rules` become full-workspace destinations, contextual rule creation stays in the compact right panel, and returning from destinations restores the exact prior `Home` state.

**Architecture:** Add an explicit dashboard root-workspace state on top of the existing inspector/panel state instead of continuing to infer destination behavior from `isRightPanelVisible` and `rightPanelMode`. Preserve the left sidebar across all root states, reuse the existing full-workspace analytics/rules views for destination screens, and keep the current right-panel rule builder flow for contextual actions. Extend the existing `WindowPresentationStore` to remember inspector width so `Home` restoration is durable rather than approximate.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, XCTest, XCUITest, existing `NavigationSplitView` dashboard shell, `WindowPresentationStore`, `PanelStateManager`, `DashboardViewModel`.

---

## Implementation Rules

- Use the approved spec as the source of truth: `Docs/superpowers/specs/2026-04-21-dashboard-layout-state-contract-design.md`.
- Do not encode root-screen routing indirectly through `NavigationSplitViewVisibility` or by overloading `RightPanelMode`.
- Keep the left sidebar persistent across `Home`, full-workspace `Analytics`, and full-workspace `Smart Rules`.
- Treat sidebar/default-panel/global actions separately from contextual file/review actions.
- Preserve the current compact rule-builder behavior for contextual entry points.
- Reuse the existing full-workspace analytics/rules surfaces instead of creating duplicate destination screens.
- Keep changes in the native app only. No `forma-website/` work belongs in this plan.

## File Structure

### Reference

- `Docs/superpowers/specs/2026-04-21-dashboard-layout-state-contract-design.md` — approved behavior contract.

### Create

- `Forma File Organizing/ViewModels/DashboardWorkspaceState.swift` — explicit root-workspace destination enum plus `Home` snapshot model used by `DashboardViewModel`.

### Modify

- `Forma File Organizing/ViewModels/DashboardViewModel.swift` — owns root-workspace state, snapshot capture/restore, global-vs-contextual routing helpers, and inspector-width persistence hooks.
- `Forma File Organizing/Views/DashboardView.swift` — chooses between `homeWorkspace`, `analyticsWorkspace`, and `rulesWorkspace` layouts while preserving the sidebar across all of them.
- `Forma File Organizing/Coordinators/PanelStateManager.swift` — keep right-panel mode focused on `Home`-context panel content only; remove destination responsibilities from the panel layer where needed.
- `Forma File Organizing/Views/SidebarView.swift` — route left-sidebar `Analytics` and `Smart Rules` to workspace destinations instead of right-panel modes.
- `Forma File Organizing/Views/DefaultPanelView.swift` — update any global “View Activity” / “Smart Rules” entry points to use workspace destinations instead of compact panel routing.
- `Forma File Organizing/Views/ProductivityReportView.swift` — expose destination-mode header behavior with `Back to Dashboard` and no active inspector navigation.
- `Forma File Organizing/Views/RulesManagementView.swift` — expose destination-mode header behavior with `Back to Dashboard`.
- `Forma File Organizing/Views/Components/UnifiedToolbar.swift` — hide or disable inspector controls outside `homeWorkspace`.
- `Forma File Organizing/DesignSystem/FormaSpacing.swift` — adjust preferred launch/right-panel defaults only if needed to match the approved `Home` width balance.

### Test

- `Forma File OrganizingTests/DashboardViewModelTests.swift`
- `Forma File OrganizingTests/DashboardSplitViewPolicyTests.swift`
- `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`
- `Forma File OrganizingUITests/UITestHarness.swift`
- `Forma File OrganizingUITests/AppStoreScreenshotTests.swift`

### Docs

- `CHANGELOG.md`
- `TODO.md`

## Task 1: Add an Explicit Dashboard Root-Workspace State

**Files:**
- Create: `Forma File Organizing/ViewModels/DashboardWorkspaceState.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`

- [ ] **Step 1: Write failing unit tests for root-workspace transitions**

Add focused tests that describe the new public contract:

```swift
func testSidebarAnalyticsEntersAnalyticsWorkspaceWithoutMutatingHomePanelState()
func testSidebarSmartRulesEntersRulesWorkspaceWithoutMutatingHomePanelState()
func testReturnToHomeWorkspaceRestoresCapturedInspectorVisibilityAndPanelMode()
func testContextualRuleBuilderStaysInHomeWorkspace()
```

Expected assertions:
- sidebar analytics/rules change a new `workspaceDestination`
- contextual rule builder leaves `workspaceDestination == .home`
- returning from a destination restores the previous `Home` snapshot

- [ ] **Step 2: Run the focused dashboard view-model tests and verify they fail**

Run:
```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:'Forma File OrganizingTests/DashboardViewModelTests'
```

Expected:
- New tests fail because `DashboardViewModel` has no explicit root-workspace state yet.

- [ ] **Step 3: Create the root-workspace model file**

Add a focused support file such as:

```swift
enum DashboardWorkspaceDestination: Equatable {
    case home
    case analytics
    case rules
}

struct DashboardHomeWorkspaceSnapshot: Equatable {
    let isRightPanelVisible: Bool
    let rightPanelMode: PanelStateManager.RightPanelMode
}
```

Keep this file limited to root-state concepts only. Do not move unrelated dashboard logic into it.

- [ ] **Step 4: Teach `DashboardViewModel` the difference between root destinations and `Home` panel state**

Add the minimum new `DashboardViewModel` surface:

```swift
@Published var workspaceDestination: DashboardWorkspaceDestination = .home

func showAnalyticsWorkspace()
func showRulesWorkspace()
func returnToHomeWorkspace()
```

Implementation rules:
- capture the current `Home` snapshot before leaving `.home`
- `showAnalyticsWorkspace()` and `showRulesWorkspace()` must not force the app through compact right-panel routing
- `showRuleBuilderPanel(...)` remains contextual and must leave `workspaceDestination == .home`

- [ ] **Step 5: Run the focused dashboard view-model tests and make them pass**

Run:
```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:'Forma File OrganizingTests/DashboardViewModelTests'
```

Expected:
- The new root-workspace tests pass.
- Existing right-panel tests still pass or fail only where the new contract intentionally changes them.

- [ ] **Step 6: Commit the root-state slice**

```bash
git add "Forma File Organizing/ViewModels/DashboardWorkspaceState.swift" \
        "Forma File Organizing/ViewModels/DashboardViewModel.swift" \
        "Forma File OrganizingTests/DashboardViewModelTests.swift"
git commit -m "Add dashboard root workspace state"
```

## Task 2: Separate Global Destination Entry Points from Contextual Panel Entry Points

**Files:**
- Modify: `Forma File Organizing/Views/SidebarView.swift`
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`

- [ ] **Step 1: Inventory every current analytics/rules entry point and classify it**

Classify each call site as either:
- `global destination` — should enter full-workspace `analyticsWorkspace` / `rulesWorkspace`
- `contextual panel` — should stay in `homeWorkspace` and use the compact right panel

At minimum, inspect and classify:
- `SidebarView.swift`
- `DefaultPanelView.swift`
- `FileInspectorView.swift`
- `RuleEditorView.swift`
- `CelebrationView.swift`
- `RuleSuggestionView.swift`

Write the intended mapping into code comments only if a seam is likely to be revisited; otherwise keep the classification in the implementation diff / commit message.

- [ ] **Step 2: Update global entry points to use workspace destinations**

Replace current global calls like:

```swift
dashboardViewModel.showAnalyticsPanel()
dashboardViewModel.showRulesManagementPanel()
```

with destination calls such as:

```swift
dashboardViewModel.showAnalyticsWorkspace()
dashboardViewModel.showRulesWorkspace()
```

Required surfaces:
- left-sidebar `Analytics`
- left-sidebar `Smart Rules`
- any global dashboard CTA that means “go to Analytics” or “go to Smart Rules” rather than “open a contextual editor”

- [ ] **Step 3: Keep contextual rule flows on compact panel routing**

Do not change contextual calls like:

```swift
dashboardViewModel.showRuleBuilderPanel(fileContext: file)
dashboardViewModel.showRuleBuilderPanel(editingRule: rule, fileContext: file)
dashboardViewModel.showRuleBuilderPanelForInspector(file)
```

Expected result:
- file/review-driven rule creation remains a `Home` action
- the center workflow stays visible
- the right panel remains the editing surface

- [ ] **Step 4: Update or replace any unit tests whose names still describe the old compact analytics behavior**

Examples to rewrite:
- `testShowAnalyticsPanelRevealsRightPanel()` should no longer be the primary global contract test
- global analytics/rules tests should assert workspace destination state
- contextual rule-builder tests should continue asserting right-panel behavior

- [ ] **Step 5: Run the focused dashboard view-model tests**

Run:
```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:'Forma File OrganizingTests/DashboardViewModelTests'
```

Expected:
- global-vs-contextual routing tests all pass

- [ ] **Step 6: Commit the routing-surface slice**

```bash
git add "Forma File Organizing/Views/SidebarView.swift" \
        "Forma File Organizing/Views/DefaultPanelView.swift" \
        "Forma File Organizing/ViewModels/DashboardViewModel.swift" \
        "Forma File OrganizingTests/DashboardViewModelTests.swift"
git commit -m "Separate dashboard destination and panel entry points"
```

## Task 3: Rebuild `DashboardView` Around Root Workspace Destinations

**Files:**
- Modify: `Forma File Organizing/Views/DashboardView.swift`
- Modify: `Forma File Organizing/Views/ProductivityReportView.swift`
- Modify: `Forma File Organizing/Views/RulesManagementView.swift`
- Modify: `Forma File Organizing/Views/Components/UnifiedToolbar.swift`
- Test: `Forma File OrganizingTests/DashboardSplitViewPolicyTests.swift`
- Test: `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`
- Test: `Forma File OrganizingUITests/UITestHarness.swift`

- [ ] **Step 1: Write failing tests for the new root layouts**

Add or rename tests to cover:

```swift
func testHomeWorkspaceUsesSidebarContentAndInspectorArrangement()
func testAnalyticsWorkspaceUsesSidebarAndFullWorkspaceArrangement()
func testRulesWorkspaceUsesSidebarAndFullWorkspaceArrangement()
func testDestinationScreensHideOrDisableInspectorToggle()
```

UI tests should assert:
- `Analytics` no longer uses `compactAnalyticsPanel`
- the left sidebar remains visible
- a full-workspace analytics surface is visible
- `Back to Dashboard` exists on both full-workspace destinations

- [ ] **Step 2: Replace the current analytics special-case split logic with explicit root-state branches**

Refactor `DashboardView` so it chooses layout by `workspaceDestination`, not by `panelStateManager.rightPanelMode == .analytics`.

Target shape:

```swift
switch dashboardViewModel.workspaceDestination {
case .home:
    homeSplitViewLayout
case .analytics:
    analyticsWorkspaceLayout
case .rules:
    rulesWorkspaceLayout
}
```

Rules:
- `homeSplitViewLayout` keeps the current three-area composition
- `analyticsWorkspaceLayout` is sidebar + full-width analytics workspace
- `rulesWorkspaceLayout` is sidebar + full-width rules workspace

- [ ] **Step 3: Reuse the existing full-workspace analytics and rules views**

Use:
- `ProductivityReportView` for analytics workspace
- `RulesManagementView` for rules workspace

Modify both views to support destination-mode chrome:
- visible `Back to Dashboard` action
- no active inspector-toggle semantics

Keep these changes narrow. Do not redesign the screens.

- [ ] **Step 4: Update toolbar behavior so inspector controls belong only to `Home`**

In `UnifiedToolbar`, gate inspector visibility with the new root destination:

```swift
let inspectorIsAvailable = dashboardViewModel.workspaceDestination == .home
```

Then:
- hide the inspector toggle entirely in destination screens, or
- keep it present but disabled only if the visual shell requires it

Prefer hiding unless the toolbar layout becomes unstable.

- [ ] **Step 5: Update probes so tests can distinguish `homeWorkspace` from destination screens**

Add or revise accessibility probes in `DashboardView` / toolbar:
- root workspace destination
- split arrangement
- inspector visibility availability

Do not rely on only the old `twoColumn` / `threeColumn` probe values, because both destination screens and hidden-inspector `Home` are two-area layouts for different reasons.

- [ ] **Step 6: Run focused layout unit and UI tests**

Run:
```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' \
  -only-testing:'Forma File OrganizingTests/DashboardSplitViewPolicyTests' \
  -only-testing:'Forma File OrganizingUITests/Forma_File_OrganizingUITests/testAnalyticsSelectionKeepsSidebarVisibleAndUsesTwoColumnLayout' \
  -only-testing:'Forma File OrganizingUITests/Forma_File_OrganizingUITests/testInspectorHiddenStateUsesTwoColumnWithoutCollapsingSidebar' \
  -only-testing:'Forma File OrganizingUITests/Forma_File_OrganizingUITests/testInspectorTogglePreservesSidebarAndSplitProbeDuringVisibilityChanges'
```

Expected:
- Existing analytics compact-panel assertions fail first, then are replaced by full-workspace assertions
- `Home` inspector tests continue to pass after probe updates

- [ ] **Step 7: Commit the dashboard layout slice**

```bash
git add "Forma File Organizing/Views/DashboardView.swift" \
        "Forma File Organizing/Views/ProductivityReportView.swift" \
        "Forma File Organizing/Views/RulesManagementView.swift" \
        "Forma File Organizing/Views/Components/UnifiedToolbar.swift" \
        "Forma File OrganizingTests/DashboardSplitViewPolicyTests.swift" \
        "Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift" \
        "Forma File OrganizingUITests/UITestHarness.swift"
git commit -m "Route analytics and rules as dashboard destinations"
```

## Task 4: Persist and Restore `Home` Inspector Width and Launch Defaults

**Files:**
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/Views/DashboardView.swift`
- Modify: `Forma File Organizing/Views/RightPanelView.swift`
- Modify: `Forma File Organizing/DesignSystem/FormaSpacing.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`

- [ ] **Step 1: Write failing tests for width persistence and launch defaults**

Add focused tests for:

```swift
func testFirstLaunchDefaultsToVisibleInspectorAtPreferredWidth()
func testReturningFromDestinationRestoresSavedInspectorVisibility()
func testReturningFromDestinationRestoresSavedInspectorWidth()
```

If width persistence lives in `WindowPresentationStore`, test it directly through isolated `UserDefaults` suites.

- [ ] **Step 2: Extend `WindowPresentationStore` to persist inspector width**

Add storage keys and accessors similar to the existing visibility persistence:

```swift
var savedInspectorWidth: CGFloat?
func setInspectorWidth(_ width: CGFloat)
func resetInspectorWidth()
```

Keep width persistence in the same object that already owns inspector visibility. Do not introduce a second ad hoc defaults store.

- [ ] **Step 3: Capture measured right-panel width only while in `homeWorkspace`**

Use the existing measured right-panel width seam from `RightPanelView` / `RightPanelLayout` to report width back into the view model.

Implementation constraints:
- persist width only for `homeWorkspace`
- ignore destination-screen widths
- debounce or threshold changes so drag-resize does not spam defaults on every pixel

- [ ] **Step 4: Align launch defaults with the approved `Home` contract**

Update `DashboardLaunchPresentation` so the first/default launch at the preferred window width opens `Home` with the inspector visible when meaningful default-panel content exists.

This may require:
- lowering or removing the `inspectorEligibleWidth` gate
- adjusting preferred window/right-panel ideal constants if the current startup right-panel width is still too thin

Do not guess blindly. Validate the default against the agreed screenshot target during implementation.

- [ ] **Step 5: Run focused persistence tests**

Run:
```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:'Forma File OrganizingTests/DashboardViewModelTests'
```

Expected:
- launch/default visibility tests pass
- width persistence tests pass

- [ ] **Step 6: Commit the persistence slice**

```bash
git add "Forma File Organizing/ViewModels/DashboardViewModel.swift" \
        "Forma File Organizing/Views/DashboardView.swift" \
        "Forma File Organizing/Views/RightPanelView.swift" \
        "Forma File Organizing/DesignSystem/FormaSpacing.swift" \
        "Forma File OrganizingTests/DashboardViewModelTests.swift"
git commit -m "Restore home inspector state across dashboard destinations"
```

## Task 5: Finish UI Verification, Screenshot Flows, and Doc Sync

**Files:**
- Modify: `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`
- Modify: `Forma File OrganizingUITests/AppStoreScreenshotTests.swift`
- Modify: `CHANGELOG.md`
- Modify: `TODO.md`

- [ ] **Step 1: Update UI tests to reflect the new destination behavior**

Replace the old compact analytics expectations with the approved contract:
- left-nav `Analytics` opens full-workspace analytics
- left-nav `Smart Rules` opens full-workspace rules
- `Back to Dashboard` restores prior `Home` state
- `Home` inspector toggle still works only inside `Home`

Add a dedicated restore-flow UI test:

```swift
func testReturningFromAnalyticsRestoresPreviousHomeInspectorState()
```

- [ ] **Step 2: Update screenshot flows that currently assume compact right-panel destinations**

`AppStoreScreenshotTests.swift` currently captures Smart Rules and Analytics from the sidebar as if they were panel surfaces. Update the expectations and screenshot names only as far as needed to match the new product behavior.

- [ ] **Step 3: Run the focused UI suite**

Run:
```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' \
  -only-testing:'Forma File OrganizingUITests/Forma_File_OrganizingUITests' \
  -only-testing:'Forma File OrganizingUITests/AppStoreScreenshotTests'
```

Expected:
- destination-state tests pass
- screenshot tests no longer assume compact analytics/rules surfaces from sidebar entry

- [ ] **Step 4: Run the repo-preferred non-UI suite**

Run:
```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:'Forma File OrganizingUITests'
```

Expected:
- Full non-UI suite passes with no regressions in dashboard/stateful flows.

- [ ] **Step 5: Sync docs**

Update:
- `CHANGELOG.md` — explain the new destination-vs-panel dashboard behavior
- `TODO.md` — mark the layout-state contract implementation accurately once complete

- [ ] **Step 6: Commit the verification and docs slice**

```bash
git add "Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift" \
        "Forma File OrganizingUITests/AppStoreScreenshotTests.swift" \
        "CHANGELOG.md" \
        "TODO.md"
git commit -m "Verify dashboard destination layout contract"
```

## Final Verification Checklist

- [ ] `Home` launches in the intended three-area layout at the preferred window size.
- [ ] The default right-panel width feels correct before any manual resize.
- [ ] Left-sidebar `Analytics` preserves the sidebar and uses the entire remaining workspace width.
- [ ] Left-sidebar `Smart Rules` preserves the sidebar and uses the entire remaining workspace width.
- [ ] Contextual rule creation from the center workflow still uses the compact right panel.
- [ ] `Back to Dashboard` exists and works in both full-workspace destinations.
- [ ] Returning from either destination restores prior `Home` right-panel visibility and width.
- [ ] Inspector toggle is only active in `Home`.
- [ ] UI tests and the non-UI suite both pass.
