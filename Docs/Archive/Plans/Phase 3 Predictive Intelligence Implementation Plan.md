# Phase 3: Predictive Intelligence Implementation Plan
This plan covers implementation of the remaining Phase 3 AI features in `AI-Feature-Development-Plan.md`: destination prediction (Feature 3.1) and natural language rule creation (Feature 3.2). It assumes Phases 1–2 are complete (LearningService multi-condition/temporal/negative patterns; ContextDetectionService; DuplicateDetectionService; AIInsightsView) and must align with the existing MVVM + Services + SwiftData architecture and the protocol-based RuleEngine.
## Problem Statement & Current State (Brief)
Today, Forma learns user patterns via `LearningService` and `LearnedPattern`, surfaces AI suggestions in `AIInsightsView`, and understands context via `ProjectCluster` and duplicates via `DuplicateDetectionService`. However, if no rule or learned pattern matches, `FileItem.status` remains `.pending` and users must manually choose destinations. Rule creation also requires using the structured rule UI. Phase 3 must:
* Predict likely destinations for files even without explicit rules, with strong privacy guarantees and conservative gating.
* Let users express rules in natural language and convert them to `Rule` + `RuleCondition` safely, with preview and error handling.
* Integrate these behaviors into existing models (`FileItem`, `LearnedPattern`, `ProjectCluster`, `TemporalContext`) and UI (`FileRow`, `AIInsightsView`), while keeping the system testable and explainable.
## Architecture & Design
### LearningService Enhancements
LearningService already:
* Extracts destinations and patterns from `ActivityItem` history.
* Builds `LearnedPattern` objects with `PatternCondition`, `TemporalContext`, and negative patterns.
Phase 3 changes:
* Add a small, focused feature-extraction API used by the ML pipeline:
    * `func makeTrainingRecords(from activities: [ActivityItem]) -> [DestinationTrainingRecord]` that reuses existing parsing helpers (e.g. `extractDestination(from:)`) so we do not duplicate string-parsing logic.
    * `DestinationTrainingRecord` is a plain Swift struct (not a SwiftData model) containing: normalized file name, inferred extension, inferred source location (e.g. Desktop/Downloads via `FileLocationKind` or details text), destination path, and timestamp.
* Add reporting hooks for AI prediction outcomes:
    * New helper: `func recordPredictionOutcome(file: FileItem, predictedPath: String, outcome: PredictionOutcome)`.
    * This method appends appropriate `ActivityItem` rows (e.g. prediction accepted/overridden) and updates `FileItem.rejectedDestination` and `rejectionCount` so negative learning continues to work with ML predictions.
* Keep LearningService independent of Core ML: it only produces and consumes value-type records and `LearnedPattern`. Core ML–specific code lives in `DestinationPredictionService`.
### DestinationPredictionService (new)
Create a dedicated service responsible for all destination ML logic, separate from LearningService’s pattern mining:
* Location: `Services/DestinationPredictionService.swift` (or `Services/AI/DestinationPredictionService.swift` if/when AI services are grouped).
* Responsibilities:
    * Build an on-device training dataset from `ActivityItem` + (optionally) `FileItem` metadata via LearningService’s new feature-extraction API.
    * Train and evaluate a Core ML classifier for destination prediction using Create ML types.
    * Manage in-memory and on-disk model instances (load, save, rollback, version selection).
    * Serve predictions for `FileItem` instances, including top-1 destination, confidence, and explanation.
    * Cooperate with LearningService to log prediction outcomes so future training incorporates user feedback.
* Core types:
    * `struct DestinationFeatures` (ephemeral): normalized tokens representing file extension, name keywords, file type category, time bucket (hour-of-day, weekday/weekend), source location, and optionally project cluster label.
    * `struct PredictedDestination`: `path`, `confidence`, `source: SuggestionSource` (e.g. `.mlModel`, `.rule`, `.pattern`), `explanation: PredictionExplanation`, and `modelVersion`.
    * `struct PredictionExplanation`: `summary` (short human-readable description), `reasons: [String]` (e.g. "Similar to 12 past invoices moved to Documents/Finance"), and `exampleFiles: [String]` (up to 3 anonymized file names or patterns).
* Public API sketch (conceptual):
    * `func predictDestination(for file: FileItem, context: PredictionContext) async -> PredictedDestination?` where `PredictionContext` includes allowed destinations and user settings.
    * `func scheduleTrainingIfNeeded(activityItems: [ActivityItem]) async`.
    * `func currentModelMetadata() -> DestinationModelMetadata?` (for AIInsightsView and diagnostics).
### NaturalLanguageRuleParser (new)
Create a service that turns user text into structured `Rule` + `RuleCondition`:
* Location: `Services/NaturalLanguageRuleParser.swift`.
* Responsibilities:
    * Parse common, constrained command patterns (move/copy/delete, age constraints, extension/type filters, destinations) using deterministic regex + Apple’s `NaturalLanguage` tagger.
    * Return a `ParsedRule` value type describing:
        * `action: Rule.ActionType?`.
        * `conditions: [RuleCondition]` (using the existing typed enum, not raw strings).
        * `logicalOperator: Rule.LogicalOperator` (default `.and` when >1 condition).
        * `destinationFolder: String?`.
        * `parseConfidence: Double`.
        * `missingPieces: [MissingComponent]` (e.g. `.destination`, `.action`, `.targetFiles`) for partial parses.
        * An `explanation` struct breaking down how each fragment of the input mapped to conditions and action.
* This parser must be deterministic and offline-only: no network calls or LLMs. It should be biased toward conservative parsing (fail or ask for clarification when ambiguous) rather than guessing.
* Conversion to `Rule`:
    * A helper `func buildRule(from parsed: ParsedRule) throws -> Rule` validates that there is at least one condition, a non-empty action, and a valid destination when required (`Rule.hasValidDestination`).
    * Complex user inputs should still result in a `Rule` whose conditions are compatible with `RuleEngine.matchesCondition(file:condition:)` and `RuleCondition`’s typed initializers.
### Integration with SwiftData Models
#### FileItem
* Continue to treat `FileItem` as the primary unit of suggestion display. `FileRow` already surfaces `suggestedDestination`, `matchReason`, and `confidenceScore` with a `ConfidenceBadge` and expandable reasoning.
* Phase 3 behavior:
    * RuleEngine remains the first step. If no rule matches (file stays `.pending` with no `suggestedDestination`), the organizing pipeline asks DestinationPredictionService for a prediction.
    * On a high-confidence prediction, we set `file.suggestedDestination`, `file.status = .ready`, `file.confidenceScore`, and `file.matchReason` based on `PredictionExplanation.summary`.
    * Introduce a small, non-breaking enum to distinguish suggestion origin (not persisted in v1 if we want to avoid migrations, or persisted as a new optional field if acceptable):
        * `enum SuggestionSource: String, Codable { case rule, pattern, mlPrediction }`.
        * Add `var suggestionSourceRaw: String?` to `FileItem` with a computed `suggestionSource: SuggestionSource` for UI and analytics; default to `.rule` where legacy suggestions already exist.
* The actual file move remains the responsibility of `FileOperationsService`; ML only influences the proposed destination.
#### LearnedPattern & TemporalContext
* Keep `LearnedPattern` and `TemporalContext` as the pattern-learning backbone:
    * DestinationPredictionService training uses LearningService outputs and ActivityItem history, not `LearnedPattern` directly, but we can optionally:
        * Downweight or skip ML predictions for file types that already have strong, high-confidence patterns (`LearnedPattern.confidenceScore >= 0.8` with `shouldSuggest == true`).
        * Use `LearnedPattern.extractedKeywords` and `timeCategory` as additional, human-readable features for `PredictionExplanation`.
* No schema changes are required for `LearnedPattern` or `TemporalContext` in Phase 3, but we will:
    * Document how temporal patterns (e.g. `timeOfDay`, `dayOfWeek`) inform ML features (e.g. time buckets for training examples).
#### ProjectCluster
* Use `ProjectCluster` as optional context features:
    * When training, annotate `DestinationTrainingRecord` with the cluster’s `suggestedFolderName` or `detectedPattern` (if the file’s `path` appears in a `ProjectCluster.filePaths`).
    * At prediction time, if a new file joins an existing cluster (based on ContextDetectionService), add a feature like `projectCluster="Project P-1024"` to `DestinationFeatures`.
* This integration is purely feature-level; we do not change the `ProjectCluster` schema.
#### New MLTrainingHistory Model (SwiftData)
* Add `@Model final class MLTrainingHistory` with fields like:
    * `id: UUID`, `modelName: String` (e.g. "destinationPrediction"), `version: String`.
    * `trainedAt: Date`, `exampleCount: Int`, `labelCount: Int`.
    * `validationAccuracy: Double`, `validationLoss: Double?`, `falsePositiveRate: Double?`.
    * `accepted: Bool` (whether this version passed evaluation gates and became active).
    * Optional `notes` for debugging.
* `MLTrainingHistory` records are written by `DestinationPredictionService` / `MLModelManager` after each training attempt and consulted for drift detection.
### Model Lifecycle Management (Training, Retraining, Invalidation)
* Introduce a small `MLModelManager` helper (can live inside DestinationPredictionService initially) responsible for:
    * Locating the on-disk model directory (under the app’s Application Support container).
    * Loading the current model into memory lazily when the first prediction is requested.
    * Writing new models after successful training and updating a `currentModelVersion` pointer (e.g. in `UserDefaults` or via `MLTrainingHistory`).
    * Rolling back to the last `MLTrainingHistory.accepted == true` model if the latest model is invalidated.
* Training flow (on-demand or scheduled):
    * Build `DestinationTrainingRecord` values from relevant `ActivityItem`s (only `fileOrganized`, `fileMoved`, and `ruleApplied` actions, excluding prediction-driven moves to avoid feedback loops unless explicitly desired in a later iteration).
    * Convert records to a Create ML–compatible `MLDataTable` (with a single text feature column aggregating tokens: extension, keywords, type, time bucket, source folder) and a string label column (`destination`).
    * Train a classifier (e.g. `MLTextClassifier`) on-device, then evaluate on a holdout set as described in the Model Lifecycle section below.
    * If metrics meet thresholds, persist the compiled model and mark it active; otherwise discard the new model and keep the previous one.
* Invalidation:
    * If runtime evaluation (acceptance/override metrics) show sustained degradation (e.g. 20 consecutive low-confidence or overridden predictions), mark the current version as invalid and:
        * Either roll back to the previous accepted version; or
        * Disable ML predictions until enough fresh data exists to retrain.
### Memory, Caching, Async Queues, Scheduling
* Prediction path:
    * Keep a single in-memory `MLModel` instance for destination prediction, shared via `DestinationPredictionService`.
    * Guard access with a lightweight concurrency primitive (e.g. actor wrapper around the model, or a private serial `DispatchQueue`) so predictions don’t race over shared resources.
    * Run predictions on a background queue or `Task.detached`, returning results to the main actor for UI updates.
* Training path:
    * Use a dedicated serial background queue / actor for training so at most one training job runs at a time.
    * Cap the size of the training dataset (e.g. last 2,000–5,000 examples) to avoid excessive memory use and to keep training within a few seconds on typical Macs.
    * Schedule training at low-disruption times (e.g. when the app is idle or AIInsightsView is open and the user is not actively organizing files) and always mark it as cancellable.
* Caching:
    * Cache recent `DestinationFeatures` for the current batch of scanned files (e.g. within the `DashboardViewModel` or a small in-memory cache) to avoid recomputing features for the same `FileItem` multiple times during a session.
    * Optionally cache the top-N predicted destinations per extension or per project in memory for very fast repeated lookups; ensure these caches are invalidated when the model version changes.
## Model Lifecycle & Evaluation
### Training Pipeline Details
* Data selection:
    * Source events from `ActivityItem` where `activityType` is `.fileOrganized`, `.fileMoved`, or `.ruleApplied` and where `extractDestination(from: details)` returns a non-empty destination.
    * Optionally filter out very old events (beyond a horizon, e.g. 6–12 months) to keep the model aligned with recent behavior.
* Feature extraction (per `DestinationTrainingRecord`):
    * `extension`: from `ActivityItem.fileExtension` or parsed from `fileName`.
    * `nameKeywords`: tokenized words from `fileName` (split on `_`, `-`, space, and numbers), lowercased and deduplicated.
    * `fileTypeCategory`: reuse `FileTypeCategory.category(for:)` to add token(s) like "image", "document".
    * `sourceLocation`: inferred from Activity details (e.g. "Added from Desktop") or from `FileItem.location` if the matching `FileItem` exists.
    * Temporal tokens: hour-of-day bucket (e.g. `hour_09`), weekday/weekend label (e.g. `weekday`, `weekend`). These can be generated from `TemporalContext(from: activity.timestamp)`.
    * Optional `projectCluster` token (if `ContextDetectionService` associates the file with a `ProjectCluster`).
* Label selection:
    * Label is the normalized destination path (e.g. tilde-ified home path, or a relative form that remains stable).
    * Very rare destinations (fewer than a minimum support threshold, e.g. 3–5 occurrences) can be grouped under an "other" label or dropped to avoid excessive label sparsity.
* Create ML constraints:
    * Use a text-based classifier (e.g. `MLTextClassifier`) with a combined text column formed by joining all tokens (extension, keywords, category, time, cluster, source) into a single whitespace-separated string.
    * Limit overall dataset size to a few thousand rows per training run to bound memory and time.
    * If the dataset is highly imbalanced, apply simple balancing strategies (downsample dominant destinations or weight the loss function if available).
### Cold-Start Strategy
* Define minimal data thresholds before enabling ML predictions:
    * At least 50 high-quality labeled examples (as in the original plan) across at least 3 distinct destinations.
    * At least 10 examples for any destination the model will be allowed to suggest automatically without additional confirmation.
* Cold-start behavior by user segment:
    * Zero or very few ActivityItems: no DestinationPredictionService used; pipeline remains: RuleEngine → LearningService patterns → extension-based defaults (if any).
    * Between minimum and target thresholds (e.g. 50–200 examples):
        * Train a model but only use it for soft suggestions (e.g. show predictions only in AIInsightsView or as secondary suggestions with lower prominence in `FileRow`).
    * Above the higher threshold (e.g. 200+ examples, with good evaluation metrics):
        * Enable inline predictions in `FileRow` for new files, subject to confidence gating.
### On-Device Model Storage, Versioning, Rollback
* Storage:
    * Persist compiled models under the app’s container in an `MLModels/` subdirectory, e.g. `.../Application Support/MLModels/destinationPrediction_vX.mlmodelc`.
    * Store only a limited number of historical versions (e.g. latest 2–3) to cap disk usage.
* Versioning:
    * Version string derived from a schema version + timestamp or incremental integer (e.g. `1-2025-12-05T120000Z`).
    * Record the active version in both `UserDefaults` (for quick lookup) and `MLTrainingHistory` (for audit and drift analysis).
* Rollback:
    * When a newly trained model fails post-deployment metrics (e.g. acceptance rate plummets), mark it `accepted = false` in `MLTrainingHistory` and switch back to the last `accepted == true` version.
    * If no prior accepted version exists (first model), disable predictions rather than using a bad model.
### Evaluation Gates (Offline Metrics and Runtime Gates)
* Offline evaluation (on holdout set during training):
    * Split data into train/test (e.g. 80/20) with label-stratified sampling.
    * Metrics to compute per training run:
        * Overall accuracy and per-destination accuracy (to detect labels the model consistently gets wrong).
        * False positive rate: fraction of predictions where the model confidently predicts destination A but ground truth is B.
        * Average confidence on correct vs incorrect predictions; the distributions should be well-separated.
    * Acceptance criteria to mark a model as deployable:
        * Overall accuracy ≥ 0.7.
        * False positive rate ≤ 0.2.
        * Average confidence of correct predictions at least 0.15 higher than incorrect ones.
* Runtime gates per prediction:
    * Top-1 confidence must exceed a hard threshold (e.g. 0.7) and be sufficiently above top-2 (e.g. margin ≥ 0.15); otherwise the prediction is considered low-confidence.
    * For destinations with very low training support (fewer than N examples), enforce a higher confidence threshold or suppress them altogether.
    * If the model suggests a destination that conflicts with strong negative patterns (`LearnedPattern.isNegativePattern == true` for that extension/path), drop the prediction and fall back.
* Fallback logic when low-confidence or suppressed:
    * If prediction is low-confidence or blocked:
        * First allow RuleEngine (`RuleEngine.evaluateFile`) and LearningService patterns to supply suggestions.
        * If still no confident suggestion, either show no AI suggestion (file remains `.pending`) or show a softer hint (e.g. "No confident AI destination yet").
### Drift Detection & Retraining Policies
* Collect lightweight runtime statistics over a sliding window (e.g. last 100–200 predictions):
    * `predictionShownCount`, `predictionAcceptedCount`, `predictionOverriddenCount`, `predictionDismissedCount`.
    * Derived metrics: user acceptance rate, override rate, and effective precision.
* Drift indicators:
    * Acceptance rate falls below a threshold (e.g. < 0.5) over the last N predictions.
    * Override rate (user moves file to a different destination than predicted) exceeds a high threshold (e.g. > 0.4).
    * Distribution of predicted destinations shifts sharply compared to the training label distribution in `MLTrainingHistory`.
* Retraining policies:
    * Use LearningService and new ActivityItem events to check `shouldRetrain(lastTrainingDate:newDataCount:)` conditions, such as:
        * More than 30 days since last training; or
        * At least 25–50 new high-quality labeled moves; or
        * Drift indicators above thresholds.
    * When retraining due to drift, favor more recent data (e.g. last 3–6 months) to realign with current behavior.
    * If multiple retrains in a row fail evaluation gates, automatically disable predictions and mark the model as needing manual review (but the app still works with rules and pattern-based logic).
## Feature Delivery
### Destination Prediction (Feature 3.1)
#### Prediction Pipeline Integration
* Organizing pipeline order for each `FileItem`:
    1. Run RuleEngine (`RuleEngine.evaluateFile`) with current rules. If `status == .ready` and `suggestedDestination` is set, stop (rule suggestion wins).
    2. If still `.pending`, compute or fetch relevant `LearnedPattern`s and apply LearningService logic to see if any pattern-based suggestion qualifies (existing behavior).
    3. If there is still no suggestion and the model is available and enabled for this user:
        * Build `DestinationFeatures` from the `FileItem` and context.
        * Call `DestinationPredictionService.predictDestination(for:context:)` on a background task.
        * If a high-confidence prediction is returned and passes all gating/negative pattern checks, update `FileItem` fields for UI.
* This ordering preserves predictable behavior: explicit rules > learned patterns > ML predictions.
#### UI Surfaces (FileRow, AIInsightsView)
* FileRow:
    * No new view type is strictly required; `FileRow` already renders `FileItem.suggestedDestination`, `matchReason`, and `confidenceScore` via `ConfidenceBadge` and an expandable reasoning view.
    * For ML predictions, `matchReason` should clearly identify the source, e.g. "AI suggestion based on 12 similar PDF invoices moved to Documents/Finance".
    * `ConfidenceBadge` requires no code changes; its thresholds (High/Medium/Low) already align with the 0.5/0.6/0.9 ranges used by RuleEngine and LearningService and can now also represent ML confidence.
* AIInsightsView:
    * Extend `AIInsightsViewModel.Tab` with an optional new case if needed (e.g. `.predictions`) or reuse an existing tab (e.g. `suggestions`) but:
        * Show high-level metrics for ML predictions (acceptance rate, total predictions made, model version).
        * Provide a toggle (per user) to enable/disable ML predictions; when disabled, the pipeline uses only rules and pattern-based suggestions.
    * When the model is not yet trained or disabled, surface a short explanation instead of prediction metrics.
#### Error Handling, Ambiguity, Preview Flows
* Ambiguous predictions (top-1 and top-2 confidences close) should not be auto-applied:
    * Option A (Phase 3 scope-friendly): treat them as low-confidence and do not show an AI destination at all.
    * Option B (if time permits): show a compact "AI is unsure" dropdown in FileRow with the top 2 candidates, requiring explicit user selection.
* When predictions fail (no model, I/O error, or cold start):
    * Do not show partial or stale predictions.
    * Fall back to existing behavior and log a non-fatal analytics event (for diagnostic logs only; no telemetry leaves the device).
* Preview flows:
    * For bulk operations (e.g. "Organize all with AI" in a future phase), reuse the existing review/preview surfaces; in Phase 3 we keep predictions per-file via FileRow to minimize risk.
#### Explainability
* Always generate a concise explanation string for `matchReason` from `PredictionExplanation`, following a consistent pattern:
    * Include at most 1–2 key factors (extension + 1 keyword or project) and an approximate count of similar historical files.
    * Example: "Similar to 18 PDF files containing 'invoice' that you moved to Documents/Finance during work hours."
* When the user hovers the `ConfidenceBadge` tooltip, show extended explanation with slightly more detail (already supported through `matchReason`).
### Natural Language Rule Creation (Feature 3.2)
#### Parser Behavior
* Support a well-defined grammar of common rule types, focusing on:
    * Actions: "move", "copy", "delete", "organize" → `Rule.ActionType`.
    * Targets:
        * File types ("PDFs", "documents", "images", explicit extensions like ".pdf").
        * Name patterns ("screenshots", "files containing 'invoice'", "starting with 'ClientABC_'").
    * Time constraints:
        * Relative ages: "older than 30 days", "from last week", "from last month" → `RuleCondition.dateOlderThan`, `.dateModifiedOlderThan`, or `.dateAccessedOlderThan`.
    * Destinations:
        * Simple folder names: "to Archive", "to Documents/Finance".
        * Patterns with placeholders (later phase) like "to Work/{YYYY-MM}" can be parsed but may require manual confirmation or rejection in this phase.
* Extract intents via a pipeline:
    * Quick regex/keyword pass to detect obvious patterns (e.g. `older than (\d+) days`, `to ([A-Za-z0-9_ /-]+)`).
    * NaturalLanguage `NLTagger` to identify quantities, dates, and potential destination phrases.
    * Map each fragment to a `RuleCondition` (e.g. `.fileExtension("pdf")`, `.nameContains("invoice")`, `.dateOlderThan(days:n, extension:nil)`).
#### UI & Preview Flows (NaturalLanguageRuleView)
* `NaturalLanguageRuleView` (new SwiftUI view) and companion `NaturalLanguageRuleViewModel`:
    * Single multi-line text field where user types the rule.
    * As the user types, the view model:
        * Debounces input.
        * Calls `NaturalLanguageRuleParser.parse(_:)` on a background queue.
        * Updates `@Published parsedRule` and `parseState` (e.g. `.valid`, `.partial`, `.invalid`), and an explanation used to render a preview.
    * When the parser returns a valid `ParsedRule`:
        * Show a `RulePreviewCard` summarizing:
        * Action.
        * Human-readable list of conditions.
        * Destination.
        * Confidence/coverage estimate if we have any (e.g. "This rule would match ~120 existing files").
        * Primary CTA: "Create Rule" which calls `buildRule(from:)`, inserts the new `Rule` into SwiftData, and optionally navigates to the standard rule editor for fine-tuning.
    * For partial parses (`missingPieces` non-empty):
        * Display a structured "We need more info" message with specific missing components (e.g. "Where should these files go?" if destination missing).
        * Disable the "Create Rule" button until required pieces are filled, either via further text or UI form controls.
    * For invalid/unsupported phrases: show a clear error and a hint toward supported patterns ("Try something like 'Move PDFs older than 30 days to Archive'").
#### Ambiguity Resolution & Error Handling
* Ambiguous time ranges or actions:
    * If multiple interpretations exist (e.g. "last month" could be interpreted as a calendar month vs. last 30 days), choose a single consistent semantic (e.g. last 30 days) and mention it in the preview description.
* Conflicting conditions (e.g. "delete PDFs to Archive"):
    * Prefer not to auto-resolve; mark `ParsedRule` as invalid with a clear message.
* Destination validation:
    * Use `Rule.isValidDestinationPath(_:)` before constructing the final rule.
    * If a path looks unsafe or outside allowed roots, prevent rule creation and show an error.
#### Explainability
* For each parsed rule, generate a short explanation derived from `Rule.naturalLanguageDescription` and the parser’s explanation fields, e.g.:
    * "Will move PDF files older than 30 days into the 'Archive' folder."
* Keep `Rule.naturalLanguageDescription` as the canonical, user-presentable explanation for the created rule, ensuring consistency between NL-created rules and rules built via the classic UI.
## Contingencies & Guardrails
### Failure Modes and Fallbacks
* Insufficient data for training (few ActivityItems or too few distinct destinations):
    * Do not attempt to train; mark ML as disabled for that user and rely entirely on RuleEngine + LearningService.
    * `AIInsightsView` should surface a non-error explanation ("AI destination prediction will appear after Forma has seen more of your activity.").
* Training failures (Create ML errors, invalid data table, out-of-memory):
    * Catch and log locally; mark the attempted training run in `MLTrainingHistory` with `accepted = false` and an error message.
    * Preserve the previous model; do not surface partial models.
* Model load failures or corrupted model files:
    * On load failure, delete the corrupted model file, fall back to the last known-good version if available, otherwise disable predictions.
* I/O or sandbox issues:
    * If the app cannot read files used during feature extraction (e.g. path inaccessible due to sandbox or missing bookmarks), gracefully skip those examples rather than failing the whole training run.
* API/Framework limitations (e.g. Create ML not available in some runtime contexts):
    * Keep all ML code behind availability checks and a single `DestinationPredictionService` boundary, so the rest of the app can compile and run without it.
    * If ML is not available, the service advertises itself as disabled and never attempts training or prediction.
* Prediction timeouts or long-running training:
    * Enforce upper bounds on prediction latency (e.g. if a prediction does not complete within a short timeout, drop it and fall back to existing behavior).
    * For training, limit runtime by restricting dataset size and running on a background queue.
* Parsing ambiguity for natural language rules:
    * When `parseConfidence` is below a threshold or `missingPieces` is non-empty, do not allow direct rule creation; require either additional user input or falling back to the structured rule builder.
* UI states out of sync (e.g. ML disabled but old prediction still displayed in `FileRow`):
    * Ensure the pipeline always re-evaluates `FileItem` suggestions from current sources before rendering, and that predictions are not cached across model disable/enable toggles without recomputation.
### Privacy Constraints and Guardrails
* All ML and NLP processing remains on-device:
    * No network access from DestinationPredictionService or NaturalLanguageRuleParser.
    * No logging of file paths or names outside the app sandbox.
* Only metadata is used for training and prediction:
    * Use file names, extensions, sizes, and simple temporal features; Phase 3 does not inspect raw file contents.
* Security and safety:
    * Always validate destination paths via `Rule.isValidDestinationPath(_:)` and `PathValidator` before acting on predictions or NL rules.
    * Never silently delete files based solely on ML predictions; delete actions must derive from explicit rules (including NL-created rules) and still go through the existing secure file operations pipeline.
## Testing Strategy
### Unit Tests
* DestinationPredictionService:
    * Test feature extraction logic from `ActivityItem`/`FileItem` to `DestinationTrainingRecord` (correct tokens, time buckets, and label normalization).
    * Test confidence gating and fallback decision logic given mocked prediction outputs (without requiring a real ML model in tests).
    * Test model-selection logic in `MLModelManager` and handling of `MLTrainingHistory` (choosing active versions, handling invalidation/rollback).
* NaturalLanguageRuleParser:
    * Test parsing of supported patterns (e.g. "Move PDFs older than 30 days to Archive", "Delete screenshots from last week").
    * Test ambiguous/invalid inputs and verify `missingPieces` and error conditions are set correctly.
    * Test conversion from `ParsedRule` to `Rule` and that resulting `RuleCondition`s match expectations and are accepted by RuleEngine.
* LearningService enhancements:
    * Test new helper methods used for training data extraction and prediction outcome recording, ensuring they produce correct `DestinationTrainingRecord`s and ActivityItem entries.
### Integration Tests
* End-to-end pipeline tests (in `Forma File OrganizingTests`):
    * Simulate a small but realistic `ActivityItem` history, train a simple fake or stubbed model, and verify that:
        * A `FileItem` with no matching rule or learned pattern receives a prediction when the model is enabled and meets confidence thresholds.
        * Predictions are suppressed correctly when negative patterns or low-confidence criteria apply.
    * Test that NL-created rules are evaluated correctly by `RuleEngine.evaluateFile` with both production and test `Fileable`/`Ruleable` types.
* AIInsightsView integration:
    * Test that the view model correctly reports prediction-related stats when given synthetic `MLTrainingHistory` data.
### Simulation Tests with Synthetic ActivityItem Datasets
* Build synthetic datasets in tests or fixtures representing different user behaviors (e.g. heavy invoice workflow, mixed personal/work, many destinations vs few):
    * Use these to verify feature-extraction robustness and to unit-test evaluation metrics and gating logic (even if we do not run full Create ML training in tests for performance reasons).
    * Ensure the cold-start thresholds behave as expected (no predictions until the dataset is large enough).
### ML Evaluation Benchmarks
* Non-UI tests (possibly using XCTest `measure` blocks) that:
    * Run the full evaluation code on a synthetic dataset and assert that metrics are computed correctly.
    * Measure approximate training time on representative dataset sizes, ensuring it remains below agreed thresholds (e.g. < 5s for 1,000 examples on a typical Mac during development).
### Regression & UI Tests
* Regression tests:
    * Verify that existing RuleEngine behavior and LearningService pattern suggestions are unchanged when ML is disabled.
    * Ensure duplicate detection and project clustering remain unaffected by ML changes.
* UI acceptance tests (UITests):
    * For FileRow, verify that:
        * When a suggestion exists (rule or prediction), the destination pill and `ConfidenceBadge` appear and toggle reasoning.
        * When no suggestion exists, the UI does not show stale AI destinations.
    * For NaturalLanguageRuleView:
        * Verify preview rendering for valid phrases.
        * Ensure invalid/ambiguous phrases disable the "Create Rule" button and show appropriate messaging.
## Milestones & Acceptance Criteria
### Milestone 1: ML Infrastructure & Data Pipeline
* Deliverables:
    * `DestinationTrainingRecord` type and feature-extraction helpers (LearningService + a small helper module).
    * `MLTrainingHistory` SwiftData model and basic `MLModelManager` scaffolding (load/save/versioning API, no real training yet).
* Acceptance criteria:
    * Unit tests cover feature extraction and MLTrainingHistory persistence.
    * App compiles with ML scaffolding code present but predictions still disabled.
### Milestone 2: DestinationPredictionService Training & Gating
* Deliverables:
    * Full training pipeline implemented (data selection, MLDataTable creation, Create ML classifier training, offline evaluation, and model persistence).
    * Confidence-based prediction API with hard thresholds and negative-pattern integration.
    * Drift detection metrics and `shouldRetrain` logic.
* Acceptance criteria:
    * On synthetic data sets, offline accuracy and false positive thresholds are enforced as specified.
    * Runtime gating prevents low-confidence predictions from surfacing.
    * Tests verify that bad models are not activated and that rollback/disable behavior works.
### Milestone 3: Prediction UI Integration
* Deliverables:
    * Organizing pipeline updated to call DestinationPredictionService after rules and patterns only.
    * `FileItem` integration (setting `suggestedDestination`, `matchReason`, `confidenceScore`, and optional `suggestionSource`).
    * AIInsightsView updated with prediction metrics and an enable/disable toggle.
* Acceptance criteria:
    * With ML disabled, behavior is identical to pre-Phase-3 builds.
    * With ML enabled and a stubbed high-quality model, eligible files show predictions in FileRow with correct reasoning and confidence.
    * User can disable predictions and see them disappear without errors.
### Milestone 4: Natural Language Rule Parser & UI
* Deliverables:
    * `NaturalLanguageRuleParser` with support for the primary grammar described in the plan.
    * `NaturalLanguageRuleView` and `RulePreviewCard` integrated into the existing rules UI.
    * Safe conversion from `ParsedRule` to `Rule`, with validation and error messages.
* Acceptance criteria:
    * At least a defined suite of natural language inputs is parsed into correct `RuleCondition`s.
    * Invalid or ambiguous inputs are blocked from direct rule creation and surface clear guidance.
    * NL-created rules behave identically to manually created rules in RuleEngine tests.
### Milestone 5: Stabilization, Performance, and UX Polish
* Deliverables:
    * Performance passes (basic benchmarks for prediction latency and training time on synthetic data).
    * Additional tests for regression, edge cases, and UI polish.
    * Documentation updates for Phase 3 behavior and configuration.
* Acceptance criteria:
    * Prediction latency per file stays within agreed bounds in typical scenarios (e.g. tens of milliseconds for individual predictions).
    * No crashes or major regressions observed in integration tests; duplicate detection, project clustering, and existing pattern learning all continue to function.
    * UX review confirms that explanations are understandable, and ML behavior remains conservative and non-intrusive.
### Definition of “Phase 3 Complete”
Phase 3 is considered complete when:
* DestinationPredictionService is fully implemented and integrated, and:
    * For users with sufficient history, offline evaluation achieves ≥ 0.7 accuracy on representative test splits.
    * Runtime user acceptance rate for predictions (accept vs override/dismiss) reaches at least 0.6 over a monitored window.
    * Low-confidence or risky predictions are correctly suppressed, with fallbacks to rules and pattern-based logic.
* NaturalLanguageRuleParser and its UI allow users to create rules in natural language for the documented grammar, with:
    * At least 70% of test utterances parsed successfully into correct rules without manual correction.
    * No unsafe rules created silently; all delete rules and path-based actions still go through existing validation.
* All new functionality is on-device and privacy-preserving, fits within the existing MVVM + Services + SwiftData patterns, and passes the agreed unit, integration, UI, and performance tests.
