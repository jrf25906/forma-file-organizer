# Project Space Automation Board V1 Design

Date: 2026-04-08
Branch: `codex/project-space-automation-board-v1`
Status: Draft for user review

## Summary

`project-space-automation-board-v1` should turn project spaces from retrieval and manual workflow surfaces into explicit automation owners.

This slice should ship:

- project-space-owned automation profiles keyed by normalized project label
- multiple constrained automation policies per project space
- one built-in workflow template assignment per policy
- realtime ingress, scheduled sweep, and saved manual-run triggers
- strong-inference admission for unlabeled files, with durable project-association writes before workflow execution
- explicit precedence between project-space policies and existing trusted rule, folder, and category scopes
- hybrid policy authoring through recommendations plus a constrained preset flow

This slice should not replace the existing trusted-scope system, introduce blank-canvas workflow authoring, or auto-enable project-space automation without user approval.

## Goals

- Make project spaces first-class automation owners rather than manual workflow-only entry points.
- Keep project-space membership metadata-derived and explainable while allowing narrow evidence-backed admission of unlabeled files.
- Reuse the shipped workflow-engine-v2 planner, runner, audit, and rollback path instead of inventing a parallel executor.
- Allow project intent to override generic automation boundaries only when the project claim is clearly stronger.
- Preserve Forma's preview-first posture by requiring evidence plus explicit user opt-in before background project automation runs.
- Give users one legible place to understand and manage automation behavior for a given project.

## Non-Goals

- No blank-canvas workflow builder or freeform step graph editor.
- No user-authored arbitrary rule language inside project spaces.
- No default-on or auto-enabled project-space autopilot.
- No cloud sync, collaboration, or shared project automation ownership.
- No replacement of `TrustedAutomationScope` as the durable owner of non-project automation.
- No speculative low-confidence project claiming in background automation.

## Options Considered

### Option A: Extend Trusted Scopes Into Project Scopes

Add a new project-space type to `TrustedAutomationScope` and store project automation directly on the existing trusted-scope ledger.

Benefits:

- minimal persistence expansion
- reuses current scope resolution and lifecycle infrastructure

Tradeoffs:

- poor fit for multiple policies per project space
- awkward for separate admission rules, trigger bundles, and project-specific health
- turns the trusted-scope model into a catch-all instead of a clear boundary system

### Option B: Recommended Project-Owned Automation Board

Keep trusted scopes for rule, folder, and category automation. Add a separate project-space automation layer with one project profile and multiple child policies.

Benefits:

- matches the desired product boundary without rewriting the existing automation stack
- lets project spaces own richer policy and trigger behavior while preserving metadata-derived membership
- keeps project automation legible in project-space detail instead of burying it inside global settings

Tradeoffs:

- adds new persistence and resolver layers
- requires explicit precedence logic between project policies and trusted scopes

### Option C: Replace Everything With One Generic Automation Policy Engine

Collapse trusted scopes and project automation into a single generic automation policy model.

Benefits:

- strongest long-term theoretical abstraction

Tradeoffs:

- too large for the next branch
- shifts the work toward infrastructure replacement instead of user-visible product value
- increases migration and regression risk across already-shipped automation surfaces

## Recommended Approach

Proceed with Option B.

This branch should add a project-owned automation board on top of the current trusted-scope and workflow-engine-v2 foundations.

That gives Forma:

- project-specific automation ownership
- multiple policies per project
- project-aware precedence and admission behavior
- reuse of the existing workflow execution and audit path

without forcing a rewrite of the current automation model.

## Product Boundary

### What Ships

This slice should ship:

- one `ProjectSpaceAutomationProfile` per normalized project label
- multiple `ProjectSpaceAutomationPolicy` rows per project profile
- policy states such as `draft`, `recommended`, `active`, `paused`, and `revoked`
- project-space-owned triggers:
  - realtime ingress
  - scheduled sweeps
  - saved manual-run presets
- one built-in workflow template assignment per policy
- background automation for files already in the project space
- background automation for unlabeled files only when a strong project claim can be written first
- policy-level run summaries that complement workflow-native audit
- project-space detail as the primary automation authoring and management surface

### What Stays Later

The following remain intentionally deferred:

- blank-canvas policy authoring
- custom step composition
- user-defined workflow templates
- auto-enable behavior based on confidence alone
- cloud/shared project automation ownership
- broad manual metadata editing beyond the narrow admission and correction paths already in scope

## Architecture

This branch should add a dedicated project-automation slice without forking workflow execution away from the current v2 engine.

### Existing Foundations To Reuse

The branch should build on:

- `ProjectSpaceWorkflowProfile` as the current lightweight project workflow anchor
- `TrustedAutomationScope` and `TrustedAutomationScopeResolver` for non-project automation ownership
- `WorkflowExecutionClient`, `WorkflowRunner`, `WorkflowAuditStore`, and the built-in template catalog for execution and audit
- `FileMetadataFoundationService` as the source of truth for durable project association

### New Core Types

Recommended new types:

- `ProjectSpaceAutomationProfile`
- `ProjectSpaceAutomationPolicy`
- `ProjectSpaceAutomationRunRecord`
- `ProjectSpaceAutomationRecommendationService`
- `ProjectSpaceAdmissionResolver`
- `ProjectAutomationOwnershipResolver`
- `ProjectSpaceAutomationService`
- `ProjectSpaceAutomationCoordinator`

### Responsibility Boundaries

Recommended ownership split:

- `ProjectSpaceAutomationProfile`
  - owns project-level automation posture, aggregate health, and latest activity summary
- `ProjectSpaceAutomationPolicy`
  - owns one constrained admission rule, one trigger bundle, one workflow template assignment, rationale, and lifecycle state
- `ProjectSpaceAdmissionResolver`
  - determines whether a file is an existing project member, can be strongly admitted, or should remain outside background automation
- `ProjectAutomationOwnershipResolver`
  - compares the best project-policy claim against the best trusted-scope claim and returns the winner or no owner
- `ProjectSpaceAutomationCoordinator`
  - performs admission writes when needed, invokes workflow execution, and records project-policy summaries
- workflow engine
  - remains the only workflow mutator

This keeps the new branch focused on ownership, admission, and product surfaces rather than duplicating file-operation logic.

## Data Model

### ProjectSpaceAutomationProfile

Recommended fields:

- `normalizedProjectLabel`
- `displayNameSnapshot`
- `status`
- `healthSummary`
- `lastRunAt`
- `latestPolicyRunID`
- `createdAt`
- `updatedAt`

Responsibilities:

- act as the durable automation owner for one project space
- summarize whether the project currently has active or attention-worthy automation
- provide the root object that project-space detail can query and manage

### ProjectSpaceAutomationPolicy

Recommended fields:

- `id`
- `projectProfileLabel`
- `displayName`
- `status`
- `admissionMode`
- `triggerKinds`
- `manualRunPreset`
- `workflowTemplateID`
- `recommendationSource`
- `rationaleSummary`
- `evidenceSnapshot`
- `prioritySnapshot`
- `lastRunAt`
- `latestRunRecordID`
- `createdAt`
- `updatedAt`

Responsibilities:

- represent one constrained automation policy for a project
- bind one admission rule shape to one built-in workflow template
- preserve enough rationale and evidence context for UI and audit explanation

### ProjectSpaceAutomationRunRecord

Recommended fields:

- `policyID`
- `projectLabel`
- `triggerKind`
- `admissionOutcome`
- `status`
- `matchedCount`
- `admittedCount`
- `organizedCount`
- `heldCount`
- `failedCount`
- `summaryText`
- `exampleFileNames`
- `linkedWorkflowRunID`
- `startedAt`
- `endedAt`

Responsibilities:

- provide the policy-owned summary ledger
- answer why a project policy acted even when workflow-native audit stores the lower-level step details
- let project-space detail show recent project-policy outcomes without reconstructing them from workflow rows alone

## Membership, Admission, and Precedence

### Membership Source Of Truth

Project-space membership should stay metadata-derived:

- `FileMetadataRecord.projectAssociation` remains the durable source of truth
- project-space retrieval continues to flow through `FileMetadataFoundationService`
- project automation must not create a second independent membership system

### Admission Tiers

The branch should use three admission outcomes:

- `existingMember`
  - the file already has a durable `projectAssociation` matching the project
- `strongConfirmed`
  - the file is unlabeled, but the project claim is strong enough to write before automation
- `insufficient`
  - evidence is weak, generic, or conflicting, so the file stays preview-first

### Strong-Confirmation Rule

`strongConfirmed` should require multiple aligned signals, not just one generic destination hint.

Representative inputs may include:

- dominant recent project destination memory
- stable project-label consistency across nearby related files
- strong project-specific metadata or naming patterns already seen in the project's accepted history

Background automation must fail closed unless the resolver can explain the project claim clearly.

### Precedence Rules

Project automation should be able to beat existing trusted scopes, but only through stronger project intent.

Recommended rules:

- `existingMember` project claims beat generic folder and category scopes
- `strongConfirmed` project claims may beat generic trusted scopes only when the project claim is clearly stronger and unambiguous
- ambiguous project claims never win; the file stays in preview-first review
- if the project claim is weaker than an existing trusted-scope claim, the existing trusted scope wins

This matches the intended posture:

- project intent can override generic automation
- but only when Forma can make a real project claim, not when it is merely guessing

### Admission Write Requirement

If a policy wins through `strongConfirmed`:

- `FileMetadataFoundationService` must write the durable `projectAssociation` first
- the metadata history must record the admission event explicitly
- workflow execution for that file must not begin if the admission write fails

## Trigger Model

This branch should keep project-space automation inside the current automation engine path while expanding trigger ownership.

### Policy Trigger Kinds

Each policy may opt into any subset of:

- `realtimeIngress`
- `scheduledSweep`
- `manualRunPreset`

The workflow template remains single-select per policy even when multiple triggers are enabled.

### Invocation Context Expansion

`WorkflowInvocationContext` should gain project-policy-specific cases rather than overloading the current generic project-space case.

Recommended additions:

- `projectPolicyManual(projectLabel: String, policyName: String)`
- `projectPolicyScheduled(projectLabel: String, policyName: String)`
- `projectPolicyRealtime(projectLabel: String, policyName: String)`

Responsibilities:

- keep activity labeling precise
- drive notify/log eligibility honestly
- distinguish manual project runs from background project automation

### Manual Run Presets

Manual runs should stay constrained and preset-driven. Representative presets:

- all current members
- recent arrivals
- items needing review
- strongly admitted unlabeled candidates

This preserves a project-owned execution surface without introducing arbitrary query building in v1.

### Background Trigger Safety

Strong-inference admission may run on realtime and scheduled triggers, but only at the higher background threshold.

Near-threshold candidates may still appear in manual preview, but background automation should fail closed.

## Authoring And UI Surfaces

This branch should use hybrid policy authoring with constrained presets.

### Creation Paths

Two creation paths should ship:

- recommendation-driven creation from project evidence
- direct creation through a constrained preset flow

The direct creation flow should remain limited to:

- intake shape
- built-in workflow template
- trigger set
- admission scope

No freeform condition builder should ship in this slice.

### Recommended Policy Presets

Representative preset directions:

- new files for this project
- screenshots for this project
- documents into project archive
- receipts or invoices for this project
- recent unlabeled files with strong project evidence

### Primary UI Surfaces

`ProjectSpaceDetailView` should become the main project automation surface.

Recommended additions:

- an `Automation` section
- grouped policy lists for active, paused, revoked, and recommended policies
- project-level health and attention summary
- recent policy-run summaries
- `Run Now` and `New Automation` entry points

### Policy Detail Sheet

Each policy should have a focused detail view that explains:

- what files it admits
- which triggers are enabled
- which built-in workflow template it runs
- why Forma recommended it or how it was configured
- recent run outcomes and admission examples

### Role Of Other Surfaces

- Default panel
  - should expose concise project-owned automation summaries
  - should not become the full project automation authoring home
- Settings
  - should remain the global automation posture surface
  - may expose debugging and high-level management, but not replace project-space detail as the primary project automation surface

## Execution Flow

Recommended end-to-end flow:

1. scan or manual run produces candidate files
2. existing prediction and project-memory signals are evaluated
3. `TrustedAutomationScopeResolver` finds the best non-project trusted-scope claim
4. `ProjectSpaceAdmissionResolver` and `ProjectAutomationOwnershipResolver` evaluate project-policy claims
5. if no owner wins cleanly, the file remains in preview-first review
6. if a project policy wins through `strongConfirmed`, the project association is written first
7. the selected built-in workflow template is planned and executed through the existing v2 workflow path
8. workflow-native audit persists run, step, and file details
9. project-policy summary audit persists the policy-owned explanation and linkage

This keeps execution unified while giving project automation its own ownership and explanation layer.

## Safety And Verification

This branch should fail closed more aggressively than the current manual project-space workflow slice.

### Failure Rules

- below-threshold project admission means no background automation
- ambiguous precedence means no automatic owner
- missing or invalid policy template means the policy records a held run rather than silently falling back
- failed project-association write blocks workflow execution for that file
- stale or broken project policies degrade to an attention state instead of continuing quietly

### Testing Layers

Recommended test coverage:

- unit tests for `ProjectSpaceAdmissionResolver`
  - existing member
  - strong confirmed
  - conflicting evidence
  - below-threshold rejection
- unit tests for `ProjectAutomationOwnershipResolver`
  - project policy beats generic trusted scope when stronger
  - trusted scope wins when project evidence is weaker
  - ambiguity falls back to no automatic owner
- service tests for project-policy CRUD and lifecycle
- integration tests through `AutomationEngine`
  - realtime trigger
  - scheduled trigger
  - manual preset execution
  - admission write before workflow execution
- workflow and audit tests
  - project-policy invocation context labeling
  - policy-run summary linkage to workflow run detail
- UI snapshot and state tests for project-space automation surfaces

### Feature Gating

The branch should be gated behind a dedicated project-space automation feature flag at the app entry point.

Recommended dependency posture:

- requires project spaces
- requires project-space memory
- requires metadata foundation
- requires workflow-engine-v2
- requires existing automation/trusted-scope foundations where the shared engine path depends on them

## Roadmap Fit

This branch intentionally continues the repo's current roadmap posture:

- preview-first remains the default
- automation is still earned and explicitly enabled
- project spaces deepen Forma's workflow lock-in and retrieval moat
- broader automation grows out of project memory rather than generic AI expansion

This is the right next branch because it productizes the project-memory and workflow foundations that are already shipped, while still holding the line against default-on autopilot and blank-canvas automation authoring.
