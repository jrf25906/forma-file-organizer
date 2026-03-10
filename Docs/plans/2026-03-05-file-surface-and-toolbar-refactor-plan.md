# Forma File Surface + Toolbar Refactor Plan

**Status:** Current
**Last Updated:** 2026-03-05
**Audience:** Designers | Developers | QA

This plan covers the next app polish loop for file presentation and the center-pane toolbar. It is intentionally narrower than the broader March 5 product redesign brief and focuses on the dashboard work surface only.

## 1. Problem Statement

The dashboard currently has the right building blocks but the wrong emphasis.

- File rows and tiles over-signal. Category color, status color, confidence, destination, and actions all compete in the same visual layer.
- Card, list, and grid share data but not a strong enough composition model.
- The toolbar was simplified into a single row, but it still behaves like a flat strip of controls instead of a grouped command surface.

## 2. Design Principles

### File surfaces

- Each file view must answer the same four questions in the same order:
  1. What is this file?
  2. What state is it in?
  3. Where is it going?
  4. What can I do right now?
- Resting rows should not show multiple competing actions.
- Destination is passive information when assigned and an active prompt only when missing.
- Color should communicate state, not decorate metadata.
- Green is reserved for completed success, not pre-action readiness.

### Toolbar

- The toolbar should expose four command families:
  - Scope
  - Context
  - Arrange
  - Display
- Compact behavior must collapse IA, not just spacing.
- The toolbar should support the file surface beneath it instead of competing with it.

## 3. Current Work Started

The first implementation pass is now live in code:

- File metadata now uses calmer state semantics and neutral destination styling.
- Confidence dots in file rows were replaced by a quieter provenance treatment.
- Card/list/grid primary actions now distinguish `Organize`, `Review`, and `Set Destination`.
- Rest-state row actions are more progressive instead of staying visible everywhere.
- The toolbar now groups commands into `Scope`, `Context`, `Arrange`, and `Display` families.
- Sorting and grouping now live inside one arrange menu, and scan state now sits in the context cluster instead of a detached chip.

## 4. Workstreams

### Workstream A: File surface semantics

**Status:** Completed

Goal: reduce noise before changing deeper layout structure.

Deliverables:

- Shared status semantics in `Components/Shared/FileMetaStrip.swift`
- Shared primary action semantics across:
  - `Views/Components/FileRow.swift`
  - `Components/FileListRow.swift`
  - `Components/FileGridItem.swift`
- Neutralized destination styling and less shouty rule affordances

Acceptance criteria:

- Assigned destinations no longer read like links.
- Ready files do not use green as their primary pre-action signal.
- Pending-with-destination files surface `Review`, not misleading `Organize`.

### Workstream B: File surface composition

**Status:** Completed in code, visual validation pending

Goal: make card, list, and grid feel like one system instead of three parallel renderings.

Deliverables:

- Define shared primitives:
  - `FileIdentityBlock`
  - `FileAccessoryActions`
  - `FileActionMenuContent`
- Reduce or remove category rails where they add more noise than value
- Recompose view-specific layouts around the same content contract
- Share destination shortcuts, rule actions, and overflow behavior across:
  - `Views/Components/FileRow.swift`
  - `Components/FileListRow.swift`
  - `Components/FileGridItem.swift`

Acceptance criteria:

- Card, list, and grid can be compared side by side and tell the same file story.
- Only one dominant action is visible per resting item.
- Metadata density feels intentional rather than accumulated.
- Secondary actions are consistent across all three views instead of being reimplemented per surface.

### Workstream C: Toolbar hierarchy

**Status:** Completed for current scope

Goal: refactor the toolbar into grouped command families with clearer emphasis.

Deliverables:

- Refactor `Views/Components/UnifiedToolbar.swift` into:
  - `ScopeGroup`
  - `ContextLabel`
  - `ArrangeMenu`
  - `DisplayGroup`
- Merge sort/grouping into a single arrange family
- Move scanning state into context instead of a separate floating chip
- Defer `Views/MainContentView.swift` host cleanup (`safeAreaInset` vs measured overlay) until file-surface composition settles

Acceptance criteria:

- Pending/All Files remains the primary mode control.
- Sort and grouping feel like arrangement parameters, not peer modes.
- Compact widths collapse command groups predictably.

## 5. File Map

- `Forma File Organizing/Components/Shared/FileMetaStrip.swift`
- `Forma File Organizing/Views/Components/FileRow.swift`
- `Forma File Organizing/Components/FileListRow.swift`
- `Forma File Organizing/Components/FileGridItem.swift`
- `Forma File Organizing/Components/RuleButtonWithMenu.swift`
- `Forma File Organizing/Views/Components/UnifiedToolbar.swift`
- `Forma File Organizing/Views/MainContentView.swift`

## 6. Validation Plan

Current status:

- Code validation passed with `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build`.
- Targeted row-action validation passed with `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests" -only-testing:"Forma File OrganizingTests/FileRowTests"`.
- Focused visual validation is documented in `Docs/Testing/2026-03-05-file-surface-toolbar-validation-findings.md`.

Follow-up required after the current validation pass:

- Tighten grid tile density and footer hierarchy.
- Raise passive destination readability without reintroducing action-like styling.
- Add a true compact-width validation path for toolbar compression because the app root still enforces a `minWidth` / `minHeight` floor in UI tests.

## 7. Decisions Locked

- Do not reintroduce a second toolbar row.
- Do not add more badges to explain existing badges.
- Do not keep persistent row-level primary actions just because there is space.
- Do not use green as the pre-action ready state.
