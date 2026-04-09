# Workflow Engine V2 Notify And Log Design

Date: 2026-04-08
Branch: `codex/workflow-engine-v2-notify-log`
Status: Draft for spec review

## Summary

`workflow-engine-v2-notify-log` is a focused follow-up to the shipped `workflow-engine-v2` `rename -> tag -> move` slice.

The release goal is to extend Forma's existing workflow engine with workflow-native `log` and `notify` side-effect steps without taking on a new trigger surface in the same branch.

This slice should ship:

- workflow-owned `log` execution on every workflow run
- template-aware, background-only `notify` execution on selected trusted-scope runs
- richer workflow audit language for side-effect failures that happen after durable work succeeds
- centralized workflow activity emission inside the engine instead of caller-specific summary logging
- duplicate-notification suppression when a workflow-native `notify` step is planned

This slice should not ship project-space-triggered workflows, blank-canvas workflow authoring, or review-surface notification delivery.

## Goals

- Extend the current workflow engine beyond durable steps without introducing a parallel notification system.
- Make `log` a real workflow step rather than a caller-side follow-up after `WorkflowRunner` returns.
- Keep `notify` narrow, trustworthy, and non-blocking by limiting it to meaningful background runs.
- Preserve honest audit and rollback semantics when side-effect steps fail after `rename`, `tag`, and `move` already succeeded.
- Reuse existing notification, activity, and trusted-scope infrastructure instead of inventing new persistence or delivery channels.

## Non-Goals

- No project-space-triggered workflow execution in this slice.
- No notification delivery for ad hoc review-driven workflow runs.
- No new top-level workflow UI surface or separate workflow notification settings model.
- No per-step retry UI, resume UI, or manual replay UI for `notify`.
- No automatic rollback when `log` or `notify` fails.
- No expansion into generic external sinks, webhook delivery, or collaboration notifications.

## Options Considered

### Option A: Notify/Log Side-Effects Slice Only

This is the recommended approach.

Benefits:

- keeps the branch focused on one engine concern
- lands real `notify` and `log` behavior without coupling it to a new UI trigger surface
- gives the roadmap a user-visible workflow expansion while preserving the later project-space branch
- keeps failure handling legible because only one new class of side effects is introduced

Tradeoffs:

- project-space-triggered workflow actions remain deferred
- only one shipped template uses workflow-native notifications at first

### Option B: Notify/Log Plus Project-Space-Triggered Workflows

Benefits:

- stronger release headline
- pushes workflow expansion and project memory closer together

Tradeoffs:

- couples engine-side semantics to a new product surface in the same branch
- increases ambiguity around where notifications come from and when they should fire
- makes regression scope materially larger than necessary

### Option C: Log-Only Follow-Up

Benefits:

- lowest-risk implementation
- easiest to validate

Tradeoffs:

- punts real `notify` execution again
- undershoots the open roadmap item about broader multi-step automation
- leaves too much engine follow-up behavior outside the workflow model

## Recommended Approach

Proceed with a focused `notify/log` side-effects slice:

- `log` becomes a universal workflow step
- `notify` becomes a template-specific, background-only workflow step
- `notify` remains non-blocking and never causes rollback of successful durable work
- project-space-triggered workflows stay out of scope for this branch

## Product Boundary

### What Ships In This Slice

This branch extends the current built-in workflow shape from:

- `rename`
- `tag`
- `move`

to:

- `rename`
- `tag`
- `move`
- `log`
- optional `notify`

The shipped behavior should be:

- every workflow run, regardless of trigger source, executes `log`
- only trusted-scope/background runs may execute `notify`
- `notify` is included only when the selected template opts in
- `notify` is planned only after durable steps succeed conceptually
- `notify` failure marks the run as completed with issues rather than failed-and-rolled-back

### Trigger Rules

The trigger matrix for this slice is:

- ad hoc review-driven runs
  - execute `rename -> tag -> move -> log`
  - never execute `notify`
- trusted-scope/background runs
  - execute `rename -> tag -> move -> log`
  - execute `notify` only if the selected template allows it

### Initial Template Policy

The first shipped notification policy should stay deliberately narrow:

- `Receipt Intake`
  - no workflow-native notify
- `Screenshot Cleanup`
  - no workflow-native notify
- `Project Drop Zone`
  - allow workflow-native notify for trusted-scope/background runs

This keeps the first `notify` release meaningful instead of noisy.

### What Stays Later

The following remain intentionally deferred:

- project-space-triggered workflow actions
- notification delivery for review-driven runs
- user-editable per-template notification preferences
- general-purpose workflow sinks beyond activity logging and system notifications
- per-step retry and recovery UI for side-effect failures

## Architecture

The branch should extend the existing engine rather than layering new behavior beside it.

### Workflow Ownership

`WorkflowRunner` remains the only orchestrator.

No caller should perform workflow-summary logging or workflow-native notification delivery after the runner returns. Those concerns move into the planned step list and execute inside the runner like every other workflow step.

### Invocation Context

Workflow planning should become context-aware.

Recommended new concept:

- `WorkflowInvocationContext`
  - `reviewAdHoc`
  - `trustedScopeAutomation(scopeDisplayName: String?)`

`WorkflowExecutionClient` and `WorkflowPlanner` should accept that context so the step list can vary by invocation source without branching the engine.

### Template Notification Policy

`BuiltInWorkflowTemplate` should gain an explicit notification policy, for example:

- `never`
- `trustedScopeOnly`

That keeps the rule legible:

- templates define whether notification is ever allowed
- invocation context decides whether notification is eligible on this run
- the planner decides whether `notify` appears in the step list
- the runner simply executes the planned chain

### Planned Step Shape

The planner should always emit:

1. `rename`
2. `tag`
3. `move`
4. `log`

It should then append:

5. `notify`

only when all of the following are true:

- the invocation context is trusted-scope/background
- the template's notification policy allows it
- the workflow definition and file inputs are otherwise runnable

### New Executors

This slice should add:

- `LogWorkflowStepExecutor`
- `NotifyWorkflowStepExecutor`

Responsibilities:

`LogWorkflowStepExecutor`
- records workflow-native completion/attention activity through `ActivityLoggingService`
- uses the existing workflow run, rollback, and trigger-surface projection language
- runs for both review and background invocations
- has no rollback payload

`NotifyWorkflowStepExecutor`
- uses existing notification delivery infrastructure rather than direct macOS calls from the runner
- only delivers for planned trusted-scope/background runs
- records success, skip, or failure in workflow audit
- has no rollback payload

### Notification Delivery Path

The notification step should reuse the existing notification service boundary.

Recommended posture:

- keep system delivery in `NotificationService`
- add a workflow-native notification method through a narrow protocol boundary rather than coupling the runner to `UNUserNotificationCenter`
- derive the notification copy from workflow template identity, scope display name, and organized file count

### Duplicate Notification Suppression

When a background trusted-scope run plans a workflow-native `notify` step, the generic automation summary notification should be suppressed for that run.

That avoids two banners for the same work:

- one generic automation summary
- one workflow-native template notification

When `notify` is not planned, existing automation-summary behavior should remain unchanged.

## Audit And Status Model

This slice needs more expressive workflow status language because side-effect steps can fail after durable work already succeeded.

### Run Status

`WorkflowRunPrimaryStatus` should be extended to distinguish:

- `succeeded`
- `completedWithIssues`
- `failed`
- existing non-terminal states such as `queued` and `running`

Meaning:

- `succeeded`
  - all planned steps succeeded
- `completedWithIssues`
  - `rename`, `tag`, and `move` completed successfully, but a side-effect step such as `notify` failed
- `failed`
  - durable work failed badly enough that the workflow did not complete its intended filesystem/metadata mutation

### Step Status

`WorkflowStepRunRecord` remains the source of truth for per-step execution state.

The existing step statuses are sufficient if step records preserve:

- `pending`
- `running`
- `succeeded`
- `failed`
- `skipped`

along with error message and timestamp fields.

### File Disposition

`WorkflowFileDisposition` should become less move-centric.

Recommended successful outcomes:

- `renamed`
- `tagged`
- `moved`
- `logged`
- `notified`
- `restored`

Recommended shared non-success outcomes:

- `pending`
- `skipped`
- `failed`

This keeps file-level audit explicit without requiring special-case interpretation from UI code.

### Compensation Rules

Compensation remains available only for durable steps:

- `rename`
- `tag`
- `move`

`log` and `notify`:

- never carry rollback payloads
- never trigger rollback by themselves
- never block rollback availability for the durable part of the run

### Failure Semantics

The branch should follow these rules:

- `rename` / `tag` / `move` failure
  - can still yield rollback logic
  - may leave the run in `failed`
- `log` failure
  - never causes rollback
  - may mark the run `completedWithIssues` if durable work succeeded
- `notify` failure
  - never causes rollback
  - may mark the run `completedWithIssues` if durable work succeeded

This keeps workflow state aligned with the real user outcome: files still landed correctly even if the post-run side effect did not.

## Activity And UI Surfaces

This slice should keep visible UI changes limited to existing audit/readout surfaces.

### Activity

`ActivityFeed` should continue using:

- `workflowRunCompleted`
- `workflowRunAttentionNeeded`

but the activity creation should now be owned by the workflow `log` step rather than by caller-specific post-run helpers.

That centralization ensures:

- review, bulk, inspector, and automation runs all log through one engine path
- future workflow trigger surfaces do not need to remember to emit summaries manually

### Inspector And Run Detail

`FileInspectorView` and `WorkflowRunDetailSheet` should:

- show `completed with issues` when side-effect steps fail after durable success
- list `log` and `notify` in the step breakdown
- preserve rollback messaging for the durable portion of the run

### Trusted Scope Detail

Trusted-scope detail surfaces should:

- keep showing latest workflow status for template-owned scopes
- reflect `completedWithIssues` distinctly from full success
- avoid treating a failed notification as if the automation move itself failed

### No New Top-Level UI

This branch should not add:

- a new workflow dashboard panel
- new project-space buttons
- a notification settings editor

The visible behavior change is deeper and more honest workflow audit, not a new interaction model.

## Testing Strategy

This slice should stay test-heavy.

### Planner Tests

Add coverage proving:

- review context plans `rename -> tag -> move -> log`
- trusted-scope context plans `rename -> tag -> move -> log -> notify` only for opted-in templates
- templates without notification policy never plan `notify`
- unknown templates still fail closed

### Runner Tests

Add coverage proving:

- `log` runs after successful durable steps
- `notify` runs only when planned
- `notify` failure marks the run `completedWithIssues`
- `notify` failure does not roll back successful `rename`, `tag`, or `move`
- `log` failure does not roll back successful durable work

### Audit Tests

Add coverage proving:

- new run statuses round-trip through SwiftData
- new file dispositions round-trip through SwiftData
- step ordering and failure messages remain stable for `log` and `notify`

### Activity And Projection Tests

Add coverage proving:

- workflow activity emission is now runner-owned
- review, bulk, and automation entry points do not duplicate workflow summary logging
- inspector/run-detail projections show `completed with issues` correctly

### Automation Tests

Add coverage proving:

- trusted-scope runs suppress generic automation-summary notifications when workflow-native `notify` is planned
- trusted-scope runs keep generic automation-summary behavior when `notify` is not planned

## Rollout

This branch should stay behind the existing `workflowEngineV2` gate.

Recommended rollout posture:

- no separate user-facing flag for notify/log side effects
- fail closed when template policy or invocation context is missing
- keep notification coverage narrow by only enabling it for `Project Drop Zone` in the first shipped catalog

## Explicit Deferrals

The following items remain open after this branch:

- project-space-triggered workflow actions
- richer workflow-memory driven triggers
- notify delivery for review-surface ad hoc runs
- user-managed notification preferences per template or per scope
- external sinks beyond in-app activity and system notifications
- broader workflow chains beyond the current built-in template catalog
