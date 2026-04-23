# Right Rail V4 Boundary Flattening Follow-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten the `Current Task` category band, flatten the `Automation` module to a single surface, and quiet the outer `Next Moves` chrome so the featured recommendation remains the primary editorial boundary.

**Architecture:** Keep the existing v4 right-rail hierarchy and the already-landed pass-scoped data model. Concentrate this follow-up in `DefaultPanelView` and `AutomationStatusWidget`, using the current probes and UI harness to lock the new composition contract without reopening ranking logic or view-model state.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, XCUITest, existing `DefaultPanelView`, `AutomationStatusWidget`, `DefaultPanelEditorialSuggestion`, and right-rail UI probes.

---

## Implementation Rules

- Treat this as a narrow composition pass on top of the approved v4 right rail, not a new direction change.
- Stay inside the native app surface only. No `forma-website/` changes belong here.
- Keep the three-module order:
  - `Current Task`
  - `Automation`
  - `Next Moves`
- Preserve the existing semantic data decisions:
  - pass-scoped hero counts
  - one linear pass-progress treatment
  - truthful review-bar copy
  - unified editorial ranking for `Next Moves`
- Prefer divider-based separation over nested rounded rectangles when the inner content is not independently meaningful.
- Update `TODO.md`, `CHANGELOG.md`, and `API_REFERENCE.md` when the implementation lands.

## File Structure

### Reference

- `docs/superpowers/specs/2026-04-22-right-rail-v4-compressed-editorial-design.md` — approved v4 direction
- `docs/superpowers/plans/2026-04-22-right-rail-v4-compressed-editorial.md` — prior implementation plan for the already-landed v4 pass

### Modify

- `Forma File Organizing/Views/DefaultPanelView.swift`
  - fix the hero category band height contract
  - remove runaway vertical expansion in `categoryStatsRow`
  - quiet the outer `Next Moves` section chrome at the `inspectorSectionCard` seam
  - add or extend lightweight UI probes only where needed to make the new structure testable
- `Forma File Organizing/Components/AutomationStatusWidget.swift`
  - remove the inset card treatment
  - flatten the automation module into one surface with divider-separated rows
  - keep `Live` hover/help behavior and split control behavior intact
- `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`
  - extend the existing right-rail tests for compact hero-band sizing and flattened surface probes

### Optional Modify

- `Forma File Organizing/Views/DefaultPanelEditorialSuggestion.swift`
  - only if needed to slightly quiet featured/secondary suggestion border strength after the section chrome is reduced
- `Forma File Organizing/DesignSystem/FormaColors.swift`
  - only if the quieter `Next Moves` outer surface needs a slightly softer neutral/border token

### Docs

- `CHANGELOG.md`
- `TODO.md`
- `API_REFERENCE.md`

## Task 1: Fix the `Current Task` Category Band Height

**Files:**
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Test: `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`

- [ ] **Step 1: Add a focused UI regression for the hero footer band**

Extend `testNeedsReviewCurrentTaskCardUsesPassScopedProgressAndShortSectionCopy()` or add a new test that verifies:

```swift
let band = harness.element(withIdentifier: "defaultPanelHeroCategoryBand")
harness.waitForExists(band, timeout: 3, message: "Hero category band should exist")

let height = band.frame.size.height
XCTAssertGreaterThan(height, 44)
XCTAssertLessThan(height, 80)
```

This is one of the few acceptable geometry assertions in the suite because the bug is runaway vertical expansion, not general visual taste.

- [ ] **Step 2: Run the focused hero UI test and verify it fails**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests/testNeedsReviewCurrentTaskCardUsesPassScopedProgressAndShortSectionCopy"
```

Expected:
- FAIL because the category band is currently stretching far beyond the intended compact-footer range.

- [ ] **Step 3: Implement the compact footer-band layout**

Update `DefaultPanelView.swift` around `categoryStatsRow` and `HeroCategoryStatButton` with these rules:

```swift
HStack(spacing: 0) {
    statCell(...)
    divider
    statCell(...)
    divider
    statCell(...)
}
.frame(height: 60)
```

Implementation rules:
- remove `.frame(maxHeight: .infinity)` from the hero stat cells
- remove `.frame(maxHeight: .infinity)` from the dividers
- replace the band’s `minHeight` contract with an explicit compact height
- keep three equal columns
- keep full-height dividers
- keep labels on one line; if `Documents` cannot fit cleanly at the approved font size, use a shorter display label such as `Docs` rather than allowing ellipsis or multiline wrapping

- [ ] **Step 4: Re-run the focused hero UI test and make it pass**

Run the same command from Step 2.

Expected:
- PASS with a compact, stable footer band that no longer behaves like a second card body.

- [ ] **Step 5: Commit the hero-band fix**

```bash
git add "Forma File Organizing/Views/DefaultPanelView.swift" \
        "Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift"
git commit -m "Fix current task category band height"
```

## Task 2: Flatten `Automation` Into One Surface

**Files:**
- Modify: `Forma File Organizing/Components/AutomationStatusWidget.swift`
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Test: `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`

- [ ] **Step 1: Extend the automation probe to capture the layout contract**

Update the existing automation UI test path so it can assert both content and structure. Add a stable value such as:

```swift
surface=single
headline=Watching Desktop and Downloads
primary=70 files waiting for review
secondary=none
```

The probe can stay in `DefaultPanelView.swift` or move into `AutomationStatusWidget.swift`, but the root automation card must expose enough structure to prove the inset panel is gone.

- [ ] **Step 2: Run the focused automation UI test and verify it fails**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests/testNeedsReviewAutomationCardCollapsesZeroValueMetrics"
```

Expected:
- FAIL because the current automation module still uses an inner bordered/tinted container instead of a true single-surface layout.

- [ ] **Step 3: Implement the flattened automation structure**

Refactor `AutomationStatusWidget.swift` so the visible hierarchy becomes:

```swift
VStack(alignment: .leading, spacing: FormaSpacing.standard) {
    headerRow
    summarySection
    subtleDivider
    splitControl
}
```

Implementation rules:
- remove the inset `cardBackground` / `cardBorder` wrapper around `summarySection` + `splitControl`
- let the outer module card from `DefaultPanelView` remain the only real container
- keep the `Live` chip in the header
- keep hover/help schedule detail on the chip
- keep the full-width split control
- keep optional secondary support text only when it carries meaningful state
- if a separator is needed above the split control, use a light divider, not another rounded rectangle

- [ ] **Step 4: Re-run the focused automation UI test and make it pass**

Run the same command from Step 2.

Expected:
- PASS with a single-surface automation card and no nested-body treatment.

- [ ] **Step 5: Commit the automation flattening slice**

```bash
git add "Forma File Organizing/Components/AutomationStatusWidget.swift" \
        "Forma File Organizing/Views/DefaultPanelView.swift" \
        "Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift"
git commit -m "Flatten automation card boundaries"
```

## Task 3: Quiet the Outer `Next Moves` Chrome

**Files:**
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Optional Modify: `Forma File Organizing/Views/DefaultPanelEditorialSuggestion.swift`
- Test: `Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift`

- [ ] **Step 1: Add a lightweight section-style probe for `Next Moves`**

Add a stable probe around `suggestionsSection` so the test harness can assert the intended structure without screenshot diffs:

```swift
outer=quiet
featured=primary
count=1
```

Use an identifier such as `defaultPanelSuggestionsSectionProbe`.

- [ ] **Step 2: Run the focused featured-card UI test and verify it fails**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests/testNeedsReviewFeaturedNextMoveUsesEditorialBodyAndFooterProbe"
```

Expected:
- FAIL after tightening the test to require the quieter outer-section contract.

- [ ] **Step 3: Implement the quieter section boundary**

Adjust the `Next Moves` outer wrapper at the `inspectorSectionCard` seam in `DefaultPanelView.swift`.

Implementation rules:
- the section still reads as its own module in the rail
- the outer chrome becomes quieter than the featured suggestion card
- the featured suggestion remains the main visual boundary
- do not remove the featured suggestion card
- do not change ranking logic or action wiring
- only touch `DefaultPanelEditorialSuggestion.swift` if the existing featured/secondary borders need slight retuning after the outer chrome is softened

Two acceptable implementation shapes:

```swift
inspectorSectionCard(style: .quiet) { suggestionsSection }
```

or

```swift
suggestionsSection
    .padding(...)
    .background(subtleSectionFill)
```

Choose the smaller change that keeps the section distinct while stopping the “card inside card” feeling.

- [ ] **Step 4: Re-run the focused featured-card UI test and make it pass**

Run the same command from Step 2.

Expected:
- PASS with the featured suggestion still editorially dominant and the section chrome no longer competing with it.

- [ ] **Step 5: Commit the `Next Moves` flattening slice**

```bash
git add "Forma File Organizing/Views/DefaultPanelView.swift" \
        "Forma File OrganizingUITests/Forma_File_OrganizingUITests.swift"
git commit -m "Quiet next moves section chrome"
```

## Task 4: Verify, Manually Review, and Sync Docs

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `TODO.md`
- Modify: `API_REFERENCE.md`

- [ ] **Step 1: Re-run the focused right-rail UI tests**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' \
  -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests/testNeedsReviewCurrentTaskCardUsesPassScopedProgressAndShortSectionCopy" \
  -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests/testNeedsReviewAutomationCardCollapsesZeroValueMetrics" \
  -only-testing:"Forma File OrganizingUITests/Forma_File_OrganizingUITests/testNeedsReviewFeaturedNextMoveUsesEditorialBodyAndFooterProbe"
```

Expected:
- PASS

If XCTest app-teardown flakiness returns, fall back to running the three tests individually and record that in the handoff.

- [ ] **Step 2: Re-run the canonical non-UI suite**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"
```

Expected:
- PASS with no new non-UI regressions

- [ ] **Step 3: Perform a quick manual browser/IAB verification**

Check these exact visual outcomes:
- the `Current Task` category band reads like a compact footer row, not a tray
- `Automation` no longer has an inset body panel
- `Next Moves` still feels distinct, but the featured suggestion is the only strong boundary inside the section

- [ ] **Step 4: Sync docs**

Update:
- `CHANGELOG.md`
- `TODO.md`
- `API_REFERENCE.md`

Document:
- compact hero footer-band contract
- single-surface automation card contract
- quieter `Next Moves` outer chrome contract

- [ ] **Step 5: Commit verification and docs**

```bash
git add "CHANGELOG.md" "TODO.md" "API_REFERENCE.md"
git commit -m "Document right rail boundary flattening follow-up"
```

## Notes For Execution

- Do not reopen copy strategy or category semantics in this pass; those decisions are already set.
- Do not add another metric shelf to `Automation`.
- Do not remove the featured `Next Moves` card; only reduce competition from the section wrapper around it.
- If the hero category band needs narrower labels for one compact-width case, prefer shorter nouns over ellipsis.
