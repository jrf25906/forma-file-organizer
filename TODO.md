# Project TODO

Canonical roadmap: [Docs/Getting-Started/TODO.md](Docs/Getting-Started/TODO.md).

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
