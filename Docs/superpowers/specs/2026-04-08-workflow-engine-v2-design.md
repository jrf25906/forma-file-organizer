# Workflow Engine V2 Design

Date: 2026-04-08
Branch: `codex/workflow-engine-v2`
Status: Draft for spec review

## Summary

`workflow-engine-v2` is the next branch after trusted automation scopes and the move-only workflow backbone.

The release goal is to expand Forma from trustworthy single-action execution into trustworthy built-in multi-step workflows without jumping into a generic workflow builder.

V2 should ship:

- 2-3 opinionated built-in workflow templates
- one shared execution shape: `rename -> tag -> move`
- explicit template ownership on trusted automation scopes
- ad hoc template execution from existing review surfaces
- deeper workflow audit at run, step, and file levels
- full-chain rollback for executed `rename`, `tag`, and `move` steps

V2 should not ship a blank-canvas composer, project-space-triggered workflows, or freeform rename editing.

This work should start in a fresh worktree branched from `main`, not the dirty root checkout, so planning, verification, and later implementation are isolated from unrelated local files such as `WorkflowPlannerTests.swift`.

## Goals

- Expand the current workflow backbone into real multi-step execution instead of a move-only future-proof shell.
- Ship a small built-in template catalog before any generic builder work.
- Keep workflow selection legible by storing template ownership on trusted scopes.
- Let review run the same templates ad hoc without silently expanding autopilot scope.
- Deepen audit from summary-level trusted-scope runs into workflow-native run, step, and file history.
- Guarantee honest, deterministic rollback across the full executed `rename -> tag -> move` chain.
- Reuse existing file-operation, metadata, and trust infrastructure rather than replacing proven subsystems.

## Non-Goals

- No workflow builder or end-user step composition UI.
- No project-space-triggered workflow execution in this slice.
- No mixed configuration ownership between rules and trusted scopes.
- No freeform rename-pattern editor.
- No live `notify` or `log` step execution in v2.
- No cloud sync, collaboration, or shared workflow conventions.
- No separate parallel execution path that bypasses existing review or trusted-scope entry points.

## Product Boundary

### What Ships In V2

The first v2 slice ships broader workflow power through existing, already-trusted product surfaces:

- existing review surfaces and trusted autopilot scopes remain the only triggers
- 2-3 built-in workflow templates are available for explicit selection
- every shipped template uses the same ordered step shape:
  - `rename`
  - `tag`
  - `move`
- trusted scopes persist a selected template as the source of truth for autopilot execution
- review can run one of the built-in templates ad hoc for a file or batch without persisting ownership
- audit shows template identity, per-step results, per-file results, and rollback status
- completed workflow runs can be rolled back across all executed steps

### What Stays Later

The following remain intentionally deferred:

- project-space-triggered workflow actions
- blank-canvas workflow authoring
- template editing beyond choosing from built-ins
- arbitrary rename token editing or freeform text patterns
- mixed step-shape template catalogs
- generic notification/logging workflow steps

## Recommended Built-In Template Catalog

V2 should ship a narrow template catalog instead of a single proof-of-concept template, but every shipped template should share the same execution semantics.

### Shared Template Shape

Each built-in template should define:

- one rename preset
- one tag application policy
- one move behavior

All templates should execute in the same step order:

1. rename the file using a built-in preset
2. apply template-defined tags to metadata
3. move the file to the already-resolved destination

That keeps planning, simulation, rollback, UI copy, and audit semantics consistent across the catalog.

### Initial Catalog Direction

The first catalog should stay anchored to common, already legible organizing scenarios rather than abstract workflow names. Representative categories include:

- screenshot cleanup
- invoice or receipt archive
- document intake or dated archive

The exact catalog names can be finalized during implementation, but each template should remain:

- opinionated
- understandable from one sentence of UI copy
- compatible with the existing destination/trust model

## Ownership And Selection Model

### Trusted Scope Ownership

`TrustedAutomationScope` should become the durable owner of workflow-template assignment.

Rules still matter, but only as matching logic and recommendation inputs. A rule can help suggest which template fits best, while the trusted scope remains the source of truth for what autopilot actually runs.

This matches the current product shape:

- autopilot already resolves and audits by trusted scope
- folder and category scopes do not map cleanly to a single rule
- scope-level ownership keeps behavior legible in settings and audit surfaces

### Review Behavior

Review should stay the safe proving ground.

For files outside a trusted scope:

- the user may choose one of the built-in templates ad hoc
- the run is executed and audited like any other workflow run
- the choice does not persist automatically

If the user later promotes or edits a trusted scope, that is the moment template ownership becomes durable.

### Configuration Surface

V2 should not introduce a general workflow editor. Configuration should stay limited to:

- choosing a built-in template for a trusted scope
- viewing what that template does
- running a built-in template ad hoc in review

## Architecture

The current workflow backbone remains the right structural starting point, but v2 turns it into a real execution path instead of a move-only scaffold.

### Core Types

Recommended core types for v2:

- `BuiltInWorkflowTemplate`
- `WorkflowTemplateCatalog`
- `WorkflowDefinition`
- `WorkflowPlanner`
- `WorkflowSimulationReport`
- `WorkflowRunner`
- `WorkflowStepExecutor`
- `RenameWorkflowStepExecutor`
- `TagWorkflowStepExecutor`
- `MoveWorkflowStepExecutor`
- `WorkflowRollbackCoordinator`
- `WorkflowAuditStore`

### WorkflowTemplateCatalog

`WorkflowTemplateCatalog` should describe the built-in templates Forma ships.

Responsibilities:

- expose the 2-3 built-in templates
- provide stable identifiers and display copy
- define each template's rename preset and tag policy
- produce a canonical `WorkflowDefinition` for planning and execution

This keeps template policy separate from runtime execution.

### WorkflowPlanner

`WorkflowPlanner` should stop treating `rename` and `tag` as mostly future steps.

In v2 it should:

- normalize the chosen template into a concrete `WorkflowDefinition`
- derive file-specific rename targets before mutation
- derive tag intents before mutation
- preserve current path, planned path, destination, and metadata context per file
- fail planning when a rename target, tag policy, or destination cannot be stated clearly

The planner remains read-only and is still the canonical owner of "what Forma intends to do."

### WorkflowRunner

`WorkflowRunner` remains the only mutating layer.

Responsibilities:

- persist the workflow run shell before execution
- execute steps in order
- persist per-step and per-file outcomes as they happen
- persist compensation payloads before each mutating step
- aggregate completion and rollback state

Review-driven execution and trusted-scope autopilot should both route through this same runner.

### Step Executors

Each step kind should be isolated behind a shared executor protocol:

- `simulate`
- `execute`
- `makeCompensationAction`

Executor ownership in v2:

- `RenameWorkflowStepExecutor`
  - performs the rename using existing secure file-operation primitives
  - updates the run's current working path for downstream steps
- `TagWorkflowStepExecutor`
  - writes tags through `FileMetadataFoundationService`
  - never invents a separate metadata side channel
- `MoveWorkflowStepExecutor`
  - delegates to the existing `FileOrganizationCoordinator` and `FileOperationsService` move path rather than re-implementing low-level move logic

### Metadata And Identity Handling

Rename introduces a path change before move, so v2 must preserve stable file identity through the full chain.

The workflow layer should therefore carry both:

- stable file identity
- current working path after each executed step

When rename or move changes the path, the workflow path state and the metadata foundation must stay synchronized so:

- durable metadata still points at the correct file
- later steps operate on the updated path
- rollback can reverse the exact executed path transitions

### Feature Gating

V2 should add a dedicated workflow-engine feature flag at the entry point, for example `Feature.workflowEngineV2`.

Entry-point rules:

- review and inspector execution paths must check the v2 flag before offering template execution
- automation paths must check the v2 flag and the existing trusted-scope gates
- metadata-backed steps must continue respecting existing metadata feature dependencies

This keeps rollout explicit and fail-closed.

## Data Model

### TrustedAutomationScope Additions

Trusted scopes should gain explicit template ownership fields such as:

- `selectedWorkflowTemplateID`
- `templateAssignedAt`
- optional stored template-summary text for presentation convenience

`allowedActions` should remain aligned with the selected template's real step set.

For the initial catalog, that means active workflow-owned scopes should advertise:

- `rename`
- `tag`
- `move`

### Workflow Audit Entities

V2 should add workflow-native audit entities rather than overloading `TrustedAutomationScopeRunRecord`.

Recommended entities:

- `WorkflowRunRecord`
- `WorkflowStepRunRecord`
- `WorkflowFileActionRecord`

#### WorkflowRunRecord

One row per workflow invocation.

Recommended fields:

- `id: UUID`
- `templateID: String`
- `triggerSurface: String`
- `triggerScopeID: UUID?`
- `startedAt: Date`
- `completedAt: Date?`
- `status: String`
- `rollbackStatus: String`
- `fileCount: Int`
- `executedFileCount: Int`
- `rolledBackFileCount: Int`
- `summaryText: String`
- `failureReason: String?`

#### WorkflowStepRunRecord

One row per step within a workflow run.

Recommended fields:

- `id: UUID`
- `runID: UUID`
- `stepIndex: Int`
- `stepKind: String`
- `status: String`
- `attemptedFileCount: Int`
- `executedFileCount: Int`
- `failedFileCount: Int`
- `rolledBackFileCount: Int`
- `summaryText: String`

#### WorkflowFileActionRecord

One row per file per step.

Recommended fields:

- `id: UUID`
- `runID: UUID`
- `stepRunID: UUID`
- `fileIdentity: String`
- `templateID: String`
- `displayName: String`
- `stepKind: String`
- `disposition: String`
- `originalPath: String?`
- `currentPath: String?`
- `targetPath: String?`
- `destinationDisplayName: String?`
- `appliedTags: [String]`
- `reason: String?`
- `compensationPayloadData: Data?`
- `timestamp: Date`

### Relationship To Existing Models

The model split should stay explicit:

- `WorkflowRunRecord` / `WorkflowStepRunRecord` / `WorkflowFileActionRecord`
  - source of truth for workflow audit and rollback context
- `TrustedAutomationScopeRunRecord`
  - condensed trusted-scope health and recent-run summary
- `FileOrganizationHistoryEntry`
  - source of truth for durable lifecycle transitions such as organized and undone
- `FileMetadataRecord`
  - source of truth for durable metadata like tags, project association, and last known path

This keeps workflow context rich without corrupting the existing lifecycle ledger.

## Execution Semantics

### Planning And Simulation First

Every workflow invocation should still plan and simulate before execution.

That applies to:

- ad hoc review execution
- trusted-scope autopilot execution

Simulation output should answer:

- which template is about to run
- what each step would do
- what would block execution
- whether rollback would be available if execution proceeds

### Fail-Closed Preconditions

V2 should fail closed. A file must not mutate unless the runner can state and persist enough information to execute and compensate each step honestly.

A file should remain blocked if:

- rename target generation is ambiguous or collides unsafely
- tag writes cannot be persisted
- destination access is missing
- compensation payload for a later mutating step cannot be created

### Step Ordering

V2 should keep one consistent execution order:

1. `rename`
2. `tag`
3. `move`

This order keeps user-visible naming stable before destination placement and lets audit explain the final state cleanly.

### Rollback

Rollback must be full-chain and reverse-order:

1. reverse `move`
2. reverse `tag`
3. reverse `rename`

Each executor should provide the compensation action needed to reverse its own step.

If rollback cannot be guaranteed ahead of time for a file, that file should not execute.

If execution partially succeeds and later fails:

- the runner records the failure
- the runner attempts reverse-order rollback immediately
- audit records both the original failure and the rollback result

## Interaction Surfaces

### Review And Inspector

Review should stay the safe proving ground for broader workflows.

V2 should add a small explicit template-selection affordance to:

- review-driven organize flows
- file-inspector organize flows

The user should be able to:

- see which built-in templates are available
- understand the selected template in one sentence
- simulate before execution
- run the template ad hoc without persisting ownership

### Trusted Scope Management

Trusted scope surfaces should expose template ownership directly.

`TrustedAutomationScopeDetailSheet` should show:

- the selected workflow template
- the template's step shape, `rename -> tag -> move`
- latest simulation or preflight summary
- latest execution summary
- rollback availability for the latest relevant run

This keeps autopilot configuration visible without introducing a builder.

### Activity And File Inspector Audit

The existing activity and file-inspector surfaces should deepen from generic organize summaries into workflow-aware summaries.

Activity should show:

- template name
- trigger surface, review or trusted automation
- file count
- final status
- rollback availability

The file inspector should show:

- the latest workflow run touching the file
- latest rename result
- tags applied by the workflow
- move destination
- an affordance to open the full run detail

The goal is that a user can answer:

- which template would run here
- what happened last time
- can I undo it

without needing a separate workflow-builder surface.

## Automation Integration

Trusted autopilot should remain scope-owned and explicit.

Automation integration in v2 should work as follows:

- `AutomationEngine` continues to gather candidates and build scoped preflight groups
- once an eligible group resolves to an active trusted scope with a selected template, execution hands off to `WorkflowRunner`
- trusted-scope summary records remain the health surface for scope management
- workflow audit records remain the deep execution surface

Rules continue to help determine destination and recommendation context, but the trusted scope owns template selection for autopilot.

## Failure Handling

Failure behavior should stay honest and explainable.

### Expected Failure Classes

V2 should explicitly model:

- rename collisions
- missing destination permissions
- metadata write failures
- move failures
- rollback failures

### User-Facing Failure Rules

- blocked-before-execution files should remain simulated only
- partially executed runs should show both failure and rollback outcome
- rollback failure should never be flattened into generic success language
- autopilot notifications should remain grouped and scope-aware rather than per-file noisy

## Verification Strategy

Implementation should stay evidence-driven in the clean worktree.

### Unit Coverage

Add targeted coverage for:

- built-in template catalog and template identity
- trusted-scope template ownership and presentation
- planner output for `rename -> tag -> move`
- rename, tag, and move executor simulation/execution contracts
- compensation generation for each executor
- workflow audit persistence and summary projection

### Integration Coverage

Use `Forma File OrganizingTests/TestHelpers/TemporaryDirectory.swift` for filesystem-safe integration tests covering:

- successful end-to-end `rename -> tag -> move`
- partial failure followed by full rollback
- ad hoc review execution that does not persist scope ownership
- trusted-scope autopilot execution that uses the persisted template
- metadata identity continuity through rename and move

### Verification Commands

The baseline verification command for this branch should remain:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"
```

During implementation, focused workflow-engine suites should run first, followed by the repo-preferred non-UI suite before completion.

## Recommendation

Proceed with `workflow-engine-v2` as a scope-owned template-catalog release:

- opinionated built-in templates first
- one stable `rename -> tag -> move` execution model
- review as the safe ad hoc proving ground
- trusted scopes as the durable autopilot owner
- workflow-native audit and full-chain rollback as the real product payoff

That keeps the branch aligned with Forma's current posture: preview-first, explicit trust, local-first metadata, and reversible automation.
