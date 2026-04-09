# Progressive Automation Trust Scopes V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add review-earned trusted automation scopes so Forma only auto-moves files inside explicit rule, folder, or category scopes while staying preview-first everywhere else.

**Architecture:** Introduce a new `TrustedAutomationScope` SwiftData model plus a `TrustedAutomationScopeService` for lifecycle and recommendation logic and a `TrustedAutomationScopeResolver` for per-file scope matching. Wire the review-success celebration panel to promote scopes, then gate `AutomationEngine` auto-organize candidates through the resolver without bypassing the existing confidence, destination, permission, or exclusion preflight checks.

**Tech Stack:** Swift, SwiftData, SwiftUI, XCTest, Swift Testing integration tests, macOS app services, security-scoped bookmarks

---

## File structure

### New files

- `Forma File Organizing/Models/TrustedAutomationScope.swift`
- `Forma File Organizing/Services/TrustedAutomationScopeService.swift`
- `Forma File Organizing/Services/TrustedAutomationScopeResolver.swift`
- `Forma File Organizing/Components/TrustedAutomationScopeRecommendationSheet.swift`
- `Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift`
- `Forma File OrganizingTests/TrustedAutomationScopeResolverTests.swift`
- `Forma File OrganizingTests/DashboardOrganizationControllerTests.swift`

### Existing files to modify

- `Forma File Organizing/Forma_File_OrganizingApp.swift`
- `Forma File Organizing/Services/FeatureFlagService.swift`
- `Forma File Organizing/Services/RuleService.swift`
- `Forma File Organizing/Services/AutomationEngine.swift`
- `Forma File Organizing/Services/DashboardFileScanProvider.swift`
- `Forma File Organizing/Services/ActivityLoggingService.swift`
- `Forma File Organizing/Coordinators/PanelStateManager.swift`
- `Forma File Organizing/ViewModels/DashboardOrganizationController.swift`
- `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- `Forma File Organizing/Views/CelebrationView.swift`
- `Forma File Organizing/Views/DefaultPanelView.swift`
- `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`
- `Forma File Organizing/Views/FileInspectorView.swift`
- `Forma File OrganizingTests/AutomationEngineTests.swift`
- `Forma File OrganizingTests/AutomationIntegrationTests.swift`
- `Forma File OrganizingTests/DashboardViewModelTests.swift`
- `TODO.md`
- `CHANGELOG.md`
- `API_REFERENCE.md`

## Task 1: Add trusted-scope persistence, feature flagging, and lifecycle APIs

**Files:**
- Create: `Forma File Organizing/Models/TrustedAutomationScope.swift`
- Create: `Forma File Organizing/Services/TrustedAutomationScopeService.swift`
- Modify: `Forma File Organizing/Forma_File_OrganizingApp.swift`
- Modify: `Forma File Organizing/Services/FeatureFlagService.swift`
- Test: `Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift`

- [ ] **Step 1: Write the failing lifecycle tests**

Add tests that prove:

```swift
func testCreateOrReactivateScope_DeduplicatesByScopeTypeAndKey() throws
func testPauseResumeAndRemove_UpdateStatusWithoutDeletingDuplicates() throws
```

Expect:
- one row per `scopeType + scopeKey`
- promoting the same scope again reactivates and refreshes evidence instead of inserting another row
- pause/resume/remove mutate status predictably

- [ ] **Step 2: Run the new service tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeServiceTests"
```

Expected: FAIL because `TrustedAutomationScope` and its service do not exist yet.

- [ ] **Step 3: Implement the minimal model and service**

Implement:
- `TrustedAutomationScope` with:
  - `scopeType`
  - `scopeKey`
  - `displayName`
  - `status`
  - `promotionSource`
  - `recommendationSource`
  - evidence counters
  - `confidenceSnapshot`
  - `rationaleSummary`
  - `allowedActions`
  - timestamps
- uniqueness helper keyed by `scopeType + scopeKey`
- `TrustedAutomationScopeService` methods:
  - `createOrReactivateScope(...)`
  - `pauseScope(id:)`
  - `resumeScope(id:)`
  - `removeScope(id:)`
  - `activeScopes()`
  - `pausedScopes()`

- [ ] **Step 4: Register the schema and feature flag**

Update:
- `Forma_File_OrganizingApp.appSchema` to include `TrustedAutomationScope.self`
- `FeatureFlagService.Feature` with `trustedAutomationScopes`
- dependencies so the promotion surface is effectively gated behind:
  - `patternLearning`
  - `backgroundMonitoring`
  - `autoOrganize`

- [ ] **Step 5: Re-run the service tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/Models/TrustedAutomationScope.swift" "Forma File Organizing/Services/TrustedAutomationScopeService.swift" "Forma File Organizing/Forma_File_OrganizingApp.swift" "Forma File Organizing/Services/FeatureFlagService.swift" "Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift"
git commit -m "feat: add trusted automation scope persistence"
```

## Task 2: Recommend the narrowest safe scope and surface promotion from review success

**Files:**
- Modify: `Forma File Organizing/Services/TrustedAutomationScopeService.swift`
- Modify: `Forma File Organizing/Services/RuleService.swift`
- Modify: `Forma File Organizing/Coordinators/PanelStateManager.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardOrganizationController.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/Views/CelebrationView.swift`
- Create: `Forma File Organizing/Components/TrustedAutomationScopeRecommendationSheet.swift`
- Test: `Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift`
- Test: `Forma File OrganizingTests/DashboardOrganizationControllerTests.swift`

- [ ] **Step 1: Write the failing recommendation tests**

Add tests that prove:

```swift
func testRecommendedScope_PrefersRuleThenFolderThenCategory() throws
func testRecommendedScope_RequiresEvidenceThresholdAndLowUndoSignal() throws
```

Expect:
- explicit/derivable rule wins over folder
- folder wins over category
- recommendation returns `nil` when evidence is below threshold or undo/correction rate is too high

- [ ] **Step 2: Run the recommendation tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeServiceTests/testRecommendedScope_PrefersRuleThenFolderThenCategory" -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeServiceTests/testRecommendedScope_RequiresEvidenceThresholdAndLowUndoSignal"
```

Expected: FAIL because recommendation logic does not exist yet.

- [ ] **Step 3: Extend the service with recommendation and promotion APIs**

Implement:
- `recommendedScope(for:file:context:)` returning:
  - recommended type
  - display label
  - rationale text
  - alternative scope choices
- thresholds matching the approved spec:
  - at least 3 related accepts
  - zero undo events across the last 5 related memory events
  - correction/override rate `<= 20%`
- `promoteFromReviewDecision(...)`
  - if recommendation is `rule` and no explicit rule exists, create or upsert a real `Rule`
  - then create or reactivate the matching `TrustedAutomationScope`

- [ ] **Step 4: Write the failing controller test for the review-success entry point**

Add a controller test shaped like:

```swift
func testOrganizeFile_SuccessPublishesTrustedScopeRecommendationWhenFeatureFlagAndEvidenceAllow() async throws
```

Expect:
- after a successful organize from `.reviewFlow`
- controller asks for recommendation
- callback/view-model state is populated with a recommendation payload

- [ ] **Step 5: Wire the review-success celebration flow**

Implement:
- `PanelStateManager` state for an optional trusted-scope recommendation
- `DashboardOrganizationController` callback for `onShowTrustedScopeRecommendation`
- `DashboardViewModel` state/actions for:
  - present recommendation
  - confirm selected scope
  - dismiss recommendation
- `CelebrationView` inline `Trust this automatically` CTA
- `TrustedAutomationScopeRecommendationSheet` shown from the celebration panel

Important guardrails:
- only show this entry when `FeatureFlagService.shared.isEnabled(.trustedAutomationScopes)` is true
- only show it for `.reviewFlow` organizes, not inspector or automation-originated moves

- [ ] **Step 6: Re-run controller and service tests**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeServiceTests" -only-testing:"Forma File OrganizingTests/DashboardOrganizationControllerTests"
```

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add "Forma File Organizing/Services/TrustedAutomationScopeService.swift" "Forma File Organizing/Services/RuleService.swift" "Forma File Organizing/Coordinators/PanelStateManager.swift" "Forma File Organizing/ViewModels/DashboardOrganizationController.swift" "Forma File Organizing/ViewModels/DashboardViewModel.swift" "Forma File Organizing/Views/CelebrationView.swift" "Forma File Organizing/Components/TrustedAutomationScopeRecommendationSheet.swift" "Forma File OrganizingTests/TrustedAutomationScopeServiceTests.swift" "Forma File OrganizingTests/DashboardOrganizationControllerTests.swift"
git commit -m "feat: add review flow trusted scope promotion"
```

## Task 3: Gate auto-organize through active trusted scopes without weakening preflight

**Files:**
- Create: `Forma File Organizing/Services/TrustedAutomationScopeResolver.swift`
- Modify: `Forma File Organizing/Services/DashboardFileScanProvider.swift`
- Modify: `Forma File Organizing/Services/AutomationEngine.swift`
- Modify: `Forma File Organizing/Services/ActivityLoggingService.swift`
- Test: `Forma File OrganizingTests/TrustedAutomationScopeResolverTests.swift`
- Test: `Forma File OrganizingTests/AutomationEngineTests.swift`
- Test: `Forma File OrganizingTests/AutomationIntegrationTests.swift`

- [ ] **Step 1: Write the failing resolver tests**

Add tests that prove:

```swift
func testResolveMatch_PrefersRuleOverFolderOverCategory() throws
func testResolveMatch_SkipsPausedAndRevokedScopes() throws
func testResolveMatch_UsesBookmarkFolderIdentityForFolderScopes() throws
```

- [ ] **Step 2: Run the resolver tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeResolverTests"
```

Expected: FAIL because resolver types do not exist yet.

- [ ] **Step 3: Implement the resolver**

Implement:
- `TrustedAutomationScopeResolver`
- a lightweight match result carrying:
  - matched scope ID
  - scope type
  - scope label
  - match reason
- matching rules:
  - rule scope uses `matchedRuleID`
  - folder scope uses monitored root identity, not a raw path string
  - category scope uses existing `FileTypeCategory.rawValue`

- [ ] **Step 4: Write the failing automation-gating tests**

Add tests that expect:
- candidates outside active trusted scopes are filtered out before auto-organize
- candidates inside trusted scopes still fail when normal preflight fails
- pausing a scope removes authorization without changing global automation mode

- [ ] **Step 5: Gate auto-organize through the resolver**

Modify `AutomationEngine` and `DashboardFileScanProvider` so the flow becomes:

1. load pending/ready candidates
2. resolve active trusted-scope matches
3. keep only matched candidates
4. run existing confidence/destination/permission/exclusion preflight
5. auto-organize the resulting files

Do **not**:
- bypass destination validity checks
- bypass permission checks
- bypass confidence thresholds
- bypass excluded-from-automation logic

- [ ] **Step 6: Add scope-aware activity logging**

Extend logging with:
- trusted-scope created / paused / resumed / removed events
- optional auto-organize batch summary text such as:
  - `Automatic pass ran inside trusted scope: Downloads`
  - or a short multi-scope summary when the batch spans more than one scope

- [ ] **Step 7: Re-run targeted automation tests**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeResolverTests" -only-testing:"Forma File OrganizingTests/AutomationEngineTests"
```

Run integration coverage:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/AutomationIntegrationTests"
```

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add "Forma File Organizing/Services/TrustedAutomationScopeResolver.swift" "Forma File Organizing/Services/DashboardFileScanProvider.swift" "Forma File Organizing/Services/AutomationEngine.swift" "Forma File Organizing/Services/ActivityLoggingService.swift" "Forma File OrganizingTests/TrustedAutomationScopeResolverTests.swift" "Forma File OrganizingTests/AutomationEngineTests.swift" "Forma File OrganizingTests/AutomationIntegrationTests.swift"
git commit -m "feat: gate automation with trusted scopes"
```

## Task 4: Surface trusted scope state in the default panel, settings, and inspector

**Files:**
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Modify: `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`
- Modify: `Forma File Organizing/Views/FileInspectorView.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`

- [ ] **Step 1: Write the failing presentation tests**

Add tests that prove:

```swift
func testTrustedAutomationSummary_ReportsActiveAndPausedCounts() throws
func testFileInspectorScopeState_ShowsMatchingTrustedScopeForSelectedFile() throws
```

Expect:
- default-panel summary derives from real active scope counts
- inspector can show `inside trusted scope` vs `preview-only`

- [ ] **Step 2: Run the presentation tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/DashboardViewModelTests/testTrustedAutomationSummary_ReportsActiveAndPausedCounts" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests/testFileInspectorScopeState_ShowsMatchingTrustedScopeForSelectedFile"
```

Expected: FAIL because the view-model helpers do not exist yet.

- [ ] **Step 3: Add view-model helpers for scope summaries and selection state**

Implement in `DashboardViewModel`:
- active scope count
- paused scope count
- default-panel summary string
- selected-file trusted-scope summary using `TrustedAutomationScopeResolver`

- [ ] **Step 4: Update the visible surfaces**

Implement:
- `DefaultPanelView`
  - show `Autopilot active in N trusted scopes`
- `SmartFeaturesSection`
  - add management rows for active and paused scopes
  - actions: `Pause`, `Resume`, `Remove`
- `FileInspectorView`
  - show the matched scope label when a file is inside an active trusted scope
  - otherwise show that the file remains preview-only

- [ ] **Step 5: Re-run the presentation tests**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Forma File Organizing/ViewModels/DashboardViewModel.swift" "Forma File Organizing/Views/DefaultPanelView.swift" "Forma File Organizing/Views/Settings/SmartFeaturesSection.swift" "Forma File Organizing/Views/FileInspectorView.swift" "Forma File OrganizingTests/DashboardViewModelTests.swift"
git commit -m "feat: surface trusted automation scope state"
```

## Task 5: Sync docs and run full verification

**Files:**
- Modify: `TODO.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`

- [ ] **Step 1: Update roadmap and reference docs**

Reflect:
- trusted automation scopes exist as the first progressive automation upgrade
- review flow is the creation surface
- v1 automatic action remains `match -> move -> log`
- scope types are `rule`, `folder`, and `category`

- [ ] **Step 2: Run the targeted trusted-scope suite**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' \
  -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeServiceTests" \
  -only-testing:"Forma File OrganizingTests/DashboardOrganizationControllerTests" \
  -only-testing:"Forma File OrganizingTests/TrustedAutomationScopeResolverTests" \
  -only-testing:"Forma File OrganizingTests/AutomationEngineTests" \
  -only-testing:"Forma File OrganizingTests/DashboardViewModelTests"
```

Expected: PASS

- [ ] **Step 3: Run the repo-preferred non-UI suite**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"
```

Expected: PASS

- [ ] **Step 4: Commit docs and final verification state**

```bash
git add "TODO.md" "CHANGELOG.md" "API_REFERENCE.md"
git commit -m "docs: record trusted automation scopes v1"
```

## Notes for the implementer

- Keep `rule`, `folder`, and `category` scopes first-class in the ledger. Do not translate folder/category promotions into hidden rules.
- If a trusted rule scope is removed, leave the underlying `Rule` intact for preview-first/manual usage.
- Do not add workflow-chain execution, tagging, Finder sync, or broad manual scope creation in this implementation.
- If the celebration panel becomes too crowded, extract only the new recommendation UI into `TrustedAutomationScopeRecommendationSheet.swift`; do not redesign the rest of the panel.
