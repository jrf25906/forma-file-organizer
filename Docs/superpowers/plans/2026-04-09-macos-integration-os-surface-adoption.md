# macOS Integration OS Surface Adoption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deepen Finder service, Spotlight/App Intents, Shortcuts, menu bar, and external-ingress review adoption on top of the workflow-backed entry-point layer without adding a new extension target.

**Architecture:** Start by replacing the flattened external-review `statusText` contract with a structured outcome summary shared by `ExternalIngressCoordinator`, `DashboardViewModel`, and OS-facing callers. Then extend App Intents and menu bar surfaces to render that shared outcome honestly, while preserving the existing workflow-engine and external-ingress request plumbing.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest, App Intents, macOS Finder Services, security-scoped bookmarks

---

## Scope and sequencing

This branch covers existing-surface depth only:

1. shared external-ingress outcome model
2. review-first App Intent / Shortcut outcome polish
3. menu bar workflow guidance polish
4. docs sync and verification

This branch does **not** add Finder Sync, a new Quick Action extension target, or new workflow step kinds.

## File map

### Core service and model files

- `Forma File Organizing/Services/ExternalIngressCoordinator.swift`
- `Forma File Organizing/Services/FormaAppIntents.swift`
- `Forma File Organizing/Services/FormaActions.swift`
- `Forma File Organizing/Services/WorkflowTemplateSelectionStore.swift`
- `Forma File Organizing/Models/WorkflowInvocationContext.swift` only if trigger-surface distinctions change

### Dashboard and menu bar surfaces

- `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- `Forma File Organizing/ViewModels/MenuBarViewModel.swift`
- `Forma File Organizing/Views/MenuBarView.swift`
- `Forma File Organizing/Views/Settings/GeneralSettingsSection.swift` only if help text needs to reflect the new behavior

### Tests

- `Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift`
- `Forma File OrganizingTests/DashboardViewModelTests.swift`
- `Forma File OrganizingTests/MenuBarViewModelTests.swift` if needed
- `Forma File OrganizingTests/AppIntentOutcomeTests.swift` if intent result-formatting logic becomes large enough to justify extraction

### Docs to keep aligned when behavior lands

- `TODO.md`
- `CHANGELOG.md`
- `API_REFERENCE.md`

---

### Task 1: Shared External-Ingress Outcome Model

**Dependencies:** None. This is the foundation for the rest of the branch.

**Files:**
- Modify: `Forma File Organizing/Services/ExternalIngressCoordinator.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Test: `Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`

- [ ] **Step 1: Write failing coordinator tests for structured external-ingress summaries**
  Cover:
  - mixed result with auto-organized + review-needed + skipped items
  - reauthorization-only result
  - published external-review session preserving structured summary data

- [ ] **Step 2: Run the focused coordinator tests and verify they fail for the right reason**
  Run:
  `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ExternalIngressCoordinatorTests"`

- [ ] **Step 3: Add a focused structured outcome type**
  Suggested shape:
  - source
  - optional workflow template ID
  - auto-organized count
  - review-needed count
  - skipped count
  - reauthorization-needed count
  - compact display helpers

- [ ] **Step 4: Replace `ExternalReviewSession.statusText`-only usage with the structured summary**
  Notes:
  - keep presentation helpers close to the model or coordinator, not duplicated in every caller
  - do not remove `skippedItems`; the structured summary should complement real item details, not erase them

- [ ] **Step 5: Update dashboard toast/session handling to consume the structured summary**
  Cover:
  - skip-only sessions preserving current filters
  - focused external review sessions still clearing when requested files are no longer actionable
  - promotion-candidate preservation on session synchronization

- [ ] **Step 6: Re-run the focused tests and make them pass**
  Run:
  `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ExternalIngressCoordinatorTests" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests"`

- [ ] **Step 7: Commit**
  ```bash
  git add "Forma File Organizing/Services/ExternalIngressCoordinator.swift" \
          "Forma File Organizing/ViewModels/DashboardViewModel.swift" \
          "Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift" \
          "Forma File OrganizingTests/DashboardViewModelTests.swift"
  git commit -m "feat: add structured external ingress outcomes"
  ```

### Task 2: Review-First App Intents and Shortcut Outcome Polish

**Dependencies:** Task 1

**Files:**
- Modify: `Forma File Organizing/Services/FormaAppIntents.swift`
- Modify: `Forma File Organizing/Services/ExternalIngressCoordinator.swift`
- Modify: `Forma File Organizing/Services/FormaActions.swift` if single-file organize results need widening beyond `Bool`
- Test: `Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift`
- Test: `Forma File OrganizingTests/AppIntentOutcomeTests.swift` if added

- [ ] **Step 1: Write failing tests for review-required and reauthorization-required selected-item outcomes**
  Notes:
  - if App Intent code is hard to unit-test directly, extract the result-formatting logic behind a small pure helper first and test that helper

- [ ] **Step 2: Run the focused intent/outcome tests and verify they fail**

- [ ] **Step 3: Update `OrganizeSelectionIntent` to derive result text from the shared external-ingress summary**
  Notes:
  - immediate success returns compact confirmation
  - review-required opens Forma and returns review-oriented copy
  - reauthorization-required uses explicit recovery wording

- [ ] **Step 4: Decide whether `FormaActions.organizeFile` needs to widen from `Bool`**
  Decision rule:
  - widen only if App Intent or menu bar callers truly need structured per-run result state that cannot be derived from existing summary data

- [ ] **Step 5: Re-run the focused intent/outcome tests and make them pass**

- [ ] **Step 6: Commit**
  ```bash
  git add "Forma File Organizing/Services/FormaAppIntents.swift" \
          "Forma File Organizing/Services/ExternalIngressCoordinator.swift" \
          "Forma File Organizing/Services/FormaActions.swift" \
          "Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift" \
          "Forma File OrganizingTests/AppIntentOutcomeTests.swift"
  git commit -m "feat: polish app intent workflow outcomes"
  ```

### Task 3: Menu Bar Workflow Guidance Polish

**Dependencies:** Task 1. Task 2 only if single-file organize result shaping is shared.

**Files:**
- Modify: `Forma File Organizing/ViewModels/MenuBarViewModel.swift`
- Modify: `Forma File Organizing/Views/MenuBarView.swift`
- Modify: `Forma File Organizing/Services/FormaActions.swift` only if richer organize results are shared here
- Test: `Forma File OrganizingTests/MenuBarViewModelTests.swift` if created

- [ ] **Step 1: Write failing tests for missing-template and blocked-plan guidance in the menu bar view model**
  Cover:
  - workflow engine enabled with no selected template
  - simulation preview has blocked files
  - enabled action with honest confirmation copy

- [ ] **Step 2: Run the focused menu-bar tests and verify they fail**

- [ ] **Step 3: Add focused computed properties for user-facing workflow action guidance**
  Notes:
  - keep string assembly in the view model, not the view
  - avoid turning `MenuBarView` into business-logic code

- [ ] **Step 4: Update `MenuBarView` to surface the guidance without redesigning the whole panel**

- [ ] **Step 5: Re-run the focused menu-bar tests and make them pass**

- [ ] **Step 6: Commit**
  ```bash
  git add "Forma File Organizing/ViewModels/MenuBarViewModel.swift" \
          "Forma File Organizing/Views/MenuBarView.swift" \
          "Forma File OrganizingTests/MenuBarViewModelTests.swift"
  git commit -m "feat: improve menu bar workflow guidance"
  ```

### Task 4: Docs Sync and Verification

**Dependencies:** Tasks 1-3

**Files:**
- Modify: `TODO.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`

- [ ] **Step 1: Update docs for the shipped macOS integration surface changes**
  Cover:
  - structured external-ingress outcome model
  - App Intent / Shortcut review-first outcome polish
  - menu bar workflow guidance improvements

- [ ] **Step 2: Run focused suites for touched areas**
  Run:
  `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ExternalIngressCoordinatorTests" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests" -only-testing:"Forma File OrganizingTests/MenuBarViewModelTests"`

- [ ] **Step 3: Run the repo-preferred non-UI suite**
  Run:
  `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"`

- [ ] **Step 4: Commit**
  ```bash
  git add TODO.md CHANGELOG.md API_REFERENCE.md
  git commit -m "docs: record macos integration surface adoption"
  ```

## Acceptance notes

- Existing Finder service, Spotlight/App Intent, and menu bar flows stay on the same workflow-backed path.
- OS-facing callers use a shared structured outcome model instead of duplicating flat status-string logic.
- Users get clearer review-first and permission-recovery feedback without adding a new extension target.
