# Project Space Automation Board V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn project spaces into explicit automation owners with multiple constrained policies, strong-inference admission for unlabeled files, and shared execution through the existing workflow-engine-v2 path.

**Architecture:** Keep project-space membership metadata-derived and add a new project-owned automation layer on top of the shipped project-space, trusted-scope, and workflow-engine-v2 foundations. Persist project profiles, policies, and policy-run summaries in SwiftData; use pure admission and ownership resolvers to decide when project policies beat generic trusted scopes; then route winning runs through the existing workflow planner/runner, with Dashboard/default-panel project-space detail becoming the main authoring and management surface.

**Tech Stack:** Swift, SwiftData, SwiftUI, XCTest, macOS app services, security-scoped bookmarks, existing workflow-engine-v2 services, `TemporaryDirectory` filesystem-safe tests

---

## Scope check

This branch touches persistence, ownership resolution, automation execution, activity/notification projection, and project-space UI, but it is still one cohesive subsystem: project-space-owned automation. Keep it as one implementation plan with staged milestones.

Do not fold these unrelated branches into this plan:

- generic workflow-builder authoring
- trusted-scope refactors unrelated to project precedence
- cloud sync or collaboration
- broader metadata editing outside narrow admission/correction flows

## File structure

### New files

- `Forma File Organizing/Models/ProjectSpaceAutomationProfile.swift`
  Purpose: SwiftData model for one project-space automation owner plus profile-level lifecycle/health fields.
- `Forma File Organizing/Models/ProjectSpaceAutomationPolicy.swift`
  Purpose: SwiftData model for one constrained project-space policy, including template assignment, triggers, admission mode, and rationale.
- `Forma File Organizing/Models/ProjectSpaceAutomationRunRecord.swift`
  Purpose: SwiftData model for policy-owned run summaries linked to workflow-native audit rows.
- `Forma File Organizing/Models/ProjectSpaceAutomationPresentationModels.swift`
  Purpose: small `Sendable` read models for grouped policy sections, policy detail snapshots, recommendation cards, and ownership decisions.
- `Forma File Organizing/Services/ProjectSpaceAutomationService.swift`
  Purpose: fetch/create/update project automation profiles and policies, including bootstrap from legacy `ProjectSpaceWorkflowProfile`.
- `Forma File Organizing/Services/ProjectSpaceAutomationRecommendationService.swift`
  Purpose: derive recommended project policies from existing project-space memory and recent workflow history.
- `Forma File Organizing/Services/ProjectSpaceAdmissionResolver.swift`
  Purpose: pure logic for `existingMember` vs `strongConfirmed` vs `insufficient` project admission decisions.
- `Forma File Organizing/Services/ProjectAutomationOwnershipResolver.swift`
  Purpose: pure precedence logic that compares project-policy claims against existing trusted-scope matches.
- `Forma File Organizing/Services/ProjectSpaceAutomationCoordinator.swift`
  Purpose: orchestrate admission writes, workflow invocation, and project-policy run-summary persistence.
- `Forma File Organizing/Components/ProjectSpaceAutomationSection.swift`
  Purpose: focused project-space detail section for grouped policies, health, run-now affordances, and recommendation cards.
- `Forma File Organizing/Components/ProjectSpaceAutomationPolicySheet.swift`
  Purpose: policy detail sheet showing triggers, admission behavior, template, and recent run context.
- `Forma File Organizing/Components/ProjectSpaceAutomationComposerSheet.swift`
  Purpose: constrained preset flow for creating or editing one project-space policy.
- `Forma File OrganizingTests/ProjectSpaceAutomationServiceTests.swift`
  Purpose: RED/GREEN coverage for profile/policy lifecycle, legacy bootstrap, and migration-safe persistence.
- `Forma File OrganizingTests/ProjectSpaceAdmissionResolverTests.swift`
  Purpose: focused resolver tests for admission thresholds and conflict handling.
- `Forma File OrganizingTests/ProjectAutomationOwnershipResolverTests.swift`
  Purpose: focused resolver tests for precedence between project policies and trusted scopes.
- `Forma File OrganizingTests/ProjectSpaceAutomationCoordinatorTests.swift`
  Purpose: coordinator-level tests for admission-write-before-workflow and run summary persistence.

### Existing files to modify

- `Forma File Organizing/Forma_File_OrganizingApp.swift`
  Purpose: register new SwiftData models in the schema.
- `Forma File Organizing/Services/FeatureFlagService.swift`
  Purpose: add a dedicated project-space automation feature gate and dependencies.
- `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`
  Purpose: expose the feature gate in Smart Features like the other metadata/workflow slices.
- `Forma File Organizing/Services/ProjectSpaceWorkflowProfileService.swift`
  Purpose: preserve current manual project-space workflow state and expose any narrow bridge helpers needed for bootstrap.
- `Forma File Organizing/Services/FileMetadataFoundationService.swift`
  Purpose: add the narrow project-admission write API and append explicit metadata history rows.
- `Forma File Organizing/Models/WorkflowInvocationContext.swift`
  Purpose: add project-policy-specific invocation contexts for manual, scheduled, and realtime triggers.
- `Forma File Organizing/Models/ActivityItem.swift`
  Purpose: add workflow trigger-surface labels for project-policy runs.
- `Forma File Organizing/Services/ActivityLoggingService.swift`
  Purpose: log project-policy workflow activity with distinct trigger labels.
- `Forma File Organizing/Services/NotificationService.swift`
  Purpose: support project-policy-friendly workflow completion copy where background project automation is notify-eligible.
- `Forma File Organizing/Services/LogWorkflowStepExecutor.swift`
  Purpose: keep trigger-surface logging aligned with the new invocation contexts.
- `Forma File Organizing/Services/NotifyWorkflowStepExecutor.swift`
  Purpose: make notify eligibility honest for project-policy manual vs background runs.
- `Forma File Organizing/Services/AutomationEngine.swift`
  Purpose: ask the project ownership resolver for project-policy winners and execute them through the shared workflow path.
- `Forma File Organizing/Models/ProjectSpaceModels.swift`
  Purpose: extend project-space detail read models with automation summaries and grouped policy snapshots.
- `Forma File Organizing/ViewModels/DashboardViewModel.swift`
  Purpose: replace single-template project-space workflow state with policy-centered project automation state and management actions.
- `Forma File Organizing/Views/ProjectSpaceDetailView.swift`
  Purpose: render the new automation board in project-space detail.
- `Forma File Organizing/Views/DefaultPanelView.swift`
  Purpose: host automation section state, composer sheets, and policy detail presentation.
- `Forma File Organizing/Components/ProjectSpacesSection.swift`
  Purpose: optionally surface concise automation status per project row if the UI needs a lightweight summary.
- `Forma File Organizing/Components/WorkflowTemplatePicker.swift`
  Purpose: reuse the shipped built-in template picker inside the constrained policy composer.
- `Forma File OrganizingTests/ProjectSpaceWorkflowProfileServiceTests.swift`
  Purpose: verify legacy manual template state remains intact while bootstrap helpers read it.
- `Forma File OrganizingTests/FileMetadataFoundationServiceTests.swift`
  Purpose: admission-write history coverage.
- `Forma File OrganizingTests/FileMetadataFoundationIntegrationTests.swift`
  Purpose: admission-refresh coverage for metadata-backed project-space membership.
- `Forma File OrganizingTests/AutomationEngineTests.swift`
  Purpose: project-policy owner selection and execution-path coverage.
- `Forma File OrganizingTests/AutomationEngineNotificationTests.swift`
  Purpose: notify eligibility and copy assertions for project-policy background runs.
- `Forma File OrganizingTests/WorkflowActivityProjectionTests.swift`
  Purpose: trigger-surface label coverage for project-policy activity projection.
- `Forma File OrganizingTests/DashboardViewModelTests.swift`
  Purpose: project-space automation state, creation, lifecycle, and manual-run behavior coverage.
- `Forma File OrganizingTests/ProjectSpaceSnapshotTests.swift`
  Purpose: project-space automation board snapshot coverage.
- `TODO.md`
- `CHANGELOG.md`
- `API_REFERENCE.md`
- `Docs/Getting-Started/TODO.md`

## Task 1: Add the project-space automation models, feature gate, and legacy bootstrap service

**Files:**
- Create: `Forma File Organizing/Models/ProjectSpaceAutomationProfile.swift`
- Create: `Forma File Organizing/Models/ProjectSpaceAutomationPolicy.swift`
- Create: `Forma File Organizing/Models/ProjectSpaceAutomationRunRecord.swift`
- Create: `Forma File Organizing/Models/ProjectSpaceAutomationPresentationModels.swift`
- Create: `Forma File Organizing/Services/ProjectSpaceAutomationService.swift`
- Create: `Forma File OrganizingTests/ProjectSpaceAutomationServiceTests.swift`
- Modify: `Forma File Organizing/Forma_File_OrganizingApp.swift`
- Modify: `Forma File Organizing/Services/FeatureFlagService.swift`
- Modify: `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`
- Modify: `Forma File Organizing/Services/ProjectSpaceWorkflowProfileService.swift`
- Test: `Forma File OrganizingTests/ProjectSpaceWorkflowProfileServiceTests.swift`

- [ ] **Step 1: Write failing service tests for profile and policy persistence**

Add focused tests shaped like:

```swift
func testProfileFetch_BootstrapsRecommendedPolicyFromLegacyWorkflowProfile() throws
func testCreatePolicy_PersistsTemplateTriggersAndAdmissionMode() throws
func testPauseAndRevokePolicy_UpdateLifecycleWithoutDeletingRunHistory() throws
func testProjectSpaceAutomationFeatureDependsOnProjectMemoryWorkflowAndAutomationFlags()
```

Expect:
- a legacy `ProjectSpaceWorkflowProfile` with a preferred template produces one bootstrap project policy instead of losing state
- policy trigger kinds persist as normalized values
- revoking a policy preserves historical rows
- the new feature flag fails closed when dependencies are off

- [ ] **Step 2: Run the new service tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceAutomationServiceTests"
```

Expected: FAIL because the project-space automation models and service do not exist yet.

- [ ] **Step 3: Add the smallest persistence model layer**

Create the new model files with focused enums and fields only.

Start with shapes like:

```swift
@Model
final class ProjectSpaceAutomationProfile { ... }

@Model
final class ProjectSpaceAutomationPolicy { ... }

@Model
final class ProjectSpaceAutomationRunRecord { ... }
```

Keep raw-value persistence patterns consistent with `TrustedAutomationScope` and `ActivityItem`.

- [ ] **Step 4: Register the models and add the feature flag**

In `Forma_File_OrganizingApp.swift`, add the new models to the SwiftData schema.

In `FeatureFlagService.Feature`, add:

```swift
case projectSpaceAutomationBoard = "feature.projectSpaceAutomationBoard"
```

Set:
- default value `false`
- display name `Project space automation board`
- dependencies on `.metadataFoundation`, `.projectSpaces`, `.projectSpaceMemory`, `.workflowEngineV2`, `.backgroundMonitoring`, and `.autoOrganize`

Expose it in `SmartFeaturesSection.swift`.

- [ ] **Step 5: Implement `ProjectSpaceAutomationService` with legacy bootstrap**

Implement service methods shaped like:

```swift
func profile(normalizedProjectLabel: String) -> ProjectSpaceAutomationProfile?
func createOrUpdatePolicy(...)
func pausePolicy(...)
func revokePolicy(...)
func bootstrapFromLegacyWorkflowProfileIfNeeded(...)
```

Constraints:
- do not delete `ProjectSpaceWorkflowProfile` in this task
- keep bootstrap idempotent
- preserve the old manual workflow state until the new UI cutover is complete

- [ ] **Step 6: Re-run the persistence tests and verify GREEN**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceAutomationServiceTests" -only-testing:"Forma File OrganizingTests/ProjectSpaceWorkflowProfileServiceTests"
```

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add "Forma File Organizing/Models/ProjectSpaceAutomationProfile.swift" "Forma File Organizing/Models/ProjectSpaceAutomationPolicy.swift" "Forma File Organizing/Models/ProjectSpaceAutomationRunRecord.swift" "Forma File Organizing/Models/ProjectSpaceAutomationPresentationModels.swift" "Forma File Organizing/Services/ProjectSpaceAutomationService.swift" "Forma File Organizing/Forma_File_OrganizingApp.swift" "Forma File Organizing/Services/FeatureFlagService.swift" "Forma File Organizing/Views/Settings/SmartFeaturesSection.swift" "Forma File Organizing/Services/ProjectSpaceWorkflowProfileService.swift" "Forma File OrganizingTests/ProjectSpaceAutomationServiceTests.swift" "Forma File OrganizingTests/ProjectSpaceWorkflowProfileServiceTests.swift"
git commit -m "feat: add project-space automation persistence scaffolding"
```

## Task 2: Add pure admission and ownership resolvers

**Files:**
- Create: `Forma File Organizing/Services/ProjectSpaceAdmissionResolver.swift`
- Create: `Forma File Organizing/Services/ProjectAutomationOwnershipResolver.swift`
- Test: `Forma File OrganizingTests/ProjectSpaceAdmissionResolverTests.swift`
- Test: `Forma File OrganizingTests/ProjectAutomationOwnershipResolverTests.swift`
- Modify: `Forma File Organizing/Models/ProjectSpaceAutomationPresentationModels.swift`

- [ ] **Step 1: Write failing resolver tests for admission thresholds**

Add tests shaped like:

```swift
func testResolveAdmission_ReturnsExistingMemberForMatchingProjectAssociation()
func testResolveAdmission_ReturnsStrongConfirmedForAlignedDominantSignals()
func testResolveAdmission_ReturnsInsufficientForConflictingSignals()
```

Expect:
- only clearly aligned evidence produces `strongConfirmed`
- generic destination hints alone are not enough
- background automation fails closed when signals conflict

- [ ] **Step 2: Write failing resolver tests for precedence**

Add tests shaped like:

```swift
func testResolveOwner_ProjectPolicyExistingMemberBeatsGenericCategoryScope()
func testResolveOwner_TrustedScopeWinsWhenProjectClaimIsWeaker()
func testResolveOwner_AmbiguousProjectClaimReturnsNoAutomaticOwner()
```

Use small fake project-policy and trusted-scope read models rather than spinning up full SwiftData containers.

- [ ] **Step 3: Run the resolver tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceAdmissionResolverTests" -only-testing:"Forma File OrganizingTests/ProjectAutomationOwnershipResolverTests"
```

Expected: FAIL because the new resolvers do not exist yet.

- [ ] **Step 4: Implement `ProjectSpaceAdmissionResolver`**

Add a pure API shaped like:

```swift
func resolveAdmission(...) -> ProjectSpaceAdmissionDecision
```

Return explicit outcomes:
- `existingMember`
- `strongConfirmed`
- `insufficient`

Keep the evidence snapshot small and serializable so the decision can later be surfaced in UI and run logs.

- [ ] **Step 5: Implement `ProjectAutomationOwnershipResolver`**

Add a pure API shaped like:

```swift
func resolveOwner(
    projectDecision: ProjectSpaceAdmissionDecision?,
    trustedScope: TrustedAutomationScope?
) -> ProjectAutomationOwnerDecision
```

Keep precedence logic deterministic and document tie-break order in code comments once, not across multiple callers.

- [ ] **Step 6: Re-run the resolver tests and verify GREEN**

Run the command from Step 3.

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add "Forma File Organizing/Services/ProjectSpaceAdmissionResolver.swift" "Forma File Organizing/Services/ProjectAutomationOwnershipResolver.swift" "Forma File Organizing/Models/ProjectSpaceAutomationPresentationModels.swift" "Forma File OrganizingTests/ProjectSpaceAdmissionResolverTests.swift" "Forma File OrganizingTests/ProjectAutomationOwnershipResolverTests.swift"
git commit -m "feat: add project-space admission and ownership resolvers"
```

## Task 3: Add recommendation, admission-write, and coordinator infrastructure

**Files:**
- Create: `Forma File Organizing/Services/ProjectSpaceAutomationRecommendationService.swift`
- Create: `Forma File Organizing/Services/ProjectSpaceAutomationCoordinator.swift`
- Test: `Forma File OrganizingTests/ProjectSpaceAutomationCoordinatorTests.swift`
- Modify: `Forma File Organizing/Services/ProjectSpaceAutomationService.swift`
- Modify: `Forma File Organizing/Services/FileMetadataFoundationService.swift`
- Test: `Forma File OrganizingTests/FileMetadataFoundationServiceTests.swift`
- Test: `Forma File OrganizingTests/FileMetadataFoundationIntegrationTests.swift`

- [ ] **Step 1: Write failing tests for recommendation generation**

Add tests shaped like:

```swift
func testRecommendations_DeriveProjectPoliciesFromDominantProjectMemory()
func testRecommendations_DoNotCreatePoliciesWhenEvidenceIsTooWeak()
```

Expect recommendation candidates to come from project memory and recent workflow history, not from generic file-type heuristics alone.

- [ ] **Step 2: Write failing coordinator tests for admission writes**

Add tests shaped like:

```swift
func testExecutePolicy_StrongConfirmedAdmissionWritesProjectAssociationBeforeWorkflowRun() throws
func testExecutePolicy_FailedAdmissionWritePreventsWorkflowExecution() throws
func testExecutePolicy_PersistsPolicyRunSummaryLinkedToWorkflowRun() throws
```

Use a workflow spy like the existing `AutomationEngineTests` pattern and filesystem-safe temp roots from `TemporaryDirectory`.

- [ ] **Step 3: Run the new service and coordinator tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceAutomationCoordinatorTests" -only-testing:"Forma File OrganizingTests/FileMetadataFoundationServiceTests"
```

Expected: FAIL because recommendation generation, admission-write APIs, and the coordinator do not exist yet.

- [ ] **Step 4: Implement the narrow metadata admission API**

In `FileMetadataFoundationService.swift`, add a write path shaped like:

```swift
func admitToProjectSpace(
    canonicalIdentity: String,
    projectLabel: String,
    detailsSummary: String,
    timestamp: Date
) throws
```

Constraints:
- normalize the project label
- append an explicit history row
- no-op safely for already-matching labels
- never bypass the existing metadata foundation

- [ ] **Step 5: Implement recommendation and coordinator services**

Implement:

```swift
func recommendedPolicies(for detail: ProjectSpaceDetail, now: Date) -> [ProjectSpaceAutomationRecommendation]
func executePolicy(...) async throws -> ProjectSpaceAutomationRunRecord
```

The coordinator must:
- call the admission resolver
- write `projectAssociation` first when `strongConfirmed`
- invoke `WorkflowExecutionClient`
- save one `ProjectSpaceAutomationRunRecord`

- [ ] **Step 6: Re-run targeted tests and verify GREEN**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceAutomationCoordinatorTests" -only-testing:"Forma File OrganizingTests/FileMetadataFoundationServiceTests" -only-testing:"Forma File OrganizingTests/FileMetadataFoundationIntegrationTests"
```

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add "Forma File Organizing/Services/ProjectSpaceAutomationRecommendationService.swift" "Forma File Organizing/Services/ProjectSpaceAutomationCoordinator.swift" "Forma File Organizing/Services/ProjectSpaceAutomationService.swift" "Forma File Organizing/Services/FileMetadataFoundationService.swift" "Forma File OrganizingTests/ProjectSpaceAutomationCoordinatorTests.swift" "Forma File OrganizingTests/FileMetadataFoundationServiceTests.swift" "Forma File OrganizingTests/FileMetadataFoundationIntegrationTests.swift"
git commit -m "feat: add project-space automation coordination"
```

## Task 4: Integrate project policies into automation, workflow invocation, activity, and notifications

**Files:**
- Modify: `Forma File Organizing/Models/WorkflowInvocationContext.swift`
- Modify: `Forma File Organizing/Models/ActivityItem.swift`
- Modify: `Forma File Organizing/Services/ActivityLoggingService.swift`
- Modify: `Forma File Organizing/Services/NotificationService.swift`
- Modify: `Forma File Organizing/Services/LogWorkflowStepExecutor.swift`
- Modify: `Forma File Organizing/Services/NotifyWorkflowStepExecutor.swift`
- Modify: `Forma File Organizing/Services/AutomationEngine.swift`
- Test: `Forma File OrganizingTests/AutomationEngineTests.swift`
- Test: `Forma File OrganizingTests/AutomationEngineNotificationTests.swift`
- Test: `Forma File OrganizingTests/WorkflowActivityProjectionTests.swift`

- [ ] **Step 1: Write failing engine tests for project-policy ownership**

Add tests shaped like:

```swift
func testPerformAutoOrganize_ProjectPolicyWinnerBeatsGenericTrustedScopeWhenProjectClaimIsStronger() async throws
func testPerformAutoOrganize_AmbiguousProjectClaimFallsBackToTrustedScopeOrReview() async throws
```

Expect the engine to keep the existing trusted-scope path intact unless a project-policy winner is explicit.

- [ ] **Step 2: Write failing notification and activity tests**

Add tests shaped like:

```swift
func testWorkflowInvocationContext_ProjectPolicyScheduledAllowsNotify()
func testWorkflowInvocationContext_ProjectPolicyManualDoesNotAllowNotify()
func testWorkflowProjection_UsesProjectPolicyRealtimeLabel()
```

Expected labels should distinguish manual project runs from background project automation.

- [ ] **Step 3: Run the engine/activity tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/AutomationEngineTests" -only-testing:"Forma File OrganizingTests/AutomationEngineNotificationTests" -only-testing:"Forma File OrganizingTests/WorkflowActivityProjectionTests"
```

Expected: FAIL because project-policy invocation contexts and engine routing do not exist yet.

- [ ] **Step 4: Expand invocation context and trigger-surface labels**

Add cases shaped like:

```swift
case projectPolicyManual(projectLabel: String, policyName: String)
case projectPolicyScheduled(projectLabel: String, policyName: String)
case projectPolicyRealtime(projectLabel: String, policyName: String)
```

Update `ActivityItem.WorkflowTriggerSurface` and helper labels so they stay honest and user-visible.

- [ ] **Step 5: Integrate the new ownership path into `AutomationEngine`**

Thread the new services through the existing auto-organize loop:

- ask `TrustedAutomationScopeResolver` for the best legacy match
- ask `ProjectAutomationOwnershipResolver` for the best project-policy decision
- execute only the winning path
- keep `workflowExecution.plan/run` as the shared executor

Do not create a parallel mutation path.

- [ ] **Step 6: Re-run targeted engine/activity tests and verify GREEN**

Run the command from Step 3.

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add "Forma File Organizing/Models/WorkflowInvocationContext.swift" "Forma File Organizing/Models/ActivityItem.swift" "Forma File Organizing/Services/ActivityLoggingService.swift" "Forma File Organizing/Services/NotificationService.swift" "Forma File Organizing/Services/LogWorkflowStepExecutor.swift" "Forma File Organizing/Services/NotifyWorkflowStepExecutor.swift" "Forma File Organizing/Services/AutomationEngine.swift" "Forma File OrganizingTests/AutomationEngineTests.swift" "Forma File OrganizingTests/AutomationEngineNotificationTests.swift" "Forma File OrganizingTests/WorkflowActivityProjectionTests.swift"
git commit -m "feat: route project policies through automation engine"
```

## Task 5: Replace the single-template project-space workflow UI with the automation board

**Files:**
- Create: `Forma File Organizing/Components/ProjectSpaceAutomationSection.swift`
- Create: `Forma File Organizing/Components/ProjectSpaceAutomationPolicySheet.swift`
- Create: `Forma File Organizing/Components/ProjectSpaceAutomationComposerSheet.swift`
- Modify: `Forma File Organizing/Models/ProjectSpaceModels.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/Views/ProjectSpaceDetailView.swift`
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Modify: `Forma File Organizing/Components/ProjectSpacesSection.swift`
- Modify: `Forma File Organizing/Components/WorkflowTemplatePicker.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`
- Test: `Forma File OrganizingTests/ProjectSpaceSnapshotTests.swift`

- [ ] **Step 1: Write failing snapshot tests for the automation board**

Add tests shaped like:

```swift
func testProjectSpaceDetailSnapshot_ShowsAutomationSectionsAndRecommendedPolicies()
func testProjectSpaceDetailSnapshot_ShowsPolicyHealthAndLatestRunSummary()
func testProjectSpaceDetailSnapshot_ShowsComposerEntryPointWhenFeatureIsEnabled()
```

Expect the old single workflow section to be replaced by an automation board that can still surface manual run actions.

- [ ] **Step 2: Write failing view-model tests for policy lifecycle and manual runs**

Add tests shaped like:

```swift
func testProjectSpaceAutomationState_BootstrapsFromLegacyWorkflowProfile()
func testCreateProjectSpacePolicy_FromPresetComposerPersistsDraft()
func testRunProjectPolicyManualPreset_UsesSelectedPolicyTemplate()
func testPauseProjectPolicy_RefreshesDetailSections()
```

Keep the current manual project-space workflow regression coverage until the new policy-based manual run path is green.

- [ ] **Step 3: Run the UI/view-model tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/DashboardViewModelTests" -only-testing:"Forma File OrganizingTests/ProjectSpaceSnapshotTests"
```

Expected: FAIL because the new automation board UI and state do not exist yet.

- [ ] **Step 4: Add project-space automation presentation models**

Extend `ProjectSpaceModels.swift` with read models such as:

```swift
struct ProjectSpaceAutomationSummary { ... }
struct ProjectSpaceAutomationPolicySummary { ... }
struct ProjectSpaceAutomationSectionSummary { ... }
```

Keep these derived-only. Do not make the views fetch SwiftData directly.

- [ ] **Step 5: Wire Dashboard/default-panel state to the new services**

Replace the single-template project-space workflow state with project-policy-centered state in `DashboardViewModel`.

Constraints:
- preserve the existing manual project-space run behavior during the transition
- only delete `selectedProjectSpaceWorkflowTemplateID`-style state after the policy-based manual run tests pass
- reuse `WorkflowTemplatePicker` in the composer rather than inventing a second template selector

- [ ] **Step 6: Implement the new views and rerun UI tests**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/DashboardViewModelTests" -only-testing:"Forma File OrganizingTests/ProjectSpaceSnapshotTests"
```

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add "Forma File Organizing/Components/ProjectSpaceAutomationSection.swift" "Forma File Organizing/Components/ProjectSpaceAutomationPolicySheet.swift" "Forma File Organizing/Components/ProjectSpaceAutomationComposerSheet.swift" "Forma File Organizing/Models/ProjectSpaceModels.swift" "Forma File Organizing/ViewModels/DashboardViewModel.swift" "Forma File Organizing/Views/ProjectSpaceDetailView.swift" "Forma File Organizing/Views/DefaultPanelView.swift" "Forma File Organizing/Components/ProjectSpacesSection.swift" "Forma File Organizing/Components/WorkflowTemplatePicker.swift" "Forma File OrganizingTests/DashboardViewModelTests.swift" "Forma File OrganizingTests/ProjectSpaceSnapshotTests.swift"
git commit -m "feat: add project-space automation board UI"
```

## Task 6: Sync docs and run branch-level verification

**Files:**
- Modify: `TODO.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`
- Modify: `Docs/Getting-Started/TODO.md`

- [ ] **Step 1: Update roadmap-execution docs**

Bring the roadmap and execution docs in line with the new shipped branch shape.

At minimum:
- mark the branch as the active follow-on to manual project-space workflows
- remove stale wording that still treats project-space automation as entirely later/future after the branch lands

- [ ] **Step 2: Update release notes and API reference**

Document:
- new feature flag
- new project-space automation models/services
- new workflow invocation contexts
- new project-space automation UI entry points

- [ ] **Step 3: Run the targeted branch suites**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceAutomationServiceTests" -only-testing:"Forma File OrganizingTests/ProjectSpaceAdmissionResolverTests" -only-testing:"Forma File OrganizingTests/ProjectAutomationOwnershipResolverTests" -only-testing:"Forma File OrganizingTests/ProjectSpaceAutomationCoordinatorTests" -only-testing:"Forma File OrganizingTests/AutomationEngineTests" -only-testing:"Forma File OrganizingTests/AutomationEngineNotificationTests" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests" -only-testing:"Forma File OrganizingTests/ProjectSpaceSnapshotTests"
```

Expected: PASS

- [ ] **Step 4: Run the repo-preferred verification commands**

Run:

```bash
xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"
```

Expected:
- build completes successfully
- non-UI test suite passes

- [ ] **Step 5: Commit**

```bash
git add "TODO.md" "CHANGELOG.md" "API_REFERENCE.md" "Docs/Getting-Started/TODO.md"
git commit -m "docs: sync project-space automation board rollout"
```

## Verification notes

- Use `Forma File OrganizingTests/TestHelpers/TemporaryDirectory.swift` for any filesystem-backed automation tests.
- Keep all new automation entry points behind `FeatureFlagService.shared.isEnabled(...)` checks at the app entry point and dashboard/project-space entry surfaces.
- Preserve security-scoped bookmark behavior; project admission may write metadata labels, but it must not bypass destination-access validation.
- Preserve existing trusted-scope behavior when no project-policy winner exists.
- Prefer deterministic unit and integration tests over broad UI automation unless snapshot/state tests leave a real gap.
