# Native App Luma-Inspired Material Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the native macOS app's material hierarchy, file surfaces, and inspector chrome so Forma feels more refined and legible without drifting away from native Mac interaction patterns.

**Architecture:** Centralize the new surface-state logic in the existing design system, then route card/list/grid file surfaces through the shared state model before applying the same elevation language to toolbar and inspector chrome. Keep the refresh native by working through semantic colors, compact spacing, and shared chrome helpers instead of introducing web-style component patterns.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit-backed materials, XCTest, Xcode build/test tooling

---

### Task 1: Introduce a shared file-surface state model in the design system

**Files:**
- Create: `Forma File Organizing/DesignSystem/FileSurfaceStyle.swift`
- Modify: `Forma File Organizing/DesignSystem/FormaColors.swift`
- Test: `Forma File OrganizingTests/FileSurfaceStyleTests.swift`

- [ ] Add a focused design-system type that resolves file-surface state priority and shared styling values for `rest`, `hover`, `selected`, `focused`, `pending`, `processing`, and `error`.
- [ ] Move any new semantic surface tokens needed for the refresh into `FormaColors.swift` instead of embedding new constants inside views.
- [ ] Add XCTest coverage for state priority and token selection so shared surface behavior is verified before the views consume it.

### Task 2: Route all file surfaces through the shared state model

**Files:**
- Modify: `Forma File Organizing/Views/Components/FileRow.swift`
- Modify: `Forma File Organizing/Components/FileListRow.swift`
- Modify: `Forma File Organizing/Components/FileGridItem.swift`
- Modify: `Forma File Organizing/Components/Shared/FileSurfaceComponents.swift`
- Modify: `Forma File Organizing/Views/MainContentView.swift`

- [ ] Update the card, list, and grid file surfaces to consume the shared style resolver instead of keeping parallel handcrafted state logic.
- [ ] Preserve each layout's density and structure while making hover, selection, and focus read as one coherent system.
- [ ] Verify the refresh touches all required file-level surfaces together, per repository guidance.

### Task 3: Refresh shared chrome and toolbar elevation

**Files:**
- Modify: `Forma File Organizing/DesignSystem/FormaControlChrome.swift`
- Modify: `Forma File Organizing/Components/SidebarGlassOverlay.swift`
- Modify: `Forma File Organizing/Views/Components/UnifiedToolbar.swift`

- [ ] Tune shared chrome surfaces so control clusters, sidebar glass, and toolbar groupings use the updated elevation ladder.
- [ ] Keep the toolbar compact and native-looking while making layer separation clearer.
- [ ] Avoid oversized radius, oversized padding, or any web-styled control treatment.

### Task 4: Apply the same material language to the right panel and inspector

**Files:**
- Modify: `Forma File Organizing/Views/RightPanelView.swift`
- Modify: `Forma File Organizing/Views/FileInspectorView.swift`

- [ ] Refit the right-panel mode header, inspector cards, and action surfaces so they match the refreshed file-surface and chrome language.
- [ ] Preserve current interaction flows and content order in the inspector.
- [ ] Keep keyboard focus and contrast at least as strong as the current implementation.

### Task 5: Add focused validation for contrast and state clarity

**Files:**
- Modify: `Forma File OrganizingTests/FileSurfaceStyleTests.swift`
- Reuse: `Forma File Organizing/Views/FileInspectorView.swift`

- [ ] Extend the new unit tests if needed to cover any additional state-mapping behavior uncovered during implementation.
- [ ] Preserve or improve existing contrast-probe and accessibility identifiers used by the inspector and file surfaces.
- [ ] Use `Forma File OrganizingTests/TestHelpers/TemporaryDirectory.swift` if any filesystem-backed UI fixtures become necessary during test work.

### Task 6: Update docs and verify the native-app pass

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `TODO.md`

- [ ] Add a note for the native material refresh to `CHANGELOG.md`.
- [ ] Update `TODO.md` if follow-up polish remains after the initial pass.
- [ ] Run `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/FileSurfaceStyleTests"` after the new tests exist.
- [ ] Run `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"`.
- [ ] Run `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build`.
