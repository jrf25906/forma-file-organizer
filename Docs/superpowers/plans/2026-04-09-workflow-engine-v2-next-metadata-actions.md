# Workflow Engine V2 Next Metadata Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the shipped `workflow-engine-v2` slice with one more durable metadata-backed step family, move the remaining workflow-v2 callers onto `WorkflowExecutionRequest`, and let trusted automation scopes participate honestly in richer workflow entry points.

**Architecture:** Keep the current planner/runner/audit backbone intact and grow it in place. Add a constrained `notesSummary` metadata step on top of `FileMetadataFoundationService`, thread it through planner, runner, rollback, and audit like the existing metadata-backed steps, then remove the last compatibility launch paths so review, dashboard, inspector, and trusted automation all enter the workflow engine through the same request model.

**Tech Stack:** Swift, SwiftData, SwiftUI, XCTest, existing workflow-engine-v2 services, metadata foundation services, trusted automation services, `TemporaryDirectory` filesystem-safe tests

---

## Scope check

This branch is still one subsystem: the next `workflow-engine-v2` expansion slice. It touches workflow planning, metadata execution, workflow launch semantics, and trusted automation entry behavior, but all of that serves one branch outcome.

Keep these out of scope:

- broad manual metadata editing
- AI-generated notes or cloud summarization work
- unrelated trusted automation redesign
- new automation surfaces outside existing review, dashboard, inspector, trusted automation, and project-space callers
- backup, sync, collaboration, or cloud storage work

## File structure

### New files

- `Forma File Organizing/Services/NotesSummaryWorkflowStepExecutor.swift`
  Purpose: preview, apply, and rollback a workflow-owned `notesSummary` write through the same step-executor path as tag, project association, and workflow status.
- `Forma File OrganizingTests/WorkflowExecutionClientTests.swift`
  Purpose: lock request-based workflow planning and execution behavior in one focused test file if coverage does not already exist elsewhere.

### Existing files to modify

- `Forma File Organizing/Models/WorkflowPlanModels.swift`
  Purpose: add the new step kind, plan-time note target payload, and compensation descriptor shape.
- `Forma File Organizing/Models/BuiltInWorkflowTemplate.swift`
  Purpose: let templates opt into a constrained note-summary policy.
- `Forma File Organizing/Models/WorkflowInvocationContext.swift`
  Purpose: expose only the branch-approved inputs needed to derive note targets and richer request context.
- `Forma File Organizing/Models/WorkflowAuditModels.swift`
  Purpose: extend file-level metadata delta payloads so note-summary changes audit the same way as tags and project metadata.
- `Forma File Organizing/Models/TrustedAutomationScope.swift`
  Purpose: keep allowed actions and template-backed workflow ownership honest when richer workflow entry points are enabled.
- `Forma File Organizing/Models/TrustedAutomationScopePresentationModels.swift`
  Purpose: project richer action shapes and workflow requirements to the trusted automation UI.
- `Forma File Organizing/Models/BulkWorkflowPreparationResult.swift`
  Purpose: preserve request-based launch semantics if bulk preparation still uses compatibility helpers.
- `Forma File Organizing/Services/WorkflowTemplateCatalog.swift`
  Purpose: opt specific built-in templates into the new metadata-backed step without disturbing existing templates.
- `Forma File Organizing/Services/WorkflowPlanner.swift`
  Purpose: derive note-summary targets, blockers, and compensation descriptors in one stable step order.
- `Forma File Organizing/Services/FileMetadataFoundationService.swift`
  Purpose: add workflow-specific preview/apply/restore helpers for `notesSummary`.
- `Forma File Organizing/Services/WorkflowExecutionClient.swift`
  Purpose: make `WorkflowExecutionRequest` the live API surface for all remaining callers and retire compatibility overloads when safe.
- `Forma File Organizing/Services/WorkflowRunner.swift`
  Purpose: register the new executor, persist note-summary deltas, and keep rollback/audit behavior consistent.
- `Forma File Organizing/Services/WorkflowRollbackCoordinator.swift`
  Purpose: carry rollback metadata deltas for note-summary restores.
- `Forma File Organizing/Services/AutomationEngine.swift`
  Purpose: keep trusted automation runs on the request-based workflow launch path and report honest hold reasons when richer templates are required.
- `Forma File Organizing/Services/TrustedAutomationScopeService.swift`
  Purpose: derive template-backed allowed actions from real workflow templates instead of leaving trusted scopes move-first by default.
- `Forma File Organizing/ViewModels/ReviewViewModel.swift`
  Purpose: migrate review-driven workflow-v2 launches to explicit requests.
- `Forma File Organizing/ViewModels/DashboardOrganizationController.swift`
  Purpose: migrate dashboard/inspector single-file workflow-v2 launches to explicit requests.
- `Forma File Organizing/ViewModels/BulkOperationViewModel.swift`
  Purpose: keep bulk workflow preparation aligned with the shared request model if any compatibility path remains.
- `Forma File Organizing/Components/TrustedAutomationScopeDetailSheet.swift`
  Purpose: show richer template-backed action shapes and missing-template requirements honestly.
- `Forma File Organizing/Components/TrustedAutomationScopeRecommendationSheet.swift`
  Purpose: keep recommendation affordances aligned with real template action shapes.
- `Forma File OrganizingTests/WorkflowPlannerTests.swift`
- `Forma File OrganizingTests/WorkflowStepExecutorTests.swift`
- `Forma File OrganizingTests/WorkflowRunnerTests.swift`
- `Forma File OrganizingTests/ReviewViewModelTests.swift`
- `Forma File OrganizingTests/DashboardOrganizationControllerTests.swift`
- `Forma File OrganizingTests/AutomationEngineTests.swift`
- `Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift`
- `Forma File OrganizingTests/TrustedAutomationScopeDetailSheetTests.swift`
- `TODO.md`
- `CHANGELOG.md`
- `API_REFERENCE.md`

## Task 1: Extend workflow definitions and planner output for note-summary metadata steps

**Files:**
- Create: `Forma File OrganizingTests/WorkflowExecutionClientTests.swift` `if missing`
- Modify: `Forma File Organizing/Models/WorkflowPlanModels.swift`
- Modify: `Forma File Organizing/Models/BuiltInWorkflowTemplate.swift`
- Modify: `Forma File Organizing/Models/WorkflowInvocationContext.swift`
- Modify: `Forma File Organizing/Services/WorkflowTemplateCatalog.swift`
- Modify: `Forma File Organizing/Services/WorkflowPlanner.swift`
- Test: `Forma File OrganizingTests/WorkflowPlannerTests.swift`

- [ ] **Step 1: Write the failing planner tests for note-summary step ordering and blockers**

Add tests shaped like:

```swift
func testPlan_ProjectTemplate_ProducesNotesSummaryStepInStableOrder() throws
func testPlan_MissingNotesSummaryInputs_BlocksNotesStep() throws
func testPlan_NotesSummaryStep_EmitsCompensationPayloadDescriptor() throws
```

Expect:
- an opted-in template can plan `rename -> tag -> projectAssociation -> workflowStatus -> notesSummary -> move -> log`
- the note-summary step blocks honestly when its required policy input is unavailable
- the compensation payload preserves the previous `notesSummary` value for rollback

- [ ] **Step 2: Run the planner tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WorkflowPlannerTests"
```

Expected: FAIL because note-summary step planning does not exist yet.

- [ ] **Step 3: Add the smallest schema needed for note-summary planning**

Implement:
- a new `WorkflowStepKind.notesSummary`
- a constrained note-summary policy on `BuiltInWorkflowTemplate`
- a note target field on planned workflow files
- a compensation payload descriptor that can restore the previous note summary

Keep all current templates backward-compatible until they explicitly opt in.

- [ ] **Step 4: Teach the planner to emit note-summary steps**

Update `WorkflowPlanner` so it:
- derives the branch-approved note-summary target from invocation/template context
- inserts the step in one stable order after existing metadata-backed steps
- blocks only the note step when the required target is missing
- skips later dependent steps only when the branch decides note-summary is required for that template

- [ ] **Step 5: Re-run the planner tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Models/WorkflowPlanModels.swift" "Forma File Organizing/Models/BuiltInWorkflowTemplate.swift" "Forma File Organizing/Models/WorkflowInvocationContext.swift" "Forma File Organizing/Services/WorkflowTemplateCatalog.swift" "Forma File Organizing/Services/WorkflowPlanner.swift" "Forma File OrganizingTests/WorkflowPlannerTests.swift"
git commit -m "feat: plan workflow notes summary steps"
```

## Task 2: Implement note-summary execution, rollback, and audit deltas

**Files:**
- Create: `Forma File Organizing/Services/NotesSummaryWorkflowStepExecutor.swift`
- Modify: `Forma File Organizing/Models/WorkflowAuditModels.swift`
- Modify: `Forma File Organizing/Services/FileMetadataFoundationService.swift`
- Modify: `Forma File Organizing/Services/WorkflowRunner.swift`
- Modify: `Forma File Organizing/Services/WorkflowRollbackCoordinator.swift`
- Test: `Forma File OrganizingTests/WorkflowStepExecutorTests.swift`
- Test: `Forma File OrganizingTests/WorkflowRunnerTests.swift`

- [ ] **Step 1: Write failing executor and runner tests for note-summary writes**

Add tests shaped like:

```swift
func testNotesSummaryExecutor_PreviewsAppliesAndRestoresNotesSummary() throws
func testRunner_ProjectTemplate_PersistsNotesSummaryMetadataDelta() async throws
func testRunner_Rollback_RestoresPriorNotesSummaryAfterLateFailure() async throws
```

Expect:
- preview paths stay read-only
- execution persists the intended `notesSummary`
- rollback restores the exact prior value, including `nil`
- file-level audit captures the note-summary delta

- [ ] **Step 2: Run the executor and runner tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WorkflowStepExecutorTests" -only-testing:"Forma File OrganizingTests/WorkflowRunnerTests"
```

Expected: FAIL because the note-summary executor and audit delta support do not exist yet.

- [ ] **Step 3: Add workflow-specific metadata helpers for `notesSummary`**

In `FileMetadataFoundationService`, add narrow APIs such as:

```swift
func previewWorkflowNotesSummary(path: String, summary: String?) throws -> WorkflowNotesSummaryPreview?
func applyWorkflowNotesSummary(path: String, summary: String?, timestamp: Date) throws -> WorkflowNotesSummaryPreview?
func restoreWorkflowNotesSummary(path: String, previousSummary: String?) throws -> WorkflowNotesSummaryPreview?
```

Do not turn this into generic metadata authoring.

- [ ] **Step 4: Implement the executor and wire it into the runner**

Implement `NotesSummaryWorkflowStepExecutor`, register it in `WorkflowRunner`, and extend the rollback coordinator plus audit models so the forward row and rollback row both carry note-summary metadata deltas.

- [ ] **Step 5: Re-run the executor and runner tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Services/NotesSummaryWorkflowStepExecutor.swift" "Forma File Organizing/Models/WorkflowAuditModels.swift" "Forma File Organizing/Services/FileMetadataFoundationService.swift" "Forma File Organizing/Services/WorkflowRunner.swift" "Forma File Organizing/Services/WorkflowRollbackCoordinator.swift" "Forma File OrganizingTests/WorkflowStepExecutorTests.swift" "Forma File OrganizingTests/WorkflowRunnerTests.swift"
git commit -m "feat: execute workflow notes summary steps"
```

## Task 3: Move remaining workflow-v2 callers onto `WorkflowExecutionRequest`

**Files:**
- Modify: `Forma File Organizing/Services/WorkflowExecutionClient.swift`
- Modify: `Forma File Organizing/ViewModels/ReviewViewModel.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardOrganizationController.swift`
- Modify: `Forma File Organizing/ViewModels/BulkOperationViewModel.swift`
- Test: `Forma File OrganizingTests/ReviewViewModelTests.swift`
- Test: `Forma File OrganizingTests/DashboardOrganizationControllerTests.swift`
- Test: `Forma File OrganizingTests/WorkflowExecutionClientTests.swift`

- [ ] **Step 1: Write failing tests around request-based workflow launch**

Add tests shaped like:

```swift
func testReviewWorkflowExecution_UsesExplicitExecutionRequest() async throws
func testDashboardInspectorWorkflowExecution_UsesExplicitExecutionRequest() async throws
func testWorkflowExecutionClient_RequestBasedPlanAndRunMatchCompatibilityBehavior() async throws
```

Expect:
- review launches include explicit request context rather than `templateID + surface`
- dashboard/inspector launches do the same
- request-based paths preserve current workflow-v2 behavior

- [ ] **Step 2: Run the request-related tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ReviewViewModelTests" -only-testing:"Forma File OrganizingTests/DashboardOrganizationControllerTests" -only-testing:"Forma File OrganizingTests/WorkflowExecutionClientTests"
```

Expected: FAIL because live callers still use compatibility overloads.

- [ ] **Step 3: Migrate review, dashboard, and inspector launches to explicit requests**

Update the remaining live callers so they build `WorkflowExecutionRequest` directly, carrying the correct trigger surface, scope ID, and owner context through one shared launch path.

- [ ] **Step 4: Trim obsolete compatibility helpers**

Once all live callers have moved, remove or de-emphasize compatibility overloads in `WorkflowExecutionClient` so the request model is the authoritative API surface for workflow-v2.

- [ ] **Step 5: Re-run the request-related tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Services/WorkflowExecutionClient.swift" "Forma File Organizing/ViewModels/ReviewViewModel.swift" "Forma File Organizing/ViewModels/DashboardOrganizationController.swift" "Forma File Organizing/ViewModels/BulkOperationViewModel.swift" "Forma File OrganizingTests/ReviewViewModelTests.swift" "Forma File OrganizingTests/DashboardOrganizationControllerTests.swift" "Forma File OrganizingTests/WorkflowExecutionClientTests.swift"
git commit -m "refactor: unify workflow execution requests"
```

## Task 4: Broaden trusted automation scopes to richer workflow entry points

**Files:**
- Modify: `Forma File Organizing/Models/TrustedAutomationScope.swift`
- Modify: `Forma File Organizing/Models/TrustedAutomationScopePresentationModels.swift`
- Modify: `Forma File Organizing/Services/TrustedAutomationScopeService.swift`
- Modify: `Forma File Organizing/Services/AutomationEngine.swift`
- Modify: `Forma File Organizing/Components/TrustedAutomationScopeDetailSheet.swift`
- Modify: `Forma File Organizing/Components/TrustedAutomationScopeRecommendationSheet.swift`
- Test: `Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift`
- Test: `Forma File OrganizingTests/AutomationEngineTests.swift`
- Test: `Forma File OrganizingTests/TrustedAutomationScopeDetailSheetTests.swift`

- [ ] **Step 1: Write failing tests for template-backed trusted automation action shapes**

Add tests shaped like:

```swift
func testPromotedTrustedScope_TemplateBackedActionsReflectSelectedWorkflowTemplate() throws
func testAutomationEngine_TrustedScopeRun_HoldsWhenTemplateRequirementsAreMissing() async throws
func testTrustedAutomationDetailSheet_ShowsTemplateBackedActionShape() throws
```

Expect:
- trusted scopes surface the real action shape implied by their selected template
- a scope without the required template or required metadata inputs holds honestly
- UI copy reflects richer workflow-backed behavior rather than a stale move-first model

- [ ] **Step 2: Run the trusted automation tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeServiceTests" -only-testing:"Forma File OrganizingTests/AutomationEngineTests" -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeDetailSheetTests"
```

Expected: FAIL because trusted automation still models action shapes and requirements too narrowly.

- [ ] **Step 3: Make trusted scopes template-derived where appropriate**

Update `TrustedAutomationScopeService` and `TrustedAutomationScope` so selected templates determine allowed actions when a workflow-backed scope exists, while keeping non-template scopes backward-compatible.

- [ ] **Step 4: Align engine and UI with honest workflow-backed scope semantics**

Update `AutomationEngine` and trusted automation UI surfaces so:
- hold reasons mention missing template or missing workflow inputs explicitly
- action badges reflect actual template-backed workflow steps
- workflow-trigger wording stays consistent with the shared request/audit model

- [ ] **Step 5: Re-run the trusted automation tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Models/TrustedAutomationScope.swift" "Forma File Organizing/Models/TrustedAutomationScopePresentationModels.swift" "Forma File Organizing/Services/TrustedAutomationScopeService.swift" "Forma File Organizing/Services/AutomationEngine.swift" "Forma File Organizing/Components/TrustedAutomationScopeDetailSheet.swift" "Forma File Organizing/Components/TrustedAutomationScopeRecommendationSheet.swift" "Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift" "Forma File OrganizingTests/AutomationEngineTests.swift" "Forma File OrganizingTests/TrustedAutomationScopeDetailSheetTests.swift"
git commit -m "feat: broaden trusted automation workflow entry points"
```

## Task 5: Docs sync and full verification

**Files:**
- Modify: `TODO.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`

- [ ] **Step 1: Update roadmap and shipped-behavior docs**

Document:
- the new `notesSummary` workflow step
- the fact that remaining workflow-v2 callers now launch through `WorkflowExecutionRequest`
- the richer trusted automation workflow entry semantics and honest hold behavior

- [ ] **Step 2: Run the merged no-UI suite**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"
```

Expected:
- all relevant workflow, automation, audit, and caller-path tests pass
- any unrelated skips remain expected

- [ ] **Step 3: Sanity-check diff hygiene**

Run:

```bash
git diff --check
git status --short
```

Expected:
- no whitespace errors
- only intended branch files changed

- [ ] **Step 4: Commit docs and verification updates**

```bash
git add TODO.md CHANGELOG.md API_REFERENCE.md
git commit -m "docs: record next workflow engine metadata slice"
```

## Suggested execution order

1. Task 1: planner/schema support
2. Task 2: executor/rollback/audit support
3. Task 3: remaining caller migration to request-based launch
4. Task 4: trusted automation workflow-entry broadening
5. Task 5: docs sync and full verification

## Verification notes

- Prefer `TemporaryDirectory` helpers for filesystem-sensitive executor and runner tests.
- Keep feature-gated workflow-v2 entry points honest; do not silently fall back to legacy launch paths inside tests.
- When adjusting trusted automation presentation, keep copy and badges aligned across recommendation, detail, and run-summary surfaces.
- Update `TODO.md`, `CHANGELOG.md`, and `API_REFERENCE.md` because this branch changes behavior, workflow semantics, and shipped roadmap status.
