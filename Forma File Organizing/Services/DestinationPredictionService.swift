import Foundation
@preconcurrency import CoreML
@preconcurrency import CreateML
import SwiftData
import TabularData

/// Service responsible for ML-based destination prediction for file organization.
///
/// ## Responsibilities
/// - Train and evaluate on-device Core ML classifiers
/// - Manage model versions, storage, and rollback
/// - Serve predictions with confidence gating
/// - Track drift metrics and trigger retraining
///
/// ## Privacy
/// All processing is on-device. No data leaves the Mac.
///
/// Note: Uses @MainActor to avoid actor boundary issues with SwiftData models
/// (FileItem, ActivityItem) which are main-actor-isolated by design.
@available(macOS 13.0, *)
@MainActor
final class DestinationPredictionService {
    
    // MARK: - Configuration
    
    /// Model identifier for tracking
    private let modelName = "destinationPrediction"
    
    /// Minimum training examples required before training
    private let minimumTrainingExamples = 50
    
    /// Minimum distinct destinations required
    private let minimumDestinations = 3
    
    /// Accuracy threshold for accepting a trained model
    private let minimumAccuracy = 0.7
    
    /// Maximum false positive rate
    private let maximumFalsePositiveRate = 0.2
    
    /// Minimum confidence difference between correct and incorrect predictions
    private let minimumConfidenceSeparation = 0.15
    
    /// Confidence margin required between top-1 and top-2
    private let confidenceMargin = 0.15
    
    /// Maximum dataset size to bound memory and training time
    private let maximumDatasetSize = 5000
    
    // MARK: - State
    
    /// Currently loaded ML model (lazy-loaded)
    private var currentModel: MLModel?
    
    /// Current model version string
    private var currentModelVersion: String?
    
    /// Whether ML predictions are enabled
    private var mlEnabled = true
    
    /// Sliding window statistics for drift detection
    private var predictionStats = PredictionStatistics()
    
    /// Model context for accessing training history
    private let modelContext: ModelContext
    
    /// Learning service for feature extraction
    private let learningService: LearningService

    /// Destination resolver for bookmark-backed predictions
    private let destinationResolver = DestinationResolver()

    /// Context detection for project cluster features
    private let contextDetectionService = ContextDetectionService()

    /// Cached training counts for explanation text
    private var trainingCountCache: [String: Int] = [:]
    private var trainingCountCacheDate: Date?
    private let trainingCountCacheTTL: TimeInterval = 300

    /// Cached project cluster lookup by file path
    private var clusterLookupCache: [String: String] = [:]
    private var clusterLookupCacheDate: Date?
    private let clusterLookupTTL: TimeInterval = 300

    /// Prediction engine for CoreML (or test stubs)
    private let predictionEngine: PredictionEngine
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        learningService: LearningService? = nil,
        predictionEngine: PredictionEngine = CoreMLPredictionEngine()
    ) {
        self.modelContext = modelContext
        // Create LearningService here in @MainActor context, not in default parameter
        self.learningService = learningService ?? LearningService()
        self.predictionEngine = predictionEngine
    }
    
    // MARK: - Public API
    
    /// Predict destination for a file with confidence gating and negative pattern filtering.
    ///
    /// - Parameters:
    ///   - file: FileItem to predict destination for
    ///   - context: Prediction context (allowed destinations, confidence thresholds)
    ///   - negativePatterns: Learned negative patterns to filter against
    /// - Returns: PredictedDestination if confident, nil otherwise
    func predictDestination(
        for file: FileItem,
        context: PredictionContext,
        negativePatterns: [LearnedPattern] = []
    ) async -> PredictedDestination? {
        await predictDestination(
            for: file,
            context: context,
            negativePatterns: negativePatterns,
            projectCluster: nil
        )
    }

    private func predictDestination(
        for file: FileItem,
        context: PredictionContext,
        negativePatterns: [LearnedPattern],
        projectCluster: String?
    ) async -> PredictedDestination? {
        // Check feature flag
        guard FeatureFlagService.shared.isEnabled(.destinationPrediction) else {
            return nil
        }

        // Check if ML is enabled
        guard mlEnabled && context.mlEnabled else { return nil }
        
        let model: MLModel?
        if predictionEngine.requiresModel {
            do {
                model = try await loadModel()
            } catch {
                Log.warning("DestinationPredictionService: Failed to load model: \(error.localizedDescription)", category: .analytics)
                return nil
            }
        } else {
            do {
                model = try await loadModel()
            } catch {
                Log.debug("DestinationPredictionService: Optional model load failed: \(error.localizedDescription)", category: .analytics)
                model = nil
            }
        }
        
        // Extract features
        let features = extractFeatures(from: file, projectCluster: projectCluster)
        
        // Run prediction
        let outcome: PredictionOutcome
        do {
            outcome = try await predictionEngine.predict(features: features, model: model)
        } catch {
            Log.warning("DestinationPredictionService: Prediction failed for \(file.name): \(error.localizedDescription)", category: .analytics)
            return nil
        }
        let predictedPath = outcome.label
        let confidence = outcome.confidence
        let top2Confidence = outcome.top2Confidence
        
        // Apply confidence gating
        guard confidence >= context.minimumConfidence else {
            Log.debug("Prediction confidence \(confidence) below threshold \(context.minimumConfidence)", category: .analytics)
            return nil
        }
        
        // Check margin between top-1 and top-2
        if let top2 = top2Confidence, confidence - top2 < confidenceMargin {
            Log.debug("Insufficient confidence margin: \(confidence) vs \(top2)", category: .analytics)
            return nil
        }
        
        // Filter by negative patterns
        for pattern in negativePatterns where pattern.isNegativePattern {
            if pattern.shouldSuppress(fileExtension: file.fileExtension, destination: predictedPath) {
                Log.debug("Prediction suppressed by negative pattern", category: .analytics)
                return nil
            }
        }
        
        // Filter by allowed destinations if specified
        if !context.allowedDestinations.isEmpty && !context.allowedDestinations.contains(predictedPath) {
            return nil
        }
        
        // Generate explanation
        let explanation = generateExplanation(
            for: file,
            predictedPath: predictedPath,
            confidence: confidence,
            features: features
        )
        
        // Record prediction shown
        predictionStats.recordPrediction()
        
        let resolvedDisplayName = displayNameForPath(predictedPath)
        let placeholderDestination = Destination.folder(bookmark: Data(), displayName: resolvedDisplayName)
        let resolvedDestination = destinationResolver.resolveIfExists(placeholderDestination)

        return PredictedDestination(
            path: predictedPath,
            confidence: confidence,
            source: .mlPrediction,
            explanation: explanation,
            modelVersion: currentModelVersion ?? "unknown",
            bookmarkData: resolvedDestination?.bookmarkData
        )
    }

    // MARK: - Batch Prediction with Caching

    /// Cache key for batch predictions (groups files by similar characteristics)
    private struct PredictionCacheKey: Hashable {
        let fileExtension: String
        let category: String
        let sourceFolder: String
        let timeBucket: String
        let projectCluster: String?
    }

    /// Predict destinations for multiple files with caching for similar files.
    /// Files with identical (extension, category, sourceFolder, timeBucket) share cached results.
    ///
    /// - Parameters:
    ///   - files: Array of FileItems to predict destinations for
    ///   - context: Prediction context (allowed destinations, confidence thresholds)
    ///   - negativePatterns: Learned negative patterns to filter against
    /// - Returns: Dictionary mapping file path to predicted destination
    func predictDestinationsBatch(
        for files: [FileItem],
        context: PredictionContext,
        negativePatterns: [LearnedPattern] = []
    ) async -> [String: PredictedDestination] {
        guard mlEnabled && context.mlEnabled else { return [:] }

        let clusterMap = clusterLookup(for: files)

        // Group files by cache key (similar characteristics get same prediction)
        var filesByKey: [PredictionCacheKey: [FileItem]] = [:]
        let timeBucket = generateTimeBucket(date: Date())

        for file in files {
            let projectCluster = clusterMap[file.path]
            let key = PredictionCacheKey(
                fileExtension: file.fileExtension,
                category: FileTypeCategory.category(for: file.fileExtension).rawValue,
                sourceFolder: file.location.rawValue,
                timeBucket: timeBucket,
                projectCluster: projectCluster
            )
            filesByKey[key, default: []].append(file)
        }

        var results: [String: PredictedDestination] = [:]
        var cache: [PredictionCacheKey: PredictedDestination?] = [:]

        // Process each group, using cache for identical feature groups
        for (key, groupFiles) in filesByKey {
            // Check cache first
            if let cachedResult = cache[key] {
                // Apply cached result to all files in group
                for file in groupFiles {
                    if let prediction = cachedResult {
                        results[file.path] = prediction
                    }
                }
                continue
            }

            // Make prediction for first file in group (representative)
            guard let representative = groupFiles.first else { continue }
            let prediction = await predictDestination(
                for: representative,
                context: context,
                negativePatterns: negativePatterns,
                projectCluster: key.projectCluster
            )

            // Cache the result
            cache[key] = prediction

            // Apply to all files in group
            for file in groupFiles {
                if let prediction = prediction {
                    results[file.path] = prediction
                }
            }
        }

        #if DEBUG
        let cacheHitRate = files.count > 0 ? Double(files.count - cache.count) / Double(files.count) : 0
        Log.debug("Batch prediction: \(files.count) files, \(cache.count) unique groups, \(Int(cacheHitRate * 100))% cache reuse", category: .analytics)
        #endif

        return results
    }

    /// Schedule training if conditions are met (sufficient data, drift detected, or time threshold).
    ///
    /// - Parameter activityItems: Recent activity history
    func scheduleTrainingIfNeeded(activityItems: [ActivityItem]) async {
        // Check if we meet minimum data requirements
        let records = learningService.makeTrainingRecords(from: activityItems)
        
        guard records.count >= minimumTrainingExamples else {
            Log.debug("Insufficient training data: \(records.count) < \(minimumTrainingExamples)", category: .analytics)
            return
        }
        
        // Check destination diversity
        let uniqueDestinations = Set(records.map { $0.destinationPath })
        guard uniqueDestinations.count >= minimumDestinations else {
            Log.debug("Insufficient destination diversity: \(uniqueDestinations.count) < \(minimumDestinations)", category: .analytics)
            return
        }
        
        // Check if retraining is needed
        let lastTraining = await getLastTrainingDate()
        let shouldRetrain = checkShouldRetrain(
            lastTrainingDate: lastTraining,
            newDataCount: records.count,
            driftDetected: predictionStats.isDriftDetected()
        )
        
        if shouldRetrain {
            Log.info("Starting scheduled training with \(records.count) examples", category: .analytics)
            await trainModel(records: records)
        }
    }
    
    /// Get metadata about the current active model.
    func currentModelMetadata() async -> DestinationModelMetadata? {
        guard let version = currentModelVersion else { return nil }
        
        // Fetch from training history
        let descriptor = FetchDescriptor<MLTrainingHistory>(
            predicate: #Predicate { $0.modelName == modelName && $0.version == version }
        )
        
        guard let history = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        
        return DestinationModelMetadata(
            version: history.version,
            trainedAt: history.trainedAt,
            exampleCount: history.exampleCount,
            labelCount: history.labelCount,
            accuracy: history.validationAccuracy,
            isActive: history.accepted
        )
    }
    
    /// Enable or disable ML predictions.
    func setMLEnabled(_ enabled: Bool) {
        mlEnabled = enabled
    }

    // MARK: - Training Pipeline
    
    /// Train a new model with the provided training records.
    private func trainModel(records: [DestinationTrainingRecord]) async {
        do {
            // Prepare dataset
            let (trainingData, testData) = prepareDataset(from: records)
            
            guard !trainingData.isEmpty && !testData.isEmpty else {
                Log.error("Dataset preparation failed", category: .analytics)
                return
            }
            
            // Train classifier
            let classifier = try await trainClassifier(data: trainingData)
            
            // Evaluate on test set
            let metrics = try await evaluateModel(classifier: classifier, testData: testData)
            
            // Check if metrics meet acceptance criteria
            let accepted = meetsAcceptanceCriteria(metrics: metrics)
            
            // Generate version string
            let version = generateVersionString()
            
            // Record training history
            let history = MLTrainingHistory(
                modelName: modelName,
                version: version,
                exampleCount: records.count,
                labelCount: Set(records.map { $0.destinationPath }).count,
                validationAccuracy: metrics.accuracy,
                falsePositiveRate: metrics.falsePositiveRate,
                accepted: accepted,
                notes: accepted ? "Passed evaluation gates" : DestinationModelAcceptanceGate.rejectionNotes(
                    for: metrics,
                    minimumAccuracy: minimumAccuracy,
                    maximumFalsePositiveRate: maximumFalsePositiveRate,
                    minimumConfidenceSeparation: minimumConfidenceSeparation
                )
            )
            
            modelContext.insert(history)
            do {
                try modelContext.save()
            } catch {
                Log.error("DestinationPredictionService: Failed to save training history - \(error.localizedDescription)", category: .analytics)
            }

            if accepted {
                // Save model to disk
                try await saveModel(classifier: classifier, version: version)
                
                // Update active version
                currentModelVersion = version
                currentModel = nil // Force reload
                
                Log.info("New model \(version) trained and activated (accuracy: \(metrics.accuracy))", category: .analytics)
            } else {
                Log.warning("Trained model rejected due to poor metrics", category: .analytics)
            }
            
        } catch {
            Log.error("Training failed: \(error.localizedDescription)", category: .analytics)
        }
    }
    
    /// Prepare training and test datasets with stratified split.
    private func prepareDataset(from records: [DestinationTrainingRecord]) -> (train: [DestinationTrainingRecord], test: [DestinationTrainingRecord]) {
        DestinationTrainingDatasetPreparer.prepare(
            records: records,
            maximumDatasetSize: maximumDatasetSize
        )
    }
    
    /// Train a text classifier using Create ML.
    private func trainClassifier(data: [DestinationTrainingRecord]) async throws -> MLTextClassifier {
        try await DestinationModelTrainer.train(data: data)
    }
    
    /// Evaluate model on test set and compute metrics.
    private func evaluateModel(
        classifier: MLTextClassifier,
        testData: [DestinationTrainingRecord]
    ) async throws -> DestinationEvaluationMetrics {
        try await DestinationModelEvaluator.evaluate(classifier: classifier, testData: testData)
    }
    
    /// Check if evaluation metrics meet acceptance criteria.
    private func meetsAcceptanceCriteria(metrics: DestinationEvaluationMetrics) -> Bool {
        DestinationModelAcceptanceGate.accepts(
            metrics: metrics,
            minimumAccuracy: minimumAccuracy,
            maximumFalsePositiveRate: maximumFalsePositiveRate,
            minimumConfidenceSeparation: minimumConfidenceSeparation
        )
    }

    // MARK: - Model Management
    
    /// Load the active model from disk.
    private func loadModel() async throws -> MLModel {
        if let model = currentModel {
            return model
        }
        
        // Find active version
        if currentModelVersion == nil {
            currentModelVersion = await getActiveModelVersion()
        }
        
        guard let version = currentModelVersion else {
            throw PredictionError.noModelAvailable
        }
        
        // Load from disk
        let modelURL = getModelURL(version: version)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw PredictionError.modelFileNotFound
        }
        
        let model = try MLModel(contentsOf: modelURL)
        currentModel = model
        return model
    }
    
    /// Save trained model to disk.
    private func saveModel(classifier: MLTextClassifier, version: String) async throws {
        let modelURL = getModelURL(version: version)
        
        // Ensure directory exists
        let directory = modelURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let stagingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FormaDestinationPredictionSave-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: stagingDirectory)
        }

        let compiledModelURL = try await DestinationModelCompiler.compileClassifier(
            classifier,
            fileName: "\(modelName)_\(version)",
            in: stagingDirectory
        )
        defer {
            try? FileManager.default.removeItem(at: compiledModelURL)
        }

        if FileManager.default.fileExists(atPath: modelURL.path) {
            try FileManager.default.removeItem(at: modelURL)
        }

        try FileManager.default.copyItem(at: compiledModelURL, to: modelURL)
        
        // Clean up old versions (keep latest 3)
        cleanupOldModels(keepCount: 3)
    }
    
    /// Get URL for model storage.
    private func getModelURL(version: String) -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if Application Support is unavailable
            Log.error("DestinationPredictionService: Application Support directory unavailable, using temp", category: .filesystem)
            let temp = FileManager.default.temporaryDirectory
            return temp.appendingPathComponent("MLModels/\(modelName)_\(version).mlmodelc")
        }
        let mlModelsDir = appSupport.appendingPathComponent("MLModels", isDirectory: true)
        return mlModelsDir.appendingPathComponent("\(modelName)_\(version).mlmodelc")
    }
    
    /// Get the active model version from training history.
    private func getActiveModelVersion() async -> String? {
        let descriptor = FetchDescriptor<MLTrainingHistory>(
            predicate: #Predicate { $0.modelName == modelName && $0.accepted == true },
            sortBy: [SortDescriptor(\.trainedAt, order: .reverse)]
        )
        
        let history = try? modelContext.fetch(descriptor).first
        return history?.version
    }
    
    /// Get the date of the last training run.
    private func getLastTrainingDate() async -> Date? {
        let descriptor = FetchDescriptor<MLTrainingHistory>(
            predicate: #Predicate { $0.modelName == modelName },
            sortBy: [SortDescriptor(\.trainedAt, order: .reverse)]
        )
        
        let history = try? modelContext.fetch(descriptor).first
        return history?.trainedAt
    }
    
    /// Clean up old model files, keeping only the most recent versions.
    private func cleanupOldModels(keepCount: Int) {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            Log.error("DestinationPredictionService: Application Support directory unavailable for cleanup", category: .filesystem)
            return
        }
        let mlModelsDir = appSupport.appendingPathComponent("MLModels", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(at: mlModelsDir, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        let modelFiles = files.filter { $0.lastPathComponent.hasPrefix(modelName) }
        let sorted = modelFiles.sorted {
            let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 > date2
        }
        
        for file in sorted.dropFirst(keepCount) {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    // MARK: - Feature Extraction
    
    /// Extract features from a FileItem for prediction.
    private func extractFeatures(from file: FileItem, projectCluster: String? = nil) -> DestinationFeatures {
        let keywords = extractKeywords(from: file.name)
        let category = FileTypeCategory.category(for: file.fileExtension).rawValue
        let timeBucket = generateTimeBucket(date: Date())
        let resolvedCluster = projectCluster ?? projectClusterIdentifier(for: file)
        
        return DestinationFeatures(
            fileExtension: file.fileExtension,
            nameKeywords: keywords,
            fileTypeCategory: category,
            timeBucket: timeBucket,
            sourceFolder: file.location.rawValue,
            projectCluster: resolvedCluster
        )
    }
    
    /// Extract keywords from a filename.
    private func extractKeywords(from fileName: String) -> [String] {
        DestinationTrainingFeatureExtractor.keywords(from: fileName)
    }
    
    /// Generate time bucket from a date.
    private func generateTimeBucket(date: Date) -> String {
        DestinationTrainingFeatureExtractor.timeBucket(for: date)
    }

    // MARK: - Context Detection

    private func projectClusterIdentifier(for file: FileItem) -> String? {
        refreshClusterLookupIfNeeded()
        return clusterLookupCache[file.path]
    }

    private func refreshClusterLookupIfNeeded() {
        if let lastUpdate = clusterLookupCacheDate,
           Date().timeIntervalSince(lastUpdate) < clusterLookupTTL {
            return
        }

        let descriptor = FetchDescriptor<ProjectCluster>(
            predicate: #Predicate<ProjectCluster> { !$0.isDismissed && !$0.isOrganized }
        )
        let clusters = (try? modelContext.fetch(descriptor)) ?? []
        clusterLookupCache = buildClusterLookup(from: clusters)
        clusterLookupCacheDate = Date()
    }

    private func clusterLookup(for files: [FileItem]) -> [String: String] {
        let detectedClusters = contextDetectionService.detectClusters(from: files)
        if !detectedClusters.isEmpty {
            return buildClusterLookup(from: detectedClusters)
        }

        refreshClusterLookupIfNeeded()
        return clusterLookupCache
    }

    private func buildClusterLookup(from clusters: [ProjectCluster]) -> [String: String] {
        var lookup: [String: String] = [:]
        for cluster in clusters {
            let identifier = cluster.detectedPattern ?? cluster.suggestedFolderName
            for path in cluster.filePaths {
                lookup[path] = identifier
            }
        }
        return lookup
    }
    
    // MARK: - Explanation Generation
    
    /// Generate human-readable explanation for a prediction.
    private func generateExplanation(
        for file: FileItem,
        predictedPath: String,
        confidence: Double,
        features: DestinationFeatures
    ) -> PredictionExplanation {
        let ext = file.fileExtension.uppercased()
        let count = trainingCount(for: predictedPath, fileExtension: file.fileExtension)
        let countLabel = count > 0 ? "\(count)" : "several"
        
        var reasons: [String] = []
        
        // Primary reason based on extension
        reasons.append("Based on \(countLabel) similar \(ext) files")
        
        // Add keyword if present
        if let keyword = features.nameKeywords.first {
            reasons.append("File name contains '\(keyword)'")
        }
        
        let summary = "Similar to \(countLabel) past \(ext) files you moved to \(abbreviatePath(predictedPath))"
        
        return PredictionExplanation(
            summary: summary,
            reasons: reasons,
            exampleFiles: []
        )
    }
    
    private func abbreviatePath(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return "~" + path.dropFirst(homeDir.count)
        }
        return path
    }

    private func displayNameForPath(_ path: String) -> String {
        if path.hasPrefix("~/") {
            return String(path.dropFirst(2))
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            let trimmed = path.dropFirst(homeDir.count)
            return trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : String(trimmed)
        }

        return path.hasPrefix("/") ? String(path.dropFirst()) : path
    }

    private func trainingCount(for predictedPath: String, fileExtension: String) -> Int {
        refreshTrainingCountCacheIfNeeded()
        let normalizedPath = normalizePredictionPath(predictedPath)
        let key = trainingCountCacheKey(extension: fileExtension, destinationPath: normalizedPath)
        return trainingCountCache[key, default: 0]
    }

    private func refreshTrainingCountCacheIfNeeded() {
        if let lastUpdate = trainingCountCacheDate,
           Date().timeIntervalSince(lastUpdate) < trainingCountCacheTTL {
            return
        }

        let descriptor = FetchDescriptor<ActivityItem>()
        let activities = (try? modelContext.fetch(descriptor)) ?? []
        let records = learningService.makeTrainingRecords(from: activities)
        var counts: [String: Int] = [:]

        for record in records {
            let key = trainingCountCacheKey(extension: record.fileExtension, destinationPath: record.destinationPath)
            counts[key, default: 0] += 1
        }

        trainingCountCache = counts
        trainingCountCacheDate = Date()
    }

    private func trainingCountCacheKey(extension fileExtension: String, destinationPath: String) -> String {
        "\(fileExtension.lowercased())|\(destinationPath)"
    }

    private func normalizePredictionPath(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return "~" + path.dropFirst(homeDir.count)
        }
        return path
    }
    
    // MARK: - Retraining Logic
    
    /// Check if retraining should be triggered.
    private func checkShouldRetrain(
        lastTrainingDate: Date?,
        newDataCount: Int,
        driftDetected: Bool
    ) -> Bool {
        // Never trained before
        guard let lastDate = lastTrainingDate else { return true }
        
        // Drift detected
        if driftDetected { return true }
        
        // Time-based: more than 30 days
        if Date().timeIntervalSince(lastDate) > 30 * 86400 { return true }
        
        // Data-based: significant new data (25+ new examples)
        if newDataCount >= 25 { return true }
        
        return false
    }
    
    /// Generate a version string for a new model.
    private func generateVersionString() -> String {
        DestinationModelVersion.string(for: Date())
    }
    
    // MARK: - Supporting Types
    
    enum PredictionError: Error {
        case noModelAvailable
        case modelFileNotFound
        case predictionFailed
    }
    
    /// Sliding window statistics for drift detection.
    private struct PredictionStatistics {
        private var predictionCount = 0
        private var acceptedCount = 0
        private var overriddenCount = 0
        private let windowSize = 100
        
        mutating func recordPrediction() {
            predictionCount += 1
        }
        
        func isDriftDetected() -> Bool {
            guard predictionCount >= windowSize else { return false }
            
            let acceptanceRate = Double(acceptedCount) / Double(predictionCount)
            let overrideRate = Double(overriddenCount) / Double(predictionCount)
            
            // Drift if acceptance < 50% or override > 40%
            return acceptanceRate < 0.5 || overrideRate > 0.4
        }
    }
}

enum DestinationModelTrainer {
    static func train(data: [DestinationTrainingRecord]) async throws -> MLTextClassifier {
        try await Task.detached(priority: .utility) {
            try trainOnCurrentExecutor(data: data)
        }.value
    }

    private static func trainOnCurrentExecutor(data: [DestinationTrainingRecord]) throws -> MLTextClassifier {
        var textFeatures: [String] = []
        var labels: [String] = []

        for record in data {
            let features = DestinationTrainingFeatureExtractor.features(from: record)
            textFeatures.append(features.combinedText())
            labels.append(record.destinationPath)
        }

        let textColumn = Column(name: "text", contents: textFeatures)
        let labelColumn = Column(name: "label", contents: labels)
        let dataFrame = DataFrame(columns: [
            textColumn.eraseToAnyColumn(),
            labelColumn.eraseToAnyColumn()
        ])

        return try MLTextClassifier(
            trainingData: dataFrame,
            textColumn: "text",
            labelColumn: "label"
        )
    }
}

enum DestinationModelCompiler {
    static func compileClassifier(
        _ classifier: MLTextClassifier,
        fileName: String,
        in directory: URL
    ) async throws -> URL {
        try await Task.detached(priority: .utility) {
            try compileClassifierOnCurrentExecutor(classifier, fileName: fileName, in: directory)
        }.value
    }

    static func compileClassifierOnCurrentExecutor(
        _ classifier: MLTextClassifier,
        fileName: String,
        in directory: URL
    ) throws -> URL {
        let rawModelURL = directory.appendingPathComponent("\(fileName).mlmodel")
        try classifier.write(to: rawModelURL)
        return try MLModel.compileModel(at: rawModelURL)
    }
}

enum DestinationModelEvaluator {
    static func evaluate(
        classifier: MLTextClassifier,
        testData: [DestinationTrainingRecord]
    ) async throws -> DestinationEvaluationMetrics {
        try await Task.detached(priority: .utility) {
            try await evaluateOnCurrentExecutor(classifier: classifier, testData: testData)
        }.value
    }

    private static func evaluateOnCurrentExecutor(
        classifier: MLTextClassifier,
        testData: [DestinationTrainingRecord]
    ) async throws -> DestinationEvaluationMetrics {
        let evaluationModelDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FormaDestinationPredictionEvaluation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: evaluationModelDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: evaluationModelDirectory)
        }

        let compiledModelURL = try DestinationModelCompiler.compileClassifierOnCurrentExecutor(
            classifier,
            fileName: "destinationPredictionEvaluation",
            in: evaluationModelDirectory
        )
        defer {
            try? FileManager.default.removeItem(at: compiledModelURL)
        }

        let evaluationModel = try MLModel(contentsOf: compiledModelURL)
        var correct = 0
        var falsePositives = 0
        var correctConfidences: [Double] = []
        var incorrectConfidences: [Double] = []
        var missingConfidenceCount = 0

        for record in testData {
            let features = DestinationTrainingFeatureExtractor.features(from: record)
            let input = try MLDictionaryFeatureProvider(dictionary: ["text": features.combinedText()])
            let prediction = try await evaluationModel.prediction(from: input)
            let predictedLabel = try CoreMLPredictionEngine.predictedLabel(from: prediction)
            let confidence = CoreMLPredictionEngine.confidence(
                for: predictedLabel,
                from: prediction
            )

            if predictedLabel == record.destinationPath {
                correct += 1
                if let confidence {
                    correctConfidences.append(confidence)
                } else {
                    missingConfidenceCount += 1
                }
            } else {
                if let confidence {
                    incorrectConfidences.append(confidence)
                } else {
                    missingConfidenceCount += 1
                }
                falsePositives += 1 // Count all errors as potential false positives
            }
        }

        return DestinationEvaluationMetrics(
            accuracy: Double(correct) / Double(testData.count),
            falsePositiveRate: Double(falsePositives) / Double(testData.count),
            avgCorrectConfidence: average(correctConfidences),
            avgIncorrectConfidence: average(incorrectConfidences),
            confidenceSampleCount: correctConfidences.count + incorrectConfidences.count,
            missingConfidenceCount: missingConfidenceCount
        )
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

enum DestinationTrainingFeatureExtractor {
    static func features(from record: DestinationTrainingRecord) -> DestinationFeatures {
        DestinationFeatures(
            fileExtension: record.fileExtension,
            nameKeywords: keywords(from: record.fileName),
            fileTypeCategory: FileTypeCategory.category(for: record.fileExtension).rawValue,
            timeBucket: timeBucket(for: record.timestamp),
            sourceFolder: record.sourceLocation,
            projectCluster: record.projectCluster
        )
    }

    static func keywords(from fileName: String) -> [String] {
        let normalized = fileName.lowercased()
        let separators = CharacterSet(charactersIn: "_- ")
        let words = normalized.components(separatedBy: separators)
        return words.filter { $0.count > 2 }
    }

    static func timeBucket(for date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)

        let isWeekend = weekday == 1 || weekday == 7
        let timeLabel = isWeekend ? "weekend" : (hour >= 9 && hour <= 17 ? "workday" : "evening")

        return "\(timeLabel)_hour_\(hour)"
    }
}

enum DestinationTrainingDatasetPreparer {
    typealias Sampler = ([DestinationTrainingRecord], Int) -> [DestinationTrainingRecord]

    static func prepare(
        records: [DestinationTrainingRecord],
        maximumDatasetSize: Int,
        trainFraction: Double = 0.8,
        sampler: Sampler = boundedRandomSample
    ) -> (train: [DestinationTrainingRecord], test: [DestinationTrainingRecord]) {
        let sampleLimit = min(max(maximumDatasetSize, 0), records.count)
        let sampledRecords = Array(sampler(records, sampleLimit).prefix(sampleLimit))
        let splitIndex = Int(Double(sampledRecords.count) * trainFraction)
        let train = Array(sampledRecords.prefix(splitIndex))
        let test = Array(sampledRecords.suffix(sampledRecords.count - splitIndex))

        return (train, test)
    }

    private static func boundedRandomSample(
        records: [DestinationTrainingRecord],
        maximumCount: Int
    ) -> [DestinationTrainingRecord] {
        guard maximumCount > 0 else { return [] }
        guard records.count > maximumCount else {
            return records.shuffled()
        }

        var selectedIndices = Set<Int>()
        selectedIndices.reserveCapacity(maximumCount)

        while selectedIndices.count < maximumCount {
            selectedIndices.insert(Int.random(in: records.indices))
        }

        return selectedIndices.map { records[$0] }.shuffled()
    }
}

enum DestinationModelVersion {
    static func string(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return "1-\(formatter.string(from: date))"
    }
}

struct DestinationEvaluationMetrics: Equatable {
    var accuracy: Double
    var falsePositiveRate: Double
    var avgCorrectConfidence: Double?
    var avgIncorrectConfidence: Double?
    var confidenceSampleCount: Int
    var missingConfidenceCount: Int
}

enum DestinationModelAcceptanceGate {
    static func accepts(
        metrics: DestinationEvaluationMetrics,
        minimumAccuracy: Double,
        maximumFalsePositiveRate: Double,
        minimumConfidenceSeparation: Double
    ) -> Bool {
        guard metrics.accuracy >= minimumAccuracy else { return false }
        guard metrics.falsePositiveRate <= maximumFalsePositiveRate else { return false }
        guard metrics.confidenceSampleCount > 0, let avgCorrectConfidence = metrics.avgCorrectConfidence else {
            return false
        }

        let avgIncorrectConfidence = metrics.avgIncorrectConfidence ?? 0
        guard avgCorrectConfidence - avgIncorrectConfidence >= minimumConfidenceSeparation else {
            return false
        }

        return true
    }

    static func rejectionNotes(
        for metrics: DestinationEvaluationMetrics,
        minimumAccuracy: Double,
        maximumFalsePositiveRate: Double,
        minimumConfidenceSeparation: Double
    ) -> String {
        if metrics.confidenceSampleCount == 0 {
            return "Failed evaluation: model output did not expose confidence probabilities"
        }

        if metrics.accuracy < minimumAccuracy {
            return "Failed evaluation: accuracy \(formatted(metrics.accuracy)) below \(formatted(minimumAccuracy))"
        }

        if metrics.falsePositiveRate > maximumFalsePositiveRate {
            return "Failed evaluation: false positive rate \(formatted(metrics.falsePositiveRate)) above \(formatted(maximumFalsePositiveRate))"
        }

        guard let avgCorrectConfidence = metrics.avgCorrectConfidence else {
            return "Failed evaluation: model output did not expose correct confidence probabilities"
        }

        let avgIncorrectConfidence = metrics.avgIncorrectConfidence ?? 0
        let confidenceSeparation = avgCorrectConfidence - avgIncorrectConfidence
        if confidenceSeparation < minimumConfidenceSeparation {
            return "Failed evaluation: confidence separation \(formatted(confidenceSeparation)) below \(formatted(minimumConfidenceSeparation))"
        }

        return "Failed evaluation: accuracy \(formatted(metrics.accuracy)), false positive rate \(formatted(metrics.falsePositiveRate))"
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
