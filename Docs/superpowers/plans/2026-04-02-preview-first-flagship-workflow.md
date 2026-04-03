# Preview-First Flagship Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make review, inspector, rule creation/editing, explanation, and undo behave like one coherent preview-first workflow without introducing a new editor architecture.

**Architecture:** Keep the existing right-panel builder and modal rule editor, but move workflow ownership above them. Introduce a shared rule-draft session plus explicit launch and return APIs so panel/modal transitions preserve draft state, review context, and action hierarchy. Limit the scope to workflow continuity, CTA clarity, and explanation/undo framing.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest, XCUITest

---

## File Structure

### New or expanded state ownership

- Modify: `Forma File Organizing/ViewModels/NavigationViewModel.swift`
  - Add shared rule-draft session state, launch metadata, return-target metadata, and helper APIs for starting, presenting, collapsing, and clearing rule drafts.
- Modify: `Forma File Organizing/Views/Components/RuleFormState.swift`
  - Keep `RuleFormState` as the form payload and add any small helper APIs needed for session construction or reset.
- Optional create if `NavigationViewModel.swift` becomes noisy: `Forma File Organizing/ViewModels/RuleDraftSession.swift`
  - Holds `RuleDraftSession`, `RuleDraftSource`, `RuleDraftPresentation`, and `RuleDraftReturnTarget`.

### Workflow entry and handoff points

- Modify: `Forma File Organizing/Views/MainContentView.swift`
  - Route card/list/grid rule-entry points through shared launch helpers instead of direct modal state mutation.
- Modify: `Forma File Organizing/Views/FileInspectorView.swift`
  - Route “Create Rule for This” and “Based on rule…” through the shared session and align explanation/undo wording.
- Modify: `Forma File Organizing/Views/InlineRuleBuilderView.swift`
  - Bind to shared draft state and preserve draft data when expanding to modal.
- Modify: `Forma File Organizing/Views/RuleEditorView.swift`
  - Bind to shared draft state and preserve draft data when collapsing back to the panel.
- Modify: `Forma File Organizing/Views/DashboardView.swift`
  - Keep the modal overlay driven by session-aware launch helpers and clean up dismiss behavior.
- Modify: `Forma File Organizing/Views/RightPanelView.swift`
  - Keep rule-builder presentation tied to workflow mode, not local form ownership.
- Modify: `Forma File Organizing/ViewModels/ProductivityReportViewModel.swift`
  - Replace direct modal-opening state mutation with shared launch helpers.
- Modify: `Forma File Organizing/Views/RulesManagementView.swift`
  - Replace direct rule-editor launch paths with shared launch helpers.

### Review-context and action hierarchy surfaces

- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
  - Add helper methods for rule-draft entry from review/inspector contexts and preserve selected file + chunk continuity.
- Modify: `Forma File Organizing/Coordinators/PanelStateManager.swift`
  - Only if needed to make panel return targets explicit; avoid turning this into a second source of truth.
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
  - Ensure pinned right-panel CTA steps back when review or active rule editing owns the next action.
- Modify: `Forma File Organizing/Components/ActivityFeed.swift`
  - Align undo/audit phrasing with inspector and default-panel language.
- Modify: `Forma File Organizing/Services/ActivityLoggingService.swift`
  - Only if current copy or detail formatting blocks the new shared language.

### Tests

- Create: `Forma File OrganizingTests/NavigationViewModelTests.swift`
  - Session creation, presentation changes, return targets, and cleanup.
- Modify: `Forma File OrganizingTests/DashboardViewModelTests.swift`
  - Review-context continuity and selected-file restoration.
- Create: `Forma File OrganizingUITests/RuleEditingWorkflowUITests.swift`
  - End-to-end panel ↔ modal draft continuity and return-to-review flow.

### Docs to update after behavior lands

- Modify: `TODO.md`
- Modify: `Docs/Getting-Started/TODO.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`

---

### Task 1: Introduce Shared Rule-Draft Session State

**Files:**
- Modify: `Forma File Organizing/ViewModels/NavigationViewModel.swift`
- Modify: `Forma File Organizing/Views/Components/RuleFormState.swift`
- Optional Create: `Forma File Organizing/ViewModels/RuleDraftSession.swift`
- Test: `Forma File OrganizingTests/NavigationViewModelTests.swift`

- [ ] Add a small session type for in-progress rule editing.
  Required fields:
  - `formState: RuleFormState`
  - `editingRule: Rule?`
  - `fileContext: FileItem?`
  - `suggestedNaturalLanguageText: String?`
  - `presentation: panel | modal`
  - `returnTarget: defaultPanel | inspector(filePath) | none`
  - `source: newFromFile | editExisting | suggestedPrompt | genericNew`

- [ ] Add `NavigationViewModel` helper APIs and stop exposing raw modal state as the main launch mechanism.
  Suggested API surface:
  - `beginRuleDraft(...)`
  - `presentRuleDraftModal()`
  - `presentRuleDraftPanel()`
  - `clearRuleDraft()`
  - `discardRuleDraft()`

- [ ] Keep `RuleFormState` as the draft payload and add only small helpers needed for session construction.
  Constraints:
  - do not move persistence logic into `RuleFormState`
  - do not add relaunch persistence for incomplete drafts

- [ ] Write focused unit tests for:
  - creating a new draft from file context
  - creating an edit draft from an existing rule
  - switching panel -> modal without replacing `formState`
  - switching modal -> panel without replacing `formState`
  - clearing the session only on explicit discard/complete

- [ ] Verify:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/NavigationViewModelTests"`

- [ ] Checkpoint:
  Commit: `feat: add shared rule draft session`

**Implementation notes:**
- Keep the draft-session types small and UI-focused.
- Prefer one owner (`NavigationViewModel`) over duplicating state between navigation and panel managers.
- Validation banners and overlap warnings may remain view-local if they can be recomputed from `formState`.

---

### Task 2: Route All Rule Entry Points Through Shared Launch Helpers

**Files:**
- Modify: `Forma File Organizing/Views/MainContentView.swift`
- Modify: `Forma File Organizing/Views/FileInspectorView.swift`
- Modify: `Forma File Organizing/ViewModels/ProductivityReportViewModel.swift`
- Modify: `Forma File Organizing/Views/RulesManagementView.swift`
- Modify: `Forma File Organizing/Views/DashboardView.swift`
- Test: `Forma File OrganizingTests/NavigationViewModelTests.swift`

- [ ] Replace direct `nav.isShowingRuleEditor = true` and scattered `nav.ruleEditor*` mutations with shared helper calls.
  Important launch surfaces:
  - card/list/grid file actions in `MainContentView.swift`
  - inspector “Create Rule for This”
  - inspector “Based on rule...”
  - productivity insight deep links
  - rules-management edit/create paths

- [ ] Set the correct return target when opening a rule draft.
  Rules:
  - review-file launch from inspector returns to inspector for that file
  - generic create from dashboard or rules returns to default panel
  - productivity/rules-management modal launches can use `none` if no dashboard panel restoration is expected

- [ ] Update `DashboardView.ruleEditorOverlay` dismiss handling so it clears or preserves the active draft intentionally instead of relying on ad hoc `nav.* = nil` resets.

- [ ] Add regression tests for:
  - file-based draft launch sets `fileContext` and inspector return target
  - rules-management edit launch sets `editingRule`
  - productivity insight launch sets suggested text without stale file context

- [ ] Verify:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/NavigationViewModelTests"`

- [ ] Checkpoint:
  Commit: `refactor: centralize rule draft launch paths`

**Implementation notes:**
- This task should reduce duplicate launch logic, not just wrap it.
- Avoid leaving mixed patterns behind; replace all direct modal launch mutations in the touched files.

---

### Task 3: Preserve Draft State Across Panel and Modal Editing

**Files:**
- Modify: `Forma File Organizing/Views/InlineRuleBuilderView.swift`
- Modify: `Forma File Organizing/Views/RuleEditorView.swift`
- Modify: `Forma File Organizing/Views/RightPanelView.swift`
- Modify: `Forma File Organizing/Views/DashboardView.swift`
- Test: `Forma File OrganizingTests/NavigationViewModelTests.swift`
- Test: `Forma File OrganizingUITests/RuleEditingWorkflowUITests.swift`

- [ ] Refactor `InlineRuleBuilderView` so it reads from and writes back to the shared draft session instead of owning the only source of truth.
  Preserve:
  - typed conditions
  - destination path/bookmark
  - category selection
  - action type
  - suggested text or file-derived defaults

- [ ] Refactor `RuleEditorView` to hydrate from the same shared draft session and write changes back before collapse/dismiss.

- [ ] Change `expandToModal()` in `InlineRuleBuilderView.swift` to switch presentation mode on the same session instead of reconstructing editor state from only `editingRule` and `fileContext`.

- [ ] Change `collapseToPanel()` in `RuleEditorView.swift` to restore the panel using the same session instead of reconstructing the builder from partial context.

- [ ] Keep view-local transient state local unless it must survive handoff.
  Safe to recompute:
  - overlap warnings
  - preview counts
  - validation message strings
  Not safe to lose:
  - `RuleFormState`
  - launch source
  - return target

- [ ] Add unit coverage for panel ↔ modal handoff preserving `RuleFormState`.

- [ ] Add one UI workflow test:
  - open a file from review
  - create rule inline
  - type/edit multiple fields
  - expand to modal
  - confirm draft values remain
  - collapse back to panel
  - confirm draft values still remain

- [ ] Verify:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/NavigationViewModelTests" -only-testing:"Forma File OrganizingUITests/RuleEditingWorkflowUITests"`

- [ ] Checkpoint:
  Commit: `feat: preserve rule draft state across panel and modal`

**Implementation notes:**
- Do not try to deduplicate the full UI structure in this task.
- The success condition is continuity, not editor unification.

---

### Task 4: Preserve Review Context and Clarify Primary Action Ownership

**Files:**
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/Coordinators/PanelStateManager.swift`
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Modify: `Forma File Organizing/Views/FileInspectorView.swift`
- Modify: `Forma File Organizing/Views/MainContentView.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`

- [ ] Add explicit helper methods in `DashboardViewModel` for starting file-context rule drafts from review and inspector flows.
  Goal:
  - keep review chunk and selection intact while the user detours into editing

- [ ] Ensure file review state survives:
  - opening inspector
  - opening inline rule builder from the inspector
  - expanding into the modal editor
  - saving or discarding the rule draft

- [ ] Re-check primary CTA ownership in `DefaultPanelView`.
  Rules:
  - when a review chunk is active, the floating action bar owns the primary action
  - when a rule draft is active, save/discard inside the editor own the primary action
  - the default-panel pinned CTA must not compete with either state

- [ ] Keep file-surface parity across:
  - `Forma File Organizing/Views/Components/FileRow.swift`
  - `Forma File Organizing/Components/FileListRow.swift`
  - `Forma File Organizing/Components/FileGridItem.swift`
  - `Forma File Organizing/Views/MainContentView.swift`
  Even if these files do not need direct code changes, verify their launch behavior remains aligned.

- [ ] Add dashboard tests for:
  - review chunk selection persists while entering/exiting rule editing
  - returning from discard/save restores expected panel target
  - current review chunk does not reset to a broader backlog view

- [ ] Verify:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/DashboardViewModelTests"`

- [ ] Checkpoint:
  Commit: `feat: preserve review context during rule editing`

**Implementation notes:**
- `PanelStateManager` should stay presentation-focused. Do not move draft-state ownership into it.
- If a selection disappears because the file was organized, restore the safest nearby state rather than forcing stale inspector content.

---

### Task 5: Align Explanation and Undo Framing

**Files:**
- Modify: `Forma File Organizing/Views/FileInspectorView.swift`
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Modify: `Forma File Organizing/Components/ActivityFeed.swift`
- Modify: `Forma File Organizing/Services/ActivityLoggingService.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`
- Test: `Forma File OrganizingUITests/RuleEditingWorkflowUITests.swift`

- [ ] Audit the current wording in inspector, default-panel undo/preflight cards, and activity feed.
  Normalize the workflow language to answer:
  - why this matched
  - what will happen
  - whether it was rule-driven or review-driven
  - whether undo is still available

- [ ] Update file-inspector copy and button labels so “Based on rule...” and rule-explanation sections feel part of the same trusted workflow as the panel summary and activity feed.

- [ ] Update default-panel summary copy only enough to align with the inspector. Avoid a broad copy rewrite.

- [ ] Update activity feed details only if existing formatting prevents consistent framing.

- [ ] Add one UI assertion that an undo-capable batch remains discoverable after completing the workflow.

- [ ] Verify:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingUITests/RuleEditingWorkflowUITests"`

- [ ] Checkpoint:
  Commit: `refactor: align workflow explanation and undo language`

**Implementation notes:**
- Keep this bounded. The goal is consistency, not a prose pass across the whole product.

---

### Task 6: Final Verification and Docs Sync

**Files:**
- Modify: `TODO.md`
- Modify: `Docs/Getting-Started/TODO.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`

- [ ] Re-run focused unit tests:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/NavigationViewModelTests" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests"`

- [ ] Re-run the workflow UI tests:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingUITests/RuleEditingWorkflowUITests"`

- [ ] Re-run the non-UI suite if targeted tests pass:
  Run: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"`

- [ ] Re-run the app build:
  Run: `xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build`

- [ ] Update docs after implementation lands:
  - mark the roadmap TODO items that this slice completes
  - add a concise `[Unreleased]` changelog entry
  - update `API_REFERENCE.md` only if shared workflow APIs or user-visible workflow contracts need documenting

- [ ] Final checkpoint:
  Commit: `feat: tighten preview-first flagship workflow`

## Risks and Guardrails

- Do not let panel state and navigation state both become draft owners.
- Do not reset the current review chunk just because the user opened a rule editor.
- Do not persist incomplete rule drafts across app relaunch in this slice.
- Do not broaden this into a rule-system rewrite.
- Keep review launch behavior aligned across card/list/grid surfaces.
