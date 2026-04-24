import CoreML
import Foundation
import SwiftData
import XCTest
@testable import Forma_File_Organizing

@available(macOS 13.0, *)
@MainActor
final class DestinationPredictionBacktest: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try TestGating.requireIntegration()
    }

    func testRunDestinationPredictionBacktestAgainstDevelopmentStore() async throws {
        let activities = try DestinationPredictionBacktestRunner.loadDevelopmentActivities()
        let summary = try await DestinationPredictionBacktestRunner.run(activities: activities)

        print(summary.consoleSummary)

        XCTAssertEqual(summary.resolvedRecordCount, summary.trainCount + summary.holdoutCount)
        let artifacts = try XCTUnwrap(summary.outputArtifacts)
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifacts.csvPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifacts.jsonPath))
    }
}

struct DestinationPredictionBacktestItem: Codable, Equatable {
    var fileName: String
    var fileExtension: String
    var fileTypeCategory: String
    var sourceBucket: String
    var actualDestination: String
    var patternPrediction: String?
    var mlPrediction: String?
}

struct DestinationPredictionBacktestPredictorScore: Codable, Equatable {
    var sampleCount: Int
    var correctCount: Int

    var top1Accuracy: Double {
        guard sampleCount > 0 else { return 0 }
        return Double(correctCount) / Double(sampleCount)
    }
}

struct DestinationPredictionBacktestScore: Codable, Equatable {
    var pattern: DestinationPredictionBacktestPredictorScore
    var ml: DestinationPredictionBacktestPredictorScore
}

struct DestinationPredictionBacktestExtraction: Equatable {
    var records: [DestinationTrainingRecord]
    var skippedActivityCount: Int
}

struct DestinationPredictionBacktestOutputArtifacts: Codable, Equatable {
    var csvPath: String
    var jsonPath: String
}

enum DestinationPredictionBacktestGateDecision: String, Codable, Equatable {
    case passed
    case insufficientResolvedRecords
    case mlUnavailable
    case mlDidNotBeatPattern
}

struct DestinationPredictionBacktestSummary: Codable, Equatable {
    var generatedAt: Date
    var resolvedRecordCount: Int
    var skippedActivityCount: Int
    var trainCount: Int
    var holdoutCount: Int
    var score: DestinationPredictionBacktestScore
    var categoryScores: [String: DestinationPredictionBacktestScore]
    var sourceScores: [String: DestinationPredictionBacktestScore]
    var mlError: String?
    var gateDecision: DestinationPredictionBacktestGateDecision
    var outputArtifacts: DestinationPredictionBacktestOutputArtifacts?

    var mlTop1Improvement: Double {
        score.ml.top1Accuracy - score.pattern.top1Accuracy
    }

    var consoleSummary: String {
        [
            "DestinationPredictionBacktest",
            "resolvedRecords=\(resolvedRecordCount)",
            "skippedActivities=\(skippedActivityCount)",
            "train=\(trainCount)",
            "holdout=\(holdoutCount)",
            "patternTop1=\(String(format: "%.3f", score.pattern.top1Accuracy))",
            "mlTop1=\(String(format: "%.3f", score.ml.top1Accuracy))",
            "improvement=\(String(format: "%.3f", mlTop1Improvement))",
            "gate=\(gateDecision.rawValue)",
            outputArtifacts.map { "csv=\($0.csvPath) json=\($0.jsonPath)" }
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}

private struct DestinationPredictionBacktestHoldoutFile: Fileable {
    var name: String
    var fileExtension: String
    var path: String
    var destination: Destination?
    var status: FileItem.OrganizationStatus = .pending
    var matchReason: String?
    var confidenceScore: Double?
    var matchedRuleID: UUID?
    var creationDate: Date
    var modificationDate: Date
    var lastAccessedDate: Date
    var sizeInBytes: Int64 = 0
    var location: FileLocationKind
}

enum DestinationPredictionBacktestRunner {
    static let minimumResolvedRecordCount = 500
    static let minimumTop1Improvement = 0.10

    @MainActor
    static func loadDevelopmentActivities() throws -> [ActivityItem] {
        let configuration = ModelConfiguration(
            schema: Forma_File_OrganizingApp.appSchema,
            isStoredInMemoryOnly: false,
            allowsSave: false,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: Forma_File_OrganizingApp.appSchema,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ActivityItem>(
            sortBy: [SortDescriptor(\ActivityItem.timestamp, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    @MainActor
    static func run(
        activities: [ActivityItem],
        learningService: LearningService = LearningService(),
        outputDirectory: URL = defaultOutputDirectory()
    ) async throws -> DestinationPredictionBacktestSummary {
        let extraction = extractRecords(from: activities, learningService: learningService)
        let split = chronologicalSplit(records: extraction.records, trainFraction: 0.8)
        let patternPredictions = patternOnlyPredictions(
            trainRecords: split.train,
            holdoutRecords: split.holdout,
            learningService: learningService
        )
        let mlResult = await mlOnlyPredictions(
            trainRecords: split.train,
            holdoutRecords: split.holdout
        )

        let items = split.holdout.enumerated().map { index, record in
            DestinationPredictionBacktestItem(
                fileName: record.fileName,
                fileExtension: record.fileExtension,
                fileTypeCategory: FileTypeCategory.category(for: record.fileExtension).rawValue,
                sourceBucket: sourceBucket(for: record),
                actualDestination: record.destinationPath,
                patternPrediction: patternPredictions[index],
                mlPrediction: mlResult.predictions[index]
            )
        }
        let overallScore = score(items: items)

        var summary = DestinationPredictionBacktestSummary(
            generatedAt: Date(),
            resolvedRecordCount: extraction.records.count,
            skippedActivityCount: extraction.skippedActivityCount,
            trainCount: split.train.count,
            holdoutCount: split.holdout.count,
            score: overallScore,
            categoryScores: bucketScores(items: items, keyPath: \.fileTypeCategory),
            sourceScores: bucketScores(items: items, keyPath: \.sourceBucket),
            mlError: mlResult.error,
            gateDecision: gateDecision(
                resolvedRecordCount: extraction.records.count,
                score: overallScore,
                mlError: mlResult.error
            ),
            outputArtifacts: nil
        )
        summary.outputArtifacts = outputArtifacts(for: summary.generatedAt, outputDirectory: outputDirectory)
        try writeOutputs(items: items, summary: summary)

        return summary
    }

    static func chronologicalSplit(
        records: [DestinationTrainingRecord],
        trainFraction: Double
    ) -> (train: [DestinationTrainingRecord], holdout: [DestinationTrainingRecord]) {
        guard !records.isEmpty else { return ([], []) }

        let sortedRecords = records.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.fileName < rhs.fileName
            }
            return lhs.timestamp < rhs.timestamp
        }
        let boundedFraction = min(max(trainFraction, 0), 1)
        let splitIndex = Int(Double(sortedRecords.count) * boundedFraction)

        return (
            train: Array(sortedRecords.prefix(splitIndex)),
            holdout: Array(sortedRecords.suffix(sortedRecords.count - splitIndex))
        )
    }

    static func score(items: [DestinationPredictionBacktestItem]) -> DestinationPredictionBacktestScore {
        DestinationPredictionBacktestScore(
            pattern: predictorScore(items: items, prediction: \.patternPrediction),
            ml: predictorScore(items: items, prediction: \.mlPrediction)
        )
    }

    static func bucketScores(
        items: [DestinationPredictionBacktestItem],
        keyPath: KeyPath<DestinationPredictionBacktestItem, String>
    ) -> [String: DestinationPredictionBacktestScore] {
        Dictionary(grouping: items, by: { $0[keyPath: keyPath] })
            .mapValues(score)
    }

    @MainActor
    static func extractRecords(
        from activities: [ActivityItem],
        learningService: LearningService
    ) -> DestinationPredictionBacktestExtraction {
        let records = learningService.makeTrainingRecords(from: activities)
        return DestinationPredictionBacktestExtraction(
            records: records,
            skippedActivityCount: activities.count - records.count
        )
    }

    private static func predictorScore(
        items: [DestinationPredictionBacktestItem],
        prediction: KeyPath<DestinationPredictionBacktestItem, String?>
    ) -> DestinationPredictionBacktestPredictorScore {
        DestinationPredictionBacktestPredictorScore(
            sampleCount: items.count,
            correctCount: items.filter { item in
                item[keyPath: prediction] == item.actualDestination
            }.count
        )
    }

    @MainActor
    private static func patternOnlyPredictions(
        trainRecords: [DestinationTrainingRecord],
        holdoutRecords: [DestinationTrainingRecord],
        learningService: LearningService
    ) -> [String?] {
        let trainingActivities = trainRecords.map(activity(from:))
        let patterns = learningService.detectPatterns(from: trainingActivities)

        return holdoutRecords.map { record in
            let file = holdoutFile(from: record)
            return learningService.findMatchingPattern(for: file, in: patterns)?.destinationPath
        }
    }

    private static func mlOnlyPredictions(
        trainRecords: [DestinationTrainingRecord],
        holdoutRecords: [DestinationTrainingRecord]
    ) async -> (predictions: [String?], error: String?) {
        guard !trainRecords.isEmpty, !holdoutRecords.isEmpty else {
            return (Array(repeating: nil, count: holdoutRecords.count), nil)
        }

        do {
            let classifier = try await DestinationModelTrainer.train(data: trainRecords)
            let modelDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("FormaDestinationPredictionBacktest-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: modelDirectory)
            }

            let compiledModelURL = try await DestinationModelCompiler.compileClassifier(
                classifier,
                fileName: "destinationPredictionBacktest",
                in: modelDirectory
            )
            defer {
                try? FileManager.default.removeItem(at: compiledModelURL)
            }

            let model = try MLModel(contentsOf: compiledModelURL)
            let engine = CoreMLPredictionEngine()
            var predictions: [String?] = []
            predictions.reserveCapacity(holdoutRecords.count)

            for record in holdoutRecords {
                let features = DestinationTrainingFeatureExtractor.features(from: record)
                let outcome = try await engine.predict(features: features, model: model)
                predictions.append(outcome.label)
            }

            return (predictions, nil)
        } catch {
            return (
                Array(repeating: nil, count: holdoutRecords.count),
                error.localizedDescription
            )
        }
    }

    static func gateDecision(
        resolvedRecordCount: Int,
        score: DestinationPredictionBacktestScore,
        mlError: String?
    ) -> DestinationPredictionBacktestGateDecision {
        guard resolvedRecordCount >= minimumResolvedRecordCount else {
            return .insufficientResolvedRecords
        }
        guard mlError == nil, score.ml.sampleCount > 0 else {
            return .mlUnavailable
        }
        guard score.ml.top1Accuracy >= score.pattern.top1Accuracy + minimumTop1Improvement else {
            return .mlDidNotBeatPattern
        }

        return .passed
    }

    private static func activity(from record: DestinationTrainingRecord) -> ActivityItem {
        let source = record.sourceLocation.map { " from \($0)" } ?? ""
        let activity = ActivityItem(
            activityType: .fileOrganized,
            fileName: record.fileName,
            details: "Moved \(record.fileName)\(source) to \(record.destinationPath)",
            fileExtension: record.fileExtension
        )
        activity.timestamp = record.timestamp
        return activity
    }

    private static func holdoutFile(from record: DestinationTrainingRecord) -> DestinationPredictionBacktestHoldoutFile {
        DestinationPredictionBacktestHoldoutFile(
            name: record.fileName,
            fileExtension: record.fileExtension,
            path: "/backtest/\(record.fileName)",
            destination: nil,
            creationDate: record.timestamp,
            modificationDate: record.timestamp,
            lastAccessedDate: record.timestamp,
            location: locationKind(for: record.sourceLocation)
        )
    }

    private static func locationKind(for sourceLocation: String?) -> FileLocationKind {
        switch sourceLocation?.lowercased() {
        case "desktop": return .desktop
        case "downloads": return .downloads
        case "documents": return .documents
        case "pictures": return .pictures
        case "music": return .music
        case .some: return .custom
        case nil: return .unknown
        }
    }

    private static func sourceBucket(for record: DestinationTrainingRecord) -> String {
        record.sourceLocation?.isEmpty == false ? record.sourceLocation! : "Unknown"
    }

    private static func outputArtifacts(
        for date: Date,
        outputDirectory: URL
    ) -> DestinationPredictionBacktestOutputArtifacts {
        let runName = "destination-prediction-backtest-\(DestinationModelVersion.string(for: date))"
        return DestinationPredictionBacktestOutputArtifacts(
            csvPath: outputDirectory.appendingPathComponent("\(runName).csv").path,
            jsonPath: outputDirectory.appendingPathComponent("\(runName).json").path
        )
    }

    private static func writeOutputs(
        items: [DestinationPredictionBacktestItem],
        summary: DestinationPredictionBacktestSummary
    ) throws {
        let artifacts = try requireOutputArtifacts(summary.outputArtifacts)
        let csvURL = URL(fileURLWithPath: artifacts.csvPath)
        let jsonURL = URL(fileURLWithPath: artifacts.jsonPath)
        try FileManager.default.createDirectory(
            at: csvURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try csvRows(for: items).write(to: csvURL, atomically: true, encoding: .utf8)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(summary)
        try data.write(to: jsonURL, options: .atomic)
    }

    private static func requireOutputArtifacts(
        _ artifacts: DestinationPredictionBacktestOutputArtifacts?
    ) throws -> DestinationPredictionBacktestOutputArtifacts {
        guard let artifacts else {
            throw CocoaError(.fileNoSuchFile)
        }
        return artifacts
    }

    private static func defaultOutputDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("FormaDestinationPredictionBacktests", isDirectory: true)
    }

    private static func csvRows(for items: [DestinationPredictionBacktestItem]) -> String {
        let header = [
            "fileName",
            "fileExtension",
            "fileTypeCategory",
            "sourceBucket",
            "actualDestination",
            "patternPrediction",
            "mlPrediction",
            "patternCorrect",
            "mlCorrect"
        ].joined(separator: ",")

        let rows = items.map { item in
            [
                item.fileName,
                item.fileExtension,
                item.fileTypeCategory,
                item.sourceBucket,
                item.actualDestination,
                item.patternPrediction ?? "",
                item.mlPrediction ?? "",
                item.patternPrediction == item.actualDestination ? "true" : "false",
                item.mlPrediction == item.actualDestination ? "true" : "false"
            ]
            .map(csvEscape)
            .joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    private static func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }

        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
