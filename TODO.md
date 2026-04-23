# Project TODO

**Last Updated:** April 23, 2026

Strategic roadmap: [forma-feature-roadmap.md](forma-feature-roadmap.md). Execution checklist: [Docs/Getting-Started/TODO.md](Docs/Getting-Started/TODO.md).

This file is ordered to match the strategic roadmap. Dated sprint logs and shipped execution history remain below as reference.

## Roadmap-Ordered Priorities (April 10, 2026)
Current active plans: [Docs/plans/2026-03-30-preview-first-roadmap-wave-1-plan.md](Docs/plans/2026-03-30-preview-first-roadmap-wave-1-plan.md), [Docs/superpowers/plans/2026-04-10-forma-optimization-program.md](Docs/superpowers/plans/2026-04-10-forma-optimization-program.md).

### Now (0-8 Weeks)
#### Critical-Path Optimization Program
- [x] Add retention and pruning for workflow audit, trusted-scope, and personal-memory history so background loops cannot grow launch- and undo-adjacent tables without bounds.
- [x] Replace watched-folder full-refresh behavior with touched-path incremental updates so a one-file drop does not pay for a whole-dashboard refresh.
- [x] Split launch into first-paint work and deferred maintenance, and make startup scan ownership singular.
- [x] Harden launch-scan completion and UI/perf harness folder defaults so cancelled startup scans retry cleanly and permission state matches bookmark-backed availability.
- [x] Rework bulk organize, undo, and redo into one-transaction paths with batched metadata, audit, and personal-memory writes.
- [x] Move inspector matching, simulation, and metadata proof to selection-local caches so open/detail/close avoid global scans.
- [x] Centralize rule writes and shift rule preview/save verification to delta-based evaluation instead of global re-evaluation.

- [x] Quick-win onboarding and first-run proof so Forma demonstrates value before asking users to configure rules.
- [x] Batch UX that hides overwhelm with chunked review sessions and set-aside deferrals.
- [x] Build trust infrastructure: rule simulation, stronger preflight checks, richer reasoning, and clearer scoped rollback.
- [x] Close the Session 2 review follow-up so trust surfaces stay accurate: manual pause/resume events remain manual in audit badges, inspector rule previews invalidate on real snapshot changes, and auto-organize logs enumerate every preflight skip bucket.
- [x] Reset automation notification tone around progress and system health instead of backlog guilt.
- [x] Preserve structured automation error buckets for scan, bookmark, and destination failures so notifications do not fall back to generic scan summaries.
- [x] Tighten the preview-first flagship workflow so review, rules, explanation, and undo feel like one coherent flow.
- [x] Convert successful one-time Finder/Spotlight folder review flows into persistent monitored folders.
- [x] Validate native window frame restoration when a saved main window reopens on a smaller display or after display-topology changes.

#### Codebase Audit Remediation (April 23, 2026)
Reference: [Docs/audits/2026-04-23-forma-audit.md](Docs/audits/2026-04-23-forma-audit.md). Ten must-fix items extracted from a full-codebase parallel review. Tiers are ordered — work A before B before C. Within a tier, items are independent.

**Tier A — Same day / pre-release (low-risk, high-impact):**
- [x] A1 — Deleted the unconditional `/tmp/thumbnail_debug.log` writer in `ThumbnailService`; thumbnail diagnostics now stay inside the shared logging facade, startup maintenance is scheduled after singleton construction with a retained task handle, and runtime coverage verifies the legacy shared `/tmp` log is not recreated.
- [x] A2 — Gated `UITestFolderAccessConfiguration` behind `#if DEBUG || UI_TESTS`; Release builds now compile a false-only stub so UI/perf argv cannot relax bookmark enforcement, with `Scripts/verify_security_configuration.sh` checking Release binary env/path constraints and the Release `UI_TESTS` compile guard.
- [ ] A3 — Add `selectedTests` to the default `Forma File Organizing.xctestplan`, un-orphan the ~10 missing test files from the Unit plan allowlist, and add a CI lint diffing test files against plan membership.
- [ ] A4 — Add `resolvingSymlinksInPath()` to `PathValidator` and `TrustedAutomationScopeBoundaryDescriptor.SourceBoundary.matches(file:)` so a symlink inside a trusted/scanned scope cannot escape the boundary check.

**Tier B — This week (medium complexity, high-value):**
- [ ] B1 — Route `FileOperationsService.moveFileUsingBookmark` through `secureFileMove` so TOCTOU protection, FD-validated `renameat`, and `withExtendedLifetime` apply on the production bookmark move path.
- [ ] B2 — Make `WorkflowRunner` emit `.skipped` step audits and `WorkflowFileActionRecord` rows for every file abandoned after a `fileLoop: break`, with an explicit `abandonedAfterUpstreamFailure` reason.
- [ ] B3 — Gate every `FormaAppIntents.perform()` on `FormaActions.shared.isFullyConfigured`, require `requestConfirmation` for `ToggleAutomationIntent`, and validate each `IntentFile` URL is bookmark-backed before dispatch.
- [ ] B4 — Decide fate of `DestinationPredictionService` drift detection and confidence-separation acceptance gate: Phase 0 evaluator repairs landed (shared Core ML probability parsing when exposed, off-main train/compile/load/evaluation, explicit label-only rejection without invented confidence, confidence-separation rejection notes, bounded sample-before-cap dataset split, POSIX UTC model versions); remaining work is the offline backtest, live shadow measurement, and either accept/override telemetry or removal of the drift branch.

**Tier C — Planning required (structural, do before next schema change or release):**
- [ ] C1 — Adopt `VersionedSchema` / `SchemaMigrationPlan` across `Models/` and wrap every `Data`-blob field (`RuleCategory.scopeData`, `LearnedPattern.destinationData`, `FileItem._destinationBookmarkData`, `TrustedAutomationScope.boundaryDescriptorData`, workflow compensation payloads, etc.) in a `VersionedBlob<T>` envelope. Needs its own plan doc under `Docs/plans/`.
- [ ] C2 — Extract `FileOperationsServiceProtocol`, inject at every call site (`UndoCommand`, `ReviewViewModel`, `BulkOperationViewModel`, `DashboardViewModel`, `MoveWorkflowStepExecutor`, `RenameWorkflowStepExecutor`), add `MockFileOperationsService`, and delete every inline `FileOperationsService()` construction.

### Next (2-4 Months)
#### Optimization Follow-Ons
- [ ] Surface watched-folder setup from common review and folder-entry surfaces instead of requiring a settings detour.
- [ ] Route learned-pattern suggestions into a staged builder with preview and explicit verification before saving.
- [ ] Simplify inspector close/reasoning affordances once the inspector open path is already fast.
- [ ] Compress onboarding only where it improves time-to-first-value after the hot paths are within budget.

- [x] Start the personal-organization-memory layer so Forma compounds from user-specific behavior rather than generic AI classification.
- [x] Complete progressive automation upgrades so trusted folders, rules, and categories can graduate into visible optional autopilot scopes.
- [x] Plan Metadata Layer v1 with lightweight local metadata such as tags, status, project association, and organization history, biased toward auto-applied metadata before manual tagging UX.
- [x] Extend the shipped metadata-backed project spaces slice beyond read-only retrieval and plan workflow-memory expansion before broad cloud or chatbot-style AI expansion.

### Later (4-8+ Months)
- [ ] Expand the shipped `workflow-engine-v2` slice beyond the current built-in `rename -> tag -> workflowStatus -> move -> log` (`Dated Archive`) and `rename -> tag -> projectAssociation -> workflowStatus -> notesSummary -> move -> log` executed paths, shipped run/step/file audit depth, template-backed trusted-scope action shapes plus template-gated `notify`, the current shared workflow execution-request layer, workflow-backed menu bar/App Intents/Finder Services/Spotlight entry points, and the new project-space/trusted-scope workflow-memory profiles into additional metadata-backed step kinds and later OS-facing workflow entry points.
- [ ] Deepen macOS integration beyond the now workflow-backed Finder Services, Spotlight, App Intents, and menu bar entry points.
- [ ] Plan backup, sync, and portability for rules, settings, metadata, and organization memory.
- [ ] Evaluate collaboration and shared conventions only after the solo local workflow is stronger.

### Not Now
- Deprioritize generic AI categorization expansion, chat-with-your-files surfaces, cloud AI summaries, and default-on autopilot until the local trust and memory story is stronger.

## Historical Delivery Log
The sections below capture dated implementation slices that have already shipped or were completed as part of earlier waves. Active roadmap work is tracked above.

## Right-Rail Editorial Mission Control (April 22, 2026)
- [x] Rework `DefaultPanelView` so the default right rail reads as a narrative instead of stacked neutral widgets: a soft editorial `Current Task` hero, a live automation beacon, and a unified `Next Moves` briefing feed.
- [x] Replace the old automation card treatment with a stateful `AutomationStatusWidget` that keeps schedule timing in hover help on the live chip, surfaces compact trust metrics, and uses a full-width split `Scan now` / `Pause or Resume` footer control.
- [x] Normalize external review promotion, file insights, and learned-pattern suggestions into one deterministic editorial recommendation model with a featured first item, subtle provenance, and full-card actions.
- [x] Flatten the second-pass right-rail composition so hero and automation metrics render as divider-based shared shelves instead of nested mini-cards, the automation summary lives directly in the main beacon card, and `Next Moves` actions sit in footer rows rather than compressing the title line.
- [x] Tighten the third-pass semantics so the hero is fully pass-scoped, the ring is removed, the category shelf stays stable for the life of the pass, automation metrics use human-facing labels, the review floating bar reports blocked states honestly, and the rail accents map to a smaller semantic color system.
- [x] Land the compressed-editorial `v4` follow-through so the featured `Next Moves` card uses a compact metadata row, full-width title/summary copy, explicit `Why it matters` framing, and a pinned footer CTA with deterministic UI-test probes.
- [x] Finish the boundary-flattening follow-up so the hero category shelf stays compact, the automation module reads as one surface instead of a card within a card, and the outer `Next Moves` wrapper quiets down enough for the featured recommendation to carry the hierarchy.

## Dashboard Workspace State Contract (April 21, 2026)
- [x] Add an explicit dashboard root-workspace contract so `Home`, `Analytics`, and left-nav `Smart Rules` are routed as distinct destinations instead of overloading compact right-panel modes.
- [x] Keep `Home` on the working three-area layout by default, persist the preferred inspector width through `WindowPresentationStore`, and restore the exact prior inspector visibility/mode/width when returning from destination screens.
- [x] Route left-sidebar and global dashboard `Analytics` / `Smart Rules` actions to full-workspace destinations with `Back to Dashboard`, while preserving compact right-panel rule creation for contextual file and review flows.

## Right-Panel Responsive Width Classes (April 10, 2026)
- [x] Introduce a shared `RightPanelLayout` / `RightPanelWidthClass` contract driven by measured detail-column width, using `FormaSpacing.Column.rightPanelMin/Ideal/Max` as the single right-panel width source of truth.
- [x] Make the default panel, inspector, Smart Rules, inline rule builder, celebration flows, and shared right-panel mode chrome reflow in compact widths instead of relying on fixed child widths.
- [x] Add unit coverage for the compact threshold at `340pt` plus dedicated UI coverage for regular and compact three-column launches across the default panel, inspector, Smart Rules, and inline rule-builder paths.

## Responsive Three-Column Layout Follow-Up (April 10, 2026)
- [x] Add a shared `FileSurfaceLayout` / `FileSurfaceWidthClass` contract in `MainContentView`, switching center-pane file surfaces into compact composition below `760pt` of usable content width.
- [x] Make card, list, and grid file surfaces keep identity, metadata, and primary actions readable in narrow three-column layouts by moving actions onto their own compact row/block instead of compressing one horizontal strip.
- [x] Treat saved inspector visibility as a launch preference filtered through `DashboardLaunchPresentation.inspectorEligibleWidth`, so narrow relaunches reopen in two-column mode while preserving the saved preference for later wide launches.

## Trusted-Scope Startup Performance Fix (April 10, 2026)
- [x] Stop `DashboardViewModel.setModelContext(_:)` from eagerly refreshing trusted automation scopes during initial window restoration, so startup and resize do not block on hidden right-panel summary work.
- [x] Defer the default panel's trusted-scope refresh onto a scheduled post-appearance task instead of running it inside the first render/layout turn.
- [x] Cache decoded category scopes and resolved scoped-folder paths per shared category in `RuleOverlapDetector`, eliminating repeated JSON decode and bookmark resolution churn during trusted-scope health classification.

## Review-Flow Follow-up Polish (April 9, 2026)
- [x] Scope Current Task progress to the active review pass and preserve a stable pass denominator after organizing files instead of backfilling from later pending items.
- [x] Tighten review-section subtitles, normalize `Needs destination` through the shared badge pill treatment, and keep review-surface checkboxes persistently visible with full-size hit targets.
- [x] Replace the generic automation placeholder card with contextual watched-root / recent-run / preflight summaries, hiding the card entirely when automation has nothing meaningful to say.
- [x] Add explicit sidebar `Request Access` affordances for locked standard folders plus destination-edit power-user entry points via row context menus, the command palette, and the focused-row `E` shortcut.
- [x] Verify that the seeded UI-test review dataset still uses synthetic `/Users/test/...` fixture paths, so generic icons there are expected and this pass does not change thumbnail behavior.

## Developer Workflow Docs (April 9, 2026)
- [x] Add repo-local guidance for using the `build-macos-apps` plugin against the native Forma app, including a reusable Codex prompt and verification checklist wired to the repo's declared commands and release scripts.
- [x] Add a project-local `script/build_and_run.sh` entrypoint and wire `.codex/environments/environment.toml` so the Codex app `Run` action builds and launches Forma through one maintained command.

## Overnight QA Follow-Up (April 9, 2026)
- [x] Restore file-surface parity so grid view exposes `Choose Destination` for files without a destination the same way card/list already do.
- [x] Update `AppStoreScreenshotTests` for the current sidebar/inspector information architecture so the screenshot flow matches the shipped Smart Rules and rule-management paths.
- [x] Stabilize `FileSurfaceToolbarValidationTests.testCaptureFileSurfaceAndToolbarValidationShots` so the screenshot flow reliably returns to card mode and captures the expected surface states.
- [x] Add direct runtime verification for onboarding permission recovery and inspector visibility persistence across relaunches.
- [x] Add direct runtime verification for onboarding folder selection.
- [x] Repair the performance validation path so `OptimizationBenchmarksTests` and `Scripts/signpost_harness_snapshot.sh` produce usable benchmark/signpost outputs again.

## Review-First Selection App Intent (April 9, 2026)
- [x] Add a persisted `ExternalIngressExecutionMode` so external requests can distinguish immediate runs from review-first runs without splitting the ingress pipeline.
- [x] Keep review-first external requests auto-organizing safe selected items while opening Forma only when reviewable items remain, not for skip-only or already-finished outcomes.
- [x] Add a multi-item `ReviewSelectionIntent` Shortcut/App Intent that routes through the shared external-ingress path and uses honest result copy for review-needed, onboarding-resume, and recovery-only outcomes.

## Sidebar / Right-Panel Cleanup Follow-Up (April 8, 2026)
- [x] Route sidebar and default-panel Analytics actions through an explicit right-panel opener so Analytics reliably reveals the inspector column instead of only changing hidden panel mode.
- [x] Remove the obsolete `NavigationSelection.rules` / `.analytics` compatibility route and the dead `MainContentView` / dashboard CTA branches that still modeled Smart Rules and Analytics as navigation destinations.
- [x] Align `DashboardView` window sizing with `FormaSpacing.Window` tokens so the shipped 1280px minimum layout no longer competes with a stale hardcoded 1200px frame.

## Split-View Inspector Stability (April 9, 2026)
- [x] Keep `DashboardView` on explicit `sidebar + content`, `sidebar + content + inspector`, and `sidebar + analytics` split-view layouts so hiding the inspector keeps the real sidebar visible and reopening it restores the expected wide-window geometry without the old left-pane morph.
- [x] Add focused split-layout coverage so the hidden/visible inspector states and relaunch persistence are asserted directly alongside the existing medium/large launch UI coverage.

## Workflow Engine v2 Notify + Log (April 8, 2026)
- [x] Add `WorkflowInvocationContext` and template-level notification policy so review-driven runs always plan `log`, while trusted-scope `Project Drop Zone` runs can append workflow-native `notify`.
- [x] Add `LogWorkflowStepExecutor`, `NotifyWorkflowStepExecutor`, `WorkflowNotificationServing`, and honest `completedWithIssues` audit semantics so non-blocking side-effect failures do not rollback successful durable file mutations.
- [x] Centralize workflow summary emission in `WorkflowRunner`, remove caller-side duplicate activity logging from dashboard/review/bulk entry points, and suppress generic automation summaries when a workflow-native notify step is already planned.

## Workflow Engine v2 Metadata Step Planning (April 9, 2026)
- [x] Extend the built-in workflow schema so templates can opt into metadata-backed `projectAssociation` and `workflowStatus` steps, and let `Project Drop Zone` plan those steps between `tag` and `move`.
- [x] Teach `WorkflowPlanner` to derive project-label-backed metadata targets from project-space and project-policy invocation contexts, while blocking unlabeled project invocations at the metadata step and skipping later dependent steps in simulation.
- [x] Extend workflow compensation descriptors/codecs so the new metadata-backed planned steps can carry rollback intent through the shared workflow models before executor work lands.

## Workflow Engine v2 Metadata Step Execution (April 9, 2026)
- [x] Add shared `ProjectAssociationWorkflowStepExecutor` and `WorkflowStatusWorkflowStepExecutor` implementations so metadata-backed steps execute through the same `WorkflowRunner` path as rename, tag, and move.
- [x] Extend `FileMetadataFoundationService` with explicit workflow-owned project-association and workflow-status preview/apply/restore helpers instead of routing these writes through inference-only metadata paths.
- [x] Keep workflow rollback honest by restoring metadata-backed step state through compensation and by recording path rollback transitions without clobbering restored workflow status back to generic `.recovered`.

## Workflow Engine v2 Audit Depth (April 9, 2026)
- [x] Persist richer run audit context in `WorkflowRunRecord` and `WorkflowAuditStore`, including trigger surface, owner display name, and project-policy label, so project-space and project-policy runs keep their caller identity.
- [x] Record preflight `planned`, `blocked`, and `skipped` step rows through `WorkflowRunner` so blocked plans and partial simulations show honest run/step audit state before execution starts.
- [x] Persist file-level metadata deltas for tags, project association, and workflow status, then project that context back into `WorkflowRunDetailSheet`, `DashboardViewModel.latestWorkflowInspectorSummary(...)`, `FileInspectorView`, and workflow activity wording.
- [x] Preserve rollback metadata summaries on restored file-action rows by inverting forward metadata deltas, so rollback audit explains removed tags and restored project/workflow state instead of dropping that context.

## Workflow Engine v2 Notes Summary + Request Adoption (April 9, 2026)
- [x] Extend the built-in workflow schema with a constrained `notesSummary` step and let `Project Drop Zone` plan `rename -> tag -> projectAssociation -> workflowStatus -> notesSummary -> move -> log` from project-space and project-policy contexts.
- [x] Add `NotesSummaryWorkflowStepExecutor` plus workflow-owned notes-summary preview/apply/restore helpers in `FileMetadataFoundationService`, and persist forward/rollback notes-summary audit deltas through the shared runner path.
- [x] Migrate the remaining review and inspector ad hoc workflow-v2 callers onto explicit `WorkflowExecutionRequest` launches so `ReviewViewModel` and `DashboardOrganizationController` no longer rely on the legacy bare template + invocation-context overloads.

## Workflow Engine v2 Next Step Kinds (April 9, 2026)
- [x] Add the built-in `Dated Archive` template so the shipped catalog now includes a constrained `rename -> tag -> workflowStatus -> move -> log` archive-oriented path alongside receipts, screenshots, and project drop.
- [x] Broaden workflow-owned status beyond project-only `organized` by adding durable `.archived`, while keeping `projectAssociation` and `notesSummary` project-scoped and allowing templates that opt into `workflowStatus` to plan that metadata step from non-project and trusted-scope invocations.
- [x] Preserve explicit archived workflow-state writes through downstream organize/move history updates so the archive template's metadata delta survives the full runner path and audit surfaces.

## Workflow Engine v2 OS Entry Points (April 9, 2026)
- [x] Add a shared manual-template selection store and entry-point organizer so manual OS-facing workflow launches can all resolve through first-class `WorkflowExecutionRequest` runs.
- [x] Route menu bar organize actions through workflow-engine-v2 when `Feature.workflowEngineV2` is enabled, including shared template selection, simulation preview, and disabled-state guidance when no template is selected.
- [x] Route Finder Services / Spotlight external ingress and App Intents organize actions through workflow-engine-v2 requests while preserving template identity, OS-specific trigger-surface audit context, and legacy organize behavior only when the feature flag is off.

## macOS Integration OS Surface Adoption (April 9, 2026)
- [x] Replace the flattened external-review `statusText` handoff with a shared `ExternalIngressOutcomeSummary` carried by `ExternalIngressResult` and `ExternalReviewSession`, preserving counts for auto-organized, review-needed, skipped, and reauthorization-required outcomes.
- [x] Use the structured external-ingress outcome model in dashboard review toasts so focused OS-launched review sessions render shared summary copy instead of recomputing status strings ad hoc.
- [x] Add summary-driven selected-item App Intent feedback and menu bar workflow guidance so Spotlight/Shortcuts users get explicit review follow-up language while the menu bar explains missing-template and all-blocked simulation states before running.

## Workflow Engine v2 Memory Profiles (April 9, 2026)
- [x] Expand `ProjectSpaceWorkflowProfile` into workflow-memory v2 with successful-template counts/recency, dominant trigger surface, latest successful destination signal, stable/stale/conflicted status, and legacy-profile hydration instead of only remembering a preferred template plus latest run.
- [x] Feed that memory from shared `WorkflowRunner` outcomes via `WorkflowExecutionRequest.workflowMemoryAttribution`, counting durable successes once per run, ignoring blocked-preflight-only runs, and marking conflicting failures without over-strengthening memory.
- [x] Make `ProjectSpaceMemoryResolver`, `ProjectSpaceAutomationRecommendationService`, `DashboardViewModel`, `TrustedAutomationScopeCatalogService`, `TrustedAutomationScopeDetailSheet`, `TrustedAutomationScopeRecommendationSheet`, and `AutomationEngine` surface workflow-backed stable/stale/conflicted memory first and fall back to destination-dominance only when workflow memory is unavailable.

## Trusted-Scope Workflow Entry Points (April 9, 2026)
- [x] Add a trusted-scope-specific `WorkflowExecutionEntryPoint` so automatic scope runs preserve scope identity, trigger source, and display name through planning, execution, notification, and audit.
- [x] Expand trusted-scope action shapes beyond the old move-first model by surfacing template-backed workflow actions, including `projectAssociation`, `workflowStatus`, and `notesSummary` for `Project Drop Zone`.
- [x] Keep trusted automation UI honest by projecting the selected template's real workflow step shape in recommendation/detail surfaces instead of implying every scope still runs the same fixed `rename -> tag -> move -> notify` path.

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
- [ ] Build on the shipped `workflow-engine-v2` slice with additional metadata-backed step kinds and broader workflow-memory consumers beyond the current built-in `rename -> tag -> workflowStatus -> move -> log` (`Dated Archive`) and `rename -> tag -> projectAssociation -> workflowStatus -> notesSummary -> move -> log` executed paths plus shipped run/step/file audit depth, shared workflow execution requests across review, inspector, menu bar, App Intents, Finder Services, Spotlight, project-policy, and trusted-scope callers, project-space workflow-memory profiles, and trusted-scope workflow-memory projection/holds.
- [ ] Keep metadata-backed workflow-memory expansion open beyond v1; the shipped slices now include read-only project-space retrieval, richer project-space detail/correction, narrow project-memory destination suggestions, manual project-space workflow execution with remembered templates/latest-run summaries, the project-space automation board with constrained manual/realtime/scheduled policy triggers, stable/stale/conflicted project-space workflow profiles, trusted-scope workflow-memory summaries, the first workflow-owned `notesSummary` step, the new reusable `.archived` workflow status, and workflow-backed OS entry points for menu bar / App Intents / Finder Services / Spotlight, while broader editing, additional metadata step kinds, deeper macOS work, and richer cross-machine memory layers remain later work.

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

## Project Space Workflow Profiles (April 8, 2026)
- [x] Add lightweight durable `ProjectSpaceWorkflowProfile` state plus `ProjectSpaceWorkflowProfileService` so project spaces can remember a preferred built-in workflow template and their latest workflow run by normalized project label without introducing a separate project entity.
- [x] Ship manual-only `Organize Project Space` execution in `DashboardViewModel`, reusing explicit-selection workflow preparation so all reachable files in the selected project space can preview, run, and audit through `WorkflowRunner`.
- [x] Surface the remembered template, simulation preview, disabled-state guidance, and latest workflow run summary directly in `ProjectSpaceDetailView` / `DefaultPanelView`, while making workflow activity labels explicitly distinguish project-space-triggered runs from review, bulk, inspector, and trusted-scope automation.

## Project-space Automation Board Task 5 (April 8, 2026)
- [x] Replace the old single-template project-space workflow block with a feature-gated automation board in project-space detail, including grouped recommended/active/paused policy sections, health/latest-run context, constrained composer entry, policy inspection, and a policy-centered manual run path that preserves the existing manual project-space execution flow during the transition.

## Project-Space Automation Board (April 8, 2026)
- [x] Ship the feature-gated project-space automation board as a policy-centered layer on top of the existing project-space retrieval surface, with grouped recommendations, active/paused/revoked lifecycle controls, derived health/latest-run context, constrained policy creation, and manual policy runs.
- [x] Keep the legacy manual project-workflow profile as the bridge for existing state, and keep unlabeled files gated behind strong-confirmed project association before workflow execution.

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
