# Destination Prediction ML Fix - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` for task-by-task execution. Use `superpowers:test-driven-development` for code changes and `superpowers:verification-before-completion` before reporting completion.

**Goal:** Resolve item **B4** from the [2026-04-23 codebase audit](../audits/2026-04-23-forma-audit.md) by first repairing the broken evaluator, dataset split, and version-string paths in `DestinationPredictionService`; then measuring whether the ML layer earns a larger role before accept/override telemetry is wired.

**Architecture:** Four-phase approach with explicit gates. Phase 0 repairs the evaluator so future decisions are based on exposed model probabilities when available, off-main Core ML train/compile/load/evaluation work, explicit missing-probability rejection when not available, and representative bounded data. Phase 1 runs an offline backtest using the existing `LearningService.makeTrainingRecords(from:)` extraction path. Phase 2 captures live shadow outcomes from `FileScanPipeline.applyMLPredictions(...)` using dev-only file logging, not a new SwiftData model. Phase 3 wires accept/override telemetry only after the prediction identity/capture contract is durable enough to do so correctly.

**Tech Stack:** Swift, `CreateML`, `CoreML`, XCTest, SwiftData reads for existing `ActivityItem` history, and dev-only CSV/JSONL artifacts for shadow results.

---

## Scope and sequencing

This plan covers audit item **B4** only. It does not change the rule engine, `PersonalMemoryService`, or the pattern-learning contract except where those surfaces are used as baselines.

The plan is **measurement-gated**. If Phase 1 or Phase 2 shows that the ML layer does not outperform simpler predictors, stop and pivot to Option B from the audit: remove the broken ML branches rather than preserving code that is not earning its maintenance cost.

Execution order:

1. **Phase 0 - Evaluator repair.** Replace placeholder confidence scoring, move Core ML train/compile/load/evaluation work off the main actor, reject missing probability output explicitly, sample before capping datasets, and make model version strings locale-stable.
2. **Phase 1 - Offline backtest.** Score pattern-only vs. ML on historical training records extracted through the production learning-service path.
3. **Phase 2 - Live shadow measurement.** Collect dev-only shadow results from the scan pipeline without adding an unversioned SwiftData model.
4. **Phase 3 - Accept/override telemetry.** Add drift counters only after a stable prediction identity can be carried through organize/review flows.

This order is deliberate:

- Phase 0 removes known evaluator defects immediately, so later gates are not measuring placeholder behavior.
- Phase 1 gives a same-day signal using the same activity parsing Forma already trusts.
- Phase 2 avoids schema churn before C1 `VersionedSchema` work while still collecting live decision evidence.
- Phase 3 is only valid once the app can reliably connect a shown prediction to the user's later accept/override action.

## File map

### Phase 0 - evaluator repair

- `Forma File Organizing/Services/PredictionEngine.swift` *(changed - shared Core ML probability extraction helper)*
- `Forma File Organizing/Services/DestinationPredictionService.swift` *(changed - off-main explicit evaluation confidence, bounded sample-before-cap dataset split, POSIX UTC version helper)*
- `Forma File OrganizingTests/DestinationPredictionGatingTests.swift` *(changed - focused regression coverage)*

### Phase 1 - offline backtest

- `Forma File OrganizingTests/Benchmarks/DestinationPredictionBacktest.swift` *(new)*
- `Forma File OrganizingTests/Benchmarks/DestinationPredictionBacktestTests.swift` *(new - meta-tests for the harness)*
- `Docs/audits/2026-04-23-forma-audit/phase-1-backtest-results.md` *(new - committed after run)*

### Phase 2 - dev-only live shadow logging

- `Forma File Organizing/Services/FileScanPipeline.swift` *(changed - optional dev-only shadow record at the point ML predictions are applied)*
- `Forma File Organizing/Services/DestinationPredictionService.swift` *(changed only if the shadow evaluator needs a non-user-facing helper)*
- `Docs/audits/2026-04-23-forma-audit/phase-2-shadow-results.md` *(new - committed after collection)*
- Dev-only runtime artifact: CSV or JSONL under a local ignored output path.

### Phase 3 - durable telemetry

- `Forma File Organizing/Models/DestinationPredictionTypes.swift` *(changed only if `PredictedDestination` gains a stable prediction identity)*
- `Forma File Organizing/Services/DestinationPredictionService.swift` *(changed - accept/override counters and drift math)*
- `Forma File Organizing/Services/FileScanPipeline.swift` and organize/review call paths *(changed - carry prediction identity when needed)*
- `Forma File OrganizingTests/DestinationPredictionServiceTests.swift` or `DestinationPredictionGatingTests.swift` *(changed - counter and drift coverage)*
- Focused controller/view-model tests only after the prediction identity contract is present.

No `ShadowPredictionLog` `@Model`, app schema registration, `HistoryRetentionService` pruning, or temporary SwiftData migration work belongs in this plan before C1.

---

## Phase 0 - Evaluator and dataset repair

**Goal:** Fix the known broken evaluator paths before using the service to make roadmap decisions.

### Implementation tasks

- [x] Add shared `CoreMLPredictionEngine` helpers that extract predicted labels and sorted probabilities from an `MLFeatureProvider` when probabilities are exposed.
- [x] Replace `evaluateModel()` placeholder confidence values with real off-main `MLModel.prediction(from:)` scoring; models without probability output now fail with explicit missing-probability notes instead of receiving invented confidence.
- [x] Move Core ML classifier train/compile/load/evaluation work to utility tasks so retraining does not run that loop on the main actor.
- [x] Sample records before applying `maximumDatasetSize` without shuffling the full activity history, so recent records are not systematically dropped and training memory stays bounded by the cap.
- [x] Move model version formatting into a testable helper using `en_US_POSIX` locale and UTC.
- [x] Add focused regression tests for probability extraction, label-only output handling, sample-before-cap ordering, and locale-stable version strings.
- [x] Run the focused `DestinationPredictionGatingTests` suite.
- [x] Run the repo-declared non-UI Xcode suite if the focused suite is clean.
- [x] Sync `TODO.md`, `CHANGELOG.md`, and `API_REFERENCE.md`.

### Exit criteria

- Focused tests pass.
- Full non-UI tests either pass or any unrelated failures are documented with exact failing tests.
- B4 remains open until the measurement and telemetry decision is complete, but TODO should note that Phase 0 evaluator repairs have landed.

---

## Phase 1 - Offline backtest harness

**Goal:** Measure whether ML adds useful signal over pattern-only prediction on the developer's historical activity data.

**Gate to Phase 2:** ML beats pattern-only on Top-1 accuracy by at least 10 percentage points across at least 500 historical training records with resolved destinations. If the gate fails, stop and convert remaining work into the audit's remove/pivot path.

### Design

Use `LearningService.makeTrainingRecords(from:)` as the source of truth for extracting `DestinationTrainingRecord` values from `ActivityItem` rows. Do not assume an `ActivityItem.moved` case or direct `ActivityItem.destination` property; the existing parser derives destinations from activity details.

Split the resulting `DestinationTrainingRecord` list chronologically by `timestamp`: earliest 80% for training, latest 20% for holdout. For each holdout record, reconstruct the minimal file context needed by the predictor.

Predictors:

- **Pattern-only:** Run `LearningService.detectPatterns(from:)` on the training activities, then score holdout files with `LearningService.findMatchingPattern(for:in:)`.
- **ML-only:** Train/evaluate through the repaired `DestinationPredictionService` path or a harness-local equivalent that uses the same feature extraction and probability helper.

Score Top-1 accuracy. Only report Top-N if the harness explicitly exposes ranked labels beyond the current top-1/top-2 confidence contract.

### Implementation tasks

- [x] Create `Forma File OrganizingTests/Benchmarks/DestinationPredictionBacktest.swift`.
- [x] Gate the harness with `try TestGating.requireIntegration()` at setup.
- [x] Load `ActivityItem` rows from the configured development SwiftData store.
- [x] Convert activities through `LearningService.makeTrainingRecords(from:)`.
- [x] Sort records by `timestamp` ascending and split 80/20 at the chronological boundary.
- [x] Build a lightweight holdout-file projection matching `DestinationPredictionService` feature extraction.
- [x] Train pattern-only and ML-only predictors from the same training window.
- [x] Score Top-1 accuracy by predictor, file category, and source-location bucket.
- [x] Write per-item CSV and JSON summary to a DerivedData-local or explicitly ignored output path.
- [x] Print a compact summary so `xcodebuild test` captures the run.

### Meta-tests

- [x] Test chronological 80/20 split on a synthetic 100-record fixture.
- [x] Test scoring for Top-1 match and miss.
- [x] Test empty category/source buckets do not crash.
- [x] Test malformed or unparseable activities are skipped before split and reported.

### Run and record

- [x] Run the harness against the development store.
- [x] Verify sample size against the 500 resolved-record gate. First local run found 116 resolved records, so Phase 2 is not unlocked.
- [x] Transcribe results to `Docs/audits/2026-04-23-forma-audit/phase-1-backtest-results.md`.
- [x] Record the gate decision in the results doc and `TODO.md`.

---

## Phase 2 - Dev-only live shadow measurement

**Goal:** Validate the offline result against real scan-pipeline predictions and later user decisions without adding schema risk.

**Prerequisite:** Phase 1 gate passed.

**Gate to Phase 3:** ML shadow acceptance-rate-if-shown is at least the pattern/default suggestion acceptance rate across at least 200 logged decisions.

### Design

Capture shadow records at `FileScanPipeline.applyMLPredictions(...)`, because this is where ML predictions are actually applied to `FileItem.destination` and `originalSuggestedDestination`. Controllers and view models consume that state later; they are not the primary prediction producer.

Use a dev-only CSV or JSONL sink behind a debug-only switch or environment variable. Do not add `ShadowPredictionLog` to SwiftData before C1 `VersionedSchema` work. If durable local storage is still required later, that decision belongs in Phase 3 after the schema migration contract exists.

### Implementation tasks

- [ ] Add a debug/dev-only shadow sink that writes one record per ML candidate from `FileScanPipeline.applyMLPredictions(...)`.
- [ ] Log only minimal privacy-conscious fields: timestamp, extension, category, source-location bucket or hash, pattern/default suggestion display label, ML suggestion display label, ML confidence, and a correlation token.
- [ ] Capture the eventual organized destination by joining on the correlation token where the organize/review path already carries enough state; otherwise document the missing identity as a Phase 3 precondition.
- [ ] Keep the output path ignored and local-only.
- [ ] Add focused tests for formatting and disabled-by-default behavior, not a SwiftData model round-trip.

### Run and record

- [ ] Enable the shadow sink only on the development machine.
- [ ] Collect at least 200 predictions with subsequent decisions.
- [ ] Summarize results in `Docs/audits/2026-04-23-forma-audit/phase-2-shadow-results.md`.
- [ ] Record the gate decision in the results doc and `TODO.md`.

---

## Phase 3 - Accept/override telemetry

**Goal:** Wire the actual B4 drift counters and acceptance gate after measurement proves the ML layer should remain.

**Prerequisite:** Phase 2 gate passed and a stable prediction identity/correlation contract is available.

### Precondition

`PredictedDestination` currently has no prediction ID. Before adding `recordAccepted` or `recordOverridden`, the app must be able to distinguish:

- which prediction was shown,
- whether the user accepted that exact destination,
- whether the user chose a different destination,
- and whether the suggestion came from ML, learned pattern, project-space memory, or another producer.

This may require a stable prediction identity on `PredictedDestination`, a durable pending-prediction event, or an existing organize request structure extended with prediction provenance.

### Implementation tasks

- [ ] Add a stable prediction identity/provenance contract if one does not already exist by then.
- [ ] Add `recordAccepted(predictionID:)` and `recordOverridden(predictionID:actualDestination:)`.
- [ ] Change drift detection to use accepted plus overridden outcomes as the denominator, not raw prediction attempts.
- [ ] Add tests for accepted count, overridden count, and drift threshold behavior.
- [ ] Wire organize/review paths only where they can pass exact prediction provenance.
- [ ] Re-run Phase 1 and Phase 2 summaries after wiring to confirm the active path still meets the gates.
- [ ] Update the audit B4 status to resolved only after this phase is verified.

### Exit criteria

- Accept/override counters are exercised by real organize/review flows.
- Drift detection cannot fire from prediction volume alone.
- B4 is marked complete in `TODO.md` and the audit only after tests and measurement evidence are recorded.

---

## Deferred schema-backed shadow store

If a durable shadow-prediction store is still useful after C1 lands, plan it as a separate schema-versioned change. That future plan must include a `VersionedSchema` migration, retention policy, privacy review, and deletion path. It should not be implemented as an unversioned temporary `@Model` in this B4 fix.

## Testing strategy

- **Phase 0:** Unit tests for the evaluator helpers plus the focused destination-prediction suite.
- **Phase 1:** Integration-gated benchmark harness with meta-tests for split/scoring behavior.
- **Phase 2:** Unit tests for debug sink formatting and disabled-by-default behavior; manual/dev collection for real decision data.
- **Phase 3:** Unit and integration tests for prediction identity, accept/override counters, drift math, and organize/review wiring.

No UI tests are required unless Phase 3 changes user-visible organize/review state.

## Milestones and exit criteria

| # | Milestone | Exit criteria |
|---|---|---|
| M0 | Evaluator repair shipped | Focused tests pass; docs synced; B4 TODO notes partial repair |
| M1 | Offline backtest run | Results doc committed; gate decision recorded |
| M2 | Live shadow results collected | Results doc committed; schema-backed storage avoided unless C1 has landed |
| M3 | Accept/override telemetry merged | Counters receive real organize/review outcomes; B4 marked resolved |
