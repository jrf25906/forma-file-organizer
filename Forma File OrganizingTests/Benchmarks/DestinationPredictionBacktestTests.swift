import XCTest
@testable import Forma_File_Organizing

@MainActor
final class DestinationPredictionBacktestTests: XCTestCase {
    func testChronologicalSplitUsesEarliestEightyPercentForTraining() {
        let records = makeRecords(count: 100)

        let split = DestinationPredictionBacktestRunner.chronologicalSplit(
            records: records.shuffled(),
            trainFraction: 0.8
        )

        XCTAssertEqual(split.train.count, 80)
        XCTAssertEqual(split.holdout.count, 20)
        XCTAssertEqual(split.train.map(\.fileName), (0..<80).map { "file-\($0).pdf" })
        XCTAssertEqual(split.holdout.map(\.fileName), (80..<100).map { "file-\($0).pdf" })
    }

    func testTopOneScoringTracksMatchesAndMissesByPredictor() {
        let items = [
            DestinationPredictionBacktestItem(
                fileName: "invoice.pdf",
                fileExtension: "pdf",
                fileTypeCategory: "documents",
                sourceBucket: "Downloads",
                actualDestination: "Documents/Finance",
                patternPrediction: "Documents/Finance",
                mlPrediction: "Documents/Archive"
            ),
            DestinationPredictionBacktestItem(
                fileName: "receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: "documents",
                sourceBucket: "Downloads",
                actualDestination: "Documents/Finance",
                patternPrediction: nil,
                mlPrediction: "Documents/Finance"
            )
        ]

        let score = DestinationPredictionBacktestRunner.score(items: items)

        XCTAssertEqual(score.pattern.sampleCount, 2)
        XCTAssertEqual(score.pattern.correctCount, 1)
        XCTAssertEqual(score.pattern.top1Accuracy, 0.5)
        XCTAssertEqual(score.ml.sampleCount, 2)
        XCTAssertEqual(score.ml.correctCount, 1)
        XCTAssertEqual(score.ml.top1Accuracy, 0.5)
    }

    func testBucketScoringHandlesEmptyAndPresentBuckets() {
        let items = [
            DestinationPredictionBacktestItem(
                fileName: "invoice.pdf",
                fileExtension: "pdf",
                fileTypeCategory: "documents",
                sourceBucket: "Downloads",
                actualDestination: "Documents/Finance",
                patternPrediction: "Documents/Finance",
                mlPrediction: "Documents/Finance"
            )
        ]

        let emptyScore = DestinationPredictionBacktestRunner.score(items: [])
        let categoryScores = DestinationPredictionBacktestRunner.bucketScores(
            items: items,
            keyPath: \.fileTypeCategory
        )

        XCTAssertEqual(emptyScore.pattern.sampleCount, 0)
        XCTAssertEqual(emptyScore.pattern.top1Accuracy, 0)
        XCTAssertEqual(categoryScores["documents"]?.ml.top1Accuracy, 1.0)
        XCTAssertNil(categoryScores["images"])
    }

    func testMalformedActivitiesAreSkippedBeforeSplitAndReported() {
        let activities = [
            makeActivity(
                fileName: "invoice.pdf",
                details: "Moved invoice.pdf from Downloads to Documents/Finance",
                fileExtension: "pdf",
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            makeActivity(
                fileName: "missing-destination.pdf",
                details: "Organized",
                fileExtension: "pdf",
                timestamp: Date(timeIntervalSince1970: 1)
            ),
            makeActivity(
                fileName: "scanned.txt",
                details: "Scanned from Downloads",
                fileExtension: "txt",
                timestamp: Date(timeIntervalSince1970: 2),
                activityType: .fileScanned
            )
        ]

        let extraction = DestinationPredictionBacktestRunner.extractRecords(
            from: activities,
            learningService: LearningService()
        )

        XCTAssertEqual(extraction.records.count, 1)
        XCTAssertEqual(extraction.skippedActivityCount, 2)
        XCTAssertEqual(extraction.records.first?.destinationPath, "Documents/Finance")
    }

    func testGateDecisionRequiresSampleSizeAvailabilityAndTenPointLift() {
        let passingScore = makeScore(
            patternCorrect: 40,
            mlCorrect: 51,
            sampleCount: 100
        )
        let shortLiftScore = makeScore(
            patternCorrect: 40,
            mlCorrect: 49,
            sampleCount: 100
        )

        XCTAssertEqual(
            DestinationPredictionBacktestRunner.gateDecision(
                resolvedRecordCount: 499,
                score: passingScore,
                mlError: nil
            ),
            .insufficientResolvedRecords
        )
        XCTAssertEqual(
            DestinationPredictionBacktestRunner.gateDecision(
                resolvedRecordCount: 500,
                score: passingScore,
                mlError: "missing probabilities"
            ),
            .mlUnavailable
        )
        XCTAssertEqual(
            DestinationPredictionBacktestRunner.gateDecision(
                resolvedRecordCount: 500,
                score: shortLiftScore,
                mlError: nil
            ),
            .mlDidNotBeatPattern
        )
        XCTAssertEqual(
            DestinationPredictionBacktestRunner.gateDecision(
                resolvedRecordCount: 500,
                score: passingScore,
                mlError: nil
            ),
            .passed
        )
    }

    private func makeRecords(count: Int) -> [DestinationTrainingRecord] {
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

    private func makeActivity(
        fileName: String,
        details: String,
        fileExtension: String?,
        timestamp: Date,
        activityType: ActivityItem.ActivityType = .fileOrganized
    ) -> ActivityItem {
        let activity = ActivityItem(
            activityType: activityType,
            fileName: fileName,
            details: details,
            fileExtension: fileExtension
        )
        activity.timestamp = timestamp
        return activity
    }

    private func makeScore(
        patternCorrect: Int,
        mlCorrect: Int,
        sampleCount: Int
    ) -> DestinationPredictionBacktestScore {
        DestinationPredictionBacktestScore(
            pattern: DestinationPredictionBacktestPredictorScore(
                sampleCount: sampleCount,
                correctCount: patternCorrect
            ),
            ml: DestinationPredictionBacktestPredictorScore(
                sampleCount: sampleCount,
                correctCount: mlCorrect
            )
        )
    }
}
