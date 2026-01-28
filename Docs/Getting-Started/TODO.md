# Forma - Project TODO

**Last Updated:** January 28, 2026

---

## Codebase Cleanup Checklist (v2)
**Last Updated:** January 28, 2026

This checklist tracks the cleanup execution plan; keep it aligned with the canonical roadmap if it becomes a release goal.

### Phase 1: Safety Fixes (zero behavioral change, prevents crashes)
- [x] 1. MenuBarViewModel.swift:185 — replace `self!` in [weak self] closure with `guard let self else { return }` (fallback: early return).
- [x] 2. ContextDetectionService.swift:336 — guard `dates.max()`/`dates.min()`; if empty, skip cluster.
- [x] 3. AnalyticsView.swift:341 + LiquidGlassComponents.swift:124 — optional tint handling with tint-less fallback.
- [x] 4. RulePreviewCard.swift:380 + FileRow.swift:73 — replace `.last!` with safe optional binding (fallback: 0 / "" as appropriate).
- [x] 5. ReviewView.swift:20 — use `$0.destination?.displayName ?? "Unknown"` for nil destinations.
- [ ] Consistency check: align nil fallbacks/placeholder strings across these views.

### Phase 2: Safe Dead Code Removal (confirmed no persistence/side-effect risk)
- [x] 6. AIInsightsView.swift:729 — remove `contextDetectionService`.
- [x] 7. LearningService.swift:713-731 — remove `recordPredictionOutcome()`.
- [x] 8. DestinationPredictionTypes.swift:158-163 — remove `PredictionOutcome`.
- [x] 9. OrganizationPersonality.swift:126-163 — remove `preferredViewMode`, `suggestedFolderDepth`, `suggestionsFrequency`, and nested `SuggestionsFrequency` enum.
- [x] 10. LearningService.swift:282-288 — remove commented-out `sizeRanges`.
- [x] 11. AIInsightsView.swift:3 — keep `Combine` import (required for `ObservableObject`/`@StateObject` in this file).
- [x] 12. SVG decision: `logo-mark-light.svg` is used by `website/`; keep it. Keep `logo-lockup.svg` as a brand asset (docs reference). No deletion.
- [x] 13. Remove empty asset directory `Assets.xcassets/Icon.iconset/`.

### Phase 3: Code Hygiene
- [x] 14. TreemapChart.swift + SmartInsightCard.swift (x2) + CalendarHeatmap.swift — replace `print(...)` with `Log.debug(..., category: .ui)`; log only `lastPathComponent` or a relative path (no full user paths).
- [x] 15. RuleEngine.swift:50-80 — replace emoji `print(...)` with `Log.debug(..., category: .pipeline)`; avoid PII.
- [ ] 16. OrganizeAnimations.swift — add `private init()` to `FormaSoundEffects` singleton.

### Phase 4: Deprecated API Migration (requires test updates)
- [x] 17. FileItem.swift:281-293 — migrate DashboardViewModelTests call sites to new `init(path:sizeInBytes:...)`. Update any shared test helpers/factories first, then remove deprecated init.
- [x] 18. RuleService.swift:223 — migrate RuleServiceTests to `createRule(_:source:)` (update shared test helpers first), then remove deprecated `addRule()`.
- [x] 19. FileSystemService.swift:76 + FileOperationsService.swift:272 — migrate remaining callers to `FormaError`, then remove deprecated error types.
- [x] 20. FileMetadata.swift:42 — migrate callers to new init, then remove deprecated init.
- [x] 21. CHANGELOG.md — add entry under [Unreleased] for removed deprecated APIs.

### Phase 5: Structural Refactoring (requires tests to pass before/after)
- [ ] Pre-flight: run full test suite before starting Phase 5.
- [ ] 22. Extract RuleCategory sorting to Array extension (`sortedByOrder`) with stable tie-breaker: sortOrder, creationDate, id.
- [ ] 23. Move conditionDisplayName(for:) to `Rule.ConditionType` computed property.
- [ ] 24. NaturalLanguageRuleParser.swift:550-700 — extract `tryMatchPattern(...)` + data-driven registry; run all NL parser tests after.
- [ ] 25. Split RuleEditorView into subviews + `RuleValidator`, share `RuleFormState`; verify state flows.
- [ ] 26. Consolidate InlineRuleBuilder/RuleEditor shared logic; after #25, run InlineRuleBuilder tests before proceeding.

### Phase 6: Track / Future
- [ ] 27. 16 TODO comments — track only (ProductivityReportViewModel handlers + architectural notes in FileScanPipeline / DestinationPredictionService).
- [ ] 28. Combine → async/await migration (MenuBarViewModel `.sink`) — gradual only.
- [ ] 29. DashboardViewModel decomposition (permission state / undo-redo) — optional.
- [ ] 30. Static analysis tooling — evaluate Periphery; plan for baselines or `--retain-public` to avoid false positives.
- [ ] 31. SuggestionSource .rule / .mlPrediction — keep as persisted forward-compat; revisit when features ship or are cut.

### Execution Notes
- [ ] Run `xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS'` before and after each phase.
- [ ] If Phase 5 changes view structure, update architecture docs in `Docs/Architecture/` as needed.

## ✅ Completed

### Documentation (January 18-20, 2025)
- [x] Consolidate setup documentation into SETUP.md
- [x] Archive Antigravity-specific documentation
- [x] Create critical documentation (Architecture, API Reference, Development, Changelog)
- [x] Update brand documentation to reflect current state
- [x] Consolidate duplicate documentation files
- [x] Archive completed implementation notes
- [x] Clean up obsolete design/Replit files

### Features (January 18, 2025)
- [x] Custom rule builder UI (RuleEditorView)
- [x] Rule creation/editing interface
- [x] Settings window integration
- [x] Quick access "+ Rule" button in ReviewView
- [x] Settings gear icon for easy access
- [x] Complete custom rules functionality

### Dashboard (January 19, 2025)
- [x] Three-column dashboard layout
- [x] Consistent gutters across sidebar, center pane, and right panel
- [x] Unified center pane content width across Grid/List/Tile
- [x] Tiered glass surfaces (base/raised/overlay) with consistent rims
- [x] Storage analytics with circular chart
- [x] File type categorization and filtering
- [x] Activity feed tracking
- [x] Recent files grid
- [x] Downloads folder support

### Architecture (January 19, 2025)
- [x] RuleEngine protocol-based refactoring
- [x] Fileable and Ruleable protocols
- [x] Enhanced testability with test doubles
- [x] Performance improvements (test execution ~0ms)
- [x] Swift 6 language mode compatibility (strict concurrency build)

---

## 🎯 High Priority

### Testing & Quality
- [x] **Comprehensive unit tests**
  - [x] Expand RuleEngine test coverage
  - [x] Add FileOperationsService tests
  - [x] Add ViewModel integration tests
  - [x] Test edge cases and error handling

- [ ] **UI/UX testing**
  - Test all user workflows end-to-end
  - Verify permission flows work correctly
  - Test rule creation/editing scenarios
  - Validate error messages and recovery

- [ ] **Performance testing**
  - Test with large file sets (1000+ files)
  - Verify storage analytics caching works
  - Test batch operations performance
  - Monitor memory usage

### Documentation Updates
- [ ] **User Guide**
  - [x] Create comprehensive end-user documentation (`Docs/Getting-Started/USER-GUIDE.md`)
  - [x] Define screenshot/GIF capture plan (`USER-GUIDE.md` visual assets section)
  - [ ] Capture screenshots/GIFs and embed annotated workflows
  - [x] Document common use cases (everyday workflows)
  - [x] Add a user-facing troubleshooting section (links to SETUP.md deep dive)

- [x] **Developer Onboarding**
  - [x] Setup guide for new contributors (`Docs/Development/DEVELOPER-ONBOARDING.md`)
  - [x] Code contribution guidelines (summary + link to DEVELOPMENT.md)
  - [x] Architecture deep-dive reading path
  - [x] Common development patterns overview

---

## 🚀 Feature Roadmap

### v1.1.0 - Enhanced Organization
**Target:** Q1 2025

- [x] **Smart Suggestions**
  - Implemented via `LearningService`, `DestinationPredictionService` (ML), and `AIInsightsView`
  - Confidence scoring + rejection learning in place

- [x] **File Preview**
  - Quick Look integration (`QuickLookService` + `QuickLookPreview`)
  - Hover/inline preview for images/PDFs

- [x] **Search & Filter**
  - Global search in dashboard and rules lists
  - Filter chips + predicate-based filtering

- [ ] **Drag & Drop**
  - Drag files to custom destinations
  - Drag to create rules
  - Visual feedback during drag

### v1.2.0 - Analytics & Insights
**Target:** Q2 2025

- [x] **Storage Trends**
  - Historical storage tracking
  - Growth/reduction charts
  - Category trends over time
  - Cleanup impact metrics

- [x] **Duplicate Detection**
  - `DuplicateDetectionService` with exact/version/near-duplicate modes
  - UI in `DuplicateGroupsView` with suggested actions

- [x] **Usage Statistics**
  - Files organized per day/week/month
  - Most used rules
  - Time saved metrics
  - Organization patterns

- [x] **Reports**
  - Weekly cleanup reports
  - Storage health score
  - Optimization recommendations
  - Export reports as PDF

- [ ] **Custom Categories**
  - Custom category creation and management
  - Show custom categories in filters and storage analytics

### v1.3.0 - Advanced Rules
**Target:** Q2 2025

- [x] **Complex Conditions**
  - Size/date conditions and AND/OR rules implemented in `RuleCondition`
  - NOT operator for condition negation (`RuleCondition.not(...)`)
  - Remaining: content-based rules, richer combinations/UI polish

- [x] **Conditional Logic**
  - Exception handling via exclusion conditions (`exclusionConditions: [RuleCondition]`)
  - Remaining: If-then-else, nested logic, rule chaining

- [x] **Rule Management** (partial)
  - [x] Rule priority ordering via `sortOrder` property
  - [x] Drag to reorder rules in RulesManagementView
  - [ ] Rule groups/categories
  - [ ] Import/export rule sets
  - [ ] Rule templates library
  - [ ] Bulk rule application (apply rules to existing files in bulk)

### v1.4.0 - Automation ✅
**Completed:** December 2025

- [x] **Background Monitoring**
  - `AutomationEngine` singleton with `@MainActor` thread-safe state management
  - Scene phase integration via `AutomationLifecycleModifier`
  - Configurable trigger conditions in `AutomationPolicy`
  - Manual/automatic mode toggle with pause/resume functionality

- [x] **Scheduling**
  - Adaptive scan intervals (5-60 minutes based on backlog)
  - Threshold-based triggers (configurable via `FormaConfig.Automation`)
  - `AutomationPolicy.shouldAutoOrganize()` with confidence + staleness checks
  - Feature flag gating for staged rollout

- [x] **Notifications**
  - Activity logging extended with automation events
  - `AutomationStatusWidget` in dashboard right panel
  - Rate-limited notifications with configurable cooldowns
  - Error/warning alerts via `ActivityLoggingService`

- [x] **Dashboard Integration**
  - `AutomationStatusWidget` showing status, next scan, pause/resume
  - Expandable last-run statistics (organized/skipped/failed counts)
  - Feature-flag gated display in `DefaultPanelView`
  - Status indicator dot with color-coded states

### v2.0.0 - Cloud & Sync
**Target:** Q4 2025

- [ ] **iCloud Support**
  - Organize iCloud Drive folders
  - iCloud sync for rules
  - Multi-device rule synchronization

- [ ] **Cloud Storage Integration**
  - Dropbox integration
  - Google Drive integration
  - OneDrive integration
  - Cloud file organization

- [ ] **Backup & Restore**
  - Settings backup
  - Rule backup
  - Restore from backup
  - Migration tools

---

## 🎨 Brand & Launch

- [ ] **App Icon & Visual Identity**
  - Tracked in `Docs/Archive/Brand/BRAND_STATUS.md` and `Docs/Design/FORMA-BRAND-TODO.md`
  - Covers custom app icon, visual identity refinements, and brand alignment work

- [ ] **Launch & Marketing Assets**
  - Tracked in the Brand docs (landing page, App Store assets, press kit, demo video, social templates)
  - Kept here as a pointer so brand work stays visible alongside the product roadmap

---

## 🐛 Bug Fixes & Improvements

### Known Issues
- [x] Investigate occasional permission bookmark staleness (stale bookmark detection + auto-reprompt implemented)
- [x] Improve error messages for edge cases (permissions and file operations)
- [x] Optimize large file list rendering (removed unused matchedGeometryEffect, fixed FileListRow `.id()` regeneration)
- [x] Handle special characters in filenames better (FilenameUtilities with Unicode normalization and regex escaping)

### UX Improvements
- [x] Add keyboard shortcuts for common actions (Dashboard keyboard commands in place)
- [x] Improve loading states with progress indicators (loading + bulk progress views)
- [x] Add undo/redo for file operations (UndoCommand + coordinator + shortcuts)
- [x] Better empty states with actionable suggestions (AllCaughtUpView, filtered empty states)

### Technical Debt
- [ ] Refactor large ViewModels
- [x] Extract reusable UI components (core dashboard components extracted to Components/)
- [x] Improve error handling consistency
- [x] Add logging framework (central Log utility + categories)
- [x] Performance profiling and optimization (PerformanceMonitor + Phase 1–3 optimizations)

---

## 📝 Notes

### Development Priorities
1. Focus on stability and testing before adding new features
2. Maintain comprehensive documentation as features are added
3. Gather user feedback to prioritize feature development
4. Keep codebase clean and well-architected

### Best Practices
- One topic = One document
- Archive instead of delete
- Update TODO.md when completing tasks
- Link related docs together
- Keep user-facing vs technical docs separate
- Write tests for new features
- Update CHANGELOG.md for all releases

---

**Created:** January 18, 2025
**Last Updated:** December 9, 2025
