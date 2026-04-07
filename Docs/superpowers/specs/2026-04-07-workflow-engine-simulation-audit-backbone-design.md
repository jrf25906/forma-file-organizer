# Workflow Engine Simulation And Audit Backbone Design

Date: 2026-04-07
Branch: `main`
Status: Draft for spec review

## Summary

`Workflow engine simulation and audit backbone` is the first slice of the roadmap's later `Workflow Chains With Simulation` milestone.

The goal is to introduce the long-term workflow architecture now, while keeping actual execution behavior narrow and low risk. Every future chain should run through one workflow engine entry point, but v1 only ships one live executor: `move`. The new backbone adds:

- declarative workflow definitions that can grow into `rename -> tag -> move -> notify -> log`
- first-class planning and simulation before execution
- persisted run-level, step-level, and file-level workflow audit
- rollback scoped to what actually executed
- minimal user-facing audit in both the Activity surface and file inspector

This slice is intentionally not a workflow editor and not a broad action expansion. It is the infrastructure pass that makes later steps pluggable without introducing a throwaway move-only design.

## Goals

- Establish one clean workflow-engine architecture that later step kinds plug into.
- Preserve current organize behavior by keeping `move` as the only executable step in v1.
- Make simulation a first-class, persisted artifact rather than an ad hoc preview.
- Add explicit workflow audit that supports both run-level and file-level inspection.
- Keep rollback bounded, deterministic, and honest about what actually happened.
- Route review-driven and automation-driven move flows through the same engine boundary.

## Non-Goals

- No workflow builder or end-user chain editing UI.
- No execution of `rename`, `tag`, `notify`, or `log` in v1.
- No automatic rollback on partial failure.
- No per-step retry UI, resume UI, or custom failure-policy UI.
- No attempt to replace all existing `ActivityItem` or metadata-history usage in this slice.
- No project-space workflow actions yet.

## Product Boundary

### What Ships In V1

The first milestone ships the workflow backbone plus one minimal user-facing audit slice:

- workflow definitions and step protocols
- planning plus simulation for every workflow invocation
- workflow run persistence
- workflow step persistence
- workflow file-action persistence
- one live step executor for `move`
- run-scoped rollback for executed move actions
- an Activity run summary surface
- a file-inspector workflow subsection

### What Stays Later

The following capabilities stay intentionally deferred:

- multi-step execution beyond `move`
- project-space-triggered workflows
- step editing or workflow template management
- step-level retry or resume tools
- broad notification/logging step implementations
- richer workflow-space expansion on top of read-only project spaces

## Architecture

The workflow engine should become the single orchestration layer for all future chains, even while v1 only executes `move`.

### Core Types

Recommended core types:

- `WorkflowDefinition`
- `WorkflowPlan`
- `WorkflowSimulator`
- `WorkflowRunner`
- `WorkflowStepExecutor`
- `WorkflowRollbackCoordinator`
- `WorkflowAuditStore`

### WorkflowDefinition

`WorkflowDefinition` is the declarative description of a chain.

It should support ordered step kinds such as:

- `match`
- `rename`
- `tag`
- `move`
- `notify`
- `log`

In v1, the runtime may understand all of those kinds structurally, but only `move` has a live executor. The other kinds exist so the engine shape is future-proof now rather than move-specific.

### WorkflowPlanner

`WorkflowPlanner` converts input files and a workflow definition into a `WorkflowPlan`.

Responsibilities:

- normalize the invoked definition
- derive ordered step intents for each file
- preserve enough per-file step context for simulation and later execution
- avoid filesystem mutation
- produce stable run inputs that can be persisted before execution begins

This layer is the canonical place to represent "what Forma intends to do."

### WorkflowSimulator

`WorkflowSimulator` consumes a `WorkflowPlan` and produces a `WorkflowSimulationReport`.

Supported dispositions should include:

- `wouldExecute`
- `wouldSkip`
- `blocked`
- `planned`
- `unsupported`

Every simulated outcome must include a reason summary suitable for later audit/UI display. Simulation is read-only by contract.

### WorkflowRunner

`WorkflowRunner` is the only layer allowed to convert a plan into a mutable run.

Responsibilities:

- persist the run shell before execution
- execute steps in order
- record step and file outcomes as they happen
- aggregate completion status
- surface whether rollback is available

Review-driven organize flows and automation-driven organize flows should both invoke the workflow runner instead of calling bulk move APIs directly.

### WorkflowStepExecutor

Each step kind gets its own executor through a shared protocol, for example:

- `simulate`
- `execute`
- `makeCompensationAction`

V1 ships only `MoveWorkflowStepExecutor`, which should delegate to existing move logic rather than re-implementing low-level file operations.

### WorkflowRollbackCoordinator

Rollback is run-scoped and executor-aware.

In v1, the rollback coordinator only knows how to reverse executed move actions. Later step kinds extend rollback by adding their own compensating behavior.

### WorkflowAuditStore

`WorkflowAuditStore` persists workflow run, step, and file records and serves as the shared audit source for both Activity and inspector surfaces.

It should be the source of truth for workflow summaries, while existing metadata history remains the source of truth for file lifecycle transitions such as organized and undone.

## Data Model

This slice adds explicit workflow audit entities rather than trying to reconstruct workflow runs from `FileOrganizationHistoryEntry`.

### WorkflowRunRecord

One row per workflow run.

Recommended fields:

- `id: UUID`
- `startedAt: Date`
- `completedAt: Date?`
- `triggerSurface: String`
- `definitionKind: String`
- `status: String`
- `fileCount: Int`
- `executedFileCount: Int`
- `rolledBackFileCount: Int`
- `summaryText: String`
- `undoAvailable: Bool`
- `failureReason: String?`
- relationship to `stepRuns`

Suggested statuses:

- `simulated`
- `running`
- `completed`
- `partialFailure`
- `failed`
- `rolledBack`

### WorkflowStepRunRecord

One row per step within a workflow run.

Recommended fields:

- `id: UUID`
- `runID`
- `stepIndex: Int`
- `stepKind: String`
- `status: String`
- `attemptedFileCount: Int`
- `executedFileCount: Int`
- `skippedFileCount: Int`
- `failureCount: Int`
- `summaryText: String`
- relationship to `fileActions`

### WorkflowFileActionRecord

One row per file per step.

Recommended fields:

- `id: UUID`
- `runID`
- `stepRunID`
- `fileIdentity: String`
- `sourcePath: String?`
- `targetPath: String?`
- `displayName: String`
- `stepKind: String`
- `disposition: String`
- `reason: String?`
- `matchedRuleID: UUID?`
- `destinationDisplayName: String?`
- `timestamp: Date`

Suggested dispositions:

- `simulated`
- `executed`
- `skipped`
- `failed`
- `rolledBack`
- `unsupported`

### Why Explicit Workflow Models

This model shape is heavier than deriving runs on read, but it solves real product requirements cleanly:

- a workflow run has a stable identity users can inspect
- step counts remain queryable as chains grow
- rollback has a stable run boundary
- Activity can summarize one run without re-grouping file history heuristically
- file inspector can show workflow context without overwriting lifecycle history

## Execution Semantics

### Planning And Simulation First

Every workflow invocation begins with planning and simulation, even if the caller intends to execute immediately afterward.

This gives the product one consistent trust posture:

- Forma determines what it intends to do
- Forma records that intention
- Forma executes only after that plan exists

### V1 Execution Order

V1 should execute sequentially:

1. by step
2. then by file inside the step

This is slower than a future more concurrent version, but it keeps audit ordering, failure handling, and rollback deterministic.

### Live Executor Scope

Only `move` is executable in v1.

`rename`, `tag`, `notify`, and `log` are valid workflow step kinds for the model layer, but they do not execute yet. Their simulation output may be `planned` and their execution output may be `unsupported` when invoked outside the narrow move-only definition.

For current product behavior, the actual definitions used by review and automation should contain only `move`. The engine supports future kinds structurally without surfacing fake multi-step execution in normal runs.

### Failure Policy

For v1, `move` execution should continue file-by-file within the step:

- one file failing does not abort the whole step immediately
- final run status becomes `completed`, `partialFailure`, or `failed` based on aggregate results
- no automatic rollback is attempted on partial failure

This matches current organize behavior more closely while still producing richer audit.

## Rollback Semantics

Rollback is run-scoped, reverse-ordered, and limited to what actually executed.

### V1 Rollback Rules

- only executed `move` actions are rollback-capable
- rollback runs in reverse action order
- simulated-only records are not rollback-capable
- unsupported steps do not pretend to have compensating actions
- successful rollback updates workflow audit and existing metadata lifecycle history

### Relationship To Existing Undo

The workflow engine should become the higher-level owner of run rollback, but it should initially reuse current move reversal behavior rather than replacing proven file undo logic wholesale.

The key product rule is:

- workflow audit is the source of truth for run/step/file workflow summaries
- existing metadata transitions remain the source of truth for durable file lifecycle state

## Integration Boundary

This slice should make a clean architectural cut rather than adding a second parallel path.

### Review-Driven Organize

Review-driven single-file and bulk organize flows should invoke the workflow engine with a definition containing a `move` step.

### Automation

`AutomationEngine` should continue to own scan, candidate gathering, and preflight filtering, but once it chooses eligible files it should hand execution to the workflow engine instead of directly invoking bulk move coordination.

### Existing Services

The new workflow layer should build on existing services rather than replacing them all at once:

- `RuleEngine` remains the matching and rule-simulation engine
- `AutomationEngine` remains the automation orchestrator above workflow execution
- `FileOrganizationCoordinator` and `FileOperationsService` remain the current move implementation that `MoveWorkflowStepExecutor` delegates to
- `FileMetadataFoundationService` continues to own durable metadata history

## Audit Surface

This milestone includes a deliberately small but real user-facing audit slice in both Activity and inspector.

### Activity Surface

Add a workflow run summary row/card backed by `WorkflowRunRecord`.

Recommended contents:

- trigger surface, such as review or automation
- file count
- run status
- simulation versus executed state
- undo-available state

Selecting the row opens a lightweight detail sheet showing:

- run summary
- ordered steps
- per-step counts: executed, skipped, failed, unsupported
- optionally expandable per-file rows inside each step

This remains an audit surface, not a workflow editor.

### File Inspector Surface

Add a compact workflow subsection in the file inspector backed by `WorkflowFileActionRecord`.

Recommended contents:

- latest workflow run status for the file
- latest step outcome
- recent workflow actions in reverse chronological order
- an affordance to open the full run detail when a backing run exists

### Relationship To Existing Metadata History

The existing metadata history remains in place.

For real move and undo lifecycle events:

- `FileOrganizationHistoryEntry` continues to capture durable lifecycle transitions

The new workflow subsection adds:

- run context
- step context
- simulation/planned context that metadata history does not model today

## Feature Gating And Rollout

This slice should be feature-gated at the app entry point.

Recommended additions:

- `FeatureFlagService.Feature.workflowEngine`
- `FeatureFlagService.Feature.workflowAuditUI`

Rollout posture:

- when disabled, current organize flows stay on the legacy path
- when enabled, review and automation entry points route through the workflow engine
- workflow audit surfaces appear only when the audit UI flag is enabled

If the repo prefers a single flag for the first cut, use one feature flag for both routing and UI exposure, then split later only if rollout pressure demands it.

## Error Handling

The workflow engine should fail closed and record why.

Recommended behavior:

- planning or simulation failure produces a failed run record when a run shell already exists, otherwise the caller surfaces an error without partial execution
- per-file execution failures are captured on `WorkflowFileActionRecord`
- step summaries aggregate file-level failures without hiding them
- Activity and inspector should display concise failure summaries rather than raw low-level error dumps

No separate retry UI is needed in v1.

## Testing

Add focused coverage around determinism, read-only simulation, and audit integrity.

### Unit Tests

- `WorkflowPlanner` produces stable ordered plans for move-only definitions
- `WorkflowSimulator` is read-only and does not mutate file state
- mixed step kinds plan correctly even when only `move` is executable
- `MoveWorkflowStepExecutor` delegates to the current move path and records the expected outcomes

### Persistence Tests

- simulated-only runs persist run, step, and file audit without mutating file state
- executed runs persist workflow audit plus existing metadata transition history
- rollback updates workflow audit and preserves durable undo semantics

### Integration Tests

- review-driven organize routes through the workflow engine
- automation-driven organize routes through the workflow engine after preflight
- current move behavior remains intact for success, failure, and partial-failure batches
- Activity and inspector read the same underlying workflow records

## Migration Strategy

This is an additive schema change.

Recommended posture:

- add workflow models without rewriting `ActivityItem`
- add workflow models without rewriting `FileOrganizationHistoryEntry`
- old stores open without backfilling historical workflow runs
- new runs begin generating workflow audit only after the feature is enabled

This keeps migration risk low while allowing the new system to coexist with current activity and metadata history.

## Risks And Guardrails

### Duplicate Truth Risk

The main risk is creating two competing histories.

Guardrail:

- workflow audit owns run, step, and per-file workflow summaries
- metadata history owns durable lifecycle transitions

### Scope Creep Risk

The workflow engine shape makes it tempting to add more executors immediately.

Guardrail:

- keep v1 execution limited to `move`
- treat future step kinds as structural only until their executor, audit wording, and compensation logic are ready

### Regression Risk

Routing current organize flows through a new engine boundary can break stable move behavior if the executor tries to replace existing move logic.

Guardrail:

- `MoveWorkflowStepExecutor` should delegate to current move coordination and file operations rather than fork a second move implementation

## Open Future Path

This backbone is designed to unlock later slices cleanly:

- `rename` executor with filename simulation and rollback
- `tag` executor backed by durable metadata or Finder integration
- `notify` executor that records notification intent and delivery audit
- `log` executor for richer workflow summaries and external sinks
- opinionated workflow templates
- project-space-triggered workflows
- richer workflow-detail UI and retry tools

For now, the slice should ship a real workflow architecture, a real simulation artifact, a real audit surface, and only one live action: `move`.
