# Workflow Engine Simulation And Audit Backbone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the workflow-engine backbone so Forma can plan, simulate, audit, and roll back move-based runs now while staying structurally ready for later `rename -> tag -> move -> notify -> log` chains.

**Architecture:** Add explicit workflow persistence (`run`, `step`, `file action`) plus pure planning/simulation services and a `WorkflowRunner` that becomes the new execution entry point inside `FileOrganizationCoordinator`. Keep real execution narrow by shipping only a `MoveWorkflowStepExecutor`, reuse the existing move path for on-disk behavior, and expose the new audit through the Analytics/Productivity report plus a compact file-inspector workflow subsection.

**Tech Stack:** Swift, SwiftData, SwiftUI, XCTest, existing macOS app services, `TemporaryDirectory` filesystem-safe tests, feature flags, security-scoped bookmark-aware file moves

---

## File structure

### New files

- `Forma File Organizing/Models/WorkflowStepKind.swift`
- `Forma File Organizing/Models/WorkflowDefinition.swift`
- `Forma File Organizing/Models/WorkflowRunRecord.swift`
- `Forma File Organizing/Models/WorkflowStepRunRecord.swift`
- `Forma File Organizing/Models/WorkflowFileActionRecord.swift`
- `Forma File Organizing/Models/WorkflowAuditSummaryModels.swift`
- `Forma File Organizing/Services/WorkflowPlanner.swift`
- `Forma File Organizing/Services/WorkflowSimulator.swift`
- `Forma File Organizing/Services/WorkflowAuditStore.swift`
- `Forma File Organizing/Services/WorkflowStepExecutor.swift`
- `Forma File Organizing/Services/MoveWorkflowStepExecutor.swift`
- `Forma File Organizing/Services/WorkflowRunner.swift`
- `Forma File Organizing/Services/WorkflowRollbackCoordinator.swift`
- `Forma File Organizing/Components/WorkflowRunActivitySection.swift`
- `Forma File Organizing/Views/WorkflowRunDetailSheet.swift`
- `Forma File OrganizingTests/WorkflowAuditStoreTests.swift`
- `Forma File OrganizingTests/WorkflowPlannerTests.swift`
- `Forma File OrganizingTests/WorkflowRunnerTests.swift`
- `Forma File OrganizingTests/FileOrganizationCoordinatorWorkflowTests.swift`
- `Forma File OrganizingTests/ProductivityReportViewModelTests.swift`

### Existing files to modify

- `Forma File Organizing/Forma_File_OrganizingApp.swift`
- `Forma File Organizing/Services/FeatureFlagService.swift`
- `Forma File Organizing/Coordinators/FileOrganizationCoordinator.swift`
- `Forma File Organizing/Services/UndoCommand.swift`
- `Forma File Organizing/ViewModels/ProductivityReportViewModel.swift`
- `Forma File Organizing/Views/ProductivityReportView.swift`
- `Forma File Organizing/Views/FileInspectorView.swift`
- `TODO.md`
- `CHANGELOG.md`
- `API_REFERENCE.md`

## Task 1: Add workflow persistence, feature flags, and audit-store scaffolding

**Files:**
- Create: `Forma File Organizing/Models/WorkflowStepKind.swift`
- Create: `Forma File Organizing/Models/WorkflowRunRecord.swift`
- Create: `Forma File Organizing/Models/WorkflowStepRunRecord.swift`
- Create: `Forma File Organizing/Models/WorkflowFileActionRecord.swift`
- Create: `Forma File Organizing/Models/WorkflowAuditSummaryModels.swift`
- Create: `Forma File Organizing/Services/WorkflowAuditStore.swift`
- Modify: `Forma File Organizing/Forma_File_OrganizingApp.swift`
- Modify: `Forma File Organizing/Services/FeatureFlagService.swift`
- Test: `Forma File OrganizingTests/WorkflowAuditStoreTests.swift`

- [ ] **Step 1: Write the failing audit-store persistence tests**

Add tests shaped like:

```swift
func testRecordSimulationRun_PersistsRunStepAndFileRows() throws
func testFetchRecentRunSummaries_SortsNewestRunsFirst() throws
```

Expect:
- one `WorkflowRunRecord` can own many ordered `WorkflowStepRunRecord` rows
- each step can own many `WorkflowFileActionRecord` rows
- recent run summaries sort by `startedAt` descending
- no existing `ActivityItem` rows are required for workflow audit to exist

- [ ] **Step 2: Run the new audit-store tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WorkflowAuditStoreTests"
```

Expected: FAIL because the workflow models, flags, and audit store do not exist yet.

- [ ] **Step 3: Implement the minimal persistence layer**

Implement:
- `WorkflowStepKind` enum with at least:
  - `match`
  - `rename`
  - `tag`
  - `move`
  - `notify`
  - `log`
- `WorkflowRunRecord` with:
  - timestamps
  - trigger surface
  - definition kind
  - status
  - file counters
  - `undoAvailable`
- `WorkflowStepRunRecord` with:
  - ordered step index
  - step kind
  - aggregate counts
  - status/summary
- `WorkflowFileActionRecord` with:
  - run linkage
  - step linkage
  - display name
  - source and target paths
  - disposition
  - reason
  - matched rule ID
- `WorkflowAuditSummaryModels` with read models for:
  - recent run summary rows
  - step summary rows
  - compact file-inspector workflow rows
- `WorkflowAuditStore` methods:
  - `recordSimulationRun(...)`
  - `recordExecutionShell(...)`
  - `fetchRecentRunSummaries(limit:)`

- [ ] **Step 4: Register schema and feature flags**

Update:
- `Forma_File_OrganizingApp.appSchema` to include:
  - `WorkflowRunRecord.self`
  - `WorkflowStepRunRecord.self`
  - `WorkflowFileActionRecord.self`
- `FeatureFlagService.Feature` with:
  - `workflowEngine`
  - `workflowAuditUI`
- dependencies so:
  - `workflowAuditUI` depends on `workflowEngine`

- [ ] **Step 5: Re-run the audit-store tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Models/WorkflowStepKind.swift" "Forma File Organizing/Models/WorkflowRunRecord.swift" "Forma File Organizing/Models/WorkflowStepRunRecord.swift" "Forma File Organizing/Models/WorkflowFileActionRecord.swift" "Forma File Organizing/Models/WorkflowAuditSummaryModels.swift" "Forma File Organizing/Services/WorkflowAuditStore.swift" "Forma File Organizing/Forma_File_OrganizingApp.swift" "Forma File Organizing/Services/FeatureFlagService.swift" "Forma File OrganizingTests/WorkflowAuditStoreTests.swift"
git commit -m "feat: add workflow audit persistence scaffolding"
```

## Task 2: Implement workflow definitions, planning, and simulation

**Files:**
- Create: `Forma File Organizing/Models/WorkflowDefinition.swift`
- Create: `Forma File Organizing/Services/WorkflowPlanner.swift`
- Create: `Forma File Organizing/Services/WorkflowSimulator.swift`
- Modify: `Forma File Organizing/Models/WorkflowAuditSummaryModels.swift`
- Test: `Forma File OrganizingTests/WorkflowPlannerTests.swift`

- [ ] **Step 1: Write the failing planner and simulator tests**

Add tests shaped like:

```swift
func testPlanMoveOnlyDefinition_ProducesSingleMoveStepForReadyFile() throws
func testSimulateDefinitionWithFutureSteps_StaysReadOnlyAndMarksPlannedOrUnsupportedSteps() throws
```

Expect:
- move-only definitions produce one ordered move step intent per eligible file
- files with no destination become `wouldSkip` or `blocked` with reasons
- future step kinds are preserved structurally in the plan
- simulation does not mutate `FileItem.status`, `destination`, or filesystem state

- [ ] **Step 2: Run the new planner tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WorkflowPlannerTests"
```

Expected: FAIL because workflow definitions, planner, and simulator do not exist yet.

- [ ] **Step 3: Implement definitions and pure planning**

Implement:
- `WorkflowDefinition` with:
  - definition kind
  - ordered steps
  - move-only convenience factory for the current product path
- `WorkflowPlanner` that converts files plus definition into a stable `WorkflowPlan`
- step-intent types that preserve:
  - file identity/path
  - step kind
  - destination display name
  - matched rule ID
  - preflight/simulation reason summaries

- [ ] **Step 4: Implement read-only simulation**

Implement `WorkflowSimulator` so it:
- consumes a `WorkflowPlan`
- emits dispositions such as:
  - `wouldExecute`
  - `wouldSkip`
  - `blocked`
  - `planned`
  - `unsupported`
- returns reason strings suitable for later audit UI
- never mutates the source files

- [ ] **Step 5: Re-run the planner tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Models/WorkflowDefinition.swift" "Forma File Organizing/Services/WorkflowPlanner.swift" "Forma File Organizing/Services/WorkflowSimulator.swift" "Forma File Organizing/Models/WorkflowAuditSummaryModels.swift" "Forma File OrganizingTests/WorkflowPlannerTests.swift"
git commit -m "feat: add workflow planning and simulation core"
```

## Task 3: Refactor file organization to execute through the workflow runner

**Files:**
- Create: `Forma File Organizing/Services/WorkflowStepExecutor.swift`
- Create: `Forma File Organizing/Services/MoveWorkflowStepExecutor.swift`
- Create: `Forma File Organizing/Services/WorkflowRunner.swift`
- Create: `Forma File Organizing/Services/WorkflowRollbackCoordinator.swift`
- Modify: `Forma File Organizing/Coordinators/FileOrganizationCoordinator.swift`
- Modify: `Forma File Organizing/Services/UndoCommand.swift`
- Modify: `Forma File Organizing/Services/WorkflowAuditStore.swift`
- Test: `Forma File OrganizingTests/WorkflowRunnerTests.swift`
- Test: `Forma File OrganizingTests/FileOrganizationCoordinatorWorkflowTests.swift`

- [ ] **Step 1: Write the failing workflow-runner tests**

Add tests shaped like:

```swift
func testExecuteMoveOnlyRun_PersistsExecutedAndFailedFileActions() async throws
func testRollbackMoveOnlyRun_ReversesExecutedMovesInReverseOrder() async throws
```

Use `Forma File OrganizingTests/TestHelpers/TemporaryDirectory.swift` for on-disk move coverage.

Expect:
- execution writes a run shell before mutation
- successful moves produce `executed` file-action rows
- failures produce `failed` rows without pretending they were rolled back
- rollback only touches executed move actions

- [ ] **Step 2: Run the workflow-runner tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WorkflowRunnerTests"
```

Expected: FAIL because executors, runner, and rollback coordinator do not exist yet.

- [ ] **Step 3: Implement executor, runner, and rollback services**

Implement:
- `WorkflowStepExecutor` protocol with:
  - `simulate(...)`
  - `execute(...)`
  - `makeCompensationAction(...)`
- `MoveWorkflowStepExecutor` that delegates to the existing move behavior instead of re-implementing low-level file operations
- `WorkflowRunner` that:
  - records simulation first
  - persists the execution shell
  - executes step-by-step and file-by-file
  - records step/file outcomes as it goes
- `WorkflowRollbackCoordinator` that:
  - reverses executed move actions only
  - runs in reverse action order
  - updates workflow audit on success/failure

- [ ] **Step 4: Write the failing coordinator integration tests**

Add tests shaped like:

```swift
func testOrganizeMultipleFiles_WhenWorkflowEngineEnabled_PersistsWorkflowRunAndKeepsUndoAvailable() async throws
func testOrganizeFile_WhenWorkflowEngineDisabled_FallsBackToLegacyPathWithoutWorkflowRows() async throws
```

Expect:
- the public coordinator APIs stay stable
- enabling `workflowEngine` routes through the new runner
- disabling `workflowEngine` preserves the legacy move path as a safety valve
- `latestUndoableBatchSummary` still works for move runs

- [ ] **Step 5: Refactor `FileOrganizationCoordinator` into the workflow entry point**

Refactor `FileOrganizationCoordinator` so:
- public `organizeFile(...)` and `organizeMultipleFiles(...)` build a move-only workflow definition and call `WorkflowRunner` when the feature is on
- extracted internal helpers keep the current move behavior available for:
  - legacy fallback
  - `MoveWorkflowStepExecutor`
- notifications, metadata transitions, personal-memory writes, and undo stack behavior stay intact

If needed, adjust `UndoCommand.swift` only enough to let workflow rollback reuse current move reversal behavior. Do not redesign the entire undo stack.

- [ ] **Step 6: Re-run the runner and coordinator tests and verify GREEN**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WorkflowRunnerTests" -only-testing:"Forma File OrganizingTests/FileOrganizationCoordinatorWorkflowTests"
```

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add "Forma File Organizing/Services/WorkflowStepExecutor.swift" "Forma File Organizing/Services/MoveWorkflowStepExecutor.swift" "Forma File Organizing/Services/WorkflowRunner.swift" "Forma File Organizing/Services/WorkflowRollbackCoordinator.swift" "Forma File Organizing/Coordinators/FileOrganizationCoordinator.swift" "Forma File Organizing/Services/UndoCommand.swift" "Forma File Organizing/Services/WorkflowAuditStore.swift" "Forma File OrganizingTests/WorkflowRunnerTests.swift" "Forma File OrganizingTests/FileOrganizationCoordinatorWorkflowTests.swift"
git commit -m "feat: route move execution through workflow runner"
```

## Task 4: Surface workflow audit in Analytics and the file inspector

**Files:**
- Create: `Forma File Organizing/Components/WorkflowRunActivitySection.swift`
- Create: `Forma File Organizing/Views/WorkflowRunDetailSheet.swift`
- Modify: `Forma File Organizing/Services/WorkflowAuditStore.swift`
- Modify: `Forma File Organizing/ViewModels/ProductivityReportViewModel.swift`
- Modify: `Forma File Organizing/Views/ProductivityReportView.swift`
- Modify: `Forma File Organizing/Views/FileInspectorView.swift`
- Test: `Forma File OrganizingTests/WorkflowAuditStoreTests.swift`
- Test: `Forma File OrganizingTests/ProductivityReportViewModelTests.swift`

- [ ] **Step 1: Write the failing audit-query tests**

Extend `WorkflowAuditStoreTests` with tests shaped like:

```swift
func testFetchRunDetail_ReturnsOrderedStepAndFileSummaries() throws
func testFetchInspectorWorkflowRows_ReturnsLatestActionsForCurrentFilePath() throws
```

Expect:
- run detail is grouped by ordered steps
- step summaries expose executed, skipped, failed, and unsupported counts
- file-inspector rows can be queried by current file path without relying on `ActivityItem`

- [ ] **Step 2: Run the expanded audit-store tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WorkflowAuditStoreTests"
```

Expected: FAIL because the detail/query APIs do not exist yet.

- [ ] **Step 3: Extend the audit store for UI-facing queries**

Implement query methods such as:
- `fetchRecentRunSummaries(limit:)`
- `fetchRunDetail(runID:)`
- `fetchInspectorWorkflowRows(forPath:limit:)`

Important guardrail:
- keep workflow run/step/file summaries in workflow audit
- do not duplicate them into `ActivityItem`

- [ ] **Step 4: Write the failing Productivity report tests**

Add tests shaped like:

```swift
func testRefresh_LoadsRecentWorkflowRunsWhenAuditUIEnabled() async throws
func testRefresh_HidesWorkflowRunsWhenAuditUIFeatureIsDisabled() async throws
```

Expect:
- `ProductivityReportViewModel` loads recent workflow run summaries for the Activity surface
- audit rows are hidden cleanly when the feature flag is off

- [ ] **Step 5: Add the user-facing audit surfaces**

Implement:
- `WorkflowRunActivitySection` as the minimal Activity surface inside the Analytics/Productivity report
- `WorkflowRunDetailSheet` with:
  - run summary
  - ordered steps
  - expandable per-file rows
- `ProductivityReportViewModel` state for:
  - recent workflow runs
  - selected run detail
  - detail-sheet presentation
- `ProductivityReportView` section placement:
  - show workflow activity without redesigning the rest of the report
- `FileInspectorView` workflow subsection:
  - latest run status
  - latest step outcome
  - recent workflow actions
  - affordance to open run detail when present

- [ ] **Step 6: Re-run the UI-adjacent tests and verify GREEN**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WorkflowAuditStoreTests" -only-testing:"Forma File OrganizingTests/ProductivityReportViewModelTests"
```

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add "Forma File Organizing/Components/WorkflowRunActivitySection.swift" "Forma File Organizing/Views/WorkflowRunDetailSheet.swift" "Forma File Organizing/Services/WorkflowAuditStore.swift" "Forma File Organizing/ViewModels/ProductivityReportViewModel.swift" "Forma File Organizing/Views/ProductivityReportView.swift" "Forma File Organizing/Views/FileInspectorView.swift" "Forma File OrganizingTests/WorkflowAuditStoreTests.swift" "Forma File OrganizingTests/ProductivityReportViewModelTests.swift"
git commit -m "feat: add workflow audit activity and inspector surfaces"
```

## Task 5: Sync roadmap docs and run verification

**Files:**
- Modify: `TODO.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`

- [ ] **Step 1: Update docs required by `codex-project.toml`**

Reflect:
- workflow-engine backbone now exists for:
  - simulation
  - run-level audit
  - file-level audit
  - rollback-ready move runs
- `move` is the only live executor in this slice
- `rename`, `tag`, `notify`, and `log` remain planned step kinds only
- Analytics/Productivity report and file inspector now expose workflow audit

- [ ] **Step 2: Run the targeted workflow suite**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' \
  -only-testing:"Forma File OrganizingTests/WorkflowAuditStoreTests" \
  -only-testing:"Forma File OrganizingTests/WorkflowPlannerTests" \
  -only-testing:"Forma File OrganizingTests/WorkflowRunnerTests" \
  -only-testing:"Forma File OrganizingTests/FileOrganizationCoordinatorWorkflowTests" \
  -only-testing:"Forma File OrganizingTests/ProductivityReportViewModelTests"
```

Expected: PASS

- [ ] **Step 3: Run the repo-preferred non-UI suite**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"
```

Expected: PASS

- [ ] **Step 4: Commit docs and verification state**

```bash
git add "TODO.md" "CHANGELOG.md" "API_REFERENCE.md"
git commit -m "docs: record workflow engine audit backbone"
```

## Notes for the implementer

- Keep `rename`, `tag`, `notify`, and `log` structural-only in this slice. They should plan and simulate cleanly, but they must not silently execute.
- Do not force workflow runs into `ActivityItem`. Workflow audit must stay a distinct source of truth for run/step/file summaries.
- Reuse `Forma File OrganizingTests/TestHelpers/TemporaryDirectory.swift` for any move/rollback tests that touch the filesystem.
- Preserve existing notification, metadata, personal-memory, and undo behavior when the move executor delegates into the current move path.
- If a detail-sheet rollback button is tempting, do not add it yet unless the rest of the run-scoped rollback path is fully tested. The backbone is the requirement; broad recovery UI is not.
- Before calling the work complete, run `@verification-before-completion` discipline and do not claim green status without actual command output.
