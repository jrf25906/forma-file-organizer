# Workflow Engine V2 Memory Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the shipped `workflow-engine-v2` slice so repeated workflow outcomes become durable project-space and trusted-automation memory instead of staying isolated audit facts.

**Architecture:** Keep the current planner, runner, audit, and request model intact. Add a narrow workflow-memory profile layer on top of existing project-space profile records, feed it only from completed shared workflow runs, then switch project recommendations and trusted-scope explanations to use that workflow evidence before older destination-only heuristics.

**Tech Stack:** Swift, SwiftData, SwiftUI, XCTest, existing workflow-engine-v2 services, project-space memory services, trusted automation services, `TemporaryDirectory` filesystem-safe tests

---

## Scope check

This branch is one subsystem: the next `workflow-engine-v2` memory slice. It touches workflow execution, project-space memory, trusted automation, and UI projections, but all of that serves one outcome: richer durable workflow memory.

Keep these out of scope:

- broad new metadata-editing surfaces
- another free-form metadata step family
- backup, sync, or cross-device portability
- new Finder, Spotlight, Shortcuts, or menu bar entry points
- collaboration or shared workflow templates
- AI-generated memory summaries

## File structure

### New files

- `Forma File OrganizingTests/ProjectSpaceAutomationRecommendationServiceTests.swift`
  Purpose: lock workflow-backed recommendation behavior in one focused test file if no direct coverage exists yet.

### Existing files to modify

- `Forma File Organizing/Models/ProjectSpaceWorkflowProfile.swift`
  Purpose: expand the persisted project workflow-memory shape beyond `preferredWorkflowTemplateID` and `lastWorkflowRunID`.
- `Forma File Organizing/Models/WorkflowAuditModels.swift`
  Purpose: expose any additional normalized run facts needed to derive stable workflow memory from durable audit.
- `Forma File Organizing/Models/WorkflowExecutionRequest.swift`
  Purpose: keep request context rich enough for memory attribution across project-policy, trusted-scope, and direct invocation callers.
- `Forma File Organizing/Models/ProjectSpaceModels.swift`
  Purpose: surface workflow-memory state to project-space summaries, detail views, and recommendation copy.
- `Forma File Organizing/Models/TrustedAutomationScope.swift`
  Purpose: store or project workflow-memory context needed to explain why a scope is trusted.
- `Forma File Organizing/Services/ProjectSpaceWorkflowProfileService.swift`
  Purpose: own workflow-memory persistence, derivation rules, and migration behavior.
- `Forma File Organizing/Services/WorkflowRunner.swift`
  Purpose: feed workflow-memory updates from real shared workflow outcomes in one place.
- `Forma File Organizing/Services/WorkflowAuditStore.swift`
  Purpose: persist any new normalized run facts needed for later workflow-memory reconstruction.
- `Forma File Organizing/Services/ProjectSpaceAutomationRecommendationService.swift`
  Purpose: prefer workflow-backed evidence over destination-only heuristics when recommending project automation.
- `Forma File Organizing/Services/ProjectSpaceMemoryResolver.swift`
  Purpose: expose workflow-backed memory alongside existing destination/history signals and preserve honest fallback behavior.
- `Forma File Organizing/Services/TrustedAutomationScopeService.swift`
  Purpose: align trusted-scope rationale and template assignment with richer workflow-memory state.
- `Forma File Organizing/Services/AutomationEngine.swift`
  Purpose: keep trusted-scope execution and hold reasons aligned with workflow-memory state.
- `Forma File Organizing/ViewModels/DashboardViewModel.swift`
  Purpose: project richer workflow-memory summaries into project-space UI and related workflow controls.
- `Forma File Organizing/Components/TrustedAutomationScopeDetailSheet.swift`
  Purpose: show stable, stale, and conflicted workflow-memory states honestly.
- `Forma File Organizing/Components/TrustedAutomationScopeRecommendationSheet.swift`
  Purpose: keep recommendation UI aligned with workflow-backed trust explanations.
- `Forma File OrganizingTests/ProjectSpaceWorkflowProfileServiceTests.swift`
- `Forma File OrganizingTests/WorkflowRunnerTests.swift`
- `Forma File OrganizingTests/WorkflowAuditStoreTests.swift`
- `Forma File OrganizingTests/ProjectSpaceMemoryResolverTests.swift`
- `Forma File OrganizingTests/DashboardViewModelTests.swift`
- `Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift`
- `Forma File OrganizingTests/TrustedAutomationScopeSnapshotTests.swift`
- `Forma File OrganizingTests/AutomationEngineTests.swift`
- `TODO.md`
- `CHANGELOG.md`
- `API_REFERENCE.md`

## Task 1: Expand the persisted workflow-memory profile model

**Files:**
- Create: `Forma File OrganizingTests/ProjectSpaceAutomationRecommendationServiceTests.swift` `if needed later`
- Modify: `Forma File Organizing/Models/ProjectSpaceWorkflowProfile.swift`
- Modify: `Forma File Organizing/Models/WorkflowAuditModels.swift`
- Modify: `Forma File Organizing/Services/ProjectSpaceWorkflowProfileService.swift`
- Test: `Forma File OrganizingTests/ProjectSpaceWorkflowProfileServiceTests.swift`
- Test: `Forma File OrganizingTests/WorkflowAuditStoreTests.swift`

- [ ] **Step 1: Write failing tests for richer workflow-memory profile fields**

Add tests shaped like:

```swift
func testProfileService_MigratesLegacyPreferredTemplateAndLatestRun() throws
func testProfileService_RepeatedSuccessfulRuns_StrengthenDominantTemplateMemory() throws
func testProfileService_ConflictingRecentRuns_MarkProfileConflicted() throws
```

Expect:
- legacy profile records still preserve `preferredWorkflowTemplateID` and latest-run semantics
- repeated successful runs build durable template/trigger/destination memory
- conflicting recent outcomes do not pretend certainty

- [ ] **Step 2: Run the profile tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceWorkflowProfileServiceTests" -only-testing:"Forma File OrganizingTests/WorkflowAuditStoreTests"
```

Expected: FAIL because the richer workflow-memory profile model does not exist yet.

- [ ] **Step 3: Add the narrowest persisted memory shape needed**

Implement profile fields for:
- successful template count/recency
- dominant trigger surface
- latest successful destination signal
- stable, stale, or conflicted memory status

Keep the model factual. Do not store speculative narrative summaries.

- [ ] **Step 4: Update the profile service to read and write the richer shape**

Implement migration-friendly logic so old data stays usable while new profiles gain richer workflow-memory fields. Keep one normalization path for template IDs, trigger surfaces, and destination signals.

- [ ] **Step 5: Re-run the profile tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Models/ProjectSpaceWorkflowProfile.swift" "Forma File Organizing/Models/WorkflowAuditModels.swift" "Forma File Organizing/Services/ProjectSpaceWorkflowProfileService.swift" "Forma File OrganizingTests/ProjectSpaceWorkflowProfileServiceTests.swift" "Forma File OrganizingTests/WorkflowAuditStoreTests.swift"
git commit -m "feat: add workflow memory profiles"
```

## Task 2: Feed workflow memory from shared workflow outcomes

**Files:**
- Modify: `Forma File Organizing/Models/WorkflowExecutionRequest.swift`
- Modify: `Forma File Organizing/Services/WorkflowRunner.swift`
- Modify: `Forma File Organizing/Services/WorkflowAuditStore.swift`
- Modify: `Forma File Organizing/Services/ProjectSpaceWorkflowProfileService.swift`
- Test: `Forma File OrganizingTests/WorkflowRunnerTests.swift`
- Test: `Forma File OrganizingTests/ProjectSpaceWorkflowProfileServiceTests.swift`

- [ ] **Step 1: Write failing tests for runner-driven memory updates**

Add tests shaped like:

```swift
func testRunner_ProjectWorkflowCompletion_UpdatesWorkflowMemoryProfileOncePerRun() async throws
func testRunner_BlockedWorkflow_DoesNotStrengthenWorkflowMemory() async throws
func testRunner_RolledBackWorkflow_RecordsConflictInsteadOfSuccess() async throws
```

Expect:
- one successful run updates memory once, even when multiple files share the project label
- blocked runs do not count as successful memory
- rolled-back or failed runs weaken or conflict memory rather than strengthening it

- [ ] **Step 2: Run the runner tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/WorkflowRunnerTests" -only-testing:"Forma File OrganizingTests/ProjectSpaceWorkflowProfileServiceTests"
```

Expected: FAIL because the shared runner does not currently feed richer workflow memory.

- [ ] **Step 3: Extend the request-to-memory attribution path**

Ensure the data needed for memory attribution is available after execution:
- template ID
- entry point / trigger surface
- owner identity where applicable
- destination signal when the run succeeds durably

Keep attribution request-driven so all callers share the same path.

- [ ] **Step 4: Update the runner to record workflow-memory outcomes**

After run completion:
- strengthen memory for successful durable runs
- ignore blocked preflight-only runs
- record stale or conflict signals for rollback and failure paths if that branch rule is adopted
- avoid per-file double counting within one project-labeled run

- [ ] **Step 5: Re-run the runner tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Models/WorkflowExecutionRequest.swift" "Forma File Organizing/Services/WorkflowRunner.swift" "Forma File Organizing/Services/WorkflowAuditStore.swift" "Forma File Organizing/Services/ProjectSpaceWorkflowProfileService.swift" "Forma File OrganizingTests/WorkflowRunnerTests.swift" "Forma File OrganizingTests/ProjectSpaceWorkflowProfileServiceTests.swift"
git commit -m "feat: feed workflow memory from runner outcomes"
```

## Task 3: Replace destination-only project recommendations with workflow-backed memory

**Files:**
- Create: `Forma File OrganizingTests/ProjectSpaceAutomationRecommendationServiceTests.swift`
- Modify: `Forma File Organizing/Models/ProjectSpaceModels.swift`
- Modify: `Forma File Organizing/Services/ProjectSpaceAutomationRecommendationService.swift`
- Modify: `Forma File Organizing/Services/ProjectSpaceMemoryResolver.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Test: `Forma File OrganizingTests/ProjectSpaceAutomationRecommendationServiceTests.swift`
- Test: `Forma File OrganizingTests/ProjectSpaceMemoryResolverTests.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`

- [ ] **Step 1: Write failing tests for workflow-backed recommendation behavior**

Add tests shaped like:

```swift
func testRecommendationService_PrefersRepeatedWorkflowTemplateEvidence() throws
func testMemoryResolver_FallsBackToDestinationDominanceWhenWorkflowMemoryMissing() throws
func testDashboardProjectSpaceSummary_ShowsConflictedWorkflowMemoryState() throws
```

Expect:
- project-space recommendations prefer repeated successful workflow evidence
- destination dominance remains only a fallback
- UI copy distinguishes stable, stale, and conflicted workflow memory

- [ ] **Step 2: Run the recommendation and projection tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceAutomationRecommendationServiceTests" -only-testing:"Forma File OrganizingTests/ProjectSpaceMemoryResolverTests" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests"
```

Expected: FAIL because project recommendations still depend primarily on destination-only heuristics.

- [ ] **Step 3: Replace dominant-destination-first recommendation rules**

Update `ProjectSpaceAutomationRecommendationService` so it:
- checks workflow-memory stability first
- recommends the proven template when memory is stable enough
- explains recommendation strength using success count, recency, and trigger pattern
- falls back to destination heuristics only when workflow memory is absent

- [ ] **Step 4: Project workflow-memory state into project-space UI**

Update the resolver and dashboard projection so project spaces can show:
- latest successful workflow template
- stable vs stale vs conflicted state
- honest fallback wording when only destination memory is available

- [ ] **Step 5: Re-run the recommendation and projection tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Models/ProjectSpaceModels.swift" "Forma File Organizing/Services/ProjectSpaceAutomationRecommendationService.swift" "Forma File Organizing/Services/ProjectSpaceMemoryResolver.swift" "Forma File Organizing/ViewModels/DashboardViewModel.swift" "Forma File OrganizingTests/ProjectSpaceAutomationRecommendationServiceTests.swift" "Forma File OrganizingTests/ProjectSpaceMemoryResolverTests.swift" "Forma File OrganizingTests/DashboardViewModelTests.swift"
git commit -m "feat: drive project recommendations from workflow memory"
```

## Task 4: Put trusted scopes on the same workflow-memory story

**Files:**
- Modify: `Forma File Organizing/Models/TrustedAutomationScope.swift`
- Modify: `Forma File Organizing/Services/TrustedAutomationScopeService.swift`
- Modify: `Forma File Organizing/Services/AutomationEngine.swift`
- Modify: `Forma File Organizing/Components/TrustedAutomationScopeDetailSheet.swift`
- Modify: `Forma File Organizing/Components/TrustedAutomationScopeRecommendationSheet.swift`
- Test: `Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift`
- Test: `Forma File OrganizingTests/TrustedAutomationScopeSnapshotTests.swift`
- Test: `Forma File OrganizingTests/AutomationEngineTests.swift`

- [ ] **Step 1: Write failing tests for trusted-scope workflow-memory explanations**

Add tests shaped like:

```swift
func testTrustedScopeService_PreservesStableWorkflowMemoryContext() throws
func testTrustedScopeService_ConflictedWorkflowMemoryDoesNotOverstateTrust() throws
func testTrustedScopeSnapshot_RendersStableAndConflictedWorkflowMemoryCopy() throws
```

Expect:
- trusted scopes can explain recent successful workflow-backed trust
- conflicted memory weakens explanation instead of hiding the problem
- automation execution and hold messaging stay aligned with that same state

- [ ] **Step 2: Run the trusted-scope tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeServiceTests" -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeSnapshotTests" -only-testing:"Forma File OrganizingTests/AutomationEngineTests"
```

Expected: FAIL because trusted scopes do not yet carry workflow-memory state.

- [ ] **Step 3: Add workflow-memory context to trusted scopes and services**

Implement only the branch-approved data needed to explain trust:
- recent successful template
- recency/count summary inputs
- stale/conflicted status

Do not silently auto-promote ambiguous scopes because memory exists.

- [ ] **Step 4: Project the same memory story into UI and automation holds**

Update detail/recommendation sheets and automation messaging so they all use the same workflow-memory state definitions and do not drift in wording.

- [ ] **Step 5: Re-run the trusted-scope tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Models/TrustedAutomationScope.swift" "Forma File Organizing/Services/TrustedAutomationScopeService.swift" "Forma File Organizing/Services/AutomationEngine.swift" "Forma File Organizing/Components/TrustedAutomationScopeDetailSheet.swift" "Forma File Organizing/Components/TrustedAutomationScopeRecommendationSheet.swift" "Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift" "Forma File OrganizingTests/TrustedAutomationScopeSnapshotTests.swift" "Forma File OrganizingTests/AutomationEngineTests.swift"
git commit -m "feat: align trusted scopes with workflow memory"
```

## Task 5: Sync docs and run full no-UI verification

**Files:**
- Modify: `TODO.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`

- [ ] **Step 1: Update roadmap and changelog language**

Document that this branch ships workflow-memory profiles and workflow-backed recommendation/trust projections, rather than another raw metadata field.

- [ ] **Step 2: Update API/reference docs**

Document:
- new `ProjectSpaceWorkflowProfile` fields
- any new workflow-memory status enum or payload shape
- recommendation semantics and fallback rules
- trusted-scope workflow-memory projection fields if they are persisted or exposed

- [ ] **Step 3: Run focused regression coverage**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceWorkflowProfileServiceTests" -only-testing:"Forma File OrganizingTests/WorkflowRunnerTests" -only-testing:"Forma File OrganizingTests/WorkflowAuditStoreTests" -only-testing:"Forma File OrganizingTests/ProjectSpaceAutomationRecommendationServiceTests" -only-testing:"Forma File OrganizingTests/ProjectSpaceMemoryResolverTests" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests" -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeServiceTests" -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeSnapshotTests" -only-testing:"Forma File OrganizingTests/AutomationEngineTests"
```

Expected: PASS

- [ ] **Step 4: Run full no-UI verification**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "TODO.md" "CHANGELOG.md" "API_REFERENCE.md"
git commit -m "docs: sync workflow memory profile roadmap"
```

## Notes for the implementing agent

- Use a dedicated git worktree before starting implementation.
- Respect `FeatureFlagService.shared.isEnabled(...)` gates at workflow-memory entry points if new surfaced behavior is behind existing flags.
- Preserve preview-first trust semantics: memory should explain or recommend workflows, not silently widen automation.
- When touching file-operation services, preserve rollback and audit honesty and add integration coverage where behavior depends on durable file state.
