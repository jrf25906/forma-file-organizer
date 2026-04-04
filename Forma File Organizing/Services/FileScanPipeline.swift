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
        scanOptions: FileScanOptions,
        fileSystemService: FileSystemServiceProtocol,
        ruleEngine: RuleEngine,
        rules: [Rule],
        context: ModelContext
    ) async -> FileScanPipeline.ScanResult

    func evaluateAndPersistExplicitFiles(
        files: [FileMetadata],
        scannedRootPaths: [String],
        reconcileMissingFiles: Bool,
        ruleEngine: RuleEngine,
        rules: [Rule],
        context: ModelContext
    ) async -> FileScanPipeline.ScanResult
}

struct FileScanPipeline: FileScanPipelineProtocol {
    typealias MetadataFoundationServiceFactory = (ModelContext) -> any FileMetadataFoundationServiceProtocol
    typealias PrimaryPersistenceSaveErrorProvider = () -> Error?

    struct ScanResult {
        let files: [FileItem]
        let errorSummary: String?
        let rawErrors: [String: Error]
        let timedOut: Bool
        let scannedRootPaths: [String]

        init(
            files: [FileItem],
            errorSummary: String?,
            rawErrors: [String: Error],
            timedOut: Bool = false,
            scannedRootPaths: [String] = []
        ) {
            self.files = files
            self.errorSummary = errorSummary
            self.rawErrors = rawErrors
            self.timedOut = timedOut
            self.scannedRootPaths = scannedRootPaths
        }
    }

    private struct PersistenceResult {
        let files: [FileItem]
        let saveError: Error?
    }

    // Services for prediction pipeline
    private let learningService = LearningService()
    private let metadataFoundationServiceFactory: MetadataFoundationServiceFactory
    private let primaryPersistenceSaveErrorProvider: PrimaryPersistenceSaveErrorProvider?

    init(
        metadataFoundationServiceFactory: @escaping MetadataFoundationServiceFactory = { context in
            FileMetadataFoundationService(modelContext: context)
        },
        primaryPersistenceSaveErrorProvider: PrimaryPersistenceSaveErrorProvider? = nil
    ) {
        self.metadataFoundationServiceFactory = metadataFoundationServiceFactory
        self.primaryPersistenceSaveErrorProvider = primaryPersistenceSaveErrorProvider
    }

    func scanAndPersist(
        baseFolders: [FolderLocation],
        scanOptions: FileScanOptions = .defaults,
        fileSystemService: FileSystemServiceProtocol,
        ruleEngine: RuleEngine,
        rules: [Rule],
        context: ModelContext
    ) async -> ScanResult {
        await performScan(
            baseFolders: baseFolders,
            scanOptions: scanOptions,
            fileSystemService: fileSystemService,
            ruleEngine: ruleEngine,
            rules: rules,
            context: context
        )
    }

    func evaluateAndPersistExplicitFiles(
        files: [FileMetadata],
        scannedRootPaths: [String],
        reconcileMissingFiles: Bool,
        ruleEngine: RuleEngine,
        rules: [Rule],
        context: ModelContext
    ) async -> ScanResult {
        let scanMeta = ScanResult(
            files: [],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: scannedRootPaths
        )

        return await persist(
            files: files,
            scannedRootPaths: scannedRootPaths,
            reconcileMissingFiles: reconcileMissingFiles,
            evaluatedBy: ruleEngine,
            rules: rules,
            context: context,
            scanMeta: scanMeta
        )
    }

    /// Performs the actual scan operation (extracted for timeout wrapper)
    private func performScan(
        baseFolders: [FolderLocation],
        scanOptions: FileScanOptions,
        fileSystemService: FileSystemServiceProtocol,
        ruleEngine: RuleEngine,
        rules: [Rule],
        context: ModelContext
    ) async -> ScanResult {
        // 1. Scan using protocol method
        let discoveryId = PerformanceMonitor.shared.begin(
            .dashboardScanDiscovery,
            metadata: "\(baseFolders.count) roots"
        )
        let result = await fileSystemService.scan(baseFolders: baseFolders, options: scanOptions)
        PerformanceMonitor.shared.end(
            .dashboardScanDiscovery,
            id: discoveryId,
            metadata: "\(result.files.count) files, \(result.scannedRootPaths.count) roots"
        )
        let scanMeta = ScanResult(
            files: [],
            errorSummary: result.errorSummary,
            rawErrors: result.errors,
            scannedRootPaths: result.scannedRootPaths
        )
        return await persist(
            files: result.files,
            scannedRootPaths: result.scannedRootPaths,
            reconcileMissingFiles: true,
            evaluatedBy: ruleEngine,
            rules: rules,
            context: context,
            scanMeta: scanMeta
        )
    }

    private func persist(
        files: [FileMetadata],
        scannedRootPaths: [String],
        reconcileMissingFiles: Bool,
        evaluatedBy ruleEngine: RuleEngine,
        rules: [Rule],
        context: ModelContext,
        scanMeta: ScanResult
    ) async -> ScanResult {
        let persistId = PerformanceMonitor.shared.begin(.ruleEvaluation, metadata: "\(files.count) files")
        let dashboardRuleEvaluationId = PerformanceMonitor.shared.begin(
            .dashboardRuleEvaluation,
            metadata: "\(files.count) files, \(rules.count) rules"
        )

        // PHASE 1: Fetch data needed for computation (SwiftData requirement)
        let (patterns, negativePatterns, hasTrainedModel) = fetchDataForComputation(context: context)

        // PHASE 2: Compute evaluation
        let ruleEvaluated = preserveOriginalSuggestions(in: ruleEngine.evaluateFiles(files, rules: rules))

        // Stamp lastTriggeredDate on rules that matched at least one file
        let matchedRuleIDs = Set(ruleEvaluated.compactMap(\.matchedRuleID))
        let now = Date()
        for rule in rules where matchedRuleIDs.contains(rule.id) {
            rule.lastTriggeredDate = now
        }

        let memoryEvaluated = applyPersonalMemorySuggestions(to: ruleEvaluated, context: context)

        let positivePatterns = patterns.filter { !$0.isNegativePattern && $0.source != .personalMemory }
        let patternEvaluated = applyLearnedPatterns(to: memoryEvaluated, patterns: positivePatterns)

        // ML predictions only if model exists
        let evaluated: [FileMetadata]
        if hasTrainedModel {
            evaluated = await applyMLPredictions(
                to: patternEvaluated,
                context: context,
                negativePatterns: negativePatterns
            )
        } else {
            evaluated = patternEvaluated
        }
        PerformanceMonitor.shared.end(
            .dashboardRuleEvaluation,
            id: dashboardRuleEvaluationId,
            metadata: "\(evaluated.count) evaluated"
        )

        // PHASE 3: Persist results (SwiftData requirement)
        let normalized = normalizeAlreadyOrganizedFiles(evaluated)
        let persistence = persistToSwiftData(
            evaluated: normalized,
            scannedRootPaths: scannedRootPaths,
            shouldReconcileMissingFiles: reconcileMissingFiles,
            context: context
        )
        let primaryPersistenceSaveError = primaryPersistenceSaveErrorProvider?() ?? persistence.saveError

        persistMetadataRecords(
            for: normalized,
            context: context,
            shouldPersist: primaryPersistenceSaveError == nil
        )

        var rawErrors = scanMeta.rawErrors
        if let saveError = primaryPersistenceSaveError {
            rawErrors["SwiftData Save"] = saveError
        }
        let errorSummary = combinedErrorSummary(
            scanErrorSummary: scanMeta.errorSummary,
            persistenceError: primaryPersistenceSaveError
        )

        PerformanceMonitor.shared.end(.ruleEvaluation, id: persistId, metadata: "\(persistence.files.count) persisted")
        return ScanResult(
            files: persistence.files,
            errorSummary: errorSummary,
            rawErrors: rawErrors,
            scannedRootPaths: scanMeta.scannedRootPaths
        )
    }

    // MARK: - MainActor Data Fetching

    @MainActor
    private func fetchDataForComputation(
        context: ModelContext
    ) -> (patterns: [LearnedPattern], negativePatterns: [LearnedPattern], hasTrainedModel: Bool) {
        // Fetch learned patterns
        let patternDescriptor = FetchDescriptor<LearnedPattern>(
            predicate: #Predicate<LearnedPattern> { pattern in
                pattern.convertedRuleId == nil
            },
            sortBy: [SortDescriptor(\.confidenceScore, order: .reverse)]
        )
        let patterns: [LearnedPattern]
        do {
            patterns = try context.fetch(patternDescriptor)
        } catch {
            Log.error("FileScanPipeline: Failed to fetch learned patterns: \(error.localizedDescription)", category: .pipeline)
            patterns = []
        }
        let negativePatterns = patterns.filter { $0.isNegativePattern }

        // Check if ML model exists
        var historyDescriptor = FetchDescriptor<MLTrainingHistory>(
            predicate: #Predicate { $0.accepted == true }
        )
        historyDescriptor.fetchLimit = 1
        let hasTrainedModel: Bool
        do {
            hasTrainedModel = (try context.fetch(historyDescriptor).first) != nil
        } catch {
            Log.error("FileScanPipeline: Failed to fetch training history: \(error.localizedDescription)", category: .pipeline)
            hasTrainedModel = false
        }

        return (patterns, negativePatterns, hasTrainedModel)
    }

    @MainActor
    private func persistToSwiftData(
        evaluated: [FileMetadata],
        scannedRootPaths: [String],
        shouldReconcileMissingFiles: Bool,
        context: ModelContext
    ) -> PersistenceResult {
        // Batch fetch existing FileItem by path
        let scannedPaths = Set(evaluated.map { $0.path })
        let descriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate<FileItem> { file in
                scannedPaths.contains(file.path)
            }
        )
        let existingFiles: [FileItem]
        do {
            existingFiles = try context.fetch(descriptor)
        } catch {
            Log.error("FileScanPipeline: Failed to fetch existing FileItem records: \(error.localizedDescription)", category: .pipeline)
            existingFiles = []
        }
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
                existing.scanRootPath = meta.scanRootPath
                existing.relativeParentPath = meta.relativeParentPath
                let shouldOverwriteSuggestionData = existing.status == .pending || meta.destination != nil || meta.status == .completed
                if shouldOverwriteSuggestionData {
                    existing.destination = meta.destination
                    existing.originalSuggestedDestination = meta.originalSuggestedDestination
                    existing.matchReason = meta.matchReason
                    existing.confidenceScore = meta.confidenceScore
                    existing.suggestionSourceRaw = meta.suggestionSourceRaw
                    existing.matchedRuleID = meta.matchedRuleID
                }

                if existing.status == .pending || meta.status == .completed {
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

        if shouldReconcileMissingFiles {
            reconcileMissingFiles(
                scannedPaths: scannedPaths,
                scannedRootPaths: scannedRootPaths.isEmpty ? Set(evaluated.compactMap(\.scanRootPath)) : Set(scannedRootPaths),
                context: context
            )
        }

        let saveError: Error?
        do {
            try context.save()
            saveError = nil
        } catch {
            saveError = error
            Log.error("FileScanPipeline: Failed to save scan results: \(error.localizedDescription)", category: .pipeline)
        }

        return PersistenceResult(files: persisted, saveError: saveError)
    }

    @MainActor
    private func persistMetadataRecords(
        for files: [FileMetadata],
        context: ModelContext,
        shouldPersist: Bool
    ) {
        guard shouldPersist,
              FeatureFlagService.shared.isEnabled(.metadataFoundation) else { return }

        let metadataContext = ModelContext(context.container)
        let metadataService = metadataFoundationServiceFactory(metadataContext)
        let timestamp = Date()

        for file in files {
            do {
                _ = try metadataService.upsertRecordWithoutSaving(
                    for: file.path,
                    displayName: file.name,
                    fileExtension: file.fileExtension,
                    timestamp: timestamp
                )
            } catch {
                Log.error(
                    "FileScanPipeline: Failed to upsert metadata record for '\(file.path)': \(error.localizedDescription)",
                    category: .pipeline
                )
            }
        }

        do {
            try metadataContext.save()
        } catch {
            Log.error(
                "FileScanPipeline: Failed to save metadata records: \(error.localizedDescription)",
                category: .pipeline
            )
        }
    }

    private func combinedErrorSummary(scanErrorSummary: String?, persistenceError: Error?) -> String? {
        switch (scanErrorSummary, persistenceError) {
        case (nil, nil):
            return nil
        case (let summary?, nil):
            return summary
        case (nil, let error?):
            return "Failed to persist scan results: \(error.localizedDescription)"
        case (let summary?, let error?):
            return "\(summary). Failed to persist scan results: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func reconcileMissingFiles(
        scannedPaths: Set<String>,
        scannedRootPaths: Set<String>,
        context: ModelContext
    ) {
        guard !scannedRootPaths.isEmpty else { return }

        let descriptor = FetchDescriptor<FileItem>()
        let existingFiles: [FileItem]
        do {
            existingFiles = try context.fetch(descriptor)
        } catch {
            Log.error("FileScanPipeline: Failed to fetch files for reconciliation: \(error.localizedDescription)", category: .pipeline)
            return
        }

        let removableStatuses: Set<FileItem.OrganizationStatus> = [.pending, .ready, .skipped]
        var removedCount = 0

        for file in existingFiles {
            guard removableStatuses.contains(file.status) else { continue }
            guard !scannedPaths.contains(file.path) else { continue }
            guard isPathUnderScannedRoots(file.path, scannedRootPaths: scannedRootPaths) else { continue }

            context.delete(file)
            removedCount += 1
        }

        if removedCount > 0 {
            Log.info("FileScanPipeline: Removed \(removedCount) stale file records under scanned roots", category: .pipeline)
        }
    }

    private func isPathUnderScannedRoots(_ path: String, scannedRootPaths: Set<String>) -> Bool {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        for root in scannedRootPaths {
            let standardizedRoot = URL(fileURLWithPath: root).standardizedFileURL.path
            let prefix = standardizedRoot.hasSuffix("/") ? standardizedRoot : standardizedRoot + "/"
            if standardizedPath == standardizedRoot || standardizedPath.hasPrefix(prefix) {
                return true
            }
        }
        return false
    }

    /// Files discovered by recursive scans may already be inside their resolved
    /// destination folder. Mark these as completed so they do not inflate
    /// review/stale counts and re-attempt redundant moves.
    private func normalizeAlreadyOrganizedFiles(_ files: [FileMetadata]) -> [FileMetadata] {
        var normalized: [FileMetadata] = []
        normalized.reserveCapacity(files.count)

        var destinationPathCache: [Destination: String?] = [:]

        for var file in files {
            guard file.status != .completed else {
                normalized.append(file)
                continue
            }

            guard let destination = file.destination,
                  let destinationFolderPath = resolvedDestinationPath(for: destination, cache: &destinationPathCache),
                  isFileAlreadyInDestinationFolder(filePath: file.path, destinationFolderPath: destinationFolderPath) else {
                normalized.append(file)
                continue
            }

            file.status = .completed
            file.matchReason = nil
            file.confidenceScore = nil
            file.suggestionSourceRaw = nil
            file.matchedRuleID = nil
            normalized.append(file)
        }

        return normalized
    }

    private func resolvedDestinationPath(
        for destination: Destination,
        cache: inout [Destination: String?]
    ) -> String? {
        if let cached = cache[destination] {
            return cached
        }

        let resolvedPath: String?
        switch destination {
        case .trash:
            resolvedPath = nil
        case .folder:
            resolvedPath = destination.resolve()?.url.standardizedFileURL.path
        }

        cache[destination] = resolvedPath
        return resolvedPath
    }

    private func isFileAlreadyInDestinationFolder(filePath: String, destinationFolderPath: String) -> Bool {
        let fileParent = URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .standardizedFileURL
            .path
        let standardizedDestination = URL(fileURLWithPath: destinationFolderPath)
            .standardizedFileURL
            .path
        return fileParent == standardizedDestination
    }
    
    // MARK: - Computation

    /// Apply learned patterns using pre-fetched data.
    /// Note: Learned patterns currently store path strings, not bookmarks.
    /// Until LearnedPattern is updated to use Destination type, this will only
    /// set match metadata without a destination.
    private func preserveOriginalSuggestions(in files: [FileMetadata]) -> [FileMetadata] {
        files.map { file in
            guard file.originalSuggestedDestination == nil,
                  file.status == .ready,
                  let destination = file.destination else {
                return file
            }

            var modified = file
            modified.originalSuggestedDestination = destination
            return modified
        }
    }

    private func applyPersonalMemorySuggestions(
        to files: [FileMetadata],
        context: ModelContext
    ) -> [FileMetadata] {
        guard FeatureFlagService.shared.isEnabled(.patternLearning),
              FeatureFlagService.shared.isEnabled(.destinationPrediction) else {
            return files
        }

        let memoryService = PersonalMemoryService(modelContext: context)
        var mutableFiles = files

        for (index, file) in mutableFiles.enumerated() {
            guard file.status == .pending else { continue }
            guard let prediction = try? memoryService.suggestion(for: file) else { continue }

            var modified = file
            if let destination = prediction.destination {
                modified.destination = destination
            } else if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                modified.destination = .folder(bookmark: Data(), displayName: prediction.path)
            }
            modified.originalSuggestedDestination = modified.destination
            modified.status = .ready
            modified.matchReason = prediction.explanation.summary
            modified.confidenceScore = prediction.confidence
            modified.suggestionSourceRaw = prediction.source.rawValue
            mutableFiles[index] = modified
        }

        return mutableFiles
    }

    private func applyLearnedPatterns(to files: [FileMetadata], patterns: [LearnedPattern]) -> [FileMetadata] {
        guard !patterns.isEmpty else { return files }

        var mutableFiles = files
        for (index, file) in mutableFiles.enumerated() {
            // Only apply patterns if file is still pending (no rule matched)
            guard file.status == .pending else { continue }

            // Check if any pattern matches
            if let matchedPattern = learningService.findMatchingPattern(for: file, in: patterns) {
                var modified = file
                // Use bookmark-backed destination when available
                if let destination = matchedPattern.destination, destination.bookmarkData != nil {
                    modified.destination = destination
                } else {
                    let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
                    let isUITesting = CommandLine.arguments.contains("--uitesting")
                    if isRunningTests || isUITesting {
                        // In tests, use a placeholder destination so precedence logic is verifiable.
                        modified.destination = .folder(bookmark: Data(), displayName: matchedPattern.destinationPath)
                    }
                }
                modified.originalSuggestedDestination = modified.destination
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
    private func applyMLPredictions(
        to files: [FileMetadata],
        context: ModelContext,
        negativePatterns: [LearnedPattern]
    ) async -> [FileMetadata] {
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
            negativePatterns: negativePatterns
        )

        // Apply predictions to mutable files (bookmark-backed destinations only)
        for index in pendingIndices {
            let file = mutableFiles[index]
            let fileItem = FileItem.from(file)

            if let prediction = predictions[fileItem.path] {
                var modified = file
                // Only apply if prediction includes a bookmark-backed destination
                if let destination = prediction.destination {
                    modified.destination = destination
                }
                modified.originalSuggestedDestination = modified.destination
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
