import Foundation
import SwiftData
import CreateML

/// Protocol describing a reusable pipeline that:
/// 1. Scans one or more folders into FileMetadata
/// 2. Evaluates rules via RuleEngine
/// 3. Applies LearningService patterns
/// 4. Applies ML predictions (DestinationPredictionService)
/// 5. Upserts FileItem entities into SwiftData
///
/// Note: SwiftData models (`FileItem`, `Rule`, `LearnedPattern`) are not `Sendable` in Swift 6,
/// so this pipeline is `@MainActor` to avoid crossing actor boundaries with model objects.
@MainActor
protocol FileScanPipelineProtocol {
    func scanAndPersist(
        baseFolders: [FolderLocation],
        customFolders: [CustomFolder],
        fileSystemService: FileSystemServiceProtocol,
        ruleEngine: RuleEngine,
        rules: [Rule],
        context: ModelContext
    ) async -> FileScanPipeline.ScanResult
}

struct FileScanPipeline: FileScanPipelineProtocol {
    struct ScanResult {
        let files: [FileItem]
        let errorSummary: String?
        let rawErrors: [String: Error]
        let timedOut: Bool

        init(files: [FileItem], errorSummary: String?, rawErrors: [String: Error], timedOut: Bool = false) {
            self.files = files
            self.errorSummary = errorSummary
            self.rawErrors = rawErrors
            self.timedOut = timedOut
        }
    }

    /// Timeout error for scan operations
    struct ScanTimeoutError: Error, LocalizedError {
        let duration: Duration
        var errorDescription: String? {
            "File scan timed out after \(Int(duration.components.seconds)) seconds"
        }
    }

    // Services for prediction pipeline
    private let learningService = LearningService()

    func scanAndPersist(
        baseFolders: [FolderLocation],
        customFolders: [CustomFolder],
        fileSystemService: FileSystemServiceProtocol,
        ruleEngine: RuleEngine,
        rules: [Rule],
        context: ModelContext
    ) async -> ScanResult {
        await performScan(
            baseFolders: baseFolders,
            customFolders: customFolders,
            fileSystemService: fileSystemService,
            ruleEngine: ruleEngine,
            rules: rules,
            context: context
        )
    }

    /// Performs the actual scan operation (extracted for timeout wrapper)
    private func performScan(
        baseFolders: [FolderLocation],
        customFolders: [CustomFolder],
        fileSystemService: FileSystemServiceProtocol,
        ruleEngine: RuleEngine,
        rules: [Rule],
        context: ModelContext
    ) async -> ScanResult {
        // 1. Scan using protocol method (no downcast needed)
        let result = await fileSystemService.scan(baseFolders: baseFolders, customFolders: customFolders)
        let scanMeta = ScanResult(files: [], errorSummary: result.errorSummary, rawErrors: result.errors)
        return await persist(files: result.files, evaluatedBy: ruleEngine, rules: rules, context: context, scanMeta: scanMeta)
    }

    private func persist(
        files: [FileMetadata],
        evaluatedBy ruleEngine: RuleEngine,
        rules: [Rule],
        context: ModelContext,
        scanMeta: ScanResult
    ) async -> ScanResult {
        let persistId = PerformanceMonitor.shared.begin(.ruleEvaluation, metadata: "\(files.count) files")

        // PHASE 1: Fetch data needed for computation (SwiftData requirement)
        let (patterns, hasTrainedModel) = fetchDataForComputation(context: context)

        // PHASE 2: Compute evaluation
        let ruleEvaluated = ruleEngine.evaluateFiles(files, rules: rules)

        let patternEvaluated = applyLearnedPatterns(to: ruleEvaluated, patterns: patterns)

        // ML predictions only if model exists
        let evaluated: [FileMetadata]
        if hasTrainedModel {
            evaluated = await applyMLPredictions(to: patternEvaluated, context: context)
        } else {
            evaluated = patternEvaluated
        }

        // PHASE 3: Persist results (SwiftData requirement)
        let persisted = persistToSwiftData(evaluated: evaluated, context: context)

        PerformanceMonitor.shared.end(.ruleEvaluation, id: persistId, metadata: "\(persisted.count) persisted")
        return ScanResult(files: persisted, errorSummary: scanMeta.errorSummary, rawErrors: scanMeta.rawErrors)
    }

    // MARK: - MainActor Data Fetching

    @MainActor
    private func fetchDataForComputation(context: ModelContext) -> (patterns: [LearnedPattern], hasTrainedModel: Bool) {
        // Fetch learned patterns
        let patternDescriptor = FetchDescriptor<LearnedPattern>(
            predicate: #Predicate<LearnedPattern> { pattern in
                pattern.convertedRuleId == nil
            },
            sortBy: [SortDescriptor(\.confidenceScore, order: .reverse)]
        )
        let patterns = (try? context.fetch(patternDescriptor)) ?? []

        // Check if ML model exists
        var historyDescriptor = FetchDescriptor<MLTrainingHistory>(
            predicate: #Predicate { $0.accepted == true }
        )
        historyDescriptor.fetchLimit = 1
        let hasTrainedModel = (try? context.fetch(historyDescriptor).first) != nil

        return (patterns, hasTrainedModel)
    }

    @MainActor
    private func persistToSwiftData(evaluated: [FileMetadata], context: ModelContext) -> [FileItem] {
        // Batch fetch existing FileItem by path
        let scannedPaths = Set(evaluated.map { $0.path })
        let descriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate<FileItem> { file in
                scannedPaths.contains(file.path)
            }
        )
        let existingFiles = (try? context.fetch(descriptor)) ?? []
        let existingByPath = Dictionary(uniqueKeysWithValues: existingFiles.map { ($0.path, $0) })

        var persisted: [FileItem] = []
        var processedPaths: Set<String> = []

        for meta in evaluated {
            // Skip duplicate paths to prevent same FileItem appearing multiple times
            guard !processedPaths.contains(meta.path) else {
                continue
            }
            processedPaths.insert(meta.path)

            if let existing = existingByPath[meta.path] {
                // Update existing metadata
                _ = existing.updateMetadata(
                    sizeInBytes: meta.sizeInBytes,
                    modificationDate: meta.modificationDate,
                    lastAccessedDate: meta.lastAccessedDate
                )
                existing.destination = meta.destination
                existing.matchReason = meta.matchReason
                existing.confidenceScore = meta.confidenceScore
                existing.suggestionSourceRaw = meta.suggestionSourceRaw

                if existing.status == .pending {
                    existing.status = meta.status
                }

                persisted.append(existing)
            } else {
                // Insert new item using trusted metadata
                let newFile = FileItem.from(meta)
                context.insert(newFile)
                persisted.append(newFile)
            }
        }

        do {
            try context.save()
        } catch {
            // Saving failures are surfaced by callers via toasts; pipeline still returns best-effort files
        }

        return persisted
    }
    
    // MARK: - Computation

    /// Apply learned patterns using pre-fetched data.
    /// Note: Learned patterns currently store path strings, not bookmarks.
    /// Until LearnedPattern is updated to use Destination type, this will only
    /// set match metadata without a destination.
    private func applyLearnedPatterns(to files: [FileMetadata], patterns: [LearnedPattern]) -> [FileMetadata] {
        guard !patterns.isEmpty else { return files }

        var mutableFiles = files
        for (index, file) in mutableFiles.enumerated() {
            // Only apply patterns if file is still pending (no rule matched)
            guard file.status == .pending else { continue }

            // Check if any pattern matches
            if let matchedPattern = learningService.findMatchingPattern(for: file, in: patterns) {
                var modified = file
                // TODO: LearnedPattern needs to store Destination instead of path string
                // For now, set the destination if pattern has bookmark data
                if let bookmarkData = matchedPattern.destinationBookmarkData {
                    modified.destination = .folder(bookmark: bookmarkData, displayName: matchedPattern.destinationPath)
                }
                modified.status = .ready
                modified.matchReason = "Based on learned pattern: \(matchedPattern.patternDescription)"
                modified.confidenceScore = matchedPattern.confidenceScore
                modified.suggestionSourceRaw = SuggestionSource.pattern.rawValue
                mutableFiles[index] = modified
            }
        }

        return mutableFiles
    }

    /// Apply ML predictions (prediction service is @MainActor for SwiftData access).
    private func applyMLPredictions(to files: [FileMetadata], context: ModelContext) async -> [FileMetadata] {
        let mlId = PerformanceMonitor.shared.begin(.mlPrediction, metadata: "\(files.count) files")

        var mutableFiles = files
        let pendingIndices = files.enumerated().compactMap { $0.element.status == .pending ? $0.offset : nil }

        // Skip if no pending files
        guard !pendingIndices.isEmpty else {
            PerformanceMonitor.shared.end(.mlPrediction, id: mlId, metadata: "no pending files")
            return mutableFiles
        }

        let predictionService = DestinationPredictionService(modelContext: context)

        // Prediction context with default settings
        let predictionContext = PredictionContext(
            allowedDestinations: [],
            mlEnabled: true,
            minimumConfidence: 0.7
        )

        // Convert pending files to FileItems for batch prediction
        let pendingFileItems: [FileItem] = pendingIndices.map { index in
            FileItem.from(mutableFiles[index])
        }

        // Use batch prediction with caching for similar files
        let predictions = await predictionService.predictDestinationsBatch(
            for: pendingFileItems,
            context: predictionContext,
            negativePatterns: [] // TODO: Fetch negative patterns from context
        )

        // Apply predictions to mutable files
        // TODO: DestinationPredictionService needs to return Destination type with bookmark
        // For now, predictions only set metadata if they include bookmark data
        for index in pendingIndices {
            let file = mutableFiles[index]
            let fileItem = FileItem.from(file)

            if let prediction = predictions[fileItem.path] {
                var modified = file
                // Only apply if prediction includes bookmark data for the destination
                if let bookmarkData = prediction.bookmarkData {
                    modified.destination = .folder(bookmark: bookmarkData, displayName: prediction.path)
                }
                modified.status = .ready
                modified.matchReason = prediction.explanation.summary
                modified.confidenceScore = prediction.confidence
                modified.suggestionSourceRaw = prediction.source.rawValue
                mutableFiles[index] = modified
            }
        }

        PerformanceMonitor.shared.end(.mlPrediction, id: mlId, metadata: "\(pendingIndices.count) files, \(predictions.count) predictions")
        return mutableFiles
    }
}
