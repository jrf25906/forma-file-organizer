# Destination Prediction ML Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve item **B4** from the [2026-04-23 codebase audit](../audits/2026-04-23-forma-audit.md) by wiring up `DestinationPredictionService`'s drift-detection and confidence-acceptance gates, gated behind a measurement phase that proves the ML layer earns its place over simpler predictors.

**Architecture:** Three-phase approach with explicit early-exit gates. Phase 1 runs an offline backtest harness against the developer's own `ActivityItem` history to measure the ML layer's standalone contribution. Phase 2 ships shadow-mode instrumentation to compare predictors live during normal dev use. Phase 3 — only reached if both prior gates pass — lands the accept/override wiring, replaces the `confidence = 1.0` placeholder with real per-prediction probabilities, fixes the training split ordering, and patches the locale issue in version string generation. No feature flag on the fix itself; shadow-mode data is the de-risking signal. If either gate fails, pivot to Option B (remove) per the audit's alternative.

**Tech Stack:** Swift, SwiftUI, SwiftData, `CreateML`, `CoreML`, XCTest, `XCTMetric` / custom benchmarks, security-scoped bookmarks (for the harness reading dev data).

---

## Scope and sequencing

This plan covers audit item **B4** only. It does not touch `LearningService` (pattern-based prediction), `PersonalMemoryService`, or the rule engine — those are reference predictors, used as the comparison baseline.

The plan is **measurement-gated**: each phase only begins if the prior phase's gate passes. Early-exit pivots to Option B (remove the broken ML paths entirely) per the original audit decision fork.

Execution order:

1. **Phase 1 — Offline backtest.** Dev-only harness, scores pattern-only vs. ML standalone, gate: ML beats pattern-only on Top-1 accuracy by ≥10 percentage points across ≥500 historical activities.
2. **Phase 2 — Shadow mode.** Live shadow logging behind a compile-time flag; runs for 2–3 weeks of normal dev use; gate: shadow-ML acceptance-rate-if-shown ≥ pattern-only's acceptance rate.
3. **Phase 3 — The fix.** Direct replacement, no feature flag. Accept/override counters wired, probability placeholder replaced, training split fixed, locale fix.
4. **M4 — Shadow-mode cleanup.** Separate PR, 2 weeks after Phase 3 stable: removes `enableShadowPredictionLogging` flag and `ShadowPredictionLog` model.

This order is deliberate:

- Phase 1's backtest can run the same day the harness lands, giving you a decision signal within hours — not weeks.
- Phase 2 only ships if Phase 1 is promising, so shadow instrumentation (which adds a new `@Model`) is never wasted work.
- Phase 3's fix is unambiguous by the time it lands, because Phase 2 produced real-world data. No feature flag is warranted because the measurement phase IS the flag.
- M4 keeps the codebase clean: shadow instrumentation served its purpose and should not accumulate as permanent maintenance.

## File map

### Test-target harness (Phase 1)

- `Forma File OrganizingTests/Benchmarks/DestinationPredictionBacktest.swift` *(new)*
- `Forma File OrganizingTests/Benchmarks/DestinationPredictionBacktestTests.swift` *(new — meta-tests for the harness itself)*
- `Docs/audits/2026-04-23-forma-audit/phase-1-backtest-results.md` *(new — results transcript, committed after run)*

### Services (Phase 2 + Phase 3)

- `Forma File Organizing/Services/DestinationPredictionService.swift` *(changed — Phase 2 adds `shadowPredict`; Phase 3 lands all B4 fixes)*
- `Forma File Organizing/Services/AnalyticsService.swift` *(changed, Phase 2 only — adds shadow-log sink)*
- `Forma File Organizing/Services/HistoryRetentionService.swift` *(changed, Phase 2 only — adds `ShadowPredictionLog` 90-day pruning)*

### ViewModels (Phase 2 + Phase 3)

- `Forma File Organizing/ViewModels/DashboardOrganizationController.swift` *(changed — Phase 2 shadow-capture wiring; Phase 3 accept/override wiring)*
- `Forma File Organizing/ViewModels/ReviewViewModel.swift` *(changed — Phase 2 shadow-capture wiring; Phase 3 accept/override wiring)*

### Models (Phase 2, temporary)

- `Forma File Organizing/Models/ShadowPredictionLog.swift` *(new, Phase 2 — deleted in M4)*

### Configuration

- `Forma File Organizing/Configuration/FormaConfig.swift` *(changed, Phase 2 — adds `Features.enableShadowPredictionLogging`, removed in M4)*
- `Forma File Organizing/Forma_File_OrganizingApp.swift` *(changed, Phase 2 — registers `ShadowPredictionLog` in schema list; removed in M4)*

### Tests

- `Forma File OrganizingTests/DestinationPredictionServiceTests.swift` *(changed — Phase 3)*
- `Forma File OrganizingTests/DashboardOrganizationControllerTests.swift` *(changed — Phase 3)*
- `Forma File OrganizingTests/ShadowPredictionLogTests.swift` *(new, Phase 2 only — deleted in M4)*

---

## Phase 1 — Offline backtest harness

**Goal:** Measure the ML layer's standalone contribution against pattern-only prediction, on the developer's own historical activity data, to decide whether Phase 2 is worth starting.

**Gate to Phase 2:** ML beats pattern-only on Top-1 accuracy by ≥10 percentage points, measured across ≥500 historical `ActivityItem` records with resolved destinations. If the gate fails, stop and convert this plan's remaining work into a "Remove `DestinationPredictionService` ML paths" sub-task under audit item B4 pivot.

### Design

Chronological train/holdout split. Earliest 80% of `ActivityItem.moved` records with resolved destinations → training set. Latest 20% → holdout test set. For each holdout activity, reconstruct the file context (extension, category, source path, relative parent) and run BOTH predictors:

- **Predictor A (pattern-only):** `LearningService.predictDestination(for:in:)` trained on the training set
- **Predictor B (ML-only):** `DestinationPredictionService` trained on the same training set, using the current (pre-fix) code path; prediction via `predictDestination(for:in:)` public API

Score each holdout item: did the top prediction's destination match the user's actual destination (`ActivityItem.destination`)? Top-1 and Top-3 accuracy reported per predictor, broken down by file category and by source folder.

### Implementation tasks

- [ ] Create `Forma File OrganizingTests/Benchmarks/DestinationPredictionBacktest.swift`
- [ ] Gate the class with `try TestGating.requireIntegration()` at `setUpWithError` — this harness belongs in the Integration plan, not Unit
- [ ] Load `ActivityItem` records from the active SwiftData store (inject via test argument or fall back to `ModelContainer` at a configurable URL)
- [ ] Filter to `.moved` activities with non-nil resolved `destination`; discard the rest
- [ ] Sort by `timestamp` ascending; split 80/20 at the chronological boundary
- [ ] Build a minimal `ActivityContext → (ext, category, sourcePath, relativeParent)` projection matching what `DestinationPredictionService.trainingFeature(from:)` expects
- [ ] Train `LearningService` against the training set by running its normal pattern-detection pipeline; capture the resulting `[LearnedPattern]`
- [ ] Train `DestinationPredictionService` against the training set via its existing `trainModel()` path
- [ ] For each holdout item: record `patternPrediction = LearningService.predict(...)` and `mlPrediction = DestinationPredictionService.predict(...)`; record Top-1 + Top-3
- [ ] Compute aggregate: Top-1 accuracy per predictor, Top-3 accuracy per predictor, broken down by `FileTypeCategory` and by source folder (`FileLocationKind`)
- [ ] Write CSV of per-item results + JSON summary to a `DerivedData`-local path passed via env var (default: `./backtest-results/`)
- [ ] Print summary to test output so `xcodebuild test` captures it in the log

### Meta-tests

- [ ] Create `Forma File OrganizingTests/Benchmarks/DestinationPredictionBacktestTests.swift`
- [ ] Test: 80/20 split is correct on a synthetic 100-item activity fixture
- [ ] Test: scoring correctly handles Top-1 match, Top-1 miss / Top-3 match, complete miss
- [ ] Test: category/folder breakdown handles empty buckets without crashing
- [ ] Test: harness gracefully skips activities with nil destination or unresolvable context

### Run and record

- [ ] Run the harness against the developer's dev-machine SwiftData store
- [ ] Verify sample size is ≥500 holdout activities with resolved destinations (if not, collect more data before deciding — the gate is statistical)
- [ ] Transcribe results to `Docs/audits/2026-04-23-forma-audit/phase-1-backtest-results.md` with Top-1 / Top-3 numbers, category breakdown, and decision
- [ ] Commit the results doc; tag the commit `b4-phase-1-results`

### Gate decision

- [ ] If ML beats pattern-only on Top-1 by ≥10 pp → proceed to Phase 2
- [ ] If not → stop this plan, convert remaining sections into Option B (remove) follow-up work, update the root `TODO.md` to reflect the pivot

---

## Phase 2 — Shadow-mode live instrumentation

**Goal:** Validate Phase 1's finding against real user decisions (not backtested reconstructions) across 2–3 weeks of normal dev use.

**Prerequisite:** Phase 1 gate passed.

**Gate to Phase 3:** Shadow-ML acceptance-rate (i.e., "if we had shown the ML prediction instead of the pattern-only one, how often would the user have accepted it?") is ≥ pattern-only's acceptance rate, measured across ≥200 predictions with logged user decisions.

### Design

When `DashboardOrganizationController` or `ReviewViewModel` requests a prediction, both predictors run concurrently. The pattern-only prediction is shown (today's user-facing behavior, unchanged). The ML prediction is logged to a new `ShadowPredictionLog` SwiftData row. When the user subsequently organizes the file, the log row is completed with the actual destination so the pair can be scored.

Privacy-conscious: source paths stored as FNV1a hashes (pattern already used in `TrustedAutomationScopeBoundaryDescriptor.fnv1a64`), destinations stored as display labels only (no bookmark data). Nothing leaves the local SwiftData store.

### Implementation tasks

#### Shadow log model

- [ ] Create `Forma File Organizing/Models/ShadowPredictionLog.swift`
- [ ] `@Model final class ShadowPredictionLog`
- [ ] Properties: `id: UUID` (marked `@Attribute(.unique)`), `timestamp: Date`, `fileExt: String`, `fileCategory: String` (rawValue of `FileTypeCategory`), `sourcePathHash: UInt64`, `patternPrediction: String?` (top-1 destination display name), `patternConfidence: Double?`, `mlPrediction: String?`, `mlConfidence: Double?`, `actualDestination: String?` (filled on organize), `wasAcceptedByUser: Bool?` (filled on organize)
- [ ] Register in `Forma_File_OrganizingApp.swift:104-126` `appSchema` list

#### Feature flag

- [ ] Add `enableShadowPredictionLogging: Bool = false` to `Forma File Organizing/Configuration/FormaConfig.swift` `Features` section
- [ ] Document that it is dev-machine-only; off for shipping builds

#### Shadow capture surface

- [ ] Add `func shadowPredict(context: PredictionContext) async -> ShadowPrediction` to `DestinationPredictionService` — returns `(mlPrediction: Destination?, confidence: Double?)` structure; *does not* go through drift/acceptance gates (we're measuring, not gating)
- [ ] Define `struct ShadowPrediction: Sendable` with `mlPrediction: Destination?`, `confidence: Double?`

#### Integration points

- [ ] In `DashboardOrganizationController`: after a pattern-only prediction is served, if `FormaConfig.Features.enableShadowPredictionLogging` is true, fire `shadowPredict` and create a pending `ShadowPredictionLog` row with `actualDestination == nil`
- [ ] In `DashboardOrganizationController.organizeFile(_:to:)`: when organize succeeds, find the pending `ShadowPredictionLog` row by `id` (pass the row `id` through the organize call path or match by `sourcePathHash` + most-recent within a time window), fill `actualDestination` and `wasAcceptedByUser`
- [ ] Mirror the wiring in `ReviewViewModel` for review-flow organize paths
- [ ] Add `recordShadowPrediction(_:)` on `AnalyticsService` as a thin write sink so VM code doesn't talk to the model context directly

#### Retention

- [ ] Extend `HistoryRetentionService` to prune `ShadowPredictionLog` rows older than 90 days (matches the `trustedScopeRunRecord` retention pattern already in that file)

#### Tests

- [ ] Create `Forma File OrganizingTests/ShadowPredictionLogTests.swift`
- [ ] Test: `ShadowPredictionLog` round-trips through a `ModelContainer` correctly
- [ ] Test: pending row (no `actualDestination`) is discoverable via a predicate filter
- [ ] Test: completing a pending row with `actualDestination` correctly sets `wasAcceptedByUser` based on match
- [ ] Test: retention pruning removes rows older than 90 days but preserves younger ones

### Run and record

- [ ] Enable `enableShadowPredictionLogging` on dev machine
- [ ] Collect 2–3 weeks of normal organize activity (≥200 logged predictions)
- [ ] Query the shadow log via a one-off script or ad-hoc test, compute pattern-only acceptance-rate-if-shown vs. ML acceptance-rate-if-shown
- [ ] Transcribe results to `Docs/audits/2026-04-23-forma-audit/phase-2-shadow-results.md`
- [ ] Commit the results doc; tag the commit `b4-phase-2-results`

### Gate decision

- [ ] If ML acceptance-rate ≥ pattern-only acceptance-rate → proceed to Phase 3
- [ ] If not → either loop back to Phase 1 (maybe the offline signal was noisy) or pivot to Option B (remove), depending on how far apart the results are

---

## Phase 3 — The fix (direct replacement)

**Goal:** Land the actual fix from audit item B4. By this point the ML layer is validated; the work is unambiguous.

**Prerequisite:** Phase 2 gate passed.

### Changes to `Services/DestinationPredictionService.swift`

- [ ] Add `func recordAccepted(predictionID: UUID)` — increments `PredictionStatistics.acceptedCount` and prunes old IDs outside the `windowSize` bound
- [ ] Add `func recordOverridden(predictionID: UUID, actualDestination: Destination)` — increments `overriddenCount` and stores a capped-length trace of `(predicted, actual)` pairs for future diagnostics
- [ ] Verify `isDriftDetected()` now signals correctly: denominator is `acceptedCount + overriddenCount` (not `predictionCount`), threshold stays at 0.5, drift only fires when accept/override data justifies it
- [ ] Replace `evaluateModel()` line 480-515 `confidence = 1.0` placeholder with real per-prediction probability extraction via `MLModel.prediction(from:)` — pattern already exists in `CoreMLPredictionEngine.predict` at `PredictionEngine.swift:27-33`; lift it into a helper and reuse
- [ ] Replace `Array(records.prefix(maximumDatasetSize))` at line 432-445 with `records.shuffled().prefix(maximumDatasetSize)` so recent patterns are not systematically dropped
- [ ] In `generateVersionString()` (line 839-845), add `formatter.locale = Locale(identifier: "en_US_POSIX")` so version strings are monotonic regardless of user locale

### Changes to `DashboardOrganizationController`

- [ ] When an organize operation completes, if the served prediction came from `DestinationPredictionService` (flag carried in the prediction's `suggestionSource` already, per existing code), call either `recordAccepted(predictionID:)` (user accepted the predicted destination) or `recordOverridden(predictionID:actualDestination:)` (user chose a different destination)
- [ ] Thread the `predictionID` through the organize call chain — likely requires extending `OrganizeFileRequest` or similar context struct to carry it

### Changes to `ReviewViewModel`

- [ ] Mirror the same wiring on the review-flow organize paths; review-sourced suggestions also need accept/override feedback

### Tests

- [ ] Add `testRecordAccepted_incrementsAcceptedCount` and `testRecordOverridden_incrementsOverriddenCount` to `DestinationPredictionServiceTests`
- [ ] Add `testDriftDetection_onlyFiresWhenOverrideRateCrossesThreshold` — exercise the drift math with accept/override volumes below, at, and above the 0.5 threshold
- [ ] Add `testEvaluateModel_producesRealConfidenceSeparation` — train on known-good vs known-bad fixture data, assert confidence separation is > 0.15 (the existing `minimumConfidenceSeparation`)
- [ ] Add `testPrepareTrainingData_shufflesBeforePrefix` — assert two successive calls produce different orderings (with determinism via seeded RNG in tests)
- [ ] Add accept/override assertions to `DashboardOrganizationControllerTests`: organize-accepted flow calls `recordAccepted`; organize-overridden flow calls `recordOverridden` with the right arguments
- [ ] Add matching assertions to `ReviewViewModelTests` for review-flow accept/override

### No feature flag

- [ ] Confirm no new flag is introduced; Phase 2 data is the de-risking signal
- [ ] Update `Docs/audits/2026-04-23-forma-audit.md` B4 status to RESOLVED after merge; mark `[x]` in both `TODO.md` files

---

## Milestone 4 — Shadow-mode cleanup (separate PR)

**Goal:** Remove the shadow instrumentation after Phase 3 has been stable in production for 2 weeks.

**Prerequisite:** Phase 3 merged; no regressions observed for 2 weeks; `recordAccepted` / `recordOverridden` are receiving calls normally.

### Implementation tasks

- [ ] Delete `Forma File Organizing/Models/ShadowPredictionLog.swift`
- [ ] Remove `ShadowPredictionLog` from `Forma_File_OrganizingApp.swift` `appSchema` list (note: this is a **breaking schema change** — coordinate with C1 `VersionedSchema` adoption; if C1 has not landed yet, defer M4 until it has, or document the one-time drop in `AppStoreMigrationTests`)
- [ ] Delete `Forma File Organizing/Configuration/FormaConfig.swift` `Features.enableShadowPredictionLogging` entry
- [ ] Delete `DestinationPredictionService.shadowPredict(context:)` method
- [ ] Remove shadow-capture wiring from `DashboardOrganizationController` and `ReviewViewModel`
- [ ] Remove `recordShadowPrediction(_:)` from `AnalyticsService`
- [ ] Delete `Forma File OrganizingTests/ShadowPredictionLogTests.swift`
- [ ] Remove shadow-log retention from `HistoryRetentionService`

---

## Testing strategy (summary)

- **Phase 1** tests the harness itself (meta-tests); no production code is exercised. Plan: Integration (`try TestGating.requireIntegration()`).
- **Phase 2** tests the new model's persistence, retention, and the shadow-capture wiring. Plan: Unit for model tests; Integration for end-to-end shadow-log-on-organize scenarios.
- **Phase 3** tests the counter wiring, drift math, confidence separation, training-split shuffle, and controller/VM integration. All Unit plan except the end-to-end organize-with-recording flow which is Integration.
- No UI tests needed — all changes are below the view layer.

## Milestones and exit criteria

| # | Milestone | Exit criteria |
|---|---|---|
| M1 | Phase 1 harness shipped; backtest run | Results doc committed; gate decision recorded |
| M2 | Phase 2 shadow-mode instrumented | Dev machine collecting shadow logs; model + retention tested |
| M3 | Phase 3 fix merged to main | All Phase 3 tests pass; re-running Phase 1 harness against post-fix code still shows improvement; B4 audit item marked RESOLVED |
| M4 | Shadow cleanup shipped (separate PR, +2 weeks) | Shadow model + flag + instrumentation deleted; schema change coordinated with C1 |

## Open questions

- **Sample size for Phase 1 gate.** The "≥500 activities" floor assumes the developer has accumulated that much data. If the dev store has fewer, the gate is deferred until enough accumulate — not loosened.
- **Phase 2 duration.** "2-3 weeks" is a starting estimate; if organize velocity is low (few predictions served per day), extend until ≥200 logged predictions regardless of calendar time.
- **Pattern-only predictor training.** `LearningService`'s pattern detection pipeline isn't currently designed to retrain on a subset of activities; Phase 1 may need a small adaptation to `LearningService` to accept an override activity set. If that adaptation is non-trivial, alternative: use the *current* in-memory set of `LearnedPattern` rows as the pattern-only predictor (less rigorous but avoids touching `LearningService`).
- **Prediction ID plumbing for Phase 3.** Accept/override recording requires a stable `predictionID` flowing from predict-time to organize-time. The existing prediction API may or may not carry one; if not, adding one is a Phase 3 prerequisite and should be scoped at the start of that phase.

## Risks

- **Pattern-only baseline is weaker than expected** — if `LearningService` has its own latent bugs, the ML layer may look artificially strong in Phase 1. Mitigation: sanity-check Top-1 accuracy against a third reference (personal memory + rules) to sniff-test the baseline.
- **Shadow-mode privacy** — even with hashed paths, shadow logs could potentially reveal organize patterns if the SwiftData store is shared. Mitigation: `enableShadowPredictionLogging` is dev-machine-only, off in shipping configs; M4 deletes the model entirely.
- **Schema churn** — adding and later removing `ShadowPredictionLog` is two breaking schema changes. Mitigation: coordinate with C1 (`VersionedSchema` adoption) so both additions and removals flow through a proper migration plan.
- **Early-exit pivot complexity** — if Phase 1 gate fails, the "remove the broken ML paths" pivot becomes audit item B4's new actual work. The original audit doc has enough detail to execute that pivot without a new plan doc.
