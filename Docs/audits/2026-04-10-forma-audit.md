# Forma Audit — 2026-04-10

> **Mode:** `find+propose` — no source files were modified.
> **Scope:** `full-audit` (4 parallel subagents: reproduction, performance,
> bug hunter, layout).
> **Raw agent reports:**
> [`agent-1-reproduction.md`](2026-04-10-forma-audit/agent-1-reproduction.md),
> [`agent-2-performance.md`](2026-04-10-forma-audit/agent-2-performance.md),
> [`agent-3-bug-hunter.md`](2026-04-10-forma-audit/agent-3-bug-hunter.md),
> [`agent-4-layout.md`](2026-04-10-forma-audit/agent-4-layout.md).
> **Screenshots:** [`2026-04-10-forma-audit/screenshots/`](2026-04-10-forma-audit/screenshots/)

## Executive summary

"Every button feels messy" is not a collection of independent bugs. Three
interlocked root causes in the SwiftUI view graph explain every seeded
symptom:

1. **`DashboardViewModel` forwards `objectWillChange` from 10 child
   view-models.** Any mutation anywhere in the VM graph invalidates every
   top-level view that holds `@EnvironmentObject var dashboardViewModel`.
   (`DashboardViewModel.swift:2481-2490`)
2. **`DashboardView` slaps `.id(splitLayoutIdentity)` on the entire
   `NavigationSplitView`.** Toggling the right panel flips the identity,
   forcing SwiftUI to destroy and rebuild the sidebar + center + right-panel
   hierarchies — including `UnifiedToolbar`, which is why the left-toggle
   icon visibly glitches mid-animation. (`DashboardView.swift:268-269`)
3. **On every rebuild, `RulesManagementView.body` re-runs an O(N²) overlap
   detector and ~1,574 synchronous security-scoped bookmark resolutions
   on the main thread.** At the user's current rule count this is ~2.47M
   rule comparisons and 1,574 syscalls per body pass.
   (`RulesManagementView.swift:202` → `RuleHealthService.swift:142-172`
   → `Destination.swift:142-179`)

Cause #1 fires cause #3 on every unrelated mutation anywhere in the app,
which is why the UI feels sluggish "everywhere" — the Smart Rules hot
path is running in the background of every interaction. Cause #2 then
fires cause #3 *again* every time the user toggles a panel, and also
explains the toolbar icon glitch directly.

One additional P0 is a latent security-scoped bookmark resource leak in
`FileOperationsService.swift:446` that is not contributing to the
"messy" feel but violates the project's documented bookmark lifecycle
convention and should be fixed alongside the perf work.

**Recommended order of operations for the follow-up implementation
session**, based on risk × impact:

1. Remove `.id(splitLayoutIdentity)` from `DashboardView`
   (low risk, high impact, fixes toolbar glitch + halves Smart-Rules
   rebuild churn).
2. Stop blanket-forwarding `objectWillChange` in `DashboardViewModel`
   (medium risk, very high impact, directly addresses "every button
   feels messy").
3. Cache `makeContentState()` output in `RulesManagementView` + move
   `Destination.validate()` / `RuleOverlapDetector` off the main thread
   (medium risk, very high impact, fixes the Smart-Rules-panel hitch
   itself).
4. Fix the `FileOperationsService.swift:446` bookmark-leak with the
   RAII wrapper already in the same file.
5. Re-run Agent 3 in a follow-up session to cover the bug-hunt
   categories it could not complete (see §P2 and the "incomplete
   coverage" note at the end of this report).

The P1 and P2 sections below list the contributing and adjacent issues
in full. Every finding from every subagent is preserved — none have
been summarized away.

---

## P0 — Seeded symptoms, root-caused

### [P0] Symptom 1 + 4: `RulesManagementView` body rebuild runs O(N²) overlap detection on the main thread

**File:** `Forma File Organizing/Views/RulesManagementView.swift:202`
**Source agent:** Agent 2 (Performance)

**Observed:** Spinning cursor and sidebar hitch when opening the
right-panel Smart Rules view with ~1,574 rules. `makeContentState()`
is called inline at the top of `body` (line 202), and `body` re-runs
on every `dashboardViewModel` mutation. Evidence screenshot
`symptom-1-after-smart-rules-open.png` is 21.4 MB vs a 2.5 MB closed
baseline — the inspector is rendering the full un-clipped content
region.

**Root cause:** `makeContentState()` calls
`ruleHealthService.classify(rules: sortedRules, ...)` which in
`RuleHealthService.swift:55-72` performs
`overlapDetector.detectOverlaps(for: rule, against: rules, ...)` once
per rule. `RuleOverlapDetector.detectOverlaps`
(`RuleOverlapDetector.swift:125-154`) iterates `existingRules` for
each call, producing O(N²) pairwise comparisons — ~2.47M comparisons
at N=1,574. Additionally, `makeContentState()` itself performs ~15
independent linear `filter`/`count` passes over `sortedRules`
(lines 158-197).

**Proposed fix:** Move `makeContentState()` output into a cached
`@State` computed asynchronously and invalidated only when `allRules`,
`searchText`, `selectedCategoryID`, `filterNeedsPermissionOnly`, or
`staleRuleThresholdDaysStorage` actually change. Inside
`RuleOverlapDetector`, pre-index rules by category scope and by
condition-signature hashes so exact-duplicate detection is O(N) via a
grouping pass; restrict pairwise comparison to rules sharing an
overlapping scope bucket.

**Risk:** med — touches core Smart Rules health classification; must
preserve duplicate/overlap semantics. Needs unit coverage for
`RuleOverlapDetector` before/after.
**Confidence:** high

---

### [P0] Symptom 1 + 4: `RuleHealthService.classify` blocks main thread with 1,574 bookmark resolutions + `fileExists` syscalls

**File:** `Forma File Organizing/Services/RuleHealthService.swift:142-172`
**Source agent:** Agent 2 (Performance)

**Observed:** Smart Rules panel hitch is not just CPU — there is
visible disk wait on cold open. The `spindump`-style spinning cursor
indicates blocking IO. Cross-validated by Agent 1's screenshot
sequence (`symptom-1-open-frame-0.png`..`open-frame-2.png`) which
shows discrete frame jumps, not smooth animation interpolation.

**Root cause:** For each rule, `classify` calls `destination.validate()`
(`Destination.swift:142-179`) which runs
`URL(resolvingBookmarkData:options:.withSecurityScope, ...)` and
`FileManager.default.fileExists(atPath:)`, OR falls through to
`destinationResolver.checkResolvability(destination)`
(`DestinationResolver.swift:353`) which also hits
`FileManager.default.fileExists` (`:297-299`, `:475-481`). All of this
runs synchronously from the `body` of `RulesManagementView` via
`makeContentState()` at line 202. At 1,574 rules this is 1,574
synchronous security-scoped bookmark resolutions on the main thread.

**Proposed fix:** Make destination validation asynchronous and
memoised. Introduce a `DestinationHealthCache` keyed on
`(bookmarkData hash, rule.id)` with a short TTL and populate it
off-main on `.task`. `RuleHealthService.classify` should consume
cached results and return `.unknown` until the cache warms (UI can
show a neutral pill while loading). `Destination.validate` itself
should be marked `nonisolated` and callers should dispatch it off main.

**Risk:** med — bookmark resolution has security implications; must
not silently drop permission errors.
**Confidence:** high

---

### [P0] Symptom 4: `DashboardViewModel` forwards `objectWillChange` from 10 child view-models

**File:** `Forma File Organizing/ViewModels/DashboardViewModel.swift:2481-2490`
**Source agent:** Agent 2 (Performance)

**Observed:** Every button feels sluggish, sidebar hitches when
unrelated work happens, Smart Rules panel refreshes without user
input.

**Root cause:** `DashboardViewModel` subscribes to `objectWillChange`
on `scanViewModel`, `filterViewModel`, `selectionViewModel`,
`analyticsViewModel`, `bulkOperationViewModel`,
`contentSearchController`, `scanRefreshController`,
`organizationCoordinator`, `panelManager`, and `permissionState`,
then re-emits its own `objectWillChange` for each. Because
`RulesManagementView`, `DefaultPanelView`, `MainContentView`, and
essentially every top-level view hold
`@EnvironmentObject var dashboardViewModel`, any `@Published` tick
anywhere in the VM graph invalidates all of them. There are also
26 `@Published` properties on the root VM
(`DashboardViewModel.swift:513-611`) compounding the problem.

**Proposed fix:** Short term — stop blanket-forwarding
`objectWillChange`. Make the child VMs direct
`@ObservedObject`/`@EnvironmentObject` on the views that actually
care about their state, so SwiftUI can diff subscriptions. Medium
term — migrate `DashboardViewModel` off `ObservableObject`/`@Published`
to `@Observable` (macOS 14+) so SwiftUI only invalidates views that
read a specific property. Flag the full migration as requiring a
dedicated design doc; the "stop forwarding" step is surgical and
unlocks most of the win.

**Risk:** med — removing forwarders may surface latent views that
were implicitly depending on a parent tick to refresh. Needs a test
pass on each child VM subscriber.
**Confidence:** high

---

### [P0] Symptom 1 + 2: `DashboardView` slaps `.id()` on the entire `NavigationSplitView`; panel toggle destroys and rebuilds all three columns

**File:** `Forma File Organizing/Views/DashboardView.swift:268-269`
**Source agents:** Agent 2 (Performance), Agent 4 (Layout) — converged
independently on the same root cause.

**Observed:** Opening the right inspector is visibly janky; sidebar
state flashes; the left-panel toggle icon visually glitches
mid-animation. Evidence:
- `s2-titlebar-t0.png` → `s2-titlebar-t2100ms.png` (5 frames)
  showing the left-toggle icon's stroke/weight changing discretely
  rather than interpolating.
- `s2-toolbar-before.png` / `s2-toolbar-mid-50ms.png` /
  `s2-toolbar-mid-250ms.png` / `s2-toolbar-after.png` showing the
  toolbar region tearing down and rebuilding.

**Root cause:** `splitViewLayout.id(splitLayoutIdentity)` with
`splitLayoutIdentity` computed at `DashboardView.swift:145-150` as
`"analyticsTwoColumn" | "threeColumn" | "centerTwoColumn"`. Because
`usesThreeColumnLayout = dashboardViewModel.isRightPanelVisible && !showsAnalyticsAsPrimaryDetail`
(`:159-161`), every toggle of `isRightPanelVisible` flips the `.id`,
forcing SwiftUI to tear down the sidebar + center + right-panel
hierarchies and rebuild from scratch. On rebuild, `RulesManagementView`
runs its cold body path (the O(N²) + 1,574 syscalls above) with no
cached state, and `UnifiedToolbar` is destroyed and reconstructed
mid-animation — producing the visible left-toggle glitch.

**Proposed fix:** Remove `.id(splitLayoutIdentity)` and let
`NavigationSplitView`'s built-in `columnVisibility` binding handle
panel visibility transitions (already wired via
`splitViewColumnVisibility` at `:163-174`). The three branches of
`splitViewLayout` (`:210-234`) can be collapsed into a single
`NavigationSplitView` with conditional columns rather than three
distinct structures. If layout mode probing is only needed for UI
tests, expose it via a separate hidden probe view that is safe to
rebuild.

**Risk:** low — the `.id` change is load-bearing only because the
layout is split into three separate `NavigationSplitView` shapes.
Collapsing into one removes the need for identity churn.
**Confidence:** high

---

### [P0] Symptom 1: `RuleManagementCard` re-runs `destinationResolver.checkResolvability` on every row render

**File:** `Forma File Organizing/Components/RuleManagementCard.swift:64, 515`
**Source agent:** Agent 2 (Performance)

**Observed:** Even after the O(N²) classification above, scrolling the
1,574-rule list still drops frames.

**Root cause:** `RuleManagementCard` holds
`private static let destinationResolver = DestinationResolver()` and
re-invokes `destinationResolver.checkResolvability(destination)` inside
the view (line 515) when computing fallback health locally — i.e., the
health is recomputed per row as SwiftUI reuses cells, even though
`RulesManagementView.ruleCardRow` already passed a precomputed
`RuleHealthService.RuleHealth` snapshot in
(`RulesManagementView.swift:928-944`). The card is defensively
recomputing what the parent already knows.

**Proposed fix:** Delete the fallback `checkResolvability` branch
inside `RuleManagementCard` and trust the `Snapshot` passed in. If a
default is needed for previews, pass a stubbed `.ready` snapshot.

**Risk:** low — purely removes duplicate work; the parent already
classifies authoritatively.
**Confidence:** high

---

### [P0] Security-scoped bookmark resource leak in `FileOperationsService`

**File:** `Forma File Organizing/Services/FileOperationsService.swift:446`
**Source agent:** Agent 3 (Bug hunter, partial run)

**Observed:** `destinationFolderURL.startAccessingSecurityScopedResource()`
is called directly at line 446 without the RAII `SecurityScopedAccess`
wrapper used elsewhere in the same file.

**Root cause:** Any throw that escapes between the `startAccessing`
call at line 446 and the `defer` cleanup at lines 452–454 leaks the
security-scoped resource handle. CLAUDE.md explicitly requires a
matching `stopAccessingSecurityScopedResource` on all paths, and the
`moveToTrash` method at lines 744–760 already demonstrates the correct
RAII pattern. Repeated leaks over an app session degrade sandbox
posture and can exhaust system handles.

**Proposed fix:** Wrap the access in the existing `SecurityScopedAccess`
RAII class (defined at `FileOperationsService.swift:30-47`), mirroring
the `moveToTrash` implementation at lines 744–760.

**Risk:** low — RAII wrapper already exists and is used in-file; the
change is mechanical and localized.
**Confidence:** high — documented convention violation with a working
template in the same file.

---

## P1 — High-confidence contributors

### [P1] `makeContentState()` does 15+ linear passes over all rules on every body rebuild

**File:** `Forma File Organizing/Views/RulesManagementView.swift:158-197`
**Source agent:** Agent 2

**Observed:** Even if overlap detection is cached, there are still 15
independent `filter`/`count` closures over `sortedRules` at
lines 158-197 (`duplicateRules`, `overlapRules`, `needsPermissionRules`,
`willCreateRules`, `recentlyTriggeredRules`, `staleRules`, `stableRules`,
`disabledRules`, then the same kinds again for `*Count`). At N=1,574
that is ~24k iterations per body rebuild for the bucketing alone,
compounded by every pass re-indexing `health(for:in:)`.

**Root cause:** Redundant enumeration; the `healths` dictionary already
contains enough info to do a single grouping pass.

**Proposed fix:** Single pass —
`let buckets = Dictionary(grouping: sortedRules) { healthByID[$0.id]?.kind ?? .ready }`
then derive every list and count from `buckets`. Drop the separate
`filteredRules.filter { health(for: $0, in: healthByID).kind == X }`
lines entirely.

**Risk:** low — straight refactor with unit coverage possible.
**Confidence:** high

---

### [P1] `DefaultPanelView` loads insights via three separate `.onChange` listeners

**File:** `Forma File Organizing/Views/DefaultPanelView.swift:159-166`
**Source agent:** Agent 2

**Observed:** Visible stutter when `DashboardViewModel` publishes
several changes in sequence during scan end (files land, activities
update, clusters update).

**Root cause:** Three back-to-back `.onChange` modifiers call
`loadInsightsDebounced()` independently: `allFiles`, `recentActivities`,
`detectedClusters.count`. Each debounces but they layer.

**Proposed fix:** Merge into a single effective signal via `.task(id:)`
on a `struct InsightInputs: Equatable` derived from all three
properties, or combine them inside a `@State private var insightSignature`
and use one `.onChange`. Existing
`scheduleInsightRefresh(metadata:debounceNanoseconds:)` is already
single-in-flight; driving it from one merged key prevents redundant
dispatches.

**Risk:** low — purely deduplicates scheduling.
**Confidence:** med

---

### [P1] `DashboardViewModel` uses `class ... ObservableObject` with 26 `@Published` fields and no split

**File:** `Forma File Organizing/ViewModels/DashboardViewModel.swift:439, 513-611`
**Source agent:** Agent 2

**Observed:** Any publish from the VM invalidates every observing
view. Compounds the cascade-forwarding finding above.

**Root cause:** Pre-`@Observable` pattern; SwiftUI cannot subscribe to
a specific property of an `ObservableObject`.

**Proposed fix:** Convert `DashboardViewModel` to
`@MainActor @Observable` so dependency tracking is per-property.
Because the class is very large (4,134 lines) this is a dedicated
refactor — flag as needing a design doc, but capture as a P1 because
the impact on latency is large. Incremental step: extract the
read-mostly surfaces used by `RulesManagementView` (primarily
`rightPanelMode`, `isRightPanelVisible`) into a small `@Observable`
facade and have `RulesManagementView` observe that instead of the
root VM.

**Risk:** high — large refactor if done in one shot.
**Confidence:** high

---

### [P1] `rulesOverviewStrip` renders 8 count pills that re-layout on every pill change

**File:** `Forma File Organizing/Views/RulesManagementView.swift:641-694`
**Source agent:** Agent 2

**Observed:** Pills flash during rapid updates.

**Root cause:** Not a measured hotspot on its own but compounds the
body-rebuild problem: each pill reads `content.XCount` directly and
has no identity, so SwiftUI re-evaluates them all together.

**Proposed fix:** Once `makeContentState` is moved off the body,
extract `rulesOverviewStrip` into its own `Equatable` struct view so
SwiftUI can skip identical renders.

**Risk:** low
**Confidence:** med

---

### [P1] `FileRow` and `FileGridItem` lack stable view identity

**Files:**
- `Forma File Organizing/Views/Components/FileRow.swift`
- `Forma File Organizing/Components/FileGridItem.swift`

**Source agent:** Agent 4 (Layout)

**Observed:** When parent views rebuild (selection changes, density
changes, filtering), `FileRow` and `FileGridItem` may lose internal
state or experience visual flicker due to lack of stable identity.

**Root cause:** `FileListRow` correctly uses `.id(file.path)` at
line 175 for stable identity across parent redraws. `FileRow` (card
layout) has no explicit `.id()`; `FileGridItem` (grid layout) has no
explicit `.id()` — both rely on default positional identity. When the
parent rebuilds, `FileListRow` retains identity while `FileRow` and
`FileGridItem` get recreated and any local `@State` (hover, quick-look
hint) resets.

**Proposed fix:** Add `.id(file.path)` to the `FileRow` body (after
line 326) and the `FileGridItem` body (after line 356), matching the
`FileListRow` pattern.

**Risk:** low — `file.path` is a stable, unique identifier; no
functional change.
**Confidence:** high

---

### [P1] Hardcoded frame heights in `UnifiedToolbar` bypass design tokens

**File:** `Forma File Organizing/Views/Components/UnifiedToolbar.swift:391, 137, 425`
**Source agent:** Agent 4 (Layout)

**Observed:** Inspector toggle button and other toolbar elements use
hardcoded frame height of 24 points, inconsistent with `FormaSpacing`
token usage elsewhere.

**Root cause:** `.frame(width: 28, height: 24)` at line 391, plus
additional `.frame(height: 24)` at lines 137 and 425. The design
system defines `FormaSpacing` with grid-aligned values; hardcoding
24pt bypasses the token system.

**Proposed fix:** Replace with nearest `FormaSpacing` token (e.g.,
`FormaSpacing.generous` at 20pt, or the nearest 8pt-grid multiple).
Confirm the intended token with the design system owner before
committing.

**Risk:** low — purely cosmetic consistency.
**Confidence:** med — 24pt is not a standard `FormaSpacing` value;
the mapping needs a design call.

---

### [P1] Toolbar compression responsive behavior complexity (preventative)

**File:** `Forma File Organizing/Views/Components/UnifiedToolbar.swift:159-623`
**Source agent:** Agent 4 (Layout)

**Observed:** Toolbar has multiple compression levels based on
available width with many state-driven visibility toggles. No defect
currently reported here.

**Root cause:** Not a defect. The complexity of the compression logic
(nested `if` statements checking `toolbarCompressionLevel` and various
state flags) creates a higher risk surface for layout edge cases
during animation or size-class transitions.

**Proposed fix:** Monitor for layout glitches during toolbar
size-class transitions (e.g., window resize). If observed, review the
order of visibility modifiers and consider explicit `.id()` on
compression-level-sensitive sections.

**Risk:** med — preventative note, no active defect.
**Confidence:** low — observation of complexity, not a specific bug.

---

## P2 — Adjacent issues

### [P2] `RuleOverlapDetector.detectConditionOverlap` re-encodes conditions via `JSONEncoder` per comparison

**File:** `Forma File Organizing/Services/RuleHealthService.swift:236-241`
**Source agent:** Agent 2

**Observed:** Hot path during duplicate detection.

**Root cause:** `canonicalConditionString` JSON-encodes and base64s
every `RuleCondition` for every call. Called from
`duplicateSignature(for:)` (`:215-224`) which is called from
`exactDuplicateCleanupPlan`. Not called from `classify`, so this is
secondary — but will bite when/if classification switches to a
signature-based grouping (see the P0 fix).

**Proposed fix:** Cache `duplicateSignature(for:)` per-rule (keyed by
`rule.id + rule.updatedAt`).

**Risk:** low
**Confidence:** med

---

### [P2] `FileScanPipeline` protocol is `@MainActor`

**File:** `Forma File Organizing/Services/FileScanPipeline.swift:14-33`
**Source agent:** Agent 2 (also the source-level cause behind
Symptom 3, file-drop rescan stutter)

**Observed:** Already documented in `Docs/PERFORMANCE_AUDIT.md` as a
historical root cause. Pipeline body runs on main and only the
`fileSystemService.scan` call hops off via `nonisolated async`. Rule
evaluation, pattern application, and SwiftData upserts still execute
on main.

**Root cause:** The comment on line 12 explains the `@MainActor`
constraint is due to SwiftData models being non-`Sendable`. The
constraint is real but the consequence is that the entire persist
pipeline blocks the main thread after the background scan returns —
which is why dropping a file into a watched folder visibly stutters
the UI during rescan (Symptom 3).

**Proposed fix:** Needs dedicated design doc — split the pipeline
into a background evaluator (operates on value-type `FileMetadata`)
and a main-thread upsert step that only touches `FileItem` models.
Out of scope for this audit.

**Risk:** high — architectural.
**Confidence:** high

---

### [P2] `RulesManagementView` reads `allRules.count` in tab title builder

**File:** `Forma File Organizing/Views/RulesManagementView.swift:449-463`
**Source agent:** Agent 2

**Observed:** Minor.

**Root cause:** `categoryTabTitle(for:)` calls `allRules.count` and
`rulesInCategory(category)` (another filter pass) per tab per body.

**Proposed fix:** Derive counts from the already-grouped
`ContentState` buckets.

**Risk:** low
**Confidence:** high

---

### [P2] `RulesManagementView` `.onChange(of: allRules.map(\.id))` allocates a new array every body pass

**File:** `Forma File Organizing/Views/RulesManagementView.swift:300-302`
**Source agent:** Agent 2

**Observed:** Minor allocation churn.

**Root cause:** `allRules.map(\.id)` produces a new `[UUID]` every
pass; SwiftUI must diff it to decide if `onChange` fires.

**Proposed fix:** Observe `allRules.count` as a cheap proxy, or move
cleanup into a centralised SwiftData observer.

**Risk:** low
**Confidence:** med

---

### [P2] `RightPanelView` wraps every mode in `matchedGeometryEffect` forcing cross-fade measurement on every mode swap

**File:** `Forma File Organizing/Views/RightPanelView.swift:65-101`
**Source agent:** Agent 2

**Observed:** Minor additional cost on panel mode transitions.

**Root cause:** `matchedGeometryEffect` adds layout measurement passes
on every mode change. Combined with the split-view `.id()` churn, it
compounds.

**Proposed fix:** Keep the geometry effect but ensure the parent
split-view identity is stable (see the P0 split-view finding).

**Risk:** low
**Confidence:** med

---

### [P2] No hardcoded colors in file-row surfaces (negative result)

**Files:** `FileRow.swift`, `FileListRow.swift`, `FileGridItem.swift`
**Source agent:** Agent 4

**Observed:** All file-row surfaces correctly use `FormaColors`
tokens throughout (`formaObsidian`, `formaBoneWhite`,
`formaSteelBlue`, `formaTertiaryLabel`, …). No hardcoded hex values
or hardcoded system colors.

**Confidence:** high — captured as a P2 negative result so the
synthesis stays complete.

---

### [P2] No small-window breakage in file-row surfaces (negative result)

**Files:** `FileRow.swift`, `FileListRow.swift`, `FileGridItem.swift`
**Source agent:** Agent 4

**Observed:** All three surfaces correctly use `fileSurfaceLayout`
environment to detect width class (compact vs regular) and adapt
layout. `FileRow` compact mode uses `VStack` with `HStack` for
accessories (lines 230-243); regular mode uses single `HStack`
(lines 245-252). `FileListRow` matches the same pattern
(lines 125-148). `FileGridItem` uses an explicit
`fileSurfaceLayout.isCompact` check (line 35). All spacing uses
density-aware computed properties scaled by `FormaSpacing`.

**Confidence:** high — captured as a P2 negative result.

---

### [P2] `MainContentView` responsive design follows pattern (partial scan)

**File:** `Forma File Organizing/Views/MainContentView.swift`
**Source agent:** Agent 4

**Observed:** Takes `availableWidth` from `GeometryReader` and passes
it to child views for responsive layout. No problematic `.id()`
patterns or hardcoded values in the examined section (lines 1-200).

**Confidence:** med — only partial file examined; no defects in the
scanned section.

---

## Incomplete coverage — requires a follow-up run

Agent 3 (bug hunter) hit permission restrictions mid-run and did not
complete the full correctness sweep. The following categories from
the audit prompt were **not covered** and should be re-run:

- Swallowed throws sweep (`try?`, empty `catch`) across the ~115
  candidate files Agent 3 identified before terminating.
- SwiftData unique-constraint risks on `FileItem.path` under
  concurrent scan / merge scenarios.
- Feature-flag gating audit — ML entry points via
  `FeatureFlagService.shared.isEnabled(...)`.
- Undo/redo integrity in `ActivityLoggingService` command pattern.
- Rule precedence correctness in `FileScanPipeline` rule evaluation
  order.

Agent 1 (reproduction) did not finish the file-drop/rescan visual
reproduction for Symptom 3 before being stopped. Source-level root
cause is captured in Agent 2's `[P2] FileScanPipeline` finding, but
visual confirmation is missing. Re-run Agent 1 targeted only at
Symptom 3 if needed.

---

## Negative results — things that are NOT the problem

These were verified clean by Agent 2 and Agent 4 and are captured so
future runs don't waste time re-investigating them:

- `MainContentView` uses `LazyVStack` / `LazyVGrid` correctly
  (`MainContentView.swift:998, 1010, 1049, 1060, 1078, 1147, 1163`).
  Not a lazy-container problem.
- `RulesManagementView.flatRulesList` and `ruleSection` use
  `LazyVStack` (`RulesManagementView.swift:722, 886, 920`). Row
  virtualisation is correct; the problem is everything that runs
  *before* the rows render.
- `FileMonitorService` has proper debouncing, cancellation, and
  pending-root coalescing (`FileMonitorService.swift:285-300`).
  File-drop → rescan cadence is controlled correctly.
- `DefaultPanelView` insight refresh uses strict single-in-flight
  policy with sequence numbers (`DefaultPanelView.swift:1380-1420`).
  Already fixed in the Feb-12 batch.
- `FileSystemService.scan(baseFolders:)` hops off the main actor via
  `async let` and `nonisolated` service methods; the enumerator runs
  on a cooperative thread (`FileSystemService.swift:824-889`). Scan
  discovery is not a main-thread problem.
- `FullListView` properly scopes its `@Query` via an explicit
  predicate and uses `List` for lazy rows (`FullListView.swift:16-25`).

---

## Appendix — Evidence

All screenshots are in
[`2026-04-10-forma-audit/screenshots/`](2026-04-10-forma-audit/screenshots/).

**Symptom 1 — Right-panel toggle lag / Smart Rules inspector stall**
- `symptom-0-baseline.png` — cold-launch idle state
- `symptom-1-right-panel-before.png`, `symptom-1-closed.png` — before toggle
- `symptom-1-after-first-click.png`, `symptom-1-panel-open.png` — first click
- `symptom-1-open-frame-0.png`..`symptom-1-open-frame-2.png` — open animation
- `symptom-1-frame-0.png`..`symptom-1-frame-5.png` — toggle frame series
  (discrete jumps, not smooth interpolation — indicator of main-thread
  block between frames)
- `symptom-1-after-smart-rules-open.png` — Smart Rules inspector loaded
  (21.4 MB on disk vs 2.5 MB closed baseline — direct indicator that the
  inspector is rendering its full rule content region rather than a
  clipped viewport)
- `symptom-1-settled.png`, `symptom-1-final-state.png` — settled
- `symptom-1-after-close.png`, `symptom-1-panel-closed-after.png` —
  inspector closed

**Symptom 2 — Toolbar toggle icon visual glitch**
- `s2-titlebar-before.png` — before click
- `s2-titlebar-t0.png` / `t100ms.png` / `t400ms.png` / `t900ms.png` /
  `t2100ms.png` — icon stroke/weight changing discretely, not
  interpolating
- `s2-toolbar-before.png` / `s2-toolbar-mid-50ms.png` /
  `s2-toolbar-mid-250ms.png` / `s2-toolbar-after.png` — toolbar region
  tearing down and rebuilding

**Symptom 3 — File drop → rescan stutter**
- Not completed visually. `s1-after-open-smart-rules.png` /
  `s1-after-close-smart-rules.png` captured but the full drop→rescan
  sequence was not finished before Agent 1 was stopped. Source-level
  root cause is `FileScanPipeline` `@MainActor` constraint
  (see P2 finding and existing `Docs/PERFORMANCE_AUDIT.md`).

**Symptom 4 — General input latency**
- Not a single-event symptom. Aggregate feel produced by Symptoms 1–3
  together, rooted in `DashboardViewModel.swift:2481-2490`
  (`objectWillChange` forwarding cascade) and the split-view `.id()`
  churn (`DashboardView.swift:268-269`).

### Finding counts

| Priority | Agent 2 | Agent 3 | Agent 4 | Synthesis |
| --- | --- | --- | --- | --- |
| P0 | 5 | 1 | 1 (merged) | 6 |
| P1 | 4 | 0 | 3 | 7 |
| P2 | 5 | 0 | 3 | 8 |
| **Total** | **14** | **1** | **7** | **21** |

Raw subagent findings total 22. In the synthesis, Agent 4's single
P0 ("NavigationSplitView rebuild on identity change causes toolbar
icon glitch") is merged into Agent 2's P0 on the same file and line
(`DashboardView.swift:268-269` — `.id(splitLayoutIdentity)`) because
both agents converged independently on the exact same root cause.
Both source agents are cited in that synthesized finding. No
findings were summarized away.

Agent 1 produced no new findings — it captured the evidence that
validates Symptoms 1 and 2 in the P0 section above.

---

## Next step

Hand this report to the user for triage. Any fixes are deferred to a
separate implementation session per `find+propose` mode.
