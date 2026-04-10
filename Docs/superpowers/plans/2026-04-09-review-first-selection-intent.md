# Review-First Selection Intent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dedicated multi-item review-first Shortcut / App Intent that reuses external ingress, auto-organizes safe items, and opens Forma only when reviewable items remain.

**Architecture:** Extend `ExternalIngressCoordinator` with an explicit execution mode so both immediate and review-first selection intents share the same bookmark resolution, scan, workflow execution, and structured outcome rails. Then add a new multi-item App Intent and feedback helper in `FormaAppIntents.swift`, keeping result copy thin and derived from the shared external-ingress result.

**Tech Stack:** Swift, App Intents, SwiftData, XCTest, macOS external-ingress services

---

## Scope and sequencing

This plan covers:

1. shared external-ingress execution mode
2. dedicated review-first multi-item App Intent
3. docs sync and verification

This plan does **not** cover:

- Finder service behavior changes
- new extension targets
- new workflow trigger-surface persistence
- workflow step-kind expansion

## File map

### Primary implementation files

- `Forma File Organizing/Services/ExternalIngressCoordinator.swift`
- `Forma File Organizing/Services/FormaAppIntents.swift`

### Tests

- `Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift`
- `Forma File OrganizingTests/FormaAppIntentsTests.swift`

### Docs to sync when the feature lands

- `TODO.md`
- `CHANGELOG.md`
- `API_REFERENCE.md`

---

### Task 1: Add Review-First Execution Mode to External Ingress

**Dependencies:** None. This is the foundation for the new intent.

**Files:**
- Modify: `Forma File Organizing/Services/ExternalIngressCoordinator.swift`
- Test: `Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift`

- [ ] **Step 1: Write failing coordinator tests for review-first presentation behavior**
  Cover:
  - review-first results with `needsReviewPaths` activate Forma and publish an external review session
  - review-first results with only skipped / recovery items do not activate Forma
  - review-first results with full success do not activate Forma
  - existing immediate behavior remains unchanged for review-needed results

- [ ] **Step 2: Run the focused coordinator tests and verify they fail for the right reason**
  Run:
  `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ExternalIngressCoordinatorTests"`

- [ ] **Step 3: Add an explicit execution mode to the coordinator**
  Suggested shape:
  - `ExternalIngressExecutionMode.immediate`
  - `ExternalIngressExecutionMode.reviewFirst`

  Apply it to:
  - `handleRequest(...)`
  - `processPendingRequestIfPossible(...)`
  - any internal helper that decides whether to activate Forma and publish review state

- [ ] **Step 4: Keep source attribution and execution policy separate**
  Notes:
  - do not add a new `ExternalIngressSource` case just for review-first App Intents
  - keep `.spotlightIntent` as the source for the new App Intent unless a later audit requirement proves otherwise

- [ ] **Step 5: Implement review-first app-open policy**
  Rules:
  - onboarding required: open Forma
  - review-needed items remain: open Forma and publish the review session
  - recovery-only or skipped-only outcomes: keep Forma closed
  - fully successful outcomes: keep Forma closed

- [ ] **Step 6: Re-run the focused coordinator tests and make them pass**
  Run:
  `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ExternalIngressCoordinatorTests"`

- [ ] **Step 7: Commit**
  ```bash
  git add "Forma File Organizing/Services/ExternalIngressCoordinator.swift" \
          "Forma File OrganizingTests/ExternalIngressCoordinatorTests.swift"
  git commit -m "feat: add review-first external ingress mode"
  ```

### Task 2: Add the Review-First Multi-Item App Intent

**Dependencies:** Task 1

**Files:**
- Modify: `Forma File Organizing/Services/FormaAppIntents.swift`
- Test: `Forma File OrganizingTests/FormaAppIntentsTests.swift`

- [ ] **Step 1: Write failing App Intent feedback tests for the new review-first surface**
  Cover:
  - clean multi-item success stays compact and does not mention opening Forma
  - review-needed result says Forma opened for review
  - recovery-only result uses recovery wording without implying the app opened
  - onboarding resume message stays explicit

- [ ] **Step 2: Run the focused App Intent tests and verify they fail**
  Run:
  `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/FormaAppIntentsTests"`

- [ ] **Step 3: Add a dedicated review-first feedback helper beside the existing selection-intent helper**
  Notes:
  - keep it pure
  - make it consume `ExternalIngressDisposition`
  - avoid rebuilding summary counts manually in the helper

- [ ] **Step 4: Add a new multi-item App Intent**
  Suggested surface:
  - name: `ReviewSelectionIntent`
  - item parameter: `[IntentFile]`
  - workflow-template parameter: same shape as `OrganizeSelectionIntent`
  - source: `.spotlightIntent`
  - execution mode: `.reviewFirst`

- [ ] **Step 5: Define multi-item input rules**
  Rules:
  - map all `IntentFile.fileURL` values into a `[URL]`
  - if no valid URLs remain, throw `FormaIntentError.selectionUnavailable`
  - do not collapse the multi-item selection into repeated single-item coordinator calls

- [ ] **Step 6: Register the new App Shortcut**
  Notes:
  - add a dedicated `AppShortcut` entry in `FormaShortcuts`
  - use phrases that clearly mean review/handoff, not immediate organization
  - keep the existing `OrganizeSelectionIntent` shortcut intact

- [ ] **Step 7: Re-run the focused App Intent tests and make them pass**
  Run:
  `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/FormaAppIntentsTests"`

- [ ] **Step 8: Run the combined focused selection-flow suite**
  Run:
  `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ExternalIngressCoordinatorTests" -only-testing:"Forma File OrganizingTests/FormaAppIntentsTests"`

- [ ] **Step 9: Commit**
  ```bash
  git add "Forma File Organizing/Services/FormaAppIntents.swift" \
          "Forma File OrganizingTests/FormaAppIntentsTests.swift"
  git commit -m "feat: add review-first selection intent"
  ```

### Task 3: Docs Sync and Verification

**Dependencies:** Tasks 1-2

**Files:**
- Modify: `TODO.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`

- [ ] **Step 1: Update docs for the new review-first Shortcut / App Intent**
  Cover:
  - new review-first multi-item selection intent
  - external-ingress execution mode
  - app-open policy differences between immediate and review-first selection flows

- [ ] **Step 2: Re-run the focused touched-area suites**
  Run:
  `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ExternalIngressCoordinatorTests" -only-testing:"Forma File OrganizingTests/FormaAppIntentsTests"`

- [ ] **Step 3: Run the repo-preferred non-UI suite**
  Run:
  `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"`

- [ ] **Step 4: Commit**
  ```bash
  git add TODO.md CHANGELOG.md API_REFERENCE.md
  git commit -m "docs: record review-first selection intent"
  ```

## Acceptance notes

- `OrganizeSelectionIntent` stays as the immediate explicit-selection action.
- A second App Intent exists for review-first multi-item selection.
- Both intents use the shared external-ingress coordinator path.
- Review-first behavior opens Forma only when actual review work remains.
- Recovery-only and clean-success results keep the app closed and return honest result text.
