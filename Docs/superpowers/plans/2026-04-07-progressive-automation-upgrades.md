# Progressive Automation Upgrades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn trusted rule, folder, and category promotions into visible optional autopilot scopes with explicit boundaries, lifecycle controls, derived health, scope-aware preflight and recent-run context, and scope-aware notifications while keeping review-earned trust and move-only automation as the product boundary.

**Architecture:** Expand `TrustedAutomationScope` into an explicit boundary-backed permission ledger, add a narrow scope-run summary model plus catalog service for scope detail and health, then route `AutomationEngine` through a new `TrustedAutomationScopeResolver` so only active trusted scopes can auto-organize. Finish by productizing the surface in the default panel, the review-promotion sheet, and Settings, while keeping activity and notifications scope-aware and deliberately stopping short of multi-step workflow execution.

**Tech Stack:** Swift, SwiftData, SwiftUI, XCTest, snapshot tests, macOS app services, security-scoped bookmarks, `TemporaryDirectory` filesystem-safe tests where file access is required

---

## Scope check

The approved post-backbone sequence is:

1. `cross-folder-project-spaces-v2`
2. `progressive-automation-upgrades`
3. `workflow-engine-v2`

This plan intentionally covers only branch 2. Do not fold multi-step workflow templates, generic workflow audit expansion, or project-space-triggered workflow execution into this work.

## File structure

### New files

- `Forma File Organizing/Models/TrustedAutomationScopeBoundaryDescriptor.swift`
  Purpose: explicit persisted boundary shape for rule, folder, and category autopilot scopes so promotion and later matching do not rely on loose display names.
- `Forma File Organizing/Models/TrustedAutomationScopeRunRecord.swift`
  Purpose: narrow persisted scope-run summaries for simulation, automatic passes, blockers, and recent activity without taking on full workflow-engine audit.
- `Forma File Organizing/Models/TrustedAutomationScopePresentationModels.swift`
  Purpose: read-only summary/detail/health/read-model types that drive the default panel, Settings, and scope detail UI.
- `Forma File Organizing/Services/TrustedAutomationScopeResolver.swift`
  Purpose: resolve candidate files against active trusted scopes and confirm destination alignment before any automatic move is allowed.
- `Forma File Organizing/Services/TrustedAutomationScopeCatalogService.swift`
  Purpose: aggregate scopes, rules, bookmark validity, and recent scope runs into UI-ready summaries, details, and health states.
- `Forma File Organizing/Components/TrustedAutomationScopesSection.swift`
  Purpose: reusable first-class scope list surface for the default panel and Settings management groupings.
- `Forma File Organizing/Components/TrustedAutomationScopeDetailSheet.swift`
  Purpose: focused detail sheet with boundary, health, recent runs, and lifecycle controls.
- `Forma File OrganizingTests/TrustedAutomationScopeResolverTests.swift`
  Purpose: focused RED/GREEN coverage for active-scope matching and destination-aware boundary enforcement.
- `Forma File OrganizingTests/TrustedAutomationScopeCatalogServiceTests.swift`
  Purpose: coverage for derived health states, summaries, and recent-run rollups.
- `Forma File OrganizingTests/TrustedAutomationScopeSnapshotTests.swift`
  Purpose: snapshot-style coverage for the new default-panel and detail-sheet scope UI.

### Existing files to modify

- `Forma File Organizing/Models/TrustedAutomationScope.swift`
- `Forma File Organizing/Forma_File_OrganizingApp.swift`
- `Forma File Organizing/Services/TrustedAutomationScopeService.swift`
- `Forma File Organizing/Services/AutomationEngine.swift`
- `Forma File Organizing/Services/AutomationNotificationServing.swift`
- `Forma File Organizing/Services/NotificationService.swift`
- `Forma File Organizing/Services/ActivityLoggingService.swift`
- `Forma File Organizing/Models/ActivityItem.swift`
- `Forma File Organizing/Components/ActivityFeed.swift`
- `Forma File Organizing/Components/AutomationStatusWidget.swift`
- `Forma File Organizing/Components/TrustedAutomationScopeRecommendationSheet.swift`
- `Forma File Organizing/Views/CelebrationView.swift`
- `Forma File Organizing/Views/DefaultPanelView.swift`
- `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`
- `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- `Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift`
- `Forma File OrganizingTests/AutomationEngineTests.swift`
- `Forma File OrganizingTests/AutomationEngineNotificationTests.swift`
- `Forma File OrganizingTests/NotificationServiceTests.swift`
- `Forma File OrganizingTests/DashboardViewModelTests.swift`
- `TODO.md`
- `CHANGELOG.md`
- `API_REFERENCE.md`

## Task 1: Persist explicit trusted boundaries and finish the scope-matching foundation

**Files:**
- Create: `Forma File Organizing/Models/TrustedAutomationScopeBoundaryDescriptor.swift`
- Create: `Forma File Organizing/Services/TrustedAutomationScopeResolver.swift`
- Modify: `Forma File Organizing/Models/TrustedAutomationScope.swift`
- Modify: `Forma File Organizing/Services/TrustedAutomationScopeService.swift`
- Test: `Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift`
- Test: `Forma File OrganizingTests/TrustedAutomationScopeResolverTests.swift`

- [ ] **Step 1: Write the failing promotion and resolver tests**

Add tests shaped like:

```swift
func testPromoteFolderScope_PersistsSubtreeBoundaryAndDestinationSnapshot() throws
func testPromoteCategoryScope_PersistsTrustedDestinationWithoutCreatingDuplicateScopes() throws
func testResolveMatch_RequiresActiveScopeAndDestinationAlignment() throws
func testResolveMatch_PrefersRuleOverFolderOverCategory() throws
```

Expect:
- promotion stores explicit trusted-boundary data instead of only a display label
- re-promoting the same scope refreshes the existing row
- resolver matches only active scopes
- resolver rejects paused or revoked scopes
- narrower scope precedence remains `rule -> folder -> category`

- [ ] **Step 2: Run the new scope tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeServiceTests" -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeResolverTests"
```

Expected: FAIL because the explicit boundary descriptor and resolver do not exist yet.

- [ ] **Step 3: Implement `TrustedAutomationScopeBoundaryDescriptor`**

Represent the trusted boundary explicitly for:

- rule scope
- folder scope
- category scope

The descriptor must preserve enough identity to explain and later validate:

- source boundary
- destination snapshot
- rule identity when applicable

Do not rely on same-name folder matching or transient predicted destinations.

- [ ] **Step 4: Extend `TrustedAutomationScope` to persist the explicit boundary**

Add SwiftData-safe storage for the boundary descriptor, plus any lifecycle timestamps needed for later UI, such as:

- `pausedAt`
- `lastRunAt`
- updated boundary summary fields if the UI needs denormalized copy

Keep revocation non-destructive so history remains inspectable.

- [ ] **Step 5: Teach `TrustedAutomationScopeService` to promote explicit boundaries**

Update promotion so:

- rule scopes carry the trusted rule identity and destination snapshot
- folder scopes persist the reviewed subtree boundary and trusted destination
- category scopes persist the trusted category plus destination snapshot
- duplicate promotions refresh the existing scope instead of creating another row

- [ ] **Step 6: Implement `TrustedAutomationScopeResolver`**

Implement matching that:

- accepts a candidate file plus destination context
- checks only active scopes
- validates destination alignment against the trusted boundary
- prefers `rule`, then `folder`, then `category`

- [ ] **Step 7: Re-run the scope tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add "Forma File Organizing/Models/TrustedAutomationScopeBoundaryDescriptor.swift" "Forma File Organizing/Services/TrustedAutomationScopeResolver.swift" "Forma File Organizing/Models/TrustedAutomationScope.swift" "Forma File Organizing/Services/TrustedAutomationScopeService.swift" "Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift" "Forma File OrganizingTests/TrustedAutomationScopeResolverTests.swift"
git commit -m "feat: persist explicit trusted automation boundaries"
```

## Task 2: Add scope-run summaries, derived health, and scope catalog read models

**Files:**
- Create: `Forma File Organizing/Models/TrustedAutomationScopeRunRecord.swift`
- Create: `Forma File Organizing/Models/TrustedAutomationScopePresentationModels.swift`
- Create: `Forma File Organizing/Services/TrustedAutomationScopeCatalogService.swift`
- Modify: `Forma File Organizing/Forma_File_OrganizingApp.swift`
- Modify: `Forma File Organizing/Services/TrustedAutomationScopeService.swift`
- Test: `Forma File OrganizingTests/TrustedAutomationScopeCatalogServiceTests.swift`
- Test: `Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift`

- [ ] **Step 1: Write the failing scope catalog and health tests**

Add tests shaped like:

```swift
func testBuildSummaries_GroupsActivePausedAndRevokedScopes() throws
func testBuildDetail_DerivesHealthyQuietAndNeedsAttentionStates() throws
func testRecordRun_PersistsHeldBucketsAndRecentExamples() throws
```

Expect:
- grouped summaries for active, paused, and revoked scopes
- health becomes `needsAttention` when bookmark access, rule validity, or recent run blockers fail
- health becomes `quiet` when a scope is valid but inactive recently
- run summaries persist held buckets and example file names

- [ ] **Step 2: Run the new catalog tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeCatalogServiceTests"
```

Expected: FAIL because the run record and catalog service do not exist yet.

- [ ] **Step 3: Implement `TrustedAutomationScopeRunRecord`**

Persist narrow scope-run summaries only:

- timestamps
- trigger source
- status
- matched/eligible/organized/held/failed counts
- held buckets
- summary text
- example file names

Do not add per-file or per-step workflow audit in this branch.

- [ ] **Step 4: Implement `TrustedAutomationScopePresentationModels`**

Add focused read models such as:

- scope summary row
- scope detail
- lifecycle summary
- health summary
- recent run row

Keep them derived-only and `Sendable`/`Hashable`.

- [ ] **Step 5: Implement `TrustedAutomationScopeCatalogService`**

Build summaries and detail payloads by combining:

- `TrustedAutomationScope`
- rule and destination validity
- bookmark resolution
- recent scope-run records

This service should be the UI source for:

- default-panel scope summaries
- settings management lists
- scope detail sheet

- [ ] **Step 6: Register the new schema**

Update `Forma_File_OrganizingApp.appSchema` to include:

- `TrustedAutomationScopeRunRecord.self`

- [ ] **Step 7: Re-run the catalog tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add "Forma File Organizing/Models/TrustedAutomationScopeRunRecord.swift" "Forma File Organizing/Models/TrustedAutomationScopePresentationModels.swift" "Forma File Organizing/Services/TrustedAutomationScopeCatalogService.swift" "Forma File Organizing/Forma_File_OrganizingApp.swift" "Forma File Organizing/Services/TrustedAutomationScopeService.swift" "Forma File OrganizingTests/TrustedAutomationScopeCatalogServiceTests.swift" "Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift"
git commit -m "feat: add trusted scope run summaries and health"
```

## Task 3: Route automatic moves, preflight, notifications, and activity through trusted scopes

**Files:**
- Modify: `Forma File Organizing/Services/AutomationEngine.swift`
- Modify: `Forma File Organizing/Services/TrustedAutomationScopeService.swift`
- Modify: `Forma File Organizing/Services/AutomationNotificationServing.swift`
- Modify: `Forma File Organizing/Services/NotificationService.swift`
- Modify: `Forma File Organizing/Services/ActivityLoggingService.swift`
- Modify: `Forma File Organizing/Models/ActivityItem.swift`
- Modify: `Forma File Organizing/Components/ActivityFeed.swift`
- Test: `Forma File OrganizingTests/AutomationEngineTests.swift`
- Test: `Forma File OrganizingTests/AutomationEngineNotificationTests.swift`
- Test: `Forma File OrganizingTests/NotificationServiceTests.swift`

- [ ] **Step 1: Write the failing engine and notification tests**

Add tests shaped like:

```swift
func testPerformAutoOrganize_OnlyProcessesFilesInsideActiveTrustedScopes() async throws
func testPerformAutoOrganize_RecordsPerScopeHeldBucketsWhenAccessBreaks() async throws
func testAutoOrganizeNotification_UsesScopeNameForSingleScopeRuns() throws
```

Expect:
- files outside active trusted scopes stay preview-first
- paused or revoked scopes do not auto-organize
- per-scope runs persist held buckets when permissions or destinations fail
- notifications name the scope when one scope dominates the run

- [ ] **Step 2: Run the engine and notification tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/AutomationEngineTests" -only-testing:"Forma File OrganizingTests/AutomationEngineNotificationTests" -only-testing:"Forma File OrganizingTests/NotificationServiceTests"
```

Expected: FAIL because scope-aware execution, activity, and notification behavior are not implemented yet.

- [ ] **Step 3: Route `AutomationEngine` through `TrustedAutomationScopeResolver`**

Update preflight and execution so that:

- trusted-scope resolution gates automatic moves
- eligible and held files can be grouped by scope
- the latest scope-specific preflight snapshot can be recorded before execution

Keep the existing global automation summary, but do not let it bypass the scope boundary.

- [ ] **Step 4: Persist scope-run summaries during simulation and automatic passes**

Use `TrustedAutomationScopeService` as the write path, or add equivalent write helpers there, so engine flows can record:

- simulated or preflight-only runs
- executed automatic runs
- held or failed runs

Ensure recent-run summaries stay concise and bounded.

- [ ] **Step 5: Make notifications scope-aware**

Extend `AutomationNotificationServing` and `NotificationService` so the engine can send:

- scope-named success summaries
- scope attention notifications for permission or destination issues

Keep multi-scope notifications grouped rather than noisy.

- [ ] **Step 6: Add scope-aware activity rows**

Extend `ActivityItem.ActivityType` and `ActivityLoggingService` to cover:

- scope promoted
- scope paused
- scope resumed
- scope revoked
- scope run summary
- scope attention needed

Update `ActivityFeed` copy and icons so scope events feel distinct from generic automation events.

- [ ] **Step 7: Re-run the engine and notification tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add "Forma File Organizing/Services/AutomationEngine.swift" "Forma File Organizing/Services/TrustedAutomationScopeService.swift" "Forma File Organizing/Services/AutomationNotificationServing.swift" "Forma File Organizing/Services/NotificationService.swift" "Forma File Organizing/Services/ActivityLoggingService.swift" "Forma File Organizing/Models/ActivityItem.swift" "Forma File Organizing/Components/ActivityFeed.swift" "Forma File OrganizingTests/AutomationEngineTests.swift" "Forma File OrganizingTests/AutomationEngineNotificationTests.swift" "Forma File OrganizingTests/NotificationServiceTests.swift"
git commit -m "feat: route automation through trusted scopes"
```

## Task 4: Build the first-class scope UI and lifecycle controls

**Files:**
- Create: `Forma File Organizing/Components/TrustedAutomationScopesSection.swift`
- Create: `Forma File Organizing/Components/TrustedAutomationScopeDetailSheet.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/Components/AutomationStatusWidget.swift`
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Modify: `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`
- Modify: `Forma File Organizing/Components/TrustedAutomationScopeRecommendationSheet.swift`
- Modify: `Forma File Organizing/Views/CelebrationView.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`
- Test: `Forma File OrganizingTests/TrustedAutomationScopeSnapshotTests.swift`

- [ ] **Step 1: Write the failing view-model and snapshot tests**

Add tests shaped like:

```swift
func testTrustedAutomationScopeDetail_PauseResumeAndRevokeRefreshVisibleGroups() throws
func testTrustedAutomationScopesSection_ShowsAttentionStateAndRecentRunSummary() throws
func testRecommendationSheet_ShowsBoundaryPreviewAndImmediatePreflightSummary() throws
```

Expect:
- dashboard state refreshes when a scope is paused, resumed, or revoked
- active, paused, and revoked groupings update correctly
- scope rows expose health and recent-run context
- the promotion sheet shows explicit source/destination boundary copy

- [ ] **Step 2: Run the new UI tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/DashboardViewModelTests" -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeSnapshotTests"
```

Expected: FAIL because the first-class scope surfaces and lifecycle controls do not exist yet.

- [ ] **Step 3: Add dashboard/default-panel scope visibility**

Update `DashboardViewModel`, `AutomationStatusWidget`, and `DefaultPanelView` so the automation area can show:

- active scope count
- top attention scopes
- recent or newly promoted scopes
- entry into scope detail

Keep the existing automation status widget, but stop making it the only automation surface.

- [ ] **Step 4: Add Settings management for active, paused, and revoked scopes**

Use `TrustedAutomationScopesSection.swift` in `SmartFeaturesSection.swift` to present grouped lists with:

- lifecycle status
- health state
- boundary summary
- destination summary
- last run summary

Each scope should expose pause, resume, and revoke from the detail flow.

- [ ] **Step 5: Upgrade the review promotion flow**

Update `TrustedAutomationScopeRecommendationSheet` and `CelebrationView` so the confirmation flow shows:

- source boundary
- trusted destination
- what becomes automatic
- a first scope-specific preflight summary

Creation should remain review-earned only in this branch.

- [ ] **Step 6: Re-run the UI tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add "Forma File Organizing/Components/TrustedAutomationScopesSection.swift" "Forma File Organizing/Components/TrustedAutomationScopeDetailSheet.swift" "Forma File Organizing/ViewModels/DashboardViewModel.swift" "Forma File Organizing/Components/AutomationStatusWidget.swift" "Forma File Organizing/Views/DefaultPanelView.swift" "Forma File Organizing/Views/Settings/SmartFeaturesSection.swift" "Forma File Organizing/Components/TrustedAutomationScopeRecommendationSheet.swift" "Forma File Organizing/Views/CelebrationView.swift" "Forma File OrganizingTests/DashboardViewModelTests.swift" "Forma File OrganizingTests/TrustedAutomationScopeSnapshotTests.swift"
git commit -m "feat: add first-class trusted scope management UI"
```

## Task 5: Sync roadmap docs and run end-to-end verification

**Files:**
- Modify: `TODO.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`

- [ ] **Step 1: Update roadmap-facing docs**

Reflect the shipped behavior in:

- `TODO.md`
- `CHANGELOG.md`
- `API_REFERENCE.md`

Document:

- explicit trusted boundaries
- scope lifecycle and health
- scope-aware notifications and activity
- the fact that `workflow-engine-v2` remains the next branch

- [ ] **Step 2: Run the targeted trusted-scope suites**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeServiceTests" -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeResolverTests" -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeCatalogServiceTests" -only-testing:"Forma File OrganizingTests/AutomationEngineTests" -only-testing:"Forma File OrganizingTests/AutomationEngineNotificationTests" -only-testing:"Forma File OrganizingTests/NotificationServiceTests" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests" -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeSnapshotTests"
```

Expected: PASS

- [ ] **Step 3: Run the repo’s non-UI verification command**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"
```

Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add "TODO.md" "CHANGELOG.md" "API_REFERENCE.md"
git commit -m "docs: sync progressive automation upgrades"
```
