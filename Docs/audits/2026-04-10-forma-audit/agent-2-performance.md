# Agent 2 — Performance Audit (2026-04-10)

## Summary

Three root causes explain every seeded symptom:

1. **`RulesManagementView.makeContentState()` runs an O(N²) pairwise overlap detector plus ~1,574 synchronous bookmark-resolution + stat() calls on the main thread on every SwiftUI body rebuild.** At 1,574 rules this is ~2.5 million rule comparisons and ~1,574 `URL(resolvingBookmarkData:)` + `FileManager.fileExists` calls per rebuild. This is the primary cause of right-panel toggle lag.
2. **`DashboardViewModel` re-publishes `objectWillChange` from 10+ child view-models** (`scanViewModel`, `filterViewModel`, `selectionViewModel`, `analyticsViewModel`, `bulkOperationViewModel`, `contentSearchController`, `scanRefreshController`, `organizationCoordinator`, `panelManager`, `permissionState`). Every mutation in any child forces a full re-evaluation of every view that holds `@EnvironmentObject var dashboardViewModel`, including `RulesManagementView` — which then re-runs the O(N²) above. This is the source of "every button feels messy".
3. **`DashboardView` applies `.id(splitLayoutIdentity)` to the entire `NavigationSplitView`**, where `splitLayoutIdentity` flips between `"centerTwoColumn"` and `"threeColumn"` the instant the right panel is toggled. SwiftUI tears down and rebuilds the entire split view on every panel toggle, compounding cause #1 with a full hierarchy reconstruction.

The existing `Docs/PERFORMANCE_AUDIT.md` covered scan-pipeline hot paths and is still valid; this report focuses on the unaudited Smart Rules panel surface and the cascade storm it sits on top of.

## P0 findings

### [P0] RulesManagementView rebuilds run O(N²) overlap detection every body pass
File: `Forma File Organizing/Views/RulesManagementView.swift:202`
Observed: Spinning cursor and sidebar hitch when opening the right-panel Smart Rules view with ~1,574 rules. `makeContentState()` is called inline at the top of `body` (line 202), and `body` re-runs on every `dashboardViewModel` mutation (see P0 cascade finding below).
Root cause: `makeContentState()` calls `ruleHealthService.classify(rules: sortedRules, ...)` which in `Forma File Organizing/Services/RuleHealthService.swift:55-72` performs `overlapDetector.detectOverlaps(for: rule, against: rules, ...)` once per rule. `RuleOverlapDetector.detectOverlaps` (`Forma File Organizing/Services/RuleOverlapDetector.swift:125-154`) iterates `existingRules` for each call, producing O(N²) pairwise comparisons — ~2.47M comparisons at N=1,574. Additionally, `makeContentState()` itself performs ~15 independent linear `filter`/`count` passes over `sortedRules` (lines 158-197).
Proposed fix: Move `makeContentState()` output into a cached `@State` computed asynchronously and invalidated only when `allRules`, `searchText`, `selectedCategoryID`, `filterNeedsPermissionOnly`, or `staleRuleThresholdDaysStorage` actually change. Inside `RuleOverlapDetector`, pre-index rules by category scope and by condition-signature hashes so exact-duplicate detection is O(N) via a grouping pass; restrict pairwise comparison to rules sharing an overlapping scope bucket.
Risk: med — touches core Smart Rules health classification; must preserve duplicate/overlap semantics. Needs unit coverage for `RuleOverlapDetector` before/after.
Confidence: high

### [P0] RuleHealthService.classify blocks main thread with 1,574 bookmark resolutions + stat() calls
File: `Forma File Organizing/Services/RuleHealthService.swift:142-172`
Observed: Smart Rules panel hitch is not just CPU — there is visible disk wait on cold open. `spindump`-style symptom (spinning cursor) indicates blocking IO.
Root cause: For each rule, `classify` calls `destination.validate()` (`Forma File Organizing/Models/Destination.swift:142-179`) which runs `URL(resolvingBookmarkData:options:.withSecurityScope, ...)` and `FileManager.default.fileExists(atPath:)`, OR falls through to `destinationResolver.checkResolvability(destination)` (`Forma File Organizing/Services/DestinationResolver.swift:353`) which also hits `FileManager.default.fileExists` (`:297-299`, `:475-481`). All of this runs synchronously from the `body` of `RulesManagementView` via `makeContentState()` at line 202. At 1,574 rules this is 1,574 synchronous security-scoped bookmark resolutions on the main thread — each one is a non-trivial syscall.
Proposed fix: Make destination validation asynchronous and memoised. Introduce a `DestinationHealthCache` keyed on `(bookmarkData hash, rule.id)` with a short TTL and populate it off-main on `.task`. `RuleHealthService.classify` should consume cached results and return `.unknown` until the cache warms (UI can show a neutral pill while loading). `Destination.validate` itself should be marked `nonisolated` and callers should dispatch it off main.
Risk: med — bookmark resolution has security implications; must not silently drop permission errors.
Confidence: high

### [P0] DashboardViewModel forwards objectWillChange from 10 child view-models, fanning out unrelated mutations to every observer
File: `Forma File Organizing/ViewModels/DashboardViewModel.swift:2481-2490`
Observed: Every button feels sluggish, sidebar hitches when unrelated work happens, Smart Rules panel refreshes without user input.
Root cause: `DashboardViewModel` subscribes to `objectWillChange` on `scanViewModel`, `filterViewModel`, `selectionViewModel`, `analyticsViewModel`, `bulkOperationViewModel`, `contentSearchController`, `scanRefreshController`, `organizationCoordinator`, `panelManager`, and `permissionState`, then re-emits its own `objectWillChange` for each. Because `RulesManagementView`, `DefaultPanelView`, `MainContentView`, and essentially every top-level view hold `@EnvironmentObject var dashboardViewModel`, any `@Published` tick anywhere in the VM graph invalidates all of them. There are also 26 `@Published` properties on the root VM (`DashboardViewModel.swift:513-611`) which compound the problem.
Proposed fix: Short term — stop blanket-forwarding `objectWillChange`. Make the child VMs direct `@ObservedObject`/`@EnvironmentObject` on the views that actually care about their state, so SwiftUI can diff subscriptions. Medium term — migrate `DashboardViewModel` off `ObservableObject`/`@Published` to `@Observable` (macOS 14+) so SwiftUI only invalidates views that read a specific property. Flag the full migration as requiring a dedicated design doc; the "stop forwarding" step is surgical and unlocks most of the win.
Risk: med — removing forwarders may surface latent views that were implicitly depending on a parent tick to refresh. Needs a test pass on each child VM subscriber.
Confidence: high

### [P0] DashboardView slaps `.id()` on the entire NavigationSplitView; toggling the right panel destroys and rebuilds all three columns
File: `Forma File Organizing/Views/DashboardView.swift:268-269`
Observed: Opening the right inspector is visibly janky; sidebar state flashes.
Root cause: `splitViewLayout.id(splitLayoutIdentity)` with `splitLayoutIdentity` computed at `:145-150` as `"analyticsTwoColumn" | "threeColumn" | "centerTwoColumn"`. Because `usesThreeColumnLayout = dashboardViewModel.isRightPanelVisible && !showsAnalyticsAsPrimaryDetail` (`:159-161`), every toggle of `isRightPanelVisible` flips the `.id`, forcing SwiftUI to tear down the sidebar + center + right-panel hierarchies and rebuild from scratch. On rebuild, `RulesManagementView` runs its cold body path (see finding above) with no cached state.
Proposed fix: Remove `.id(splitLayoutIdentity)` and let `NavigationSplitView`'s built-in `columnVisibility` binding handle panel visibility transitions (already wired via `splitViewColumnVisibility` at `:163-174`). The three branches of `splitViewLayout` (`:210-234`) can be collapsed into a single `NavigationSplitView` with conditional columns rather than three distinct structures. If layout mode probing is only needed for UI tests, expose it via a separate hidden probe view that is safe to rebuild.
Risk: low — the `.id` change is load-bearing only because the layout is split into three separate `NavigationSplitView` shapes. Collapsing into one removes the need for identity churn.
Confidence: high

### [P0] RuleManagementCard re-runs destinationResolver.checkResolvability on every row render
File: `Forma File Organizing/Components/RuleManagementCard.swift:64, 515`
Observed: Even after the O(N²) classification above, scrolling the 1,574-rule list still drops frames.
Root cause: `RuleManagementCard` holds `private static let destinationResolver = DestinationResolver()` and re-invokes `destinationResolver.checkResolvability(destination)` inside the view (line 515) when computing fallback health locally — i.e., the health is recomputed per row as SwiftUI reuses cells, even though `RulesManagementView.ruleCardRow` already passed a precomputed `RuleHealthService.RuleHealth` snapshot in (`RulesManagementView.swift:928-944`). The card is defensively recomputing what the parent already knows.
Proposed fix: Delete the fallback `checkResolvability` branch inside `RuleManagementCard` and trust the `Snapshot` passed in. If a default is needed for previews, pass a stubbed `.ready` snapshot.
Risk: low — purely removes duplicate work; the parent already classifies authoritatively.
Confidence: high

## P1 findings

### [P1] `makeContentState()` does 15+ linear passes over all rules on every body rebuild
File: `Forma File Organizing/Views/RulesManagementView.swift:158-197`
Observed: Even if overlap detection is cached, there are still 15 independent `filter`/`count` closures over `sortedRules` at lines 158-197 (`duplicateRules`, `overlapRules`, `needsPermissionRules`, `willCreateRules`, `recentlyTriggeredRules`, `staleRules`, `stableRules`, `disabledRules`, then the same kinds again for `*Count`). At N=1,574 that is ~24k iterations per body rebuild for the bucketing alone, compounded by every pass re-indexing `health(for:in:)`.
Root cause: Redundant enumeration; the healths dictionary already contains enough info to do a single grouping pass.
Proposed fix: Single pass — `let buckets = Dictionary(grouping: sortedRules) { healthByID[$0.id]?.kind ?? .ready }` then derive every list and count from `buckets`. Drop the separate `filteredRules.filter { health(for: $0, in: healthByID).kind == X }` lines entirely.
Risk: low — straight refactor with unit coverage possible.
Confidence: high

### [P1] `DefaultPanelView` loads insights via three separate `.onChange` listeners instead of one merged signal
File: `Forma File Organizing/Views/DefaultPanelView.swift:159-166`
Observed: Visible stutter when DashboardViewModel publishes several changes in sequence during scan end (files land, activities update, clusters update).
Root cause: Three back-to-back `.onChange` modifiers call `loadInsightsDebounced()` independently: `allFiles`, `recentActivities`, `detectedClusters.count`. Each debounces but they layer.
Proposed fix: Merge into a single effective signal via `.task(id:)` on a `struct InsightInputs: Equatable` derived from all three properties, or combine them inside a `@State private var insightSignature` and use one `.onChange`. Existing `scheduleInsightRefresh(metadata:debounceNanoseconds:)` is already single-in-flight; driving it from one merged key prevents redundant dispatches.
Risk: low — purely deduplicates scheduling.
Confidence: med

### [P1] DashboardViewModel uses `class ... ObservableObject` with 26 `@Published` fields and no split
File: `Forma File Organizing/ViewModels/DashboardViewModel.swift:439, 513-611`
Observed: Any publish from the VM invalidates every observing view. Compounds finding #3 above.
Root cause: Pre-`@Observable` pattern; SwiftUI cannot subscribe to a specific property of an `ObservableObject`.
Proposed fix: Convert `DashboardViewModel` to `@MainActor @Observable` so dependency tracking is per-property. Because the class is very large (4,134 lines) this is a dedicated refactor — flag as needing a design doc, but capture as a P1 because the impact on latency is large. Incremental step: extract the read-mostly surfaces used by `RulesManagementView` (primarily `rightPanelMode`, `isRightPanelVisible`) into a small `@Observable` facade and have `RulesManagementView` observe that instead of the root VM.
Risk: high — large refactor if done in one shot.
Confidence: high

### [P1] `rulesOverviewStrip` renders 8 count pills but reads 8 distinct content-state fields, causing the whole strip to re-layout on every pill change
File: `Forma File Organizing/Views/RulesManagementView.swift:641-694`
Observed: Pills flash during rapid updates.
Root cause: Not a measured hotspot on its own but compounds the body-rebuild problem: each pill reads `content.XCount` directly and has no identity, so SwiftUI re-evaluates them all together.
Proposed fix: Once `makeContentState` is moved off the body, extract `rulesOverviewStrip` into its own `Equatable` struct view so SwiftUI can skip identical renders.
Risk: low
Confidence: med

## P2 findings

### [P2] `RuleOverlapDetector.detectConditionOverlap` re-encodes conditions with JSONEncoder via `RuleHealthService.canonicalConditionString` for every comparison
File: `Forma File Organizing/Services/RuleHealthService.swift:236-241`
Observed: Hot path during duplicate detection.
Root cause: `canonicalConditionString` JSON-encodes and base64s every `RuleCondition` for every call. Called from `duplicateSignature(for:)` (`:215-224`) which is called from `exactDuplicateCleanupPlan`. Not called from `classify`, so this is secondary — but will bite when/if classification switches to a signature-based grouping (see P0 fix).
Proposed fix: Cache `duplicateSignature(for:)` per-rule (keyed by `rule.id + rule.updatedAt`).
Risk: low
Confidence: med

### [P2] `FileScanPipeline` protocol is `@MainActor`
File: `Forma File Organizing/Services/FileScanPipeline.swift:14-33`
Observed: Already documented in `Docs/PERFORMANCE_AUDIT.md` as a historical root cause; pipeline body runs on main and only the `fileSystemService.scan` call hops off via `nonisolated async`. Rule evaluation, pattern application, and SwiftData upserts still execute on main.
Root cause: Comment on line 12 explains the `@MainActor` constraint is due to SwiftData model non-`Sendable`. The constraint is real but the consequence is that the entire persist pipeline blocks the main thread after the background scan returns.
Proposed fix: Needs dedicated design doc — split the pipeline into a background evaluator (operates on value-type `FileMetadata`) and a main-thread upsert step that only touches `FileItem` models. Out of scope for this audit.
Risk: high — architectural.
Confidence: high

### [P2] `RulesManagementView` reads `allRules.count` in tab title builder causing another full-list walk on body
File: `Forma File Organizing/Views/RulesManagementView.swift:449-463`
Observed: Minor.
Root cause: `categoryTabTitle(for:)` calls `allRules.count` and `rulesInCategory(category)` (another filter pass) per tab per body.
Proposed fix: Derive counts from the already-grouped `ContentState` buckets.
Risk: low
Confidence: high

### [P2] `RulesManagementView` `.onChange(of: allRules.map(\.id))` allocates a new array every body pass
File: `Forma File Organizing/Views/RulesManagementView.swift:300-302`
Observed: Minor allocation churn.
Root cause: `allRules.map(\.id)` produces a new `[UUID]` every pass; SwiftUI must diff it to decide if `onChange` fires.
Proposed fix: Observe `allRules.count` as a cheap proxy, or move cleanup into a centralised SwiftData observer.
Risk: low
Confidence: med

### [P2] `RightPanelView` wraps every mode in `.matchedGeometryEffect(id: "panel", ...)` which forces cross-fade measurement on every mode swap
File: `Forma File Organizing/Views/RightPanelView.swift:65-101`
Observed: Minor additional cost on panel mode transitions.
Root cause: `matchedGeometryEffect` adds layout measurement passes on every mode change. Combined with the split-view `.id()` churn above, it compounds.
Proposed fix: Keep the geometry effect but ensure the parent split-view identity is stable (P0 split-view finding).
Risk: low
Confidence: med

## Negative results (things that are NOT the problem)

- `MainContentView` uses `LazyVStack` / `LazyVGrid` correctly (`Forma File Organizing/Views/MainContentView.swift:998, 1010, 1049, 1060, 1078, 1147, 1163`). Not a lazy-container problem.
- `RulesManagementView.flatRulesList` and `ruleSection` use `LazyVStack` (`RulesManagementView.swift:722, 886, 920`). The row virtualisation is correct; the problem is everything that runs *before* the rows render.
- `FileMonitorService` has proper debouncing, cancellation, and pending-root coalescing (`FileMonitorService.swift:285-300`). File drop → rescan cadence is controlled correctly.
- `DefaultPanelView` insight refresh uses a strict single-in-flight policy with sequence numbers (`DefaultPanelView.swift:1380-1420`). Already fixed in the Feb-12 batch.
- `FileSystemService.scan(baseFolders:)` hops off the main actor via `async let` and `nonisolated` service methods; the enumerator itself runs on a cooperative thread (`FileSystemService.swift:824-889`). Scan discovery is not a main-thread problem.
- `FullListView` properly scopes its `@Query` via an explicit predicate and uses `List` for lazy rows (`FullListView.swift:16-25`).

## Files read

- `Docs/prompts/forma-audit-prompt.md`
- `Docs/PERFORMANCE_AUDIT.md`
- `Forma File Organizing/Views/RightPanelView.swift`
- `Forma File Organizing/Views/RulesManagementView.swift`
- `Forma File Organizing/Views/DashboardView.swift`
- `Forma File Organizing/Views/DefaultPanelView.swift`
- `Forma File Organizing/Views/MainContentView.swift`
- `Forma File Organizing/Views/FullListView.swift`
- `Forma File Organizing/Components/RuleManagementCard.swift`
- `Forma File Organizing/ViewModels/DashboardViewModel.swift` (selected ranges)
- `Forma File Organizing/Coordinators/PanelStateManager.swift` (selected ranges)
- `Forma File Organizing/Services/RuleHealthService.swift`
- `Forma File Organizing/Services/RuleOverlapDetector.swift`
- `Forma File Organizing/Services/FileScanPipeline.swift` (header + persist range)
- `Forma File Organizing/Services/FileSystemService.swift` (selected ranges)
- `Forma File Organizing/Services/FileMonitorService.swift`
- `Forma File Organizing/Services/DestinationResolver.swift` (selected ranges)
- `Forma File Organizing/Models/Destination.swift` (validate range)
