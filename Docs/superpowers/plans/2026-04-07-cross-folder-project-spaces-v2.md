# Cross-Folder Project Spaces V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn project spaces from a read-only retrieval slice into a richer workflow-memory surface with recent activity, preferred-destination context, lightweight project-association correction, and a narrow project-memory suggestion path back into scan/review.

**Architecture:** Keep project spaces metadata-derived and local-first. Add a feature-gated `ProjectSpaceMemoryResolver` that aggregates existing `FileMetadataRecord` rows plus `FileOrganizationHistoryEntry` into richer read models, have `FileMetadataFoundationService` expose those models and own the correction write path, then extend the dashboard/default-panel project-space UI to show the new memory sections. Finish by adding a narrow `projectSpaceMemory` suggestion stage in `FileScanPipeline` for files that already have a durable project association and a dominant recent destination, while preserving explicit-rule and personal-memory precedence.

**Tech Stack:** Swift, SwiftData, SwiftUI, XCTest, macOS app services, security-scoped bookmarks, `TemporaryDirectory` filesystem-safe tests

---

## Scope check

The approved roadmap spec spans three later branches:

1. `cross-folder-project-spaces-v2`
2. `progressive-automation-upgrades`
3. `workflow-engine-v2`

This plan intentionally covers only branch 1. Do not fold trusted-autopilot lifecycle work or multi-step workflow execution into this plan.

## File structure

### New files

- `Forma File Organizing/Models/ProjectSpaceMemoryModels.swift`
  Purpose: derived project-space v2 read models such as overview stats, preferred destinations, recent activity rows, and a narrow project-memory suggestion payload.
- `Forma File Organizing/Services/ProjectSpaceMemoryResolver.swift`
  Purpose: pure aggregation over metadata/history that computes project-space memory summaries and dominant-destination suggestions without mutating filesystem state.
- `Forma File Organizing/Components/ProjectSpaceAssociationEditorView.swift`
  Purpose: focused correction UI for relabeling one file from the project-space detail flow without turning the whole app into a metadata editor.
- `Forma File OrganizingTests/ProjectSpaceMemoryResolverTests.swift`
  Purpose: focused RED/GREEN coverage for memory aggregation and suggestion-threshold behavior.

### Existing files to modify

- `Forma File Organizing/Services/FeatureFlagService.swift`
  Purpose: add the new feature gate for project-space memory.
- `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`
  Purpose: expose the new gate in debug/settings surfaces like the other metadata features.
- `Forma File Organizing/Models/ProjectSpaceModels.swift`
  Purpose: extend the top-level project-space summary/detail models to carry the new memory sections.
- `Forma File Organizing/Services/FileMetadataFoundationService.swift`
  Purpose: keep project-space retrieval/correction anchored in the metadata foundation and delegate derivation to the new resolver.
- `Forma File Organizing/ViewModels/DashboardViewModel.swift`
  Purpose: own project-space detail, correction sheet state, save/cancel flows, and refresh after metadata mutation.
- `Forma File Organizing/Components/ProjectSpacesSection.swift`
  Purpose: upgrade the summary cards so v2 feels like a product surface instead of a thin list.
- `Forma File Organizing/Views/ProjectSpaceDetailView.swift`
  Purpose: render overview, preferred destinations, recent activity, and file-level correction affordances.
- `Forma File Organizing/Views/DefaultPanelView.swift`
  Purpose: host the richer project-space detail experience and correction editor presentation.
- `Forma File Organizing/Services/FileScanPipeline.swift`
  Purpose: insert the narrow project-memory suggestion stage without disturbing existing precedence guarantees.
- `Forma File Organizing/Models/DestinationPredictionTypes.swift`
  Purpose: add the persisted `SuggestionSource.projectSpaceMemory` enum case.
- `Forma File Organizing/Components/Shared/FileMetaStrip.swift`
  Purpose: render the new suggestion source label/icon/help text in file surfaces.
- `Forma File OrganizingTests/FileMetadataFoundationServiceTests.swift`
  Purpose: service-level project-space detail/correction coverage.
- `Forma File OrganizingTests/FileMetadataFoundationIntegrationTests.swift`
  Purpose: end-to-end metadata-backed project-space refresh coverage.
- `Forma File OrganizingTests/DashboardViewModelTests.swift`
  Purpose: dashboard selection/correction state coverage.
- `Forma File OrganizingTests/ProjectSpaceSnapshotTests.swift`
  Purpose: snapshot-style coverage for the new detail cards and correction affordance text.
- `Forma File OrganizingTests/FileScanPipelinePrecedenceTests.swift`
  Purpose: precedence coverage proving explicit rules and personal memory still outrank project-space memory.
- `Forma File OrganizingTests/SuggestionSourcePersistenceTests.swift`
  Purpose: stored raw-value compatibility for the new suggestion source.
- `TODO.md`
- `forma-feature-roadmap.md`
- `CHANGELOG.md`
- `API_REFERENCE.md`

## Task 1: Add project-space memory models, resolver, and feature gating

**Files:**
- Create: `Forma File Organizing/Models/ProjectSpaceMemoryModels.swift`
- Create: `Forma File Organizing/Services/ProjectSpaceMemoryResolver.swift`
- Create: `Forma File OrganizingTests/ProjectSpaceMemoryResolverTests.swift`
- Modify: `Forma File Organizing/Services/FeatureFlagService.swift`
- Modify: `Forma File Organizing/Views/Settings/SmartFeaturesSection.swift`

- [ ] **Step 1: Write failing resolver tests for the v2 memory shape**

Add focused tests shaped like:

```swift
func testBuildOverview_AggregatesPreferredDestinationsActiveFoldersAndRecentActivity() throws
func testBuildOverview_ExcludesUnresolvableOrNonProjectRecords() throws
func testSuggestion_ReturnsNilWhenNoDominantDestinationExists() throws
```

Expect:
- preferred destinations aggregate from recent `organized` / `rekeyed` history
- recent activity includes `organized`, `undone`, `ignored`, and `noted` rows in reverse-chronological order
- active folders derive from currently resolvable member paths
- suggestion is `nil` unless one destination is both recent and dominant

- [ ] **Step 2: Run the new resolver tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceMemoryResolverTests"
```

Expected: FAIL because the new resolver/models/feature flag do not exist yet.

- [ ] **Step 3: Implement the smallest read-model layer**

Create `ProjectSpaceMemoryModels.swift` with focused, derived value types only:
- `ProjectSpaceOverview`
- `ProjectSpacePreferredDestination`
- `ProjectSpaceRecentActivityRow`
- `ProjectSpaceMemorySuggestion`

Keep them `Hashable`/`Sendable` and derived-only. Do not add new persisted SwiftData models for v2.

- [ ] **Step 4: Implement `ProjectSpaceMemoryResolver`**

Implement pure helpers that accept metadata/history records and produce:
- project overview stats
- preferred destinations sorted by recency + count
- active folder summaries
- recent activity rows
- a narrow dominant-destination suggestion

Keep this layer read-only and deterministic. Do not let it reach into SwiftUI state or filesystem mutation.

- [ ] **Step 5: Add a dedicated feature gate**

In `FeatureFlagService.Feature` add:
- `projectSpaceMemory = "feature.projectSpaceMemory"`

Set:
- default value `false`
- display name like `Project space memory`
- description explaining richer project context + suggestion reuse
- dependencies:
  - `.metadataFoundation`
  - `.autoProjectAssociation`
  - `.projectSpaces`

Expose the new flag in `SmartFeaturesSection.swift`.

- [ ] **Step 6: Re-run the resolver tests and verify GREEN**

Run the same command from Step 2.

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add "Forma File Organizing/Models/ProjectSpaceMemoryModels.swift" "Forma File Organizing/Services/ProjectSpaceMemoryResolver.swift" "Forma File Organizing/Services/FeatureFlagService.swift" "Forma File Organizing/Views/Settings/SmartFeaturesSection.swift" "Forma File OrganizingTests/ProjectSpaceMemoryResolverTests.swift"
git commit -m "feat: add project space memory resolver scaffolding"
```

## Task 2: Extend the metadata foundation with v2 detail fetches and correction writes

**Files:**
- Modify: `Forma File Organizing/Models/ProjectSpaceModels.swift`
- Modify: `Forma File Organizing/Services/FileMetadataFoundationService.swift`
- Test: `Forma File OrganizingTests/FileMetadataFoundationServiceTests.swift`
- Test: `Forma File OrganizingTests/FileMetadataFoundationIntegrationTests.swift`

- [ ] **Step 1: Write failing service tests for richer detail retrieval**

Add tests shaped like:

```swift
func testFetchProjectSpaceDetail_V2IncludesOverviewPreferredDestinationsAndRecentActivity() throws
func testFetchProjectSpaceDetail_UsesNotedAndIgnoredHistoryInRecentActivity() throws
```

Expect `ProjectSpaceDetail` to include:
- existing summary/file rows
- a non-empty `overview`
- preferred destinations ordered by dominance
- recent activity rows capped to a small, deterministic limit

- [ ] **Step 2: Write a failing service test for correction**

Add a test shaped like:

```swift
func testCorrectProjectAssociation_UpdatesNormalizedLabelAndAppendsNotedHistory() throws
```

Expect:
- the target record’s `projectAssociation` changes to the normalized new label
- the old label is removed from the affected project detail
- a `noted` history row is appended with a concise correction summary

- [ ] **Step 3: Run the metadata foundation tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/FileMetadataFoundationServiceTests"
```

Expected: FAIL because the richer detail payload and correction API do not exist yet.

- [ ] **Step 4: Extend `ProjectSpaceModels.swift` without replacing v1 types**

Add fields like:
- `ProjectSpaceDetail.overview: ProjectSpaceOverview`
- `ProjectSpaceDetail.recentActivity: [ProjectSpaceRecentActivityRow]`

Extend `ProjectSpaceFileRow` only with fields truly needed by the correction flow, for example:
- current `projectAssociation`
- current directory/source hint if the UI needs it

Do not introduce a brand-new persisted `Project` entity.

- [ ] **Step 5: Wire the resolver into `FileMetadataFoundationService`**

Implement:
- richer `fetchProjectSpaceSummaries()` that can reuse overview hints where appropriate
- richer `fetchProjectSpaceDetail(for:)`
- a mutation API such as `correctProjectAssociation(forCanonicalIdentity:to:timestamp:)`

Use the existing metadata/history records as the source of truth. Correction should:
- normalize the new label
- no-op on empty/unchanged labels
- append a `noted` history entry
- save through the existing context

- [ ] **Step 6: Add an integration test for refresh after correction**

In `FileMetadataFoundationIntegrationTests.swift`, add a flow that:
- seeds `Alpha`
- corrects one file to `Beta`
- re-fetches summaries/details
- proves counts and file membership update correctly

- [ ] **Step 7: Re-run foundation tests and verify GREEN**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/FileMetadataFoundationServiceTests" -only-testing:"Forma File OrganizingTests/FileMetadataFoundationIntegrationTests"
```

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add "Forma File Organizing/Models/ProjectSpaceModels.swift" "Forma File Organizing/Services/FileMetadataFoundationService.swift" "Forma File OrganizingTests/FileMetadataFoundationServiceTests.swift" "Forma File OrganizingTests/FileMetadataFoundationIntegrationTests.swift"
git commit -m "feat: add project space v2 detail and correction APIs"
```

## Task 3: Upgrade the dashboard/default-panel project-space UI and correction flow

**Files:**
- Create: `Forma File Organizing/Components/ProjectSpaceAssociationEditorView.swift`
- Modify: `Forma File Organizing/ViewModels/DashboardViewModel.swift`
- Modify: `Forma File Organizing/Components/ProjectSpacesSection.swift`
- Modify: `Forma File Organizing/Views/ProjectSpaceDetailView.swift`
- Modify: `Forma File Organizing/Views/DefaultPanelView.swift`
- Test: `Forma File OrganizingTests/DashboardViewModelTests.swift`
- Test: `Forma File OrganizingTests/ProjectSpaceSnapshotTests.swift`

- [ ] **Step 1: Write failing snapshot tests for the richer detail layout**

Add tests shaped like:

```swift
func testProjectSpaceDetailSnapshot_ShowsOverviewPreferredDestinationsAndRecentActivity()
func testProjectSpaceDetailSnapshot_ShowsCorrectionAffordanceForFiles()
```

Expect the snapshot to surface:
- overview text
- preferred-destination pills/rows
- recent-activity list text
- a deterministic correction CTA per file row

- [ ] **Step 2: Write failing view-model tests for correction state**

Add tests shaped like:

```swift
func testProjectSpaces_BeginCorrectionLoadsSelectedFileAndSuggestedLabels() throws
func testProjectSpaces_SaveCorrectionRefreshesDetailAndClearsEditorState() throws
func testProjectSpaces_CancelCorrectionLeavesSelectionIntact() throws
```

Expect:
- editor state is view-model owned
- saving refreshes summaries/detail
- cancelling does not close the project-space detail view

- [ ] **Step 3: Run the UI-facing unit tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceSnapshotTests" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests"
```

Expected: FAIL because the new snapshot fields and correction state do not exist yet.

- [ ] **Step 4: Add view-model correction state and save/cancel methods**

In `DashboardViewModel.swift`, add only the minimum project-space editor state:
- selected file row for correction
- proposed label text
- maybe a small suggested-label list derived from current project-space summaries

Implement:
- `beginProjectSpaceAssociationCorrection(...)`
- `saveProjectSpaceAssociationCorrection()`
- `cancelProjectSpaceAssociationCorrection()`

Keep refresh behavior centralized in existing project-space refresh paths.

- [ ] **Step 5: Implement the correction editor and richer detail cards**

Create `ProjectSpaceAssociationEditorView.swift` for the sheet/editor surface.

Update `ProjectSpaceDetailView.swift` to render:
- overview header block
- preferred destination section
- recent activity section
- per-file correction affordance

Update `DefaultPanelView.swift` to present the editor inside the existing right-panel/default-panel flow. Keep the sidebar/navigation model unchanged.

- [ ] **Step 6: Upgrade `ProjectSpacesSection` carefully**

Add one extra hint line only if it strengthens the summary card, for example:
- top preferred destination
- active-folder summary

Do not overload the card or turn it into a dashboard-within-a-dashboard.

- [ ] **Step 7: Re-run the snapshot/view-model tests and verify GREEN**

Run the same command from Step 3.

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add "Forma File Organizing/Components/ProjectSpaceAssociationEditorView.swift" "Forma File Organizing/ViewModels/DashboardViewModel.swift" "Forma File Organizing/Components/ProjectSpacesSection.swift" "Forma File Organizing/Views/ProjectSpaceDetailView.swift" "Forma File Organizing/Views/DefaultPanelView.swift" "Forma File OrganizingTests/DashboardViewModelTests.swift" "Forma File OrganizingTests/ProjectSpaceSnapshotTests.swift"
git commit -m "feat: ship project space v2 detail and correction UI"
```

## Task 4: Feed narrow project-memory suggestions back into scan/review

**Files:**
- Modify: `Forma File Organizing/Services/ProjectSpaceMemoryResolver.swift`
- Modify: `Forma File Organizing/Services/FileScanPipeline.swift`
- Modify: `Forma File Organizing/Models/DestinationPredictionTypes.swift`
- Modify: `Forma File Organizing/Components/Shared/FileMetaStrip.swift`
- Test: `Forma File OrganizingTests/FileScanPipelinePrecedenceTests.swift`
- Test: `Forma File OrganizingTests/SuggestionSourcePersistenceTests.swift`
- Test: `Forma File OrganizingTests/ProjectSpaceMemoryResolverTests.swift`

- [ ] **Step 1: Write failing precedence tests for project-memory suggestions**

Add tests shaped like:

```swift
func testProjectSpaceMemorySuggestion_AppliesForKnownProjectWithDominantRecentDestination() throws
func testProjectSpaceMemorySuggestion_DoesNotOverrideExplicitRuleOrPersonalMemory() throws
```

Expect precedence to be:
1. explicit rule
2. personal memory
3. project-space memory
4. learned pattern
5. ML prediction

- [ ] **Step 2: Write a failing raw-value compatibility test**

In `SuggestionSourcePersistenceTests.swift`, add:

```swift
XCTAssertEqual(SuggestionSource.projectSpaceMemory.rawValue, "projectSpaceMemory")
```

Include the new case in any round-trip arrays.

- [ ] **Step 3: Run the targeted precedence tests and verify RED**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/FileScanPipelinePrecedenceTests" -only-testing:"Forma File OrganizingTests/SuggestionSourcePersistenceTests" -only-testing:"Forma File OrganizingTests/ProjectSpaceMemoryResolverTests"
```

Expected: FAIL because the new suggestion source and pipeline stage do not exist yet.

- [ ] **Step 4: Add the new suggestion source and presentation text**

In `DestinationPredictionTypes.swift`, add:
- `case projectSpaceMemory`

In `FileMetaStrip.swift`, map it to:
- label like `Project`
- icon distinct from `personalMemory`
- help text that mentions recent activity in the current project

Keep the raw value stable and explicit.

- [ ] **Step 5: Insert the new pipeline stage narrowly**

In `FileScanPipeline.swift`:
- add `applyProjectSpaceMemorySuggestions(...)` after personal memory and before learned patterns
- only evaluate files that do not already have an explicit-rule or personal-memory destination
- only assign a destination when the resolver returns a dominant, resolvable suggestion
- set:
  - `file.destination`
  - `file.suggestionSource = .projectSpaceMemory`
  - `file.matchReason`
  - `file.confidenceScore`

Do not let this stage infer project labels for brand-new unknown files. It should only reuse durable project associations already known in metadata.

- [ ] **Step 6: Re-run the targeted precedence tests and verify GREEN**

Run the same command from Step 3.

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add "Forma File Organizing/Services/ProjectSpaceMemoryResolver.swift" "Forma File Organizing/Services/FileScanPipeline.swift" "Forma File Organizing/Models/DestinationPredictionTypes.swift" "Forma File Organizing/Components/Shared/FileMetaStrip.swift" "Forma File OrganizingTests/FileScanPipelinePrecedenceTests.swift" "Forma File OrganizingTests/SuggestionSourcePersistenceTests.swift" "Forma File OrganizingTests/ProjectSpaceMemoryResolverTests.swift"
git commit -m "feat: add project memory-backed review suggestions"
```

## Task 5: Sync roadmap/docs and run verification

**Files:**
- Modify: `TODO.md`
- Modify: `forma-feature-roadmap.md`
- Modify: `CHANGELOG.md`
- Modify: `API_REFERENCE.md`

- [ ] **Step 1: Sync roadmap wording to the shipped v2 behavior**

Update:
- `TODO.md` to reflect shipped `cross-folder-project-spaces-v2` scope and remaining future work
- `forma-feature-roadmap.md` so project spaces now describe a workflow-memory surface instead of only read-only retrieval
- `CHANGELOG.md` with the user-visible v2 release notes
- `API_REFERENCE.md` with the new feature flag, suggestion source, and project-space correction behavior

- [ ] **Step 2: Run the targeted verification suite**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -only-testing:"Forma File OrganizingTests/ProjectSpaceMemoryResolverTests" -only-testing:"Forma File OrganizingTests/FileMetadataFoundationServiceTests" -only-testing:"Forma File OrganizingTests/FileMetadataFoundationIntegrationTests" -only-testing:"Forma File OrganizingTests/DashboardViewModelTests" -only-testing:"Forma File OrganizingTests/ProjectSpaceSnapshotTests" -only-testing:"Forma File OrganizingTests/FileScanPipelinePrecedenceTests" -only-testing:"Forma File OrganizingTests/SuggestionSourcePersistenceTests"
```

Expected: PASS

- [ ] **Step 3: Run the repo-preferred non-UI suite**

Run:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -skip-testing:"Forma File OrganizingUITests"
```

Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add "TODO.md" "forma-feature-roadmap.md" "CHANGELOG.md" "API_REFERENCE.md"
git commit -m "docs: sync project spaces v2 roadmap and api notes"
```

## Guardrails

- Keep project spaces metadata-derived. Do not introduce a new persisted `Project` model in this branch.
- Respect security-scoped bookmark boundaries. Suggestions must stay best-effort and only surface destinations that can still resolve locally.
- Do not turn correction into a broad metadata editor. One-file relabeling from the project-space surface is enough for v2.
- Preserve preview-first posture. Project-memory suggestions should improve destination recommendations, not trigger execution from project spaces.
- Keep file-level UI parity untouched unless a project-memory source badge appears there. Do not accidentally expand this branch into unrelated card/list/grid redesign work.
