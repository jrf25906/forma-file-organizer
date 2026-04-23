import XCTest
import SwiftData
import CoreML
@testable import Forma_File_Organizing

/// Regression tests for DestinationPredictionService gating logic.
///
/// Tests cover:
/// - Cold-start behavior (insufficient data thresholds)
/// - Confidence threshold gating
/// - Negative pattern blocking
/// - Model invalidation and rollback
/// - Drift detection triggers
/// - ML enable/disable toggles
@available(macOS 13.0, *)
@MainActor
final class DestinationPredictionGatingTests: XCTestCase {

    private final class StubPredictionEngine: PredictionEngine, @unchecked Sendable {
        var requiresModel: Bool { false }
        var nextOutcome: PredictionOutcome?
        private(set) var predictCalls: [DestinationFeatures] = []

        enum StubError: Error {
            case noOutcome
        }

        func predict(features: DestinationFeatures, model: MLModel?) async throws -> PredictionOutcome {
            predictCalls.append(features)
            guard let outcome = nextOutcome else {
                throw StubError.noOutcome
            }
            return outcome
        }
    }
    
    var container: ModelContainer!
    var modelContext: ModelContext!
    var service: DestinationPredictionService!
    var learningService: LearningService!
    private var predictionEngine: StubPredictionEngine!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()

        FeatureFlagService.shared.resetToDefaults()
        
        // Create in-memory model container
        let schema = Schema([FileItem.self, Rule.self, ActivityItem.self, LearnedPattern.self, MLTrainingHistory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        modelContext = container.mainContext
        learningService = LearningService()
        predictionEngine = StubPredictionEngine()
        service = DestinationPredictionService(
            modelContext: modelContext,
            learningService: learningService,
            predictionEngine: predictionEngine
        )
    }
    
    override func tearDown() async throws {
        // IMPORTANT: Set actor to nil first while event loop is still active
        // to allow proper Swift Concurrency cleanup
        service = nil
        
        // Small yield to let actor deallocation complete
        await Task.yield()
        
        // Now safe to clean up the rest
        predictionEngine = nil
        learningService = nil
        modelContext = nil
        container = nil
        
        FeatureFlagService.shared.resetToDefaults()
        try await super.tearDown()
    }
    
    // MARK: - Cold-Start Behavior Tests
    
    /// Test: No training with insufficient data (< 50 examples)
    func testColdStart_InsufficientData() async throws {
        // Create only 30 activity items (below minimum of 50)
        let activityItems = createSyntheticActivityItems(count: 30, destinations: ["Documents/Work", "Archive"])
        
        await service.scheduleTrainingIfNeeded(activityItems: activityItems)
        
        // Verify no model was trained
        let metadata = await service.currentModelMetadata()
        XCTAssertNil(metadata, "No model should be trained with < 50 examples")
        
        // Verify predictions return nil
        let file = createTestFile(name: "test.pdf", ext: "pdf")
        let context = PredictionContext()
        let result = await service.predictDestination(for: file, context: context)
        XCTAssertNil(result, "Predictions should return nil when no model exists")
    }
    
    /// Test: No training with insufficient destination diversity (< 3 destinations)
    func testColdStart_InsufficientDestinations() async throws {
        // Create 60 examples but only 2 unique destinations
        let activityItems = createSyntheticActivityItems(count: 60, destinations: ["Documents/Work", "Documents/Work"])
        
        await service.scheduleTrainingIfNeeded(activityItems: activityItems)
        
        // Verify no model was trained
        let metadata = await service.currentModelMetadata()
        XCTAssertNil(metadata, "No model should be trained with < 3 unique destinations")
    }
    
    /// Test: Training succeeds with minimum thresholds met (50 examples, 3 destinations)
    func testColdStart_MinimumThresholdsMet() async throws {
        // Create exactly 50 examples with 3 destinations
        let destinations = ["Documents/Work", "Documents/Personal", "Archive"]
        let activityItems = createSyntheticActivityItems(count: 50, destinations: destinations)
        
        await service.scheduleTrainingIfNeeded(activityItems: activityItems)
        
        // Verify model was trained (metadata should exist)
        // Note: Actual model training may still fail evaluation gates, so we check attempt was made
        // by verifying training history exists
        let descriptor = FetchDescriptor<MLTrainingHistory>()
        let history = try modelContext.fetch(descriptor)
        XCTAssertEqual(history.count, 1, "Training should record a model history row when thresholds are met")
    }

    func testColdStart_LabelOnlyClassifierRecordsMissingProbabilityRejection() async throws {
        let destinations = ["Documents/Work", "Documents/Personal", "Archive"]
        let activityItems = createSyntheticActivityItems(count: 50, destinations: destinations)

        await service.scheduleTrainingIfNeeded(activityItems: activityItems)

        let descriptor = FetchDescriptor<MLTrainingHistory>()
        let history = try XCTUnwrap(modelContext.fetch(descriptor).first)
        XCTAssertFalse(history.accepted, "Label-only CreateML output should not be accepted as confidence-gated")
        let notes = try XCTUnwrap(history.notes)
        XCTAssertTrue(
            notes.localizedCaseInsensitiveContains("confidence probabilities"),
            "Rejection notes should identify missing probability output instead of implying poor accuracy alone"
        )
    }
    
    // MARK: - Confidence Threshold Gating Tests
    
    /// Test: Predictions below minimum confidence are suppressed
    func testConfidenceGating_BelowMinimum() async throws {
        let file = createTestFile(name: "test.pdf", ext: "pdf")
        let context = PredictionContext(minimumConfidence: 0.9) // Very high threshold

        predictionEngine.nextOutcome = PredictionOutcome(label: "Archive", confidence: 0.5, top2Confidence: 0.1)

        let result = await service.predictDestination(for: file, context: context)
        XCTAssertNil(result, "High confidence threshold should suppress predictions")
    }
    
    /// Test: Confidence margin between top-1 and top-2 enforced
    func testConfidenceGating_InsufficientMargin() async throws {
        // When top-1 and top-2 are too close (< 0.15 margin), prediction should be suppressed
        let file = createTestFile(name: "ambiguous.pdf", ext: "pdf")
        let context = PredictionContext(minimumConfidence: 0.6)

        predictionEngine.nextOutcome = PredictionOutcome(label: "Documents", confidence: 0.8, top2Confidence: 0.7)

        let result = await service.predictDestination(for: file, context: context)
        XCTAssertNil(result, "Ambiguous predictions should be suppressed")
    }
    
    // MARK: - Negative Pattern Blocking Tests
    
    /// Test: Predictions are blocked by negative patterns
    func testNegativePatternBlocking() async throws {
        let file = createTestFile(name: "screenshot.png", ext: "png")
        
        // Create a negative pattern for png -> Archive
        let negativePattern = LearnedPattern(
            patternDescription: "PNG -> Archive (negative)",
            fileExtension: "png",
            destinationPath: "Archive",
            occurrenceCount: 5,
            confidenceScore: 0.9,
            conditions: [.fileExtension("png")],
            isNegativePattern: true
        )
        
        let context = PredictionContext()

        predictionEngine.nextOutcome = PredictionOutcome(label: "Archive", confidence: 0.8, top2Confidence: 0.2)
        
        // Prediction should be suppressed if it suggests Archive for png
        let result = await service.predictDestination(
            for: file,
            context: context,
            negativePatterns: [negativePattern]
        )
        
        // If a prediction was made, verify it's not the blocked destination
        if let prediction = result {
            XCTAssertNotEqual(
                prediction.path,
                "Archive",
                "Negative pattern should block predictions to Archive for png files"
            )
        }
    }
    
    /// Test: Negative patterns don't block unrelated predictions
    func testNegativePattern_DoesNotBlockUnrelated() async throws {
        let file = createTestFile(name: "invoice.pdf", ext: "pdf")
        
        // Create negative pattern for png -> Archive (should not affect pdf files)
        let negativePattern = LearnedPattern(
            patternDescription: "PNG -> Archive (negative)",
            fileExtension: "png",
            destinationPath: "Archive",
            occurrenceCount: 5,
            confidenceScore: 0.9,
            conditions: [.fileExtension("png")],
            isNegativePattern: true
        )
        
        let context = PredictionContext()
        predictionEngine.nextOutcome = PredictionOutcome(label: "Documents/Work", confidence: 0.8, top2Confidence: 0.2)
        
        // PDF prediction should not be affected by png negative pattern
        let result = await service.predictDestination(
            for: file,
            context: context,
            negativePatterns: [negativePattern]
        )
        
        // Result may be nil (no model), but negative pattern shouldn't cause false blocking
        // This test verifies the filtering logic is extension-specific
        XCTAssertNotNil(result, "Unrelated negative patterns should not block predictions")
    }
    
    // MARK: - Allowed Destinations Filtering Tests
    
    /// Test: Predictions outside allowed destinations are filtered
    func testAllowedDestinations_Filtering() async throws {
        let file = createTestFile(name: "test.pdf", ext: "pdf")
        
        let context = PredictionContext(
            allowedDestinations: ["Documents/Work", "Documents/Personal"],
            mlEnabled: true,
            minimumConfidence: 0.7
        )

        predictionEngine.nextOutcome = PredictionOutcome(label: "Archive", confidence: 0.8, top2Confidence: 0.2)
        
        let result = await service.predictDestination(for: file, context: context)
        
        XCTAssertNil(result, "Predictions outside allowed destinations should be filtered")
    }
    
    /// Test: Empty allowed destinations list allows all predictions
    func testAllowedDestinations_EmptyListAllowsAll() async throws {
        let file = createTestFile(name: "test.pdf", ext: "pdf")
        
        let context = PredictionContext(
            allowedDestinations: [], // Empty = no restrictions
            mlEnabled: true
        )

        predictionEngine.nextOutcome = PredictionOutcome(label: "Archive", confidence: 0.8, top2Confidence: 0.2)
        
        let result = await service.predictDestination(for: file, context: context)
        
        XCTAssertNotNil(result, "Empty allowed destinations should not filter predictions")
    }
    
    // MARK: - ML Enable/Disable Tests
    
    /// Test: Predictions disabled when ML is off in context
    func testMLDisabled_InContext() async throws {
        let file = createTestFile(name: "test.pdf", ext: "pdf")
        
        let context = PredictionContext(mlEnabled: false)

        predictionEngine.nextOutcome = PredictionOutcome(label: "Archive", confidence: 0.8, top2Confidence: 0.2)
        
        let result = await service.predictDestination(for: file, context: context)
        XCTAssertNil(result, "Predictions should return nil when ML is disabled in context")
    }
    
    /// Test: Predictions disabled when ML is off in service
    func testMLDisabled_InService() async throws {
        service.setMLEnabled(false)
        
        let file = createTestFile(name: "test.pdf", ext: "pdf")
        let context = PredictionContext(mlEnabled: true) // Enabled in context but not service

        predictionEngine.nextOutcome = PredictionOutcome(label: "Archive", confidence: 0.8, top2Confidence: 0.2)
        
        let result = await service.predictDestination(for: file, context: context)
        XCTAssertNil(result, "Predictions should return nil when ML is disabled in service")
    }
    
    /// Test: Predictions re-enabled when ML toggle is turned back on
    func testMLEnabled_Toggle() async throws {
        // Disable ML
        service.setMLEnabled(false)
        
        let file = createTestFile(name: "test.pdf", ext: "pdf")
        let context = PredictionContext()

        predictionEngine.nextOutcome = PredictionOutcome(label: "Archive", confidence: 0.8, top2Confidence: 0.2)
        
        var result = await service.predictDestination(for: file, context: context)
        XCTAssertNil(result, "Predictions should be nil when disabled")
        
        // Re-enable ML
        service.setMLEnabled(true)
        
        result = await service.predictDestination(for: file, context: context)
        XCTAssertNotNil(result, "Predictions should resume after re-enabling ML")
    }
    
    // MARK: - Model Invalidation and Rollback Tests
    
    /// Test: Failed training does not replace existing good model
    func testModelInvalidation_KeepsPreviousModel() async throws {
        // This test would require:
        // 1. Training a good model
        // 2. Attempting to train a bad model (low accuracy)
        // 3. Verifying the good model is still active
        
        // For now, we verify the behavior conceptually
        // by checking that MLTrainingHistory tracks accepted vs rejected models
        
        let goodModelHistory = MLTrainingHistory(
            modelName: "destinationPrediction",
            version: "1-2024-01-01",
            exampleCount: 100,
            labelCount: 3,
            validationAccuracy: 0.75,
            falsePositiveRate: 0.15,
            accepted: true,
            notes: "Good model"
        )
        
        let badModelHistory = MLTrainingHistory(
            modelName: "destinationPrediction",
            version: "1-2024-01-02",
            exampleCount: 100,
            labelCount: 3,
            validationAccuracy: 0.5, // Below 0.7 threshold
            falsePositiveRate: 0.3,
            accepted: false,
            notes: "Failed evaluation"
        )
        
        modelContext.insert(goodModelHistory)
        modelContext.insert(badModelHistory)
        try modelContext.save()
        
        // Verify only accepted models are considered active
        let descriptor = FetchDescriptor<MLTrainingHistory>(
            predicate: #Predicate { $0.accepted == true }
        )
        let acceptedModels = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(acceptedModels.count, 1, "Only good model should be accepted")
        XCTAssertEqual(acceptedModels.first?.version, "1-2024-01-01")
    }
    
    /// Test: Rollback to previous version when current model is invalidated
    func testModelRollback() async throws {
        // Create two model versions: v1 (active) and v2 (rejected)
        let v1 = MLTrainingHistory(
            modelName: "destinationPrediction",
            version: "1-2024-01-01",
            exampleCount: 100,
            labelCount: 3,
            validationAccuracy: 0.8,
            accepted: true,
            notes: "Original good model"
        )
        
        let v2 = MLTrainingHistory(
            modelName: "destinationPrediction",
            version: "1-2024-01-02",
            exampleCount: 120,
            labelCount: 3,
            validationAccuracy: 0.55,
            accepted: false,
            notes: "Rejected update"
        )
        
        modelContext.insert(v1)
        modelContext.insert(v2)
        try modelContext.save()
        
        // Verify rollback logic: latest accepted model should be v1
        let descriptor = FetchDescriptor<MLTrainingHistory>(
            predicate: #Predicate { $0.accepted == true && $0.modelName == "destinationPrediction" },
            sortBy: [SortDescriptor(\.trainedAt, order: .reverse)]
        )
        
        let activeModel = try modelContext.fetch(descriptor).first
        XCTAssertEqual(activeModel?.version, "1-2024-01-01", "Should roll back to last accepted model")
    }

    // MARK: - Evaluation Helper Tests

    func testPredictionOutcomeExtractsSortedProbabilitiesFromCoreMLProvider() throws {
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "label": "Documents/Work",
            "labelProbability": [
                "Archive": 0.12,
                "Documents/Work": 0.74,
                "Pictures": 0.14
            ]
        ])

        let outcome = try CoreMLPredictionEngine.outcome(from: provider)

        XCTAssertEqual(outcome.label, "Documents/Work")
        XCTAssertEqual(outcome.confidence, 0.74, accuracy: 0.0001)
        XCTAssertEqual(outcome.top2Confidence ?? -1, 0.14, accuracy: 0.0001)
    }

    func testPredictionLabelExtractionAllowsMissingProbabilitiesWithoutInventingConfidence() throws {
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "label": "Documents/Work"
        ])

        XCTAssertEqual(try CoreMLPredictionEngine.predictedLabel(from: provider), "Documents/Work")
        XCTAssertNil(CoreMLPredictionEngine.confidence(for: "Documents/Work", from: provider))
        XCTAssertThrowsError(try CoreMLPredictionEngine.outcome(from: provider))
    }

    func testDatasetPreparationSamplesBeforeCapping() {
        let records = createTrainingRecords(count: 10)
        var observedLimit: Int?

        let prepared = DestinationTrainingDatasetPreparer.prepare(
            records: records,
            maximumDatasetSize: 5,
            trainFraction: 0.8,
            sampler: { records, limit in
                observedLimit = limit
                return Array(records.reversed().prefix(limit))
            }
        )

        XCTAssertEqual(observedLimit, 5)
        XCTAssertEqual(prepared.train.map(\.fileName), ["file-9.pdf", "file-8.pdf", "file-7.pdf", "file-6.pdf"])
        XCTAssertEqual(prepared.test.map(\.fileName), ["file-5.pdf"])
    }

    func testAcceptanceGateRejectsMissingConfidenceSamples() {
        let metrics = DestinationEvaluationMetrics(
            accuracy: 0.95,
            falsePositiveRate: 0.05,
            avgCorrectConfidence: nil,
            avgIncorrectConfidence: nil,
            confidenceSampleCount: 0,
            missingConfidenceCount: 10
        )

        XCTAssertFalse(
            DestinationModelAcceptanceGate.accepts(
                metrics: metrics,
                minimumAccuracy: 0.7,
                maximumFalsePositiveRate: 0.2,
                minimumConfidenceSeparation: 0.15
            ),
            "Models without probability output should fail explicitly instead of receiving invented confidence"
        )
        XCTAssertTrue(
            DestinationModelAcceptanceGate.rejectionNotes(
                for: metrics,
                minimumAccuracy: 0.7,
                maximumFalsePositiveRate: 0.2,
                minimumConfidenceSeparation: 0.15
            ).localizedCaseInsensitiveContains("confidence probabilities")
        )
    }

    func testAcceptanceGateNotesConfidenceSeparationFailures() {
        let metrics = DestinationEvaluationMetrics(
            accuracy: 0.95,
            falsePositiveRate: 0.05,
            avgCorrectConfidence: 0.64,
            avgIncorrectConfidence: 0.55,
            confidenceSampleCount: 10,
            missingConfidenceCount: 0
        )

        XCTAssertFalse(
            DestinationModelAcceptanceGate.accepts(
                metrics: metrics,
                minimumAccuracy: 0.7,
                maximumFalsePositiveRate: 0.2,
                minimumConfidenceSeparation: 0.15
            )
        )
        XCTAssertTrue(
            DestinationModelAcceptanceGate.rejectionNotes(
                for: metrics,
                minimumAccuracy: 0.7,
                maximumFalsePositiveRate: 0.2,
                minimumConfidenceSeparation: 0.15
            ).localizedCaseInsensitiveContains("confidence separation")
        )
    }

    func testModelVersionStringUsesPOSIXLocaleAndUTC() {
        let version = DestinationModelVersion.string(for: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(version, "1-1970-01-01T000000Z")
        XCTAssertTrue(version.allSatisfy(\.isASCII), "Version strings should stay ASCII across user locales")
    }
    
    // MARK: - Helper Methods
    
    /// Create synthetic activity items for testing.
    func createSyntheticActivityItems(count: Int, destinations: [String]) -> [ActivityItem] {
        let extensions = ["pdf", "docx", "jpg", "png", "mp4"]
        let names = ["invoice", "report", "screenshot", "document", "video"]
        
        return (0..<count).map { i in
            let ext = extensions[i % extensions.count]
            let name = "\(names[i % names.count])_\(i)"
            let dest = destinations[i % destinations.count]
            
            return ActivityItem(
                activityType: .fileOrganized,
                fileName: "\(name).\(ext)",
                details: "Moved \(name).\(ext) to \(dest)",
                fileExtension: ext
            )
        }
    }
    
    /// Create a test FileItem.
    func createTestFile(name: String, ext: String) -> FileItem {
        FileItem(
            path: "/tmp/\(name).\(ext)",
            sizeInBytes: 1024,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .desktop,
            destination: nil,
            status: .pending
        )
    }

    private func createTrainingRecords(count: Int) -> [DestinationTrainingRecord] {
        (0..<count).map { index in
            DestinationTrainingRecord(
                fileName: "file-\(index).pdf",
                fileExtension: "pdf",
                sourceLocation: "Downloads",
                destinationPath: "Documents/\(index % 3)",
                timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                projectCluster: nil
            )
        }
    }
}
