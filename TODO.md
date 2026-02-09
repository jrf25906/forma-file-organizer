# Project TODO

Canonical roadmap: [Docs/Getting-Started/TODO.md](Docs/Getting-Started/TODO.md).

## Codebase Cleanup Checklist (v2)
**Last Updated:** February 9, 2026

This checklist tracks the cleanup execution plan; keep it aligned with the canonical roadmap if it becomes a release goal.

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
- [x] Implement Shift-click range selection behavior for card/list/grid file selection flows.
- [x] Add regression tests for range-selection anchor updates and deselect reset behavior.

### macOS Chrome Architecture Sprint (February 9, 2026)
- [x] Replace custom overlay shell in `DashboardView` with `NavigationSplitView` (sidebar/content/inspector columns).
- [x] Remove custom traffic-light/titlebar geometry assumptions from main app window configuration.

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
- [ ] 29. DashboardViewModel decomposition (permission state / undo-redo) — optional.
- [ ] 30. Static analysis tooling — evaluate Periphery (script: `Scripts/periphery.sh`); plan for baselines or `--retain-public` to avoid false positives.
- [ ] 31. SuggestionSource .rule / .mlPrediction — keep as persisted forward-compat; revisit when features ship or are cut.

### Execution Notes
- [x] Run unit/integration tests before and after each phase (CLI: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS'`).
- [x] Run UI tests before and after each phase (CLI: `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - UI" -destination 'platform=macOS'`; may require Accessibility/Automation permissions; use ad-hoc signing overrides when needed).
- [x] If Phase 5 changes view structure, update architecture docs in `Docs/Architecture/` as needed.

---

## Testing Framework Refactor (v1)
**Last Updated:** February 2, 2026  
Goal: deterministic, behavior-driven tests with clear separation of unit/integration/performance/UI suites.

### Priority 1 — Testable Infrastructure + Determinism
- [ ] 1. Add injectable clock/calendar + defaults suites for time/UserDefaults usage in services:
  - [x] `Services/ReportService.swift` (UserDefaults + Calendar + now)
  - [x] `Services/InsightsService.swift` (Calendar + now + greeting)
  - [x] `Services/AutomationEngine.swift` (clock + scheduler/backoff time)
  - [ ] `Services/AnalyticsService.swift` (time-based summaries if needed)
- [x] 2. Introduce wrappers for external side effects:
  - [x] `SecureBookmarkStore` (Keychain) wrapper for tests
  - [x] `FileManager` wrapper for filesystem behavior
  - [ ] Optional: `NotificationService` wrapper for AutomationEngine tests
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
- [ ] 9. Add explicit accessibility identifiers for focus/selection/row status across:
  - `Views/FileRow.swift`, `Views/FileListRow.swift`, `Views/FileGridItem.swift`
  - `Views/MainContentView.swift` / review segments / counters
- [ ] 10. Update UI tests to use predicate expectations instead of `sleep()`:
  - `Forma_File_OrganizingUITests.swift`, `MicroInteractionsUITests.swift`, `FileRowUITests.swift`.

### Priority 5 — Data-Driven Fixtures & Structured Assertions
- [ ] 11. Convert NL parser datasets to fixture files and structured assertions:
  - `NaturalLanguageRuleParserDatasetTests.swift`
  - `NaturalLanguageRuleParserEdgeCaseTests.swift` (avoid message text coupling)
- [ ] 12. Convert “constant-only” tests to behavioral assertions:
  - [x] `AutomationEngineTests.swift`
  - [ ] `AutomationIntegrationTests.swift`
  - [ ] `OrganizationTemplateTests.swift`
  - [ ] `RuleServiceTests.swift`.
