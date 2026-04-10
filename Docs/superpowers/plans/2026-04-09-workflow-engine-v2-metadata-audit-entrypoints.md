# Workflow Engine V2 Metadata Audit Entry Points Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the shipped `workflow-engine-v2` slice with metadata-backed step kinds, richer audit projections, and first-class workflow entry requests so project-space automation can use broader workflow entry points without forking execution logic.

**Architecture:** Keep the existing planner/runner/audit backbone and grow it in place. Add a small metadata-step policy layer to workflow definitions, implement new step executors on top of `FileMetadataFoundationService`, deepen audit persistence so run/step/file rows can describe metadata deltas and trigger ownership, then replace the loose `templateID + invocationContext` execution handoff with a richer request model shared by project-policy, trusted-scope, and manual callers.

**Tech Stack:** Swift, SwiftData, SwiftUI, XCTest, existing workflow-engine-v2 services, metadata foundation services, project-space automation services, `TemporaryDirectory` filesystem-safe tests

---

## Scope check

This branch is still one subsystem: workflow-engine-v2 growth. It touches planner schema, step execution, audit persistence, activity projection, and project-policy orchestration, but all of that serves one branch outcome.

Keep these out of scope:

- user-authored workflow builders
- broad manual metadata editing
- unrelated trusted-scope UI refactors
- sync, collaboration, or cloud storage work
- brand-new automation surfaces outside the existing project-space and trusted-scope owners

## File structure

### New files

- `Forma File Organizing/Models/WorkflowExecutionRequest.swift`
  Purpose: typed execution handoff carrying template, trigger, owner, notification context, and any entry-point metadata needed by the runner and audit layer.
- `Forma File Organizing/Services/ProjectAssociationWorkflowStepExecutor.swift`
  Purpose: preview/apply/rollback the durable `projectAssociation` metadata write as a workflow-native step.
- `Forma File Organizing/Services/WorkflowStatusWorkflowStepExecutor.swift`
  Purpose: preview/apply/rollback metadata-backed workflow-status writes such as `queued`, `organized`, or other branch-approved status targets.

### Existing files to modify

- `Forma File Organizing/Models/WorkflowPlanModels.swift`
  Purpose: add new step kinds, metadata-step payloads, and compensation descriptors.
- `Forma File Organizing/Models/BuiltInWorkflowTemplate.swift`
  Purpose: allow built-in templates to describe metadata-step policies.
- `Forma File Organizing/Models/MetadataWorkflowStatus.swift`
  Purpose: confirm or extend the durable status values that workflow-native metadata steps can target.
- `Forma File Organizing/Models/WorkflowAuditModels.swift`
  Purpose: add run-level owner/entry metadata plus file-level metadata-delta payload storage.
- `Forma File Organizing/Models/WorkflowInvocationContext.swift`
  Purpose: stay focused on user-facing trigger semantics while the richer execution-request model carries the rest of the request state.
- `Forma File Organizing/Models/ProjectSpaceAutomationPresentationModels.swift`
  Purpose: expose any new workflow request/audit summary details needed by project-policy UI.
- `Forma File Organizing/Services/WorkflowTemplateCatalog.swift`
  Purpose: define which shipped templates opt into the new metadata-backed steps.
- `Forma File Organizing/Services/WorkflowPlanner.swift`
  Purpose: emit metadata-backed planned steps, blockers, and compensation payloads in stable order.
- `Forma File Organizing/Services/FileMetadataFoundationService.swift`
  Purpose: expose narrow preview/apply/revert helpers for workflow-owned metadata writes.
- `Forma File Organizing/Services/WorkflowRunner.swift`
  Purpose: register the new executors, audit richer run/file metadata, and accept richer execution requests.
- `Forma File Organizing/Services/WorkflowExecutionClient.swift`
  Purpose: move callers from loose parameters to a shared execution request shape.
- `Forma File Organizing/Services/WorkflowAuditStore.swift`
  Purpose: persist run owner/entry metadata and metadata-delta file actions.
- `Forma File Organizing/Services/WorkflowRollbackCoordinator.swift`
  Purpose: restore metadata state on rollback using the new compensation payloads.
- `Forma File Organizing/Services/ActivityLoggingService.swift`
  Purpose: project richer workflow audit back into activity surfaces with honest entry-point wording.
- `Forma File Organizing/Services/AutomationEngine.swift`
  Purpose: build and execute project-policy/trusted-scope workflow requests through the shared handoff.
- `Forma File Organizing/Services/ProjectSpaceAutomationCoordinator.swift`
  Purpose: build project-policy-owned workflow execution requests and preserve bookkeeping against the richer audit model.
- `Forma File Organizing/Services/ProjectSpaceAutomationService.swift`
  Purpose: keep project-policy detail and latest-run projection aligned with the richer workflow audit rows.
- `Forma File Organizing/ViewModels/DashboardViewModel.swift`
  Purpose: project richer workflow-run summaries into inspector and project-space surfaces.
- `Forma File Organizing/Components/WorkflowRunDetailSheet.swift`
  Purpose: render run/step/file audit depth including metadata deltas and entry-point context.
- `Forma File Organizing/Components/ProjectSpaceAutomationSection.swift`
  Purpose: surface richer latest-run context for project policies if the branch adds it.
- `Forma File Organizing/Views/FileInspectorView.swift`
  Purpose: present improved workflow audit summary at file level.
- `Forma File OrganizingTests/WorkflowPlannerTests.swift`
- `Forma File OrganizingTests/WorkflowStepExecutorTests.swift`
- `Forma File OrganizingTests/WorkflowRunnerTests.swift`
- `Forma File OrganizingTests/WorkflowAuditStoreTests.swift`
- `Forma File OrganizingTests/WorkflowRunDetailSheetTests.swift`
- `Forma File OrganizingTests/WorkflowActivityProjectionTests.swift`
- `Forma File OrganizingTests/ProjectSpaceAutomationCoordinatorTests.swift`
- `Forma File OrganizingTests/AutomationEngineTests.swift`
- `TODO.md`
- `CHANGELOG.md`
- `API_REFERENCE.md`

## Task 1: Extend workflow definitions and planner output for metadata-backed steps

**Files:**
- Create: `Forma File Organizing/Models/WorkflowExecutionRequest.swift`
- Modify: `Forma File Organizing/Models/WorkflowPlanModels.swift`
- Modify: `Forma File Organizing/Models/BuiltInWorkflowTemplate.swift`
- Modify: `Forma File Organizing/Models/MetadataWorkflowStatus.swift`
- Modify: `Forma File Organizing/Services/WorkflowTemplateCatalog.swift`
- Modify: `Forma File Organizing/Services/WorkflowPlanner.swift`
- Test: `Forma File OrganizingTests/WorkflowPlannerTests.swift`

- [ ] **Step 1: Write the failing planner tests for metadata-backed step ordering and blockers**

Add tests shaped like:

```swift
func testPlan_ProjectTemplate_ProducesMetadataBackedStepsInStableOrder() throws
func testPlan_MissingMetadataPolicy_BlocksMetadataStepAndSkipsDependentSteps() throws
func testPlan_MetadataBackedSteps_EmitCompensationPayloadDescriptors() throws
```

Expect:
- the planner can emit a branch-approved shape such as `rename -> tag -> projectAssociation -> workflowStatus -> move -> log`
- metadata steps are skipped or blocked honestly when their policy is missing
- compensation payloads preserve the previous metadata value needed for rollback

- [ ] **Step 2: Run the planner tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WorkflowPlannerTests"
```

Expected: FAIL because metadata-backed step kinds and planner support do not exist yet.

- [ ] **Step 3: Add the smallest schema needed for metadata-native planning**

Implement:
- new `WorkflowStepKind` cases:
  - `projectAssociation`
  - `workflowStatus`
- metadata-step policy data on `BuiltInWorkflowTemplate`
- any narrow payload descriptors needed to say:
  - which project label should be written
  - which workflow status should be written
  - what previous value should be restored on rollback

Keep current shipped templates backward-compatible if they do not opt into new metadata steps.

- [ ] **Step 4: Teach the planner to emit metadata-backed simulated steps**

Update `WorkflowPlanner` so it:
- inserts metadata-backed steps in one stable, documented order
- assigns blockers only to the affected step
- skips later dependent steps when an earlier required metadata step blocks
- preserves current `notify` eligibility behavior

- [ ] **Step 5: Re-run the planner tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Models/WorkflowExecutionRequest.swift" "Forma File Organizing/Models/WorkflowPlanModels.swift" "Forma File Organizing/Models/BuiltInWorkflowTemplate.swift" "Forma File Organizing/Models/MetadataWorkflowStatus.swift" "Forma File Organizing/Services/WorkflowTemplateCatalog.swift" "Forma File Organizing/Services/WorkflowPlanner.swift" "Forma File OrganizingTests/WorkflowPlannerTests.swift"
git commit -m "feat: plan metadata-backed workflow steps"
```

## Task 2: Implement metadata-backed step executors and rollback support

**Files:**
- Create: `Forma File Organizing/Services/ProjectAssociationWorkflowStepExecutor.swift`
- Create: `Forma File Organizing/Services/WorkflowStatusWorkflowStepExecutor.swift`
- Modify: `Forma File Organizing/Services/FileMetadataFoundationService.swift`
- Modify: `Forma File Organizing/Services/WorkflowRunner.swift`
- Modify: `Forma File Organizing/Services/WorkflowRollbackCoordinator.swift`
- Test: `Forma File OrganizingTests/WorkflowStepExecutorTests.swift`
- Test: `Forma File OrganizingTests/WorkflowRunnerTests.swift`

- [ ] **Step 1: Write failing executor tests for preview, apply, and rollback**

Add tests shaped like:

```swift
func testProjectAssociationExecutor_PreviewsAndAppliesMetadataWrite() throws
func testWorkflowStatusExecutor_PreviewsAndAppliesStatusWrite() throws
func testMetadataBackedCompensation_RestoresPriorValuesOnRollback() async throws
```

Expect:
- preview paths are read-only
- execution writes only the intended metadata field
- rollback restores the exact prior value rather than clearing blindly

- [ ] **Step 2: Run the executor and runner tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WorkflowStepExecutorTests" -only-testing:"Forma File OrganizingTests/WorkflowRunnerTests"
```

Expected: FAIL because the metadata executors and rollback helpers do not exist yet.

- [ ] **Step 3: Add narrow metadata preview/apply/revert helpers**

In `FileMetadataFoundationService`, add the smallest APIs needed for workflow-owned metadata writes, for example:

```swift
func previewWorkflowProjectAssociation(path: String, label: String?) throws -> String?
func applyWorkflowProjectAssociation(path: String, label: String?, timestamp: Date) throws -> String?
func restoreWorkflowProjectAssociation(path: String, previousLabel: String?) throws

func previewWorkflowStatus(path: String, status: MetadataWorkflowStatus) throws -> MetadataWorkflowStatus?
func applyWorkflowStatus(path: String, status: MetadataWorkflowStatus, timestamp: Date) throws -> MetadataWorkflowStatus?
func restoreWorkflowStatus(path: String, previousStatus: MetadataWorkflowStatus?) throws
```

Keep the APIs workflow-specific and do not turn this task into a generic metadata editor.

- [ ] **Step 4: Implement the new step executors and register them in the runner**

Implement:
- `ProjectAssociationWorkflowStepExecutor`
- `WorkflowStatusWorkflowStepExecutor`

Then wire them into `WorkflowRunner` beside the existing rename/tag/move executors so mixed path+metadata workflows stay on one execution rail.

- [ ] **Step 5: Re-run the executor and runner tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Services/ProjectAssociationWorkflowStepExecutor.swift" "Forma File Organizing/Services/WorkflowStatusWorkflowStepExecutor.swift" "Forma File Organizing/Services/FileMetadataFoundationService.swift" "Forma File Organizing/Services/WorkflowRunner.swift" "Forma File Organizing/Services/WorkflowRollbackCoordinator.swift" "Forma File OrganizingTests/WorkflowStepExecutorTests.swift" "Forma File OrganizingTests/WorkflowRunnerTests.swift"
git commit -m "feat: execute metadata-backed workflow steps"
```

## Task 3: Deepen workflow audit persistence and UI projections

**Files:**
- Modify: `Forma File Organizing/Models/WorkflowAuditModels.swift`
- Modify: `Forma File Organizing/Services/WorkflowAuditStore.swift`
- Modify: `Forma File Organizing/Services/ActivityLoggingService.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/Components/WorkflowRunDetailSheet.swift`
- Modify: `Forma File Organizing/Views/FileInspectorView.swift`
- Test: `Forma File OrganizingTests/WorkflowAuditStoreTests.swift`
- Test: `Forma File OrganizingTests/WorkflowRunDetailSheetTests.swift`
- Test: `Forma File OrganizingTests/WorkflowActivityProjectionTests.swift`

- [ ] **Step 1: Write failing audit-store and UI projection tests**

Add tests shaped like:

```swift
func testAuditStore_RunRowsPersistEntryPointAndOwnerMetadata() throws
func testAuditStore_FileActionsPersistMetadataDeltaPayloads() throws
func testWorkflowRunDetailSheet_RendersBlockedStepsAndMetadataChanges()
func testWorkflowActivityProjection_UsesDistinctProjectPolicyLabels()
```

Expect:
- run rows persist trigger/owner metadata separately from template and status
- file actions can describe metadata deltas as well as path changes
- run detail renders the extra audit depth without hiding failures
- activity wording remains honest for project space, project policy, review, and trusted scope surfaces

- [ ] **Step 2: Run the audit and projection tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WorkflowAuditStoreTests" -only-testing:"Forma File OrganizingTests/WorkflowRunDetailSheetTests" -only-testing:"Forma File OrganizingTests/WorkflowActivityProjectionTests"
```

Expected: FAIL because richer audit payloads and projections do not exist yet.

- [ ] **Step 3: Extend audit models and store methods**

Add fields sufficient to persist:
- entry-point or owner metadata on `WorkflowRunRecord`
- metadata-delta payloads on `WorkflowFileActionRecord`
- any step-level planned/blocked detail needed by the UI

Keep the storage format compact and consistent with the current raw-value + JSON-payload patterns.

- [ ] **Step 4: Render the deeper audit surfaces**

Update projections so:
- `WorkflowRunDetailSheet` shows trigger context, owner, blocked/skipped/succeeded steps, and metadata deltas
- file inspector summary can distinguish metadata-only actions from path-mutating actions
- activity logging does not flatten project-policy or metadata-rich runs into generic copy

- [ ] **Step 5: Re-run the audit and projection tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Models/WorkflowAuditModels.swift" "Forma File Organizing/Services/WorkflowAuditStore.swift" "Forma File Organizing/Services/ActivityLoggingService.swift" "Forma File Organizing/ViewModels/DashboardViewModel.swift" "Forma File Organizing/Components/WorkflowRunDetailSheet.swift" "Forma File Organizing/Views/FileInspectorView.swift" "Forma File OrganizingTests/WorkflowAuditStoreTests.swift" "Forma File OrganizingTests/WorkflowRunDetailSheetTests.swift" "Forma File OrganizingTests/WorkflowActivityProjectionTests.swift"
git commit -m "feat: deepen workflow audit projections"
```

## Task 4: Move callers to a richer workflow execution request

**Files:**
- Modify: `Forma File Organizing/Models/WorkflowExecutionRequest.swift`
- Modify: `Forma File Organizing/Models/WorkflowInvocationContext.swift`
- Modify: `Forma File Organizing/Services/WorkflowExecutionClient.swift`
- Modify: `Forma File Organizing/Services/ProjectSpaceAutomationCoordinator.swift`
- Modify: `Forma File Organizing/Services/ProjectSpaceAutomationService.swift`
- Modify: `Forma File Organizing/Services/AutomationEngine.swift`
- Modify: `Forma File Organizing/Models/ProjectSpaceAutomationPresentationModels.swift`
- Modify: `Forma File Organizing/Components/ProjectSpaceAutomationSection.swift`
- Test: `Forma File OrganizingTests/ProjectSpaceAutomationCoordinatorTests.swift`
- Test: `Forma File OrganizingTests/AutomationEngineTests.swift`

- [ ] **Step 1: Write failing orchestration tests for project-policy-owned workflow requests**

Add tests shaped like:

```swift
func testExecutePolicy_BuildsWorkflowExecutionRequestWithManualPolicyContext() async throws
func testAutomationEngine_ScheduledProjectPolicyRun_UsesSharedWorkflowRequestShape() async throws
func testProjectPolicyLatestRunProjection_ReadsRicherWorkflowAuditSummary() throws
```

Expect:
- manual, scheduled, and realtime project-policy calls build explicit workflow requests
- the runner still receives one shared request shape regardless of caller
- latest-run bookkeeping continues to work when the run stores richer owner metadata

- [ ] **Step 2: Run the coordinator and engine tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceAutomationCoordinatorTests" -only-testing:"Forma File OrganizingTests/AutomationEngineTests"
```

Expected: FAIL because callers still use the looser execution handoff.

- [ ] **Step 3: Define the shared execution request shape**

Implement `WorkflowExecutionRequest` with fields for:
- template ID
- invocation context
- trigger owner type and ID where needed
- display name or policy name for user-facing projection
- notification eligibility context if the runner needs it

Do not push all of this back into `WorkflowInvocationContext`; keep request plumbing and user-facing trigger semantics separate.

- [ ] **Step 4: Move project-space automation and automation engine callers to the new request**

Update:
- `ProjectSpaceAutomationCoordinator`
- `AutomationEngine`
- `WorkflowExecutionClient`

Constraints:
- preserve current trusted-scope behavior
- keep project-policy manual/scheduled/realtime runs distinct in audit projection
- avoid a separate project-policy runner path

- [ ] **Step 5: Re-run the coordinator and engine tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Models/WorkflowExecutionRequest.swift" "Forma File Organizing/Models/WorkflowInvocationContext.swift" "Forma File Organizing/Services/WorkflowExecutionClient.swift" "Forma File Organizing/Services/ProjectSpaceAutomationCoordinator.swift" "Forma File Organizing/Services/ProjectSpaceAutomationService.swift" "Forma File Organizing/Services/AutomationEngine.swift" "Forma File Organizing/Models/ProjectSpaceAutomationPresentationModels.swift" "Forma File Organizing/Components/ProjectSpaceAutomationSection.swift" "Forma File OrganizingTests/ProjectSpaceAutomationCoordinatorTests.swift" "Forma File OrganizingTests/AutomationEngineTests.swift"
git commit -m "feat: add shared workflow execution requests"
```

## Task 5: Verify end-to-end behavior and sync roadmap docs

**Files:**
- Modify: `TODO.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`

- [ ] **Step 1: Add or finish any remaining mixed-path regression coverage**

Before the final verification run, make sure the suite covers:
- mixed path + metadata workflows
- metadata rollback after a later hard failure
- project-policy manual vs scheduled vs realtime trigger wording
- file-level audit projection for metadata-only actions

- [ ] **Step 2: Run the repo-preferred non-UI test command**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"
```

Expected: PASS

- [ ] **Step 3: If time allows, run the full repo test command**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS'
```

Expected: PASS

- [ ] **Step 4: Update the roadmap and API docs**

Update:
- `TODO.md` to replace the open branch note with the shipped slice or narrower follow-up
- `CHANGELOG.md` with the new metadata-backed steps, audit depth, and project-policy workflow entry-point support
- `API_REFERENCE.md` with new step kinds, request models, audit fields, and executor/store changes

- [ ] **Step 5: Commit**

```bash
git add "TODO.md" "CHANGELOG.md" "API_REFERENCE.md"
git commit -m "docs: document workflow metadata and audit expansion"
```
