# Project TODO

Strategic roadmap: [forma-feature-roadmap.md](forma-feature-roadmap.md). Execution checklist: [Docs/Getting-Started/TODO.md](Docs/Getting-Started/TODO.md).

## Strategic Roadmap Reset (March 30, 2026)
Wave 1 implementation plan: [Docs/plans/2026-03-30-preview-first-roadmap-wave-1-plan.md](Docs/plans/2026-03-30-preview-first-roadmap-wave-1-plan.md).

- [ ] Ship quick-win onboarding and first-run proof so Forma demonstrates value before asking users to configure rules.
- [ ] Add chunked review sessions with `Done for now` semantics to reduce overwhelm in the core preview flow.
- [ ] Build trust infrastructure: rule simulation, stronger preflight checks, richer reasoning, and clearer scoped rollback.
- [ ] Reframe automation notifications around progress and system health instead of backlog guilt.
- [ ] Add a post-review path that converts useful one-time Finder/Spotlight folder requests into persistent monitored folders.
- [ ] Start the personal-organization-memory layer so Forma compounds from user-specific behavior rather than generic AI classification.
- [ ] Plan metadata-backed project spaces and workflow memory before broad cloud or chatbot-style AI expansion.

## Preview-First Onboarding Wave (March 30, 2026)
- [x] Surface a first-run quick-win banner only when Forma has a meaningful visible ready batch, scope the CTA to that batch instead of every ready file in the current dashboard state, and suppress the banner during focused external review sessions.

## Spotlight + Finder Services Integration (March 25, 2026)
- [x] Add an `ExternalIngressCoordinator` that normalizes Finder Services and Spotlight/App Intent requests into one resumable ingress flow.
- [x] Accept both directly selected files and selected folders, scanning only each folder's immediate file children for one-time external organization requests.
- [x] Persist pending external requests through onboarding and resume them automatically once setup completes.
- [x] Scope dashboard review sessions to externally requested file paths so ambiguous items open in a focused review state.
- [x] Clear focused external review sessions once their requested files are no longer pending, and keep skip-only feedback from wiping the user’s existing dashboard filters.
- [x] Register `Organize with Forma` in the app's `NSServices` metadata and refresh Finder Services registration on first launch after version changes.
- [x] Add the required Finder context and provider port metadata to the `Organize with Forma` service declaration so Finder can both show and dispatch the service reliably.
- [x] Rebuild Launch Services plus the `pbs` Services cache during refresh so Finder picks up updated service metadata instead of holding stale pre-fix entries.
- [x] Surface explicit reauthorization feedback when Finder/Spotlight selections lose security-scoped access instead of silently retrying raw paths.
- [x] Add targeted coverage for explicit selection scanning, non-reconciling explicit persistence, external review scoping, onboarding resume, and registration refresh state.
- [ ] Add a post-review affordance to convert a one-time external folder request into a persistent monitored folder when the workflow proves useful.

## Realtime Filesystem Watching (March 25, 2026)
- [x] Add an `FSEvents`-backed `FileMonitorService` for enabled bookmark-backed standard folders, with debounced root-level change coalescing.
- [x] Route watcher changes through `AutomationEngine` as targeted rescans and queue one follow-up realtime rescan instead of starting overlapping scans.
- [x] Merge partial automation refreshes by scanned root so dashboard and menu bar stay correct after create/delete/rename/modify events.
- [x] Surface live watching state in automation UI copy and keep scheduled interval sweeps as the recovery path.

## Website Dark-Mode Polish (March 23, 2026)
- [x] Refactor the website hero window to use shared semantic theme tokens.
- [x] Restore dark-mode readability for the screenshot-style hero composition.
- [x] Replace the washed-out "How Forma Works" background with a dark-aware section surface and tighter hierarchy.

## Menu Bar De-Dashboarding (March 23, 2026)
- [x] Flatten the menu bar popover into one outer shell, one primary review block, and lightweight supporting rows.
- [x] Remove the nested destination/review card treatment in the menu bar and simplify the action hierarchy around one primary organize button.
- [x] Remove the remaining warning-panel treatment for missing destinations so the review card stays one continuous surface in both ready and needs-destination states.
- [x] Tighten the shell, footer, and support-row density so the popover reads like a compact utility instead of a mini dashboard.
- [x] Add stable menu bar previews for pending-with-destination, pending-without-destination, and all-clear states.

## Optical Chrome Pass (March 10, 2026)
- [x] Add a shared optical chrome primitive for concentric rims, specular sheen, and stateful elevation in `DesignSystem/FormaControlChrome.swift`.
- [x] Apply the chrome pass to the dashboard toolbar and file-surface actions/states across card/list/grid.
- [x] Apply the same chrome and numeric emphasis rules to the menu bar summary, review card, and button surfaces.
- [x] Rebuild the macOS app after the chrome pass to verify the SwiftUI refactor compiles cleanly.

## Product Redesign Program (March 5, 2026)
- [x] Document master brief (`Docs/plans/2026-03-05-forma-product-redesign-master-brief.md`)
- [x] Execute website redesign
- [x] Document website validation plan (`Docs/Testing/2026-03-05-website-redesign-validation-plan.md`)
- [x] Run website validation pass
- [x] Execute app polish pass
- [x] Document app validation pass (`Docs/Testing/2026-03-05-app-polish-validation-plan.md`)
- [x] Capture post-polish app runtime evidence (`Docs/Testing/2026-03-05-app-polish-second-pass-findings.md`, `APP-007`)

## Rule Health & Template Destinations (March 10, 2026)
- [x] Split Smart Rules health into duplicate/overlap, needs permission, will create, stable, and disabled states.
- [x] Split exact duplicates from overlaps in Smart Rules so duplicate cleanup does not hide real routing conflicts.
- [x] Add a contextual bulk duplicate cleanup action so historically duplicated stores do not require one-by-one rule deletion.
- [x] Pre-populate destination permission flows with the suggested path and auto-create missing subfolders after access is granted.
- [x] Materialize resolvable placeholder destinations on explicit save in Rule Editor and Inline Rule Builder.
- [x] Add a bulk `Create Folders Now` action for resolvable generated-rule destinations.
- [x] Normalize template/default destinations to canonical root-relative paths and prevent duplicate onboarding template seeding.
- [x] Restore the default screenshot routing rule when it was recently deleted during duplicate cleanup and no replacement screenshot rule exists.
- [x] Add regression coverage for destination materialization, legacy path normalization, template generation, onboarding scope, and rule health classification.

## File Surface + Toolbar Refactor (March 5, 2026)
- [x] Document focused refactor plan (`Docs/plans/2026-03-05-file-surface-and-toolbar-refactor-plan.md`)
- [x] Implement file surface pass 1: calmer status/destination/action semantics across card/list/grid
- [x] Recompose card/list/grid around shared identity/state/destination/action primitives
- [x] Refactor toolbar into grouped scope/context/arrange/display command families
- [x] Run targeted card/toolbar validation capture pass (`Docs/Testing/2026-03-05-file-surface-toolbar-validation-findings.md`)
- [x] Tighten grid tile density and footer hierarchy after validation (`FST-001`)
- [x] Raise passive destination readability without reintroducing link-like styling (`FST-002`)
- [x] Add a real compact-width validation harness or lower the debug/test window minimum for toolbar compression checks (`FST-003`)
- [x] Align the menu bar extra shell, review card, and footer controls with the main app’s surface and button system.
- [x] Run focused file-surface / toolbar rerun and capture sign-off evidence (`Docs/Testing/2026-03-05-file-surface-toolbar-second-pass-findings.md`)

## Website Direction Pass (March 1, 2026)
- [x] Ship the approved `C — Honest Utility` design to `forma-website` homepage, including high-fidelity Mac hero shell, simplified section flow, and standardized 3x3 Forma lockups in nav/footer.
- [x] Align remaining website routes (`/blog`, `/blog/[slug]`, `/support`, `/privacy`, `/terms`, `/get-forma`, `/for-agents`) to the same typography and surface system used by the updated homepage.
- [x] Complete a final copy polish pass so headings and body text share one cohesive Forma voice across all marketing routes.
- [x] Run final multi-breakpoint QA (accessibility + layout/spacing), then fix remaining homepage contrast and `/for-agents` small-screen keyboard/scroll usability issues.

## Tomorrow Focus (Thursday, February 12, 2026)
- [x] Implement recursive scanning across dashboard/manual, automation, menu bar, and review flows with bounded depth/file caps and root-relative path context in card/list/grid UI.
- [x] Add accessibility identifiers for selection/focus/row status in `Views/FileRow.swift`, `Views/FileListRow.swift`, `Views/FileGridItem.swift`, and `Views/MainContentView.swift`.
- [x] Replace `sleep()` in UI tests with predicate-based expectations in `Forma File OrganizingUITests/`.
- [x] Add injectable clock/calendar/defaults for `Services/AnalyticsService.swift` and update tests for deterministic time behavior.
- [x] Investigate current task card organized percentage not updating in real time.
- [x] Convert NL parser dataset tests to fixture files with structured assertions.
- [x] Convert remaining constant-only tests to behavioral assertions in `AutomationIntegrationTests.swift`, `OrganizationTemplateTests.swift`, and `RuleServiceTests.swift`.
- [x] Run full macOS tests (unit/integration, then UI test plan) and triage top regressions.
- [x] Evaluate Periphery via `Scripts/periphery.sh` and document baseline strategy (`--retain-public` vs baseline file).
- [x] Timebox `DashboardViewModel` decomposition design (permission state vs undo/redo) and capture a concrete split plan.

## Speed & Reliability Sprint (February 12, 2026)
- [x] Add hard performance regression budgets for optimization benchmarks and include `OptimizationBenchmarksTests` in the dedicated performance test plan.
- [x] Reuse precomputed project clusters in default-panel insight generation to avoid duplicate context-detection work.
- [x] Stabilize `FileInsight` identifiers so dismissed quick actions stay dismissed across recomputation.
- [x] Skip redundant content-search runs when query + file snapshot are unchanged and cover with `DashboardViewModelTests`.
- [x] Capture `DashboardScanRefresh` and `DefaultPanelInsightRefresh` p50/p95 using a repeatable signpost harness run.

## Next Optimization Batch (Starting February 12, 2026)
- [x] Split `DashboardScanRefresh` into sub-phase signposts to isolate p95/p99 outlier paths.
- [x] Add and document a warm-up cutoff policy for signpost harness analysis.
- [x] Capture a 60+ interval signpost run and record p50/p95/p99 in `Docs/PERFORMANCE_AUDIT.md`.
- [x] Add a reusable `Scripts/` command to run the signpost harness and export summary stats.
- [x] Add pre-PR signpost snapshot steps to `Docs/Development/TESTING.md`.
- [x] Enforce a strict single in-flight default-panel insight refresh path under rapid updates.
- [x] Add scan phase status text in the dashboard for better perceived responsiveness during long operations.

## Codebase Cleanup Checklist (v2)
**Last Updated:** February 11, 2026

This checklist tracks the cleanup execution plan; keep it aligned with the canonical roadmap if it becomes a release goal.

### Website SEO + AI Surface Sprint (February 11, 2026)
- [x] Ship conversion-safe CTA instrumentation and optional privacy-first analytics hooks in `forma-website`.
- [x] Expand homepage structured data graph and tighten robots/sitemap crawler directives.
- [x] Launch in-repo MDX blog with initial keyword-targeted guides (`/blog`, `/blog/[slug]`).
- [x] Add machine-readable AI routes (`/llms.txt`, `/for-agents`, `/openapi.json`, `/api/public/*`).
- [x] Document MCP-readiness constraints and planned future tool contracts (`Docs/Marketing/MCP-READINESS.md`).
- [x] Complete marketing-site accessibility hardening pass: raise low-contrast text tokens, improve floating header pill visibility on scroll, and ensure Forma favicon branding replaces default tab icon.
- [x] Wire the live Mac App Store listing (`id6759181510`) as the default website CTA target so "Download for Mac" no longer depends on placeholder env values.

### Performance Optimization Sprint (February 5, 2026)
- [x] Move content search scanning off the main actor and keep UI lookup O(1) by path.
- [x] Remove `MainContentView` identity invalidation churn tied to content-search count updates.
- [x] Reduce thumbnail pipeline overhead by checking memory/disk cache before security-scope access.
- [x] Reduce folder scan syscall volume via prefetched URL resource keys.
- [x] Parallelize standard base-folder scans in `FileSystemService.scan(baseFolders:)`.
- [x] Fix `FileFilterManager` cache invalidation when `contentMatchedPaths` changes.
- [x] Optimize duplicate detection (compiled regex reuse, streaming hashes, bucketed near-name comparisons).
- [x] Remove unused `FileFilterManager` debounce/batch-reset APIs no longer used by the app flow.
- [x] Add targeted regression tests for filter-cache invalidation and duplicate-detection behavior.
- [x] Capture before/after benchmark numbers for scan/search/duplicate detection in a dedicated performance note (`Docs/PERFORMANCE_AUDIT.md`).

### Design Polish Sprint (February 5, 2026)
- [x] 1. Audit cross-screen UX/visual hierarchy for Dashboard, All Files, Rule Builder, Smart Rules, Analytics, and Settings (light + dark).
- [x] 2. CTA hierarchy pass 1: when bulk review controls are active, hide competing right-panel primary CTA and de-emphasize always-on row-level primary organize buttons.
- [x] 3. CTA hierarchy pass 2: enforce one primary action per screen state (primary, secondary, tertiary action map).
- [x] 4. Rule Builder IA pass: split into explicit "When" and "Then" sections with inline validation and impact preview.
- [x] 5. Smart Rules empty-state cleanup: remove duplicate create-entry points and add starter templates.
- [x] 6. Analytics focus mode: reduce right-rail visual competition and improve no-data guidance.
- [x] 7. Settings visual consistency pass: align shell, spacing, surfaces, and typography with main app chrome.
- [x] 8. Contrast/accessibility pass: raise secondary text/icon/chip contrast in both themes.
- [x] 9. Status semantics pass: simplify redundant status cues (stripe, pill, icon, copy) into a single coherent system.
- [x] 10. Interaction polish across card/list/grid: focus visibility, hit targets, hover/pressed states, motion consistency.

### macOS UX Conventions Sprint (February 9, 2026)
- [x] Wire `Launch at Login` to macOS `SMAppService` so the toggle applies immediately and reports failures.
- [x] Honor `Auto-scan on Launch` before startup scans and post-onboarding auto-scan triggers.
- [x] Replace menu bar synthetic `Cmd+,` settings opening with the shared settings opener.
- [x] Standardize user-visible settings entry points on native `SettingsLink` to avoid unbound actions and Settings-scene warnings.
- [x] Implement Shift-click range selection behavior for card/list/grid file selection flows.
- [x] Add regression tests for range-selection anchor updates and deselect reset behavior.

### macOS Chrome Architecture Sprint (February 10, 2026)
- [x] Replace custom overlay shell in `DashboardView` with `NavigationSplitView` (sidebar/content/inspector columns).
- [x] Remove custom traffic-light/titlebar geometry assumptions from main app window configuration.
- [x] Establish shared control-chrome tokens for segmented/toggle shells (`DesignSystem/FormaControlChrome.swift`).
- [x] Normalize segmented/toggle shells and hover/pressed/active states across center toolbar and inspector controls.
- [x] Align category tabs and productivity period controls to the same control-shell state model for center/inspector cohesion.
- [x] Harden full-bleed pane material fallback so debug glass flags cannot reintroduce oversized contour artifacts.

### Toolbar HIG Polish (February 21, 2026)
- [x] Simplify the center-pane toolbar to a single-row command strip by moving grouping controls into a menu and removing the expanding secondary row.

### Phase 1: Safety Fixes (zero behavioral change, prevents crashes)
- [x] 1. MenuBarViewModel.swift:185 — replace `self!` in [weak self] closure with `guard let self else { return }` (fallback: early return).
- [x] 2. ContextDetectionService.swift:336 — guard `dates.max()`/`dates.min()`; if empty, skip cluster.
- [x] 3. AnalyticsView.swift:341 + LiquidGlassComponents.swift:124 — optional tint handling with tint-less fallback.
- [x] 4. RulePreviewCard.swift:380 + FileRow.swift:73 — replace `.last!` with safe optional binding (fallback: 0 / "" as appropriate).
- [x] 5. ReviewView.swift:20 — use `$0.destination?.displayName ?? "Uncategorized"` for nil destinations.
- [x] Consistency check: align nil fallbacks/placeholder strings across these views (use "Uncategorized" to match list/grid views).

### Phase 2: Safe Dead Code Removal (confirmed no persistence/side-effect risk)
- [x] 6. AIInsightsView.swift:729 — remove `contextDetectionService`.
- [x] 7. LearningService.swift:713-731 — remove `recordPredictionOutcome()`.
- [x] 8. DestinationPredictionTypes.swift:158-163 — remove `PredictionOutcome`.
- [x] 9. OrganizationPersonality.swift:126-163 — remove `preferredViewMode`, `suggestedFolderDepth`, `suggestionsFrequency`, and nested `SuggestionsFrequency` enum.
- [x] 10. LearningService.swift:282-288 — remove commented-out `sizeRanges`.
- [x] 11. AIInsightsView.swift:3 — keep `Combine` import (required for `ObservableObject`/`@StateObject` in this file).
- [x] 12. SVG decision: keep `logo-mark-light.svg` as a brand asset and retain `logo-lockup.svg` for docs references. No deletion.
- [x] 13. Remove empty asset directory `Assets.xcassets/Icon.iconset/`.

### Phase 3: Code Hygiene
- [x] 14. TreemapChart.swift + SmartInsightCard.swift (x2) + CalendarHeatmap.swift — replace `print(...)` with `Log.debug(..., category: .ui)`; log only `lastPathComponent` or a relative path (no full user paths).
- [x] 15. RuleEngine.swift:50-80 — replace emoji `print(...)` with `Log.debug(..., category: .pipeline)`; avoid PII.
- [x] 16. OrganizeAnimations.swift — add `private init()` to `FormaSoundEffects` singleton.

### Phase 4: Deprecated API Migration (requires test updates)
- [x] 17. FileItem.swift:281-293 — migrate DashboardViewModelTests call sites to new `init(path:sizeInBytes:...)`. Update any shared test helpers/factories first, then remove deprecated init.
- [x] 18. RuleService.swift:223 — migrate RuleServiceTests to `createRule(_:source:)` (update shared test helpers first), then remove deprecated `addRule()`.
- [x] 19. FileSystemService.swift:76 + FileOperationsService.swift:272 — migrate remaining callers to `FormaError`, then remove deprecated error types.
- [x] 20. FileMetadata.swift:42 — migrate callers to new init, then remove deprecated init.
- [x] 21. CHANGELOG.md — add entry under [Unreleased] for removed deprecated APIs.

### Phase 5: Structural Refactoring (requires tests to pass before/after)
- [x] Pre-flight: run full test suite before starting Phase 5.
- [x] 22. Extract RuleCategory sorting to Array extension (`sortedByOrder`) with stable tie-breaker: sortOrder, creationDate, id.
- [x] 23. Move conditionDisplayName(for:) to `Rule.ConditionType` computed property.
- [x] 24. NaturalLanguageRuleParser.swift:550-700 — extract `tryMatchPattern(...)` + data-driven registry; run all NL parser tests after.
- [x] 25. Split RuleEditorView into subviews + `RuleValidator`, share `RuleFormState`; verify state flows.
- [x] 26. Consolidate InlineRuleBuilder/RuleEditor shared logic; after #25, run InlineRuleBuilder tests before proceeding.

### Phase 6: Track / Future
- [x] 27. TODO comment backlog (split into tracked items).
  - [x] 27.1 ProductivityReportViewModel.swift — navigate to folder or show file details.
  - [x] 27.2 ProductivityReportViewModel.swift — navigate to screenshot management or trigger archive.
  - [x] 27.3 ProductivityReportViewModel.swift — navigate to large files view.
  - [x] 27.4 ProductivityReportViewModel.swift — navigate to Downloads folder review.
  - [x] 27.5 ProductivityReportViewModel.swift — open rule editor with suggested pattern.
  - [x] 27.6 ProductivityReportViewModel.swift — navigate to automation settings.
  - [x] 27.7 ProductivityReportViewModel.swift — navigate to specific folder.
  - [x] 27.8 ProductivityReportViewModel.swift — navigate to cleanup view or show stale files.
  - [x] 27.9 FileScanPipeline.swift — store Destination in LearnedPattern (not path string).
  - [x] 27.10 FileScanPipeline.swift — fetch negative patterns from context.
  - [x] 27.11 FileScanPipeline.swift — return Destination (with bookmark) from DestinationPredictionService.
  - [x] 27.12 DestinationPredictionService.swift — integrate ContextDetectionService (projectCluster).
  - [x] 27.13 DestinationPredictionService.swift — compute training counts (remove random placeholder).
  - [x] 27.14 DashboardFileScanProvider.swift — honor automation exclusions for source folders.
  - [x] 27.15 ManageCategoriesSheet.swift — show folder picker.
  - [x] 27.16 MainContentView.swift — implement bulk operation cancellation.
- [x] 28. Combine → async/await migration (MenuBarViewModel `.sink`) — replaced with async sequence observation tasks.
- [x] 29. DashboardViewModel decomposition (permission state / undo-redo) — optional.
- [x] 30. Static analysis tooling — evaluated Periphery (`Scripts/periphery.sh`) with explicit target configuration; documented baseline strategy in `Docs/Development/DEVELOPMENT.md`.
- [x] 31. SuggestionSource .rule / .mlPrediction — kept for persisted forward-compat with dedicated persistence tests.

### Execution Notes
- [x] Run unit/integration tests before and after each phase (CLI: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS'`).
- [x] Run UI tests before and after each phase (CLI: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - UI" -destination 'platform=macOS'`; may require Accessibility/Automation permissions; use ad-hoc signing overrides when needed).
- [x] If Phase 5 changes view structure, update architecture docs in `Docs/Architecture/` as needed.

---

## Testing Framework Refactor (v1)
**Last Updated:** February 2, 2026  
Goal: deterministic, behavior-driven tests with clear separation of unit/integration/performance/UI suites.

### Priority 1 — Testable Infrastructure + Determinism
- [x] 1. Add injectable clock/calendar + defaults suites for time/UserDefaults usage in services:
  - [x] `Services/ReportService.swift` (UserDefaults + Calendar + now)
  - [x] `Services/InsightsService.swift` (Calendar + now + greeting)
  - [x] `Services/AutomationEngine.swift` (clock + scheduler/backoff time)
  - [x] `Services/AnalyticsService.swift` (time-based summaries if needed)
- [x] 2. Introduce wrappers for external side effects:
  - [x] `SecureBookmarkStore` (Keychain) wrapper for tests
  - [x] `FileManager` wrapper for filesystem behavior
  - [x] Optional: `NotificationService` wrapper for AutomationEngine tests
- [x] 3. Update tests to use isolated dependencies:
  - `ReportServiceTests.swift`, `InsightsServiceTests.swift`, `AutomationEngineTests.swift`,
    `AutomationPolicyTests.swift`, `OrganizationPersonalityTests.swift`, `FolderTemplateSelectionTests.swift`.

### Priority 2 — Replace Tautological or Duplicated Logic Tests
- [x] 4. `FileRowTests.swift`: stop re-implementing view logic; extract helper (view model or static function) and test that.
- [x] 5. `EnhancedReviewFeatureTests.swift`: move confidence badge/average/grouping logic into production helpers and test those.
- [x] 6. `LoggingPolicyTests.swift`: replace raw string search with SwiftSyntax or SwiftLint rule to avoid false positives.

### Priority 3 — Performance / Integration / UI Test Separation
- [x] 7. Create separate test plans:
  - Unit/default: exclude perf/integration/UI where possible
  - Performance: `DestinationPredictionPerformanceTests`, `RateLimitingPerformanceTests`, `StorageServiceTests` perf
  - Integration: `FileOperationsServiceTests`, `FileSystemServiceTests`, `SecureBookmarkStoreTests`, security suites
- [x] 8. Gate perf/integration tests behind env flags to avoid CI flake.

### Priority 4 — UI Test Stabilization
- [x] 9. Add explicit accessibility identifiers for focus/selection/row status across:
  - `Views/FileRow.swift`, `Views/FileListRow.swift`, `Views/FileGridItem.swift`
  - `Views/MainContentView.swift` / review segments / counters
- [x] 10. Update UI tests to use predicate expectations instead of `sleep()`:
  - `Forma_File_OrganizingUITests.swift`, `MicroInteractionsUITests.swift`, `FileRowUITests.swift`.

### Priority 5 — Data-Driven Fixtures & Structured Assertions
- [x] 11. Convert NL parser datasets to fixture files and structured assertions:
  - `NaturalLanguageRuleParserDatasetTests.swift`
  - `NaturalLanguageRuleParserEdgeCaseTests.swift` (avoid message text coupling)
- [x] 12. Convert “constant-only” tests to behavioral assertions:
  - [x] `AutomationEngineTests.swift`
  - [x] `AutomationIntegrationTests.swift`
  - [x] `OrganizationTemplateTests.swift`
  - [x] `RuleServiceTests.swift`.
