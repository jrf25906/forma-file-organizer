# Right Rail V4 Compressed Editorial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved v4 compressed-editorial right rail so `Current Task` is tighter and fully recomposed, `Automation` becomes a flatter beacon without redundant zero-value proofing, and `Next Moves` becomes the editorial payoff of the rail.

**Architecture:** Reuse the pass-scoped data and ranked editorial feed already landed on the current branch. Keep the model layer stable where possible and concentrate this pass in view composition, copy helpers, accessibility hooks, and semantic accent tuning inside the existing right-rail surfaces. Preserve the three-module order, but compress the first two modules and give the featured `Next Moves` card the reclaimed vertical space.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, XCTest, XCUITest, existing `DefaultPanelView`, `AutomationStatusWidget`, `DefaultPanelEditorialSuggestion`, `FormaColors`, and right-panel UI tests.

---

## Implementation Rules

- Use the approved spec as the source of truth: `docs/superpowers/specs/2026-04-22-right-rail-v4-compressed-editorial-design.md`.
- Keep this pass inside the native app only. No `forma-website/` work belongs here.
- Reuse the existing pass-scoped review data and editorial ranking model; do not reopen the model layer unless a view requirement cannot be met without a narrow presentation helper.
- Preserve the v3 semantic fixes:
  - no progress ring
  - pass-scoped hero counts
  - truthful bottom action-bar wording
  - semantic state palette
- Stage only the files for each task. The worktree is already dirty on this branch; do not revert or reformat unrelated changes.
- Use accessibility identifiers for new UI assertions instead of brittle coordinate- or index-based UI tests.
- Update `TODO.md`, `CHANGELOG.md`, and `API_REFERENCE.md` when the implementation lands.

## File Structure

### Reference

- `docs/superpowers/specs/2026-04-22-right-rail-v4-compressed-editorial-design.md` — approved v4 design contract.

### Modify

- `Forma File Organizing/Views/DefaultPanelView.swift`
  - Recompose `Current Task`
  - tighten right-rail spacing
  - rebalance featured and secondary `Next Moves` cards
  - add stable accessibility identifiers for hero and featured-move sections
- `Forma File Organizing/Components/AutomationStatusWidget.swift`
  - collapse redundant zero-value proofing
  - simplify content hierarchy
  - quiet the split control
  - add stable accessibility identifiers for automation summary states
- `Forma File Organizing/Views/DefaultPanelEditorialSuggestion.swift`
  - keep accent mapping aligned to the smaller semantic palette
  - only adjust snapshot text wiring if the featured card needs cleaner `why now` or footer action phrasing
- `Forma File Organizing/DesignSystem/FormaColors.swift`
  - keep `RightRailSemanticTone` authoritative if any tone values need slight retuning for quieter controls or clearer state contrast
- `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`
  - extend right-rail coverage for hero compression, automation simplification, and featured footer CTA structure

### Guardrail Tests To Re-Run

- `Forma File OrganizingTests/DashboardViewModelTests.swift`
  - `testCurrentPassCategorySummariesStayScopedToSnapshotAfterOrganizing`
  - `testCurrentPassReviewActionBarStatePrefersDestinationBlockersWhenNothingIsReady`
  - `testCurrentPassReviewActionBarStateFallsBackToReviewWhenNothingIsReady`
- `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`
  - `testNeedsReviewCurrentTaskCardUsesPassScopedProgressAndShortSectionCopy`
  - add new automation and featured-card assertions in this file instead of creating a second UI test surface

### Docs

- `CHANGELOG.md`
- `TODO.md`
- `API_REFERENCE.md`

## Task 1: Recompose `Current Task` Into the Compressed Hero

**Files:**
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Test: `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`

- [ ] **Step 1: Extend the existing hero UI test with the v4 assertions**

Update `testNeedsReviewCurrentTaskCardUsesPassScopedProgressAndShortSectionCopy()` so it asserts the v4 hero contract:

```swift
let hero = app.otherElements["defaultPanelHeroSection"]
XCTAssertTrue(hero.exists)
XCTAssertEqual(app.staticTexts["defaultPanelHeroCount"].label, "8")
XCTAssertEqual(app.staticTexts["defaultPanelHeroSummary"].label, "8 files in this pass. Mostly images. 61 wait outside this pass.")
XCTAssertTrue(app.otherElements["defaultPanelHeroCategoryBand"].exists)
XCTAssertFalse(app.otherElements["defaultPanelHeroRing"].exists)
```

Do not add pixel or position assertions. Keep this test semantic and identifier-driven.

- [ ] **Step 2: Run the focused hero UI test and verify it fails**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests/testNeedsReviewCurrentTaskCardUsesPassScopedProgressAndShortSectionCopy"
```

Expected:
- FAIL because the current hero still uses the v3 summary/copy and does not expose the new v4 identifiers.

- [ ] **Step 3: Implement the compressed hero layout**

In `DefaultPanelView.swift`, recompose the hero around this structure:

```swift
VStack(alignment: .leading, spacing: FormaSpacing.standard) {
    sectionLabel
    heroCount
    heroTitle
    heroSummary
    heroProgressRow
    heroCategoryBand
}
```

Implementation rules:
- reduce the headline count to the approved `30-32pt` visual range for compact rail widths
- remove any remaining layout that still reserves visual space for the deleted ring
- rewrite the support line to the pass-first copy posture
- convert the category shelf from a large tray into a short footer band with equal columns and full-height dividers
- add identifiers:
  - `defaultPanelHeroCount`
  - `defaultPanelHeroSummary`
  - `defaultPanelHeroCategoryBand`

- [ ] **Step 4: Re-run the focused hero UI test and make it pass**

Run the same command from Step 2.

Expected:
- PASS with the tighter hero structure and new summary copy.

- [ ] **Step 5: Commit the compressed hero slice**

```bash
git add "Forma File Organizing/Views/DefaultPanelView.swift" \
        "Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift"
git commit -m "Compress current task hero layout"
```

## Task 2: Collapse `Automation` Into a Beacon Card

**Files:**
- Modify: `Forma File Organizing/Components/AutomationStatusWidget.swift`
- Test: `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`

- [ ] **Step 1: Add a focused automation UI test for the zero-metric case**

Add a new test such as:

```swift
func testNeedsReviewAutomationCardCollapsesZeroValueMetrics() throws {
    let app = launchNeedsReviewHarness()

    XCTAssertTrue(app.otherElements["defaultPanelAutomationStatusCard"].exists)
    XCTAssertTrue(app.staticTexts["Watching Desktop + Downloads"].exists)
    XCTAssertTrue(app.staticTexts["69 files waiting for review"].exists)
    XCTAssertFalse(app.staticTexts["folders on autopilot"].exists)
    XCTAssertFalse(app.staticTexts["folders blocked"].exists)
}
```

If the current harness does not expose exact strings consistently, add identifiers such as:
- `defaultPanelAutomationHeadline`
- `defaultPanelAutomationPrimaryState`
- `defaultPanelAutomationSecondaryState`

- [ ] **Step 2: Run the focused automation UI test and verify it fails**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests/testNeedsReviewAutomationCardCollapsesZeroValueMetrics"
```

Expected:
- FAIL because the current v3 automation card still renders the zero-value shelf and duplicate proofing.

- [ ] **Step 3: Implement the flattened automation beacon**

Refactor `AutomationStatusWidget.swift` so the card reduces to:

```swift
VStack(alignment: .leading, spacing: FormaSpacing.standard) {
    headerRow // section label + Live chip
    watchedRootsHeadline
    primaryWaitingState
    if let secondarySupportLine { secondarySupportLine }
    splitControl
}
```

Implementation rules:
- remove the permanent three-column trust shelf when both `activeScopeCount` and `attentionScopeCount` are zero
- keep a single optional secondary line only when there is meaningful support state
- quiet the split control so the automation state reads first and the button reads second
- do not regress schedule hover/help behavior on the `Live` chip
- add identifiers for the main text seams if needed for the UI test

- [ ] **Step 4: Re-run the focused automation UI test and make it pass**

Run the same command from Step 2.

Expected:
- PASS with no redundant zero-value proofing.

- [ ] **Step 5: Commit the automation slice**

```bash
git add "Forma File Organizing/Components/AutomationStatusWidget.swift" \
        "Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift"
git commit -m "Flatten automation beacon card"
```

## Task 3: Give `Next Moves` The Reclaimed Space

**Files:**
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Modify: `Forma File Organizing/Views/DefaultPanelEditorialSuggestion.swift`
- Test: `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`

- [ ] **Step 1: Add a focused featured-card UI test**

Add a test such as:

```swift
func testFeaturedNextMoveUsesWhyItMattersAndFooterAction() throws {
    let app = launchNeedsReviewHarness()

    XCTAssertTrue(app.otherElements["defaultPanelFeaturedNextMove"].exists)
    XCTAssertTrue(app.staticTexts["defaultPanelFeaturedNextMoveWhyNow"].exists)
    XCTAssertTrue(app.buttons["defaultPanelFeaturedNextMoveFooterAction"].exists)
}
```

Prefer identifiers over exact prose for the footer structure so future copy edits do not create false failures.

- [ ] **Step 2: Run the focused featured-card UI test and verify it fails**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests/testFeaturedNextMoveUsesWhyItMattersAndFooterAction"
```

Expected:
- FAIL because the current featured card does not yet expose the v4 footer and `Why it matters` contract cleanly.

- [ ] **Step 3: Rebalance the right-rail spacing and featured-card composition**

In `DefaultPanelView.swift`, adjust the right-rail stack and featured-card layout so:

```swift
featuredCard = VStack(alignment: .leading, spacing: ...) {
    eyebrow
    title
    bodyCopy
    whyNowLine
    footerAction
}
```

Implementation rules:
- reduce padding/height in the hero and automation cards enough to visibly lift `Next Moves`
- keep the whole featured card tappable
- pin the action to a footer row with a divider above it
- give the title/body copy the full line length
- keep secondary cards in the same language, but tighter
- only touch `DefaultPanelEditorialSuggestion.swift` if the snapshot text or accent mapping needs slight cleanup to support the v4 hierarchy

- [ ] **Step 4: Re-run the focused featured-card UI test and make it pass**

Run the same command from Step 2.

Expected:
- PASS with the featured card exposing the `why now` and footer-action seams.

- [ ] **Step 5: Commit the featured-feed slice**

```bash
git add "Forma File Organizing/Views/DefaultPanelView.swift" \
        "Forma File Organizing/Views/DefaultPanelEditorialSuggestion.swift" \
        "Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift"
git commit -m "Elevate featured next moves briefing"
```

## Task 4: Docs And Regression Validation

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `TODO.md`
- Modify: `API_REFERENCE.md`
- Test: `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`

- [ ] **Step 1: Update the repo docs to match the shipped v4 behavior**

Document the v4 changes concisely:

- `Current Task` is now a compressed hero with a short footer band
- `Automation` is now a flatter beacon with optional secondary support state instead of always-on zero metrics
- `Next Moves` now carries more of the rail hierarchy with a featured editorial briefing card

Keep the wording user-facing in `CHANGELOG.md` and contract-focused in `API_REFERENCE.md`.

- [ ] **Step 2: Run the three focused UI tests together**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' \
  -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests/testNeedsReviewCurrentTaskCardUsesPassScopedProgressAndShortSectionCopy" \
  -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests/testNeedsReviewAutomationCardCollapsesZeroValueMetrics" \
  -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests/testFeaturedNextMoveUsesWhyItMattersAndFooterAction"
```

Expected:
- PASS with stable identifier-driven right-rail assertions.

- [ ] **Step 3: Re-run the pass-scope guardrail unit tests**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' \
  -only-testing:"Forma File OrganizingTests/DashboardViewModelTests/testCurrentPassCategorySummariesStayScopedToSnapshotAfterOrganizing" \
  -only-testing:"Forma File OrganizingTests/DashboardViewModelTests/testCurrentPassReviewActionBarStatePrefersDestinationBlockersWhenNothingIsReady" \
  -only-testing:"Forma File OrganizingTests/DashboardViewModelTests/testCurrentPassReviewActionBarStateFallsBackToReviewWhenNothingIsReady"
```

Expected:
- PASS, confirming the v4 visual pass did not regress the existing semantics.

- [ ] **Step 4: Run the canonical non-UI suite**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"
```

Expected:
- PASS with no regressions outside the UI slice.

- [ ] **Step 5: Commit the docs-and-validation slice**

```bash
git add CHANGELOG.md TODO.md API_REFERENCE.md \
        "Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift"
git commit -m "Document right rail v4 refinement"
```

## Final Verification Checklist

- [ ] `Current Task` has no dead top-right space left over from the removed ring
- [ ] the pass count is visibly smaller than v3
- [ ] the hero uses one progress treatment only
- [ ] the category footer reads as a compact summary band, not a stat tray
- [ ] `Automation` shows the state headline first and does not render zero-value proofing when it adds no meaning
- [ ] the split control is visually quieter than the state text
- [ ] the featured `Next Moves` card has a visible `Why it matters` line and footer CTA
- [ ] docs are synced
- [ ] focused UI tests pass
- [ ] pass-scope guardrail unit tests pass
- [ ] canonical non-UI suite passes
