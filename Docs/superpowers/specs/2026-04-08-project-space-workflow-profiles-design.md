# Project Space Workflow Profiles Design

Date: 2026-04-08
Branch: `codex/workflow-engine-v2-notify-log`
Status: Draft for user review

## Summary

Forma should make project spaces a real workflow entry point without jumping all the way to project-space-owned background automation.

The next slice should:

- add a manual `Organize Project Space` action to project-space detail
- remember a preferred built-in workflow template per project space
- reuse the existing workflow engine, planner, runner, simulation, and audit path
- expand workflow invocation context so activity labels are explicit for project space, inspector, bulk, review, and trusted-scope surfaces
- keep project spaces manual-only for now

This slice should not introduce scheduled or realtime project-space automation, project-space trust controls, or a new durable project-space entity.

## Goals

- Let a project space run workflow-engine-v2 manually from its detail view.
- Give each project space lightweight workflow-owned state without making project space membership itself durable outside the metadata layer.
- Fix the current coarse workflow activity labels by making invocation context precise enough for the runner to log the correct surface directly.
- Reuse the existing workflow template picker and simulation model instead of inventing a project-space-specific workflow engine.
- Start from a foundation that can grow into project-space-owned automation later without committing to that behavior in this branch.

## Non-Goals

- No scheduled or realtime project-space-triggered automation.
- No project-space pause/resume/revoke controls.
- No project-space-specific notification rules beyond whatever the existing workflow template and invocation context already allow.
- No manual file subset picker inside project-space detail for this first execution slice.
- No new durable first-class `ProjectSpace` entity with independent membership persistence.
- No broad workflow authoring or user-defined templates.

## Options Considered

### Option A: Stateless Manual Project-Space Run

Add `Organize Project Space`, require explicit template choice every time, and run the current reachable members through the existing workflow engine.

Benefits:

- smallest implementation
- lowest persistence surface area
- easy to validate

Tradeoffs:

- likely redoes work when project spaces later need owned workflow state
- does not give project spaces a durable workflow identity beyond the immediate button press
- leaves the roadmap path toward project-space automation under-modeled

### Option B: Recommended Lightweight Project-Space Workflow Profile

Add a small durable workflow profile keyed by normalized project label, keep project-space membership derived from metadata, and keep execution manual-only.

Benefits:

- gives project spaces owned workflow state without promoting them into full automation subjects yet
- creates a natural place to remember preferred template and latest run linkage
- keeps the manual-first trust posture while moving the model closer to eventual project-space automation
- lets workflow audit and UI start treating project space as a first-class workflow surface

Tradeoffs:

- adds one new persistence model and service layer
- still requires a later step if project spaces become background automation owners

### Option C: Full Project-Space Automation Owner

Let project spaces own preferred template, background automation policy, and trigger behavior immediately.

Benefits:

- closest to the long-term destination
- strongest roadmap headline

Tradeoffs:

- project spaces are still derived from metadata labels and reachable files, so background automation semantics would be premature
- increases product risk around trust, scope drift, and notification behavior
- materially broadens the branch beyond the manual workflow entry point we need first

## Recommended Approach

Proceed with Option B.

Ship a lightweight `ProjectSpaceWorkflowProfile` keyed by normalized project label, make project-space detail a manual workflow entry point, and expand workflow invocation context so workflow audit and activity surfaces log the exact trigger surface.

That gives Forma:

- a real project-space workflow surface now
- remembered template state now
- correct activity labels now
- a stable stepping stone toward project-space automation later

without crossing the trust boundary into background project-space automation yet.

## Product Boundary

### What Ships

This slice should ship:

- a primary `Organize Project Space` action in project-space detail
- remembered preferred built-in template per project space
- project-space-scoped workflow simulation preview
- project-space workflow execution for all currently reachable files in the selected project space
- precise workflow activity labels for:
  - dashboard review
  - review list
  - inspector
  - bulk organize
  - project space
  - scheduled trusted-scope run
  - live trusted-scope run
  - trusted-scope inspection/manual refresh
- refreshed project-space detail after workflow execution, including latest run projection

### What Stays Later

The following remain deferred:

- scheduled project-space automation
- realtime project-space automation
- project-space trust or autopilot controls
- per-project-space notification settings
- manual per-run subset selection inside project-space detail
- broad workflow-memory ownership beyond preferred template and latest run linkage
- durable first-class project-space entities independent of metadata-backed membership

## Architecture

This branch should treat project spaces as metadata-derived collections with a lightweight workflow overlay.

### Membership Source Of Truth

Project-space membership stays exactly where it is today:

- `FileMetadataRecord.projectAssociation` remains the durable source of truth
- `FileMetadataFoundationService.fetchProjectSpaceSummaries()` and `fetchProjectSpaceDetail(for:)` continue to derive project spaces from reachable metadata-backed files

The new workflow profile must not try to own or redefine membership.

### New Durable Profile

Add a small SwiftData model such as:

- `ProjectSpaceWorkflowProfile`
  - unique `normalizedProjectLabel`
  - `preferredWorkflowTemplateID`
  - `lastWorkflowRunID`
  - `lastWorkflowCompletedAt`
  - `updatedAt`

Responsibilities:

- remember the preferred built-in template for that project space
- keep a lightweight link to the latest workflow run for quick detail projection
- avoid becoming a second source of truth for membership, labels, or file state

The profile should be created lazily the first time a preferred template is saved or a project-space workflow run completes.

### Profile Service Layer

Add a narrow service such as `ProjectSpaceWorkflowProfileService` rather than burying workflow-profile writes inside the metadata foundation.

Responsibilities:

- fetch profile for a normalized project label
- upsert preferred template
- record latest run linkage after a successful or failed run finalizes
- expose a tiny read model for the dashboard VM

This keeps project-space workflow preferences decoupled from file metadata persistence.

### Invocation Context Expansion

Replace the current coarse `WorkflowInvocationContext` with explicit cases for each user-visible trigger surface. Recommended shape:

- `dashboardReview`
- `reviewList`
- `inspector`
- `bulkOrganize`
- `projectSpace(projectLabel: String)`
- `trustedScopeScheduled(scopeDisplayName: String?)`
- `trustedScopeRealtime(scopeDisplayName: String?)`
- `trustedScopeInspection(scopeDisplayName: String?)`

The context should answer three questions directly:

- what activity trigger surface label should be logged
- whether workflow-native notify is eligible on this run
- what display name, if any, should be passed into notification copy

This removes the current inference step in `LogWorkflowStepExecutor` and makes the runner the single source of truth for workflow activity labeling.

### Trigger-Surface Mapping

`ActivityItem.WorkflowTriggerSurface` should gain:

- `projectSpace`

and should continue to distinguish:

- `reviewFlow`
- `reviewView`
- `inspector`
- `bulkOrganize`
- `scheduledAutomationPass`
- `realtimeAutomationPass`
- `manualRefreshInspection`

The log step should read the trigger surface from invocation context directly instead of collapsing everything into `Review` or `Scheduled trusted scope`.

### Notification Eligibility

This slice should preserve the notify boundary introduced in the current workflow-engine-v2 follow-up:

- project-space runs are manual and never background trusted-scope runs
- project-space runs therefore do not plan workflow-native `notify`
- only scheduled or live trusted-scope contexts remain notify-eligible when the template opts in

That keeps the project-space entry point manual and quiet.

## Project-Space Execution Flow

### Template Selection

Project-space detail should use the remembered preferred template when available.

Behavior:

- if a project-space profile has a preferred template, preselect it
- if no profile exists or no template is remembered, require explicit template choice
- the user may change the template before any run
- when the user runs the workflow, persist the chosen template back to the project-space profile

### Candidate Files

The first slice should run the workflow against:

- all currently reachable files in the selected project space

This matches the current project-space membership model and avoids adding a second selection model inside detail.

The simulation preview should still distinguish:

- runnable files
- blocked files
- any zero-action or missing-destination cases already surfaced by the planner

### Execution

`DashboardViewModel` should own a project-space-specific workflow path that:

- resolves the selected project-space detail
- builds `FileItem` candidates for the current reachable members
- produces a project-space workflow simulation preview
- runs `WorkflowExecutionClient.plan(..., .projectSpace(...))`
- executes `WorkflowExecutionClient.run(...)`
- records the latest run linkage into the project-space workflow profile
- refreshes project-space detail after completion

The project-space action should reuse the current `WorkflowRunner` path rather than introducing any project-space-specific runner.

### Latest Run Projection

Project-space detail should surface the latest run using the profile's `lastWorkflowRunID`.

Recommended posture:

- `ProjectSpaceWorkflowProfile` stores the last run linkage
- `WorkflowAuditStore` gains the minimal read helper needed to fetch a run by ID, plus any related step/file data required for summary projection
- project-space detail renders a lightweight summary, not a brand-new audit surface

This keeps the profile lightweight while leaving workflow audit as the source of truth for run details.

## UI

### Project Space Detail

`ProjectSpaceDetailView` should gain a workflow section near the top of the detail view, above or alongside existing overview content.

The section should include:

- selected template summary
- template picker affordance
- simulation preview
- one primary `Organize Project Space` action
- latest run summary once a run exists

Tone:

- clearly manual
- clearly scoped to the current project space
- no autoplay, trust, or background language

### Disabled States

The primary action should be unavailable when:

- workflow-engine-v2 is disabled
- project-space detail has no current reachable files
- no built-in template is selected
- a project-space run is already in progress

The UI should explain the blocking reason in product language rather than silently hiding the control.

## Error Handling

- If the project-space detail becomes stale and no longer resolves, close or refresh the detail rather than attempting to run against a dead snapshot.
- If some project-space members are blocked, reuse existing workflow simulation and mixed-result handling rather than inventing project-space-specific error copy.
- If workflow execution fails after durable work succeeds, keep the existing `completedWithIssues` semantics and latest-run projection.
- If profile persistence fails after workflow completion, do not recast the workflow run itself as failed. Prefer a best-effort profile update with logging.

## Testing

The branch should add targeted coverage for:

- `ProjectSpaceWorkflowProfile` persistence and lazy creation
- preferred template recall for a selected project space
- project-space simulation preview built from current reachable members only
- project-space workflow execution reusing planner/runner with `.projectSpace(...)` invocation context
- latest-run linkage and project-space detail refresh after run completion
- distinct activity label mapping for all invocation contexts
- notify remaining unavailable for project-space manual runs
- project-space detail UI states for:
  - no template selected
  - template selected with preview
  - no reachable files
  - latest run available

## Migration And Rollout

- No membership migration is required because project spaces stay derived from existing metadata.
- `ProjectSpaceWorkflowProfile` rows should be created lazily.
- Existing project-space users should see no behavior change until they interact with the new workflow affordance.
- If the profile is absent, the product should degrade to explicit template choice rather than hiding the workflow feature.

## Why This Is The Right Starting Point

This approach starts in the direction of full project-space workflow ownership without taking on premature background automation semantics.

It gives us:

- a real project-space workflow surface
- durable project-space workflow preferences
- exact workflow activity labels
- a clean bridge into later project-space automation

while avoiding:

- trust ambiguities around background project-space runs
- new scope-management semantics before project spaces are ready
- a heavy first-class project-space entity that would outpace the current metadata-backed product model
