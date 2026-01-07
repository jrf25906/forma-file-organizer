# Phase 3: Predictive Intelligence Architecture

This document describes the architecture and implementation of Phase 3 AI features: ML-based destination prediction and natural language rule creation.

## Overview

Phase 3 extends Forma's AI capabilities with two major features:

1. **Destination Prediction (Feature 3.1)**: ML-based prediction of file destinations when no rules or patterns match
2. **Natural Language Rule Creation (Feature 3.2)**: Natural language parser for creating rules from freeform text

Both features integrate seamlessly with existing Phase 1-2 components (RuleEngine, LearningService, ContextDetectionService) while maintaining strong privacy guarantees and conservative gating.

## Architecture Principles

### Privacy-First
- All processing is **100% on-device**
- No network calls, no telemetry, no data leaves the Mac
- Training data derived only from local ActivityItem history

### Conservative Gating
- ML predictions require minimum data thresholds (50+ examples, 3+ destinations)
- Confidence-based filtering (minimum 0.7 confidence, 0.15 margin between top-2)
- Negative pattern blocking prevents unwanted suggestions
- Model evaluation gates prevent deployment of poor models

### Predictable Precedence
Organizing pipeline maintains strict ordering:
1. **RuleEngine** (explicit rules always win)
2. **LearnedPattern** (pattern-based suggestions)
3. **ML Predictions** (only when nothing else matches)

### Testability
- Protocol-based design allows dependency injection
- In-memory ModelContainer for tests
- Synthetic dataset generators for benchmarking
- Separate business logic from SwiftData/UI layers

## Component Architecture

### DestinationPredictionService

**Location**: `Services/DestinationPredictionService.swift`

**Responsibilities**:
- Train on-device Core ML classifiers from ActivityItem history
- Serve predictions with confidence gating and negative pattern filtering
- Manage model versions, storage, and rollback
- Track drift metrics and trigger retraining

**Key Types**:
```swift
actor DestinationPredictionService {
    func predictDestination(
        for file: FileItem,
        context: PredictionContext,
        negativePatterns: [LearnedPattern]
    ) async -> PredictedDestination?
    
    func scheduleTrainingIfNeeded(activityItems: [ActivityItem]) async
    func currentModelMetadata() async -> DestinationModelMetadata?
    func setMLEnabled(_ enabled: Bool)
    func recordOutcome(_ outcome: PredictionOutcome)
}
```

**Design Decisions**:
- **Actor isolation**: Prevents race conditions over shared ML model
- **Lazy loading**: Model loaded only on first prediction
- **Background training**: Training runs on dedicated serial queue

### Training Pipeline

**Data Flow**:
```
ActivityItem history → DestinationTrainingRecord → MLDataTable → MLTextClassifier
       ↓
  80/20 split for train/test
       ↓
  Evaluation (accuracy, FPR, confidence separation)
       ↓
  Model accepted/rejected → MLTrainingHistory
```

**Feature Extraction**:
- **Extension**: File extension (e.g., "pdf")
- **Name keywords**: Tokenized words from filename
- **File type category**: "document", "image", etc.
- **Time bucket**: Hour of day, weekday/weekend
- **Source folder**: Desktop, Downloads, etc.
- **Project cluster**: Optional cluster label from ContextDetectionService

Combined into single text feature for MLTextClassifier:
```
"ext_pdf kw_invoice cat_document workday_hour_10 src_Desktop"
```

### Evaluation Gates

**Offline (during training)**:
- Overall accuracy ≥ 0.7
- False positive rate ≤ 0.2
- Confidence separation ≥ 0.15 (avg correct vs incorrect predictions)

**Runtime (per prediction)**:
- Top-1 confidence ≥ 0.7
- Confidence margin (top-1 vs top-2) ≥ 0.15
- Not blocked by negative patterns
- Within allowed destinations (if specified)

### Cold-Start Strategy

**Thresholds**:
- **Minimum**: 50 examples across 3+ destinations (training enabled)
- **Inline predictions**: 200+ examples (show predictions in FileRow)
- **Below minimum**: No ML predictions, rely on rules + patterns

**Behavior by stage**:
- 0-49 examples: ML disabled
- 50-199 examples: ML enabled but soft suggestions (AIInsightsView only)
- 200+ examples: Inline predictions in FileRow

### Model Lifecycle

**Storage**:
```
~/Library/Application Support/Forma/MLModels/
  destinationPrediction_1-2024-12-03T120000Z.mlmodelc
  destinationPrediction_1-2024-12-05T140000Z.mlmodelc
```

**Versioning**:
- Version format: `{schema}-{timestamp}`
- Active version stored in UserDefaults
- Keep latest 3 versions on disk

**Rollback**:
When runtime metrics degrade (acceptance < 50% or override > 40%):
1. Mark current model as `accepted = false` in MLTrainingHistory
2. Revert to last `accepted == true` version
3. If no prior version, disable predictions

### Drift Detection

**Metrics tracked** (sliding window of last 100-200 predictions):
- Acceptance rate (user clicks "Organize")
- Override rate (user moves to different destination)
- Dismissal rate (user skips/ignores suggestion)

**Triggers for retraining**:
- Acceptance rate < 0.5
- Override rate > 0.4
- 30+ days since last training
- 25+ new high-quality labeled moves
- Label distribution shift

### NaturalLanguageRuleParser

**Location**: `Services/NaturalLanguageRuleParser.swift`

**Responsibilities**:
- Parse freeform text into structured `NLParsedRule`
- Detect ambiguities and mark for user resolution
- Convert parsed rules to concrete `Rule` models

**Architecture**:
```
User Input (String)
    ↓
Extract Clauses (action, file types, patterns, time, destination)
    ↓
Detect Ambiguities (time phrases, grouping hints)
    ↓
Generate RuleConditions
    ↓
NLParsedRule (ephemeral representation)
    ↓
Convert to Rule (after user confirms/resolves ambiguities)
```

**Supported Grammar**:
- **Actions**: move, copy, delete, organize
- **File types**: Extensions (.pdf), kinds (images, documents)
- **Name patterns**: "containing X", "starting with Y", "ending with Z"
- **Time constraints**: "older than N days/weeks/months/years"
- **Destinations**: "to FOLDER", "into PATH"
- **Logical operators**: "and", "or" (for multiple conditions)

**Ambiguity Handling**:

| Phrase | Ambiguity | Resolution |
|--------|-----------|------------|
| "last week" | Ambiguous time (7 days? Calendar week?) | Default to 7 days, warn user |
| "last month" | Ambiguous time (30 days? Calendar month?) | Default to 30 days, warn user |
| "by month" | Grouping (creation month? mod month?) | Prompt user for clarification |
| Conflicting actions | "move and delete" | Flag conflict, block conversion |

**Error Handling**:
- **No action**: Blocking error, cannot create rule
- **No destination**: Warning for move/copy (allowed for delete)
- **No conditions**: Warning, low confidence
- **Invalid path**: Validation via `Rule.isValidDestinationPath`

### FileScanPipeline Integration

**Location**: `Services/FileScanPipeline.swift`

**Pipeline Flow**:
```swift
func scanAndPersist(...) async -> ScanResult {
    // 1. Scan files from folders
    let files = await fileSystemService.scan(...)
    
    // 2. Evaluate explicit rules (RuleEngine)
    let ruleEvaluated = ruleEngine.evaluateFiles(files, rules: rules)
    
    // 3. Apply learned patterns (only for .pending files)
    let patternEvaluated = applyLearnedPatterns(to: ruleEvaluated)
    
    // 4. Apply ML predictions (only for still-.pending files)
    let evaluated = await applyMLPredictions(to: patternEvaluated)
    
    // 5. Upsert FileItem entities to SwiftData
    return persist(evaluated)
}
```

**Key Implementation Details**:
- Each stage checks `file.status == .pending` before applying suggestions
- Rules set `status = .ready` → patterns and ML are skipped
- Patterns set `status = .ready` → ML is skipped
- ML only runs for files that remain `.pending` after rules + patterns

### Data Models

**New Models**:

**MLTrainingHistory** (`@Model`):
```swift
@Model final class MLTrainingHistory {
    var id: UUID
    var modelName: String
    var version: String
    var trainedAt: Date
    var exampleCount: Int
    var labelCount: Int
    var validationAccuracy: Double
    var falsePositiveRate: Double?
    var accepted: Bool
    var notes: String?
}
```

**Ephemeral Types** (not persisted):
- `DestinationTrainingRecord`: Plain struct for training data
- `DestinationFeatures`: Feature representation for prediction
- `PredictedDestination`: Prediction result with confidence + explanation
- `PredictionContext`: Prediction settings (allowed destinations, thresholds)
- `NLParsedRule`: Parsed natural language rule (pre-conversion)

**Extended Fields** (on FileItem):
```swift
var suggestionSourceRaw: String? // "rule", "pattern", "mlPrediction"
var suggestionSource: SuggestionSource { get } // Computed property
```

## UI Integration

### Prediction Explanations

**PredictionExplanation**:
```swift
struct PredictionExplanation {
    var summary: String  // Short, user-facing explanation
    var reasons: [String]  // 1-3 key factors
    var exampleFiles: [String]  // Up to 3 example file names
}
```

**Example Explanations**:
- Rule: "Matches your 'PDFs to Work Documents' rule"
- Pattern: "Based on learned pattern: PDFs containing 'invoice' → Documents/Finance"
- ML: "Similar to 18 PDF files containing 'invoice' that you moved to Documents/Finance during work hours"

### Ambiguity Resolution Sheets

**NaturalLanguageRuleView** presents modal sheets when ambiguities detected:

**Time Ambiguity Sheet**:
- Prompt: "'Last week' could mean different things"
- Options: "Exactly 7 days", "Last Monday-Sunday", "Custom..."

**Grouping Ambiguity Sheet**:
- Prompt: "'By month' – which date do you mean?"
- Options: "Use creation month", "Use modification month", "Keep grouping manual"

### FileRow Display

**ConfidenceBadge** (existing component):
- High (≥0.9): Green badge
- Medium (0.6-0.89): Yellow badge
- Low (<0.6): Gray badge

**Source indicators**:
- Rule: "📋 Rule Match"
- Pattern: "🧠 Learned Pattern"
- ML: "🤖 AI Suggestion"

## Performance Targets

### Prediction Latency
- **Target**: ≤5-20ms per file (depending on dataset size)
- **Measurement**: XCTest `measure{}` blocks in `DestinationPredictionPerformanceTests`

### Training Time
- 100 examples: ≤1 second
- 500 examples: ≤2 seconds
- 1000 examples: ≤4 seconds (**key Milestone 5 criterion**)
- 5000 examples (max): ≤10 seconds

### Memory Usage
- Model size: ~5-10 MB on disk
- In-memory overhead: <50 MB during training
- No memory leaks (verified via XCTMemoryMetric)

## Security & Safety

### Path Validation
All destinations validated via existing `Rule.isValidDestinationPath`:
- No path traversal attacks
- Must be within user's home directory
- No system folders

### Delete Rule Safety
NL-created delete rules:
- Show file count preview before enabling
- Require explicit user confirmation
- Cannot be created with low confidence

### Symlink Protection
Existing FileOperationsService security applies:
- No following symlinks
- Device node rejection
- FIFO rejection

## Testing Strategy

### Unit Tests
- **DestinationPredictionService**: Feature extraction, gating logic, model selection
- **NaturalLanguageRuleParser**: Parse accuracy, ambiguity detection, error messages
- **LearningService**: Training record generation, outcome recording

### Integration Tests
- **FileScanPipeline**: Precedence ordering (rules → patterns → ML)
- **DashboardViewModel**: End-to-end file scanning with predictions
- **Prediction outcome tracking**: Acceptance/override flow

### Regression Tests
- Cold-start behavior (insufficient data thresholds)
- Confidence gating (low confidence, insufficient margin)
- Negative pattern blocking
- Model invalidation and rollback
- Drift detection triggers
- NL parser edge cases (ambiguous inputs, invalid syntax)

### Performance Tests
- Prediction latency benchmarks
- Training time benchmarks (100, 500, 1000, 5000 examples)
- Memory usage during training

## Fallback Behavior

**When ML predictions fail**:
- Corrupted model → Delete and fall back to previous version
- No model available → Fall back to rules + patterns only
- Training fails → Mark model rejected, keep previous model
- Prediction timeout → Log and return nil (non-fatal)

**User Experience**:
- ML failure is transparent (app continues with rules/patterns)
- No blocking errors or crashes
- Diagnostic logs for troubleshooting

## Future Enhancements

**Phase 3 Scope** (current):
- Single text feature column (combined tokens)
- MLTextClassifier (Create ML)
- Basic time buckets (hour, weekday/weekend)

**Future Phases** (out of scope):
- Multi-column features (numeric, categorical)
- Custom CoreML models with embeddings
- Per-user model tuning
- Cross-device sync (via iCloud)
- Advanced time features (seasonal patterns)

## References

- **Phase 3 Implementation Plan**: `Docs/Phase 3 Predictive Intelligence Implementation Plan.md`
- **Main Architecture Doc**: `Docs/Architecture/ARCHITECTURE.md`
- **RuleEngine Architecture**: `Docs/Architecture/RuleEngine-Architecture.md`
- **WARP.md**: Development workflows and testing patterns
- **Test Files**:
  - `DestinationPredictionPerformanceTests.swift`
  - `DestinationPredictionGatingTests.swift`
  - `NaturalLanguageRuleParserEdgeCaseTests.swift`
  - `FileScanPipelinePrecedenceTests.swift`
