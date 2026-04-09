# Project TODO

**Last Updated:** April 8, 2026

Strategic roadmap: [forma-feature-roadmap.md](forma-feature-roadmap.md). Execution checklist: [Docs/Getting-Started/TODO.md](Docs/Getting-Started/TODO.md).

This file is ordered to match the strategic roadmap. Dated sprint logs and shipped execution history remain below as reference.

## Roadmap-Ordered Priorities (April 2, 2026)
Current wave implementation plan: [Docs/plans/2026-03-30-preview-first-roadmap-wave-1-plan.md](Docs/plans/2026-03-30-preview-first-roadmap-wave-1-plan.md).

### Now (0-8 Weeks)
- [x] Quick-win onboarding and first-run proof so Forma demonstrates value before asking users to configure rules.
- [x] Batch UX that hides overwhelm with chunked review sessions and `Done for now` semantics.
- [x] Build trust infrastructure: rule simulation, stronger preflight checks, richer reasoning, and clearer scoped rollback.
- [x] Close the Session 2 review follow-up so trust surfaces stay accurate: manual pause/resume events remain manual in audit badges, inspector rule previews invalidate on real snapshot changes, and auto-organize logs enumerate every preflight skip bucket.
- [x] Reset automation notification tone around progress and system health instead of backlog guilt.
- [x] Preserve structured automation error buckets for scan, bookmark, and destination failures so notifications do not fall back to generic scan summaries.
- [x] Tighten the preview-first flagship workflow so review, rules, explanation, and undo feel like one coherent flow.
- [x] Convert successful one-time Finder/Spotlight folder review flows into persistent monitored folders.
- [x] Validate native window frame restoration when a saved main window reopens on a smaller display or after display-topology changes.

### Next (2-4 Months)
- [x] Start the personal-organization-memory layer so Forma compounds from user-specific behavior rather than generic AI classification.
- [x] Complete progressive automation upgrades so trusted folders, rules, and categories can graduate into visible optional autopilot scopes.
- [x] Plan Metadata Layer v1 with lightweight local metadata such as tags, status, project association, and organization history, biased toward auto-applied metadata before manual tagging UX.
- [x] Extend the shipped metadata-backed project spaces slice beyond read-only retrieval and plan workflow-memory expansion before broad cloud or chatbot-style AI expansion.

### Later (4-8+ Months)
- [ ] Expand the shipped `workflow-engine-v2` slice beyond the current built-in `rename -> tag -> move -> log` path and template-gated trusted-scope `notify` into project-space-triggered flows and broader metadata-backed automation entry points.
- [ ] Deepen macOS integration beyond current Finder Services, Spotlight, App Intents, and menu bar entry points.
- [ ] Plan backup, sync, and portability for rules, settings, metadata, and organization memory.
- [ ] Evaluate collaboration and shared conventions only after the solo local workflow is stronger.

### Not Now
- Deprioritize generic AI categorization expansion, chat-with-your-files surfaces, cloud AI summaries, and default-on autopilot until the local trust and memory story is stronger.

## Historical Delivery Log
The sections below capture dated implementation slices that have already shipped or were completed as part of earlier waves. Active roadmap work is tracked above.

## Workflow Engine v2 Notify + Log (April 8, 2026)
- [x] Add `WorkflowInvocationContext` and template-level notification policy so review-driven runs always plan `log`, while trusted-scope `Project Drop Zone` runs can append workflow-native `notify`.
- [x] Add `LogWorkflowStepExecutor`, `NotifyWorkflowStepExecutor`, `WorkflowNotificationServing`, and honest `completedWithIssues` audit semantics so non-blocking side-effect failures do not rollback successful durable file mutations.
- [x] Centralize workflow summary emission in `WorkflowRunner`, remove caller-side duplicate activity logging from dashboard/review/bulk entry points, and suppress generic automation summaries when a workflow-native notify step is already planned.

## Progressive Automation Upgrades (April 8, 2026)
- [x] Promote review-earned folder, rule, and category trust into explicit autopilot boundaries backed by `TrustedAutomationScopeBoundaryDescriptor`, `TrustedAutomationScopeRunRecord`, and `TrustedAutomationScopeResolver`.
- [x] Ship first-class autopilot scope UI in the default panel and Smart Features, including active/paused/revoked grouping, derived health, recent runs, and pause/resume/revoke lifecycle controls.
- [x] Make trusted-scope promotion, preflight, notifications, and activity scope-aware while keeping move-only automation and review-earned trust as the product boundary.
- [x] Land Task 5 of `workflow-engine-v2`: require explicit built-in template selection for feature-gated ad hoc organize flows, add shared template-picker + simulation-preview state on dashboard/review/inspector surfaces, preserve trusted-scope recommendations on the v2 single-file review path, keep blocked v2 batches as partial failures with workflow-aware retry, and route dashboard, bulk, inspector, and review organizes through `WorkflowRunner` when `Feature.workflowEngineV2` is enabled while keeping legacy organize behavior when it is off.
- [x] Tighten the shipped Task 5 behavior so workflow-v2 partial-success toasts do not offer dead undo affordances and successful v2 single-file organizes still feed accepted decisions into personal-memory learning.
- [x] Finish the shipped `workflow-engine-v2` slice with the built-in template catalog, shared planner/runner, rollback coordination, trusted-scope template ownership, workflow audit persistence, and activity/inspector audit surfaces for the feature-gated `rename -> tag -> move` path.

## App Store Migration Recovery (April 7, 2026)
- [x] Keep pre-metadata app stores launchable by making `ProjectCluster.filePathsSearchBlob` lightweight-migration safe and adding regression coverage for legacy `FileItem`, `LearnedPattern`, and `ProjectCluster` rows opening under the current app schema.

## Personal Organization Memory v1 (April 2, 2026)
- [x] Record structured personal-memory events from review-flow organizes, inspector organizes, bulk organizes, undo recoveries, and rule-suggestion accept/dismiss loops.
- [x] Persist destination preferences by file extension, file category, source location, and relative parent path so repeated choices can outrank generic pattern and ML suggestions.
- [x] Feed personal-memory predictions into the scan pipeline ahead of learned patterns, preserve each file's original suggestion for later correction/undo learning, and label memory-sourced suggestions in the UI.
- [x] Derive reusable rule suggestions from stable personal-memory preferences, expose a memory summary/reset surface in Smart Features, and cover the loop with targeted personal-memory and precedence tests.

## Trusted Automation Scope Promotion Foundations (April 3, 2026)
- [x] Persist shared trusted automation scopes for rule, folder, and category trust boundaries with lifecycle controls and a feature-flagged app entry point.
- [x] Derive review-earned trusted-scope recommendations from personal-memory evidence, preferring rule, then folder, then category scope candidates when confidence is high and recent undo/correction signals stay low.
- [x] Surface `Trust this automatically` in the review celebration flow with a recommended-scope sheet that can promote the selected scope into immediate move-only autopilot behavior.
- [x] Tighten trust-scope promotion so only review-earned evidence unlocks trust, folder scopes stay bound to the reviewed subtree, stale rule destinations are not silently rearmed even when folders share a label, derived rules use the confirmed bookmark from review instead of same-name preference history, and undo/celebration state invalidates staged recommendations without resetting the success timer.

## Metadata Foundation v1 (April 3, 2026)
- [x] Ship the durable local metadata foundation for scan, organize, undo, redo, and inspector proof surfaces with `FileMetadataRecord`, `FileOrganizationHistoryEntry`, `FileMetadataInspectorSummary`, and `FileMetadataFoundationService`.
- [x] Complete durable workflow status v1 so scan discovery seeds `queued`, organize/undo/ignore lifecycle writes persist `organized` / `recovered` / `ignored`, skip actions capture durable-status snapshots for undo/redo, and inspector proof exposes one read-only workflow-status line behind `FeatureFlagService.Feature.durableWorkflowStatus`.
- [ ] Build on the shipped `workflow-engine-v2` slice with additional metadata-backed step kinds, broader audit projections, and richer workflow-memory layers beyond the current built-in `rename -> tag -> move -> log` path plus template-gated trusted-scope `notify`.
- [ ] Keep metadata-backed workflow-memory expansion open beyond v1; the shipped slices now include read-only project-space retrieval, richer project-space detail/correction, and narrow project-memory destination suggestions, while broader editing, workflow execution, and richer memory layers remain later work.

## Auto-Applied Project Association v1 (April 6, 2026)
- [x] Add the feature-gated `autoProjectAssociation` resolver layer with `ProjectAssociationWriteContext`, `MetadataProjectAssociationResolver`, exact `Projects/...` explicit qualification, cluster-organize explicit opt-in, and strong-winner inferred fallback.
- [x] Write durable `projectAssociation` labels during scan and explicit-file evaluation using stored active `ProjectCluster` rows plus exact `Projects/...` destinations, while keeping metadata writes best-effort and provenance label-only.
- [x] Persist explicit project association through single-file organize, cluster-driven bulk organize, redo, and undo by carrying project-association context in metadata snapshots and preserving the stored label on undo.
- [x] Keep the broader metadata roadmap open: this slice remains label-only and auto-applied, now powering shipped read-only project-space retrieval while still avoiding manual metadata editing and workflow-chain expansion.

## Cross-Folder Project Spaces v1 (April 6, 2026)
- [x] Ship the feature-gated `projectSpaces` dashboard retrieval slice with `ProjectSpacesSection`, `ProjectSpaceDetailView`, and `DashboardViewModel` selection state so known project groupings are browseable across folders without creating a separate project entity.
- [x] Base project-space membership strictly on durable `projectAssociation` labels already stored in `FileMetadataRecord`, using the metadata foundation retrieval path instead of speculative live inference.
- [x] Limit v1 membership to files that still resolve locally through existing path/bookmark lookup, so missing files do not appear as historical placeholders.
- [x] Keep the roadmap honest: v1 is read-only retrieval only, while manual project editing, workflow execution from spaces, and broader workflow-memory expansion remain future work.

## Cross-Folder Project Spaces v2 (April 7, 2026)
- [x] Expand project-space detail beyond membership-only retrieval with overview, preferred destinations, and recent activity derived from durable metadata/history through `ProjectSpaceMemoryResolver`.
- [x] Add a narrow project-space correction flow so one file's durable `projectAssociation` can be corrected from project-space detail without opening broad metadata editing.
- [x] Feed dominant recent project destination memory into the scan pipeline ahead of learned patterns and ML only for files that already have a durable project association, and label those suggestions as `Project` in the dashboard UI.

## Auto-Applied Content Tags v1 (April 6, 2026)
- [x] Add the feature-gated durable content-tag layer with a small built-in vocabulary, explicit-signal-first resolution, and conservative inference through `MetadataContentTag`, `MetadataContentTagResolver`, and metadata-foundation write paths.
- [x] Expose metadata-backed content-tag quick filters in the dashboard with `FileFilterManager`, `DashboardViewModel`, `MainContentView`, and `ActiveFiltersBar`, while keeping the slice read-only and avoiding manual tag editing or Finder tag sync.
- [x] Tighten quick-filter behavior so selected tags remain stable when the base scope changes, active-filter chips can remove one tag at a time, deferred review state stays isolated by selected content-tag scope, and filter caching invalidates when selected tags or the durable tag index changes.

## Permission Grant Recovery Fixes (April 1, 2026)
- [x] Stop dashboard/JIT folder permission grants from re-showing onboarding when the sheet was already dismissed.
- [x] Refresh newly granted folder availability immediately and reduce the delayed rescan debounce so permission unlocks feel more responsive.

## External Review Folder Promotion (April 1, 2026)
- [x] Detect eligible one-time Finder/Spotlight folder reviews that map to standard bookmark-backed folders (`Desktop`, `Downloads`, `Documents`, `Pictures`, `Music`) and carry a promotion candidate through the external review session.
- [x] Surface a default-panel `Keep monitoring <Folder>` affordance during eligible external review sessions so users can promote a one-time folder review into ongoing monitoring without leaving the workflow.
- [x] Persist promoted standard folders through `BookmarkFolderService` without resetting existing enabled or automation-exclusion preferences, and cover the path with targeted coordinator, dashboard, and bookmark-service tests.

## Luma Refresh Follow-Ups (March 31, 2026)
- [x] Honor `accessibilityReduceTransparency` in `SidebarGlassOverlay` so the sidebar sheen falls back cleanly when macOS Reduce Transparency is enabled.
- [x] Add one browser-level assertion for newsletter success-focus behavior and revisit the regex-based homepage shell-boundary coverage if homepage section nesting changes.

## Website Header Shell Follow-Up (March 31, 2026)
- [x] Tighten the floating website header shell with a dedicated glass surface, smaller inset/height contract, and stronger hero clearance so the sticky header no longer reads as a washed-out blocker over homepage copy.

## Hybrid A Website Header (March 31, 2026)
- [x] Convert the website header to the approved Hybrid A behavior: quiet top-of-page brand + CTA state, compact split-nav reveal after scroll, warmer shell tokens, and keyboard-safe desktop-nav reveal on focus.

## Stability Fixes (March 31, 2026)
- [x] Restore lightweight migration for legacy `StorageSnapshot` rows created before `folderBreakdownData` existed so existing installs no longer crash during SwiftData container startup.

## Preview-First Onboarding Wave (March 30, 2026)
- [x] Surface a first-run quick-win banner only when Forma has a meaningful visible ready batch, scope the CTA to that batch instead of every ready file in the current dashboard state, and suppress the banner during focused external review sessions.
- [x] Upgrade first-run proof from a generic folder/count prompt into deterministic quick-win candidates (screenshots, archives, stale downloads, invoices, fallback ready batches), reset onboarding completion into the review-first state, and persist per-candidate dismissals across sessions.

## Adaptive Window Launch Presentation (March 30, 2026)
- [x] Default dashboard launch to `twoColumn` at medium window widths and to `threeColumn` only on wide launches with meaningful default inspector content.
- [x] Persist user-driven inspector visibility across relaunches through `WindowPresentationStore` instead of resetting to an always-open inspector.
- [x] Add targeted UI coverage for medium-width launch, large-width launch, and inspector visibility persistence across relaunches.
- [x] Isolate UI-test window-presentation defaults per suite so screenshot and layout coverage stay deterministic.

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

## Realtime Filesystem Watching (March 25, 2026)
- [x] Add an `FSEvents`-backed `FileMonitorService` for enabled bookmark-backed standard folders, with debounced root-level change coalescing.
- [x] Route watcher changes through `AutomationEngine` as targeted rescans and queue one follow-up realtime rescan instead of starting overlapping scans.
- [x] Merge partial automation refreshes by scanned root so dashboard and menu bar stay correct after create/delete/rename/modify events.
- [x] Surface live watching state in automation UI copy and keep scheduled interval sweeps as the recovery path.

## Folder Health Alerts (March 25, 2026)
- [x] Persist per-folder snapshot bytes alongside category breakdowns for analytics history.
- [x] Add user-configurable folder-size thresholds and a global stale-rule inactivity threshold in Smart Features.
- [x] Centralize folder/stale-rule evaluation so Rules, Analytics, and automation notifications use the same alert state.
- [x] Send and clear dedicated folder health/stale-rule notifications from `AutomationEngine` after successful scans.

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
