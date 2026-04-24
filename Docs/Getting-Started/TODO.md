# Forma - Project TODO

**Last Updated:** April 23, 2026

Strategic roadmap: [`forma-feature-roadmap.md`](../../forma-feature-roadmap.md). This document is the execution checklist and historical backlog reference.

---

## Roadmap-Ordered Priorities (April 2, 2026)

Current sequencing is intentionally aligned with the preview-first, moat-driven roadmap.

Implementation plan for the active wave: [`Docs/plans/2026-03-30-preview-first-roadmap-wave-1-plan.md`](../plans/2026-03-30-preview-first-roadmap-wave-1-plan.md).

### Now (0-8 Weeks)
- [x] Ship quick-win onboarding and first-run proof before asking users to configure more rules.
- [x] Add chunked review sessions with `Done for now` semantics so the core workflow feels finite and forgiving.
- [x] Build trust infrastructure first: rule simulation, stronger preflight checks, richer explanations, and clearer scoped rollback.
- [x] Close the Session 2 review follow-up so trust surfaces stay accurate: manual pause/resume events remain manual in audit badges, inspector rule previews invalidate on real snapshot changes, and auto-organize logs enumerate every preflight skip bucket.
- [x] Rewrite automation notifications around progress and system health instead of backlog guilt.
- [x] Preserve structured automation error buckets for scan, bookmark, and destination failures so notifications do not fall back to generic scan summaries.
- [x] Tighten the preview-first flagship workflow so review, rules, explanation, and undo feel like one coherent flow.
- [x] Convert successful one-time Finder/Spotlight review flows into persistent monitored folders.
- [x] Validate native window frame restoration when a saved main window reopens on a smaller display or after display-topology changes.

#### Codebase Audit Remediation (April 23, 2026)
Full report: [`Docs/audits/2026-04-23-forma-audit.md`](../audits/2026-04-23-forma-audit.md). Ten must-fix items from a full-codebase parallel review. Tiers are execution-ordered — A before B before C. Items within a tier are independent.

**Tier A — Same day / pre-release:**
- [x] A1 — Deleted the unconditional `/tmp/thumbnail_debug.log` writer in `ThumbnailService`; thumbnail diagnostics now stay inside the shared logging facade, startup maintenance is scheduled after singleton construction with a retained task handle, and runtime coverage verifies the legacy shared `/tmp` log is not recreated.
- [x] A2 — Gated `UITestFolderAccessConfiguration` behind `#if DEBUG || UI_TESTS`; Release builds now compile a false-only stub so UI/perf argv cannot relax bookmark enforcement, with `Scripts/verify_security_configuration.sh` checking Release binary env/path constraints and the Release `UI_TESTS` compile guard.
- [x] A3 — Fixed `xctestplan` hygiene: added explicit `selectedTests` to default/Unit/Performance/UI plans, un-orphaned current Unit-plan suites, and added `Scripts/verify_test_plan_membership.py` plus CI coverage for membership drift.
- [x] A4 — Added `resolvingSymlinksInPath()` to `PathValidator` and `TrustedAutomationScopeBoundaryDescriptor.SourceBoundary.matches(file:)`; symlink escapes from home-relative paths and trusted scanned scopes now fail with release-visible security logs.

**Tier B — This week:**
- [ ] B1 — Route `FileOperationsService.moveFileUsingBookmark` through the TOCTOU-safe `secureFileMove` path with `withExtendedLifetime` around scoped access.
- [ ] B2 — `WorkflowRunner` must emit `.skipped` step + file-action audit rows when `fileLoop: break` abandons remaining planned files.
- [ ] B3 — Add `isFullyConfigured` gates and `requestConfirmation` to state-mutating `FormaAppIntents`; validate `IntentFile` URLs are bookmark-backed before dispatch.
- [ ] B4 — Decide: wire up or remove `DestinationPredictionService` drift detection + confidence-separation acceptance gate. Plan doc first.

**Tier C — Planning required (structural):**
- [ ] C1 — Adopt SwiftData `VersionedSchema` / `SchemaMigrationPlan` and wrap every `Data`-blob field in a versioned envelope before the next breaking schema change. Needs a dedicated plan doc under `Docs/plans/`.
- [ ] C2 — Extract `FileOperationsServiceProtocol`, inject at every call site, add `MockFileOperationsService`, and delete every inline `FileOperationsService()` construction.

### Next (2-4 Months)
- [x] Start the personal-organization-memory layer before broad cloud or chatbot-style AI expansion.
- [x] Complete progressive automation upgrades so trusted folders, rules, and categories can graduate into visible optional autopilot scopes.
- [x] Plan Metadata Layer v1 with lightweight local metadata such as tags, status, project association, and organization history, biased toward auto-applied metadata before manual tagging UX.
- [x] Extend the shipped metadata-backed project spaces slice beyond read-only retrieval and plan workflow-memory expansion before broad cloud or chatbot-style AI expansion.

### Later (4-8+ Months)
- [ ] Expand the shipped `workflow-engine-v2` slice beyond the current built-in `rename -> tag -> move -> log` path, template-gated trusted-scope `notify`, and manual project-space organize entry into project-space-owned automation triggers and broader metadata-backed automation entry points.
- [ ] Deepen macOS integration beyond current Finder Services, Spotlight, App Intents, and menu bar entry points.
- [ ] Plan backup, sync, and portability for rules, settings, metadata, and organization memory.
- [ ] Evaluate collaboration and shared conventions only after the solo local workflow is stronger.

### Not Now
- Deprioritize generic AI categorization expansion, chat-with-your-files surfaces, cloud AI summaries, and default-on autopilot until the local trust and memory story is stronger.

## Recent Delivered Work
The dated sections below capture shipped work and execution history. Use the roadmap-ordered section above to decide what comes next.

## Critical-Path Optimization Follow-Through (April 15, 2026)
- [x] Batch bulk organize, undo, and redo into one persistence transaction per batch/scope, staging file-item updates, metadata history, activity/audit rows, and personal-memory writes together while compensating successful disk moves if the final save fails.
- [x] Add bounded retention for workflow audit, trusted-scope run history, and personal-memory event history, then switch latest-run and recommendation-evidence reads to the same 90-day bounded query window with count caps.
- [x] Add direct runtime verification for Downloads onboarding so cancelled or unverifiable picker results stay on Get Started with a retryable error instead of completing onboarding.

## Right-Panel Responsive Width Classes (April 10, 2026)
- [x] Add a measured `RightPanelLayout` / `RightPanelWidthClass` contract and keep `FormaSpacing.Column.rightPanelMin/Ideal/Max` as the only right-panel width source of truth.
- [x] Update default-panel, inspector, Smart Rules, inline rule-builder, celebration, and shared right-panel mode-header surfaces so compact-width layouts wrap or stack instead of clipping around fixed child widths.
- [x] Add unit coverage for the `340pt` compact threshold and UI coverage for regular/compact three-column launches across default-panel, inspector, Smart Rules, and inline rule-builder flows.

## App Store Migration Recovery (April 7, 2026)
- [x] Keep pre-metadata app stores launchable by making `ProjectCluster.filePathsSearchBlob` lightweight-migration safe and adding regression coverage for legacy `FileItem`, `LearnedPattern`, and `ProjectCluster` rows opening under the current app schema.

## Personal Organization Memory v1 (April 2, 2026)
- [x] Capture structured decision memory across review-flow organizes, inspector organizes, bulk organize actions, rule-suggestion responses, and undo recoveries.
- [x] Build personal-memory preferences keyed by file extension, file category, source location, and relative parent path so user-specific habits can outrank generic learned-pattern and ML suggestions.
- [x] Preserve the original suggestion on each file, surface a dedicated `Personal Memory` suggestion source in the UI, and keep memory-backed rule suggestions synchronized with analytics pattern detection.
- [x] Add Smart Features summary/reset controls for learned memory and cover the core behavior with targeted personal-memory, precedence, and suggestion-source persistence tests.

## Project-Space Automation Board (April 8, 2026)
- [x] Ship the feature-gated project-space automation board as a policy-centered layer over the existing project-space retrieval slice, with grouped recommendations, active/paused/revoked lifecycle controls, derived health/latest-run context, constrained policy creation, and manual policy runs.
- [x] Keep the legacy manual project-workflow profile as the bridge for existing state, and keep unlabeled files gated behind strong-confirmed project association before workflow execution.

## External Review Folder Promotion (April 1, 2026)
- [x] Detect one-time Finder/Spotlight folder reviews that map cleanly onto bookmark-backed standard folders and carry a promotion candidate through the external review session.
- [x] Show a right-panel/default-panel `Keep monitoring <Folder>` affordance during eligible external review sessions so users can convert the one-time pass into ongoing monitoring in place.
- [x] Persist promoted standard folders through `BookmarkFolderService` without overwriting existing enabled or automation-exclusion preferences, and cover the loop with focused coordinator, dashboard, and service tests.

## Website Header Shell Follow-Up (March 31, 2026)
- [x] Tighten the floating website header shell with a dedicated glass surface, smaller inset/height contract, and stronger hero clearance so the sticky header no longer reads as a washed-out blocker over homepage copy.

## Hybrid A Website Header (March 31, 2026)
- [x] Convert the website header to the approved Hybrid A behavior: quiet top-of-page brand + CTA state, compact split-nav reveal after scroll, warmer shell tokens, and keyboard-safe desktop-nav reveal on focus.

## Adaptive Window Launch Presentation (March 30, 2026)
- [x] Default dashboard launch to `twoColumn` at medium window widths and to `threeColumn` only on wide launches with meaningful default inspector content.
- [x] Persist user-driven inspector visibility across relaunches through `WindowPresentationStore` instead of resetting to an always-open inspector.
- [x] Add targeted UI coverage for medium-width launch, large-width launch, and inspector visibility persistence across relaunches.
- [x] Isolate UI-test window-presentation defaults per suite so screenshot and layout coverage stay deterministic.

## Preview-First Onboarding Wave (March 30, 2026)
- [x] Upgrade first-run proof from a generic folder/count prompt into deterministic quick-win candidates (screenshots, archives, stale downloads, invoices, fallback ready batches), reset onboarding completion into the review-first state, and persist per-candidate dismissals across sessions.

---

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
- [x] Materialize resolvable placeholder destinations on explicit save in Rule Editor and Inline Rule Builder.
- [x] Add a bulk `Create Folders Now` action for resolvable generated-rule destinations.
- [x] Normalize template/default destinations to canonical root-relative paths and prevent duplicate onboarding template seeding.
- [x] Add regression coverage for destination materialization, legacy path normalization, template generation, onboarding scope, and rule health classification.

## Optical Chrome Pass (March 10, 2026)
- [x] Add a shared optical chrome primitive for concentric rims, specular sheen, and stateful elevation in `DesignSystem/FormaControlChrome.swift`.
- [x] Apply the chrome pass to the dashboard toolbar and file-surface actions/states across card/list/grid.
- [x] Apply the same chrome and numeric emphasis rules to the menu bar summary, review card, and button surfaces.
- [x] Rebuild the macOS app after the chrome pass to verify the SwiftUI refactor compiles cleanly.

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

---

## Website Direction Pass (March 1, 2026)
- [x] Ship the approved `C — Honest Utility` design to `forma-website` homepage, including high-fidelity Mac hero shell, simplified section flow, and standardized 3x3 Forma lockups in nav/footer.
- [x] Align remaining website routes (`/blog`, `/blog/[slug]`, `/support`, `/privacy`, `/terms`, `/get-forma`, `/for-agents`) to the same typography and surface system used by the updated homepage.
- [x] Complete a final copy polish pass so headings and body text share one cohesive Forma voice across all marketing routes.
- [x] Run final multi-breakpoint QA (accessibility + layout/spacing), then fix remaining homepage contrast and `/for-agents` small-screen keyboard/scroll usability issues.

---

## Tomorrow Focus (Thursday, February 12, 2026)
- [x] Add accessibility identifiers for selection/focus/row status in `Views/FileRow.swift`, `Views/FileListRow.swift`, `Views/FileGridItem.swift`, and `Views/MainContentView.swift`.
- [x] Replace `sleep()` in UI tests with predicate-based expectations in `Forma File OrganizingUITests/`.
- [x] Add injectable clock/calendar/defaults for `Services/AnalyticsService.swift` and update tests for deterministic time behavior.
- [x] Investigate current task card organized percentage not updating in real time.
- [x] Convert NL parser dataset tests to fixture files with structured assertions.
- [x] Convert remaining constant-only tests to behavioral assertions in `AutomationIntegrationTests.swift`, `OrganizationTemplateTests.swift`, and `RuleServiceTests.swift`.
- [x] Run full macOS tests (unit/integration, then UI test plan) and triage top regressions.
- [x] Evaluate Periphery via `Scripts/periphery.sh` and document baseline strategy (`--retain-public` vs baseline file).
- [x] Timebox `DashboardViewModel` decomposition design (permission state vs undo/redo) and capture a concrete split plan.

---

## Speed & Reliability Sprint (February 12, 2026)
- [x] Add hard performance regression budgets for optimization benchmarks and include `OptimizationBenchmarksTests` in the dedicated performance test plan.
- [x] Reuse precomputed project clusters in default-panel insight generation to avoid duplicate context-detection work.
- [x] Stabilize `FileInsight` identifiers so dismissed quick actions stay dismissed across recomputation.
- [x] Skip redundant content-search runs when query + file snapshot are unchanged and cover with `DashboardViewModelTests`.
- [x] Capture `DashboardScanRefresh` and `DefaultPanelInsightRefresh` p50/p95 using a repeatable signpost harness run.

---

## Next Optimization Batch (Starting February 12, 2026)
- [x] Split `DashboardScanRefresh` into sub-phase signposts to isolate p95/p99 outlier paths.
- [x] Add and document a warm-up cutoff policy for signpost harness analysis.
- [x] Capture a 60+ interval signpost run and record p50/p95/p99 in `Docs/PERFORMANCE_AUDIT.md`.
- [x] Add a reusable `Scripts/` command to run the signpost harness and export summary stats.
- [x] Add pre-PR signpost snapshot steps to `Docs/Development/TESTING.md`.
- [x] Enforce a strict single in-flight default-panel insight refresh path under rapid updates.
- [x] Add scan phase status text in the dashboard for better perceived responsiveness during long operations.

---

## Website SEO + AI Surface Sprint (February 11, 2026)
- [x] Ship conversion-safe CTA instrumentation and optional privacy-first analytics hooks in `forma-website`.
- [x] Expand homepage structured data graph and tighten robots/sitemap crawler directives.
- [x] Launch in-repo MDX blog with initial keyword-targeted guides (`/blog`, `/blog/[slug]`).
- [x] Add machine-readable AI routes (`/llms.txt`, `/for-agents`, `/openapi.json`, `/api/public/*`).
- [x] Document MCP-readiness constraints and planned future tool contracts (`Docs/Marketing/MCP-READINESS.md`).
- [x] Wire the live Mac App Store listing (`id6759181510`) as the default website CTA target so "Download for Mac" no longer depends on placeholder env values.

---

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

## 🚀 Historical Versioned Roadmap

The versioned roadmap below is preserved as a backlog reference. It is **not** the source of truth for sequencing. Use the strategic roadmap above when deciding what to build next.

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

### Later - Portability, Backup, and Cloud
**Status:** Deferred behind trust infrastructure, personal memory, and metadata-backed workflows

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
- [x] Refactor large ViewModels
  - [x] Extract dashboard content-search orchestration into `DashboardContentSearchController` while preserving `DashboardViewModel` content-search APIs.
  - [x] Extract dashboard scan/refresh orchestration into `DashboardScanRefreshController` while preserving `DashboardViewModel` scan/automation APIs and phase-status updates.
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
**Last Updated:** February 12, 2026
