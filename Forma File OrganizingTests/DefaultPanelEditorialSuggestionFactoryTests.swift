import XCTest
@testable import Forma_File_Organizing

final class DefaultPanelEditorialSuggestionFactoryTests: XCTestCase {
    func testBuildPrioritizesPromotionThenInsightsThenPatterns() {
        let promotion = ExternalReviewPromotionSuggestion(
            folderType: .downloads,
            bookmarkData: Data("bookmark".utf8)
        )
        let highPriorityInsight = FileInsight(
            message: "4 large files taking up 999.4 MB",
            actionLabel: "Review Files",
            priority: 9,
            iconName: "externaldrive.fill",
            affectedCount: 4
        )
        let lowerPriorityInsight = FileInsight(
            message: "15 files in Downloads need review",
            actionLabel: "Review Now",
            priority: 7,
            iconName: "arrow.down.circle",
            affectedCount: 15
        )
        let strongerPattern = LearnedPattern(
            patternDescription: "PDF files → ~/Documents/Finance",
            fileExtension: "pdf",
            destinationPath: "~/Documents/Finance",
            occurrenceCount: 8,
            confidenceScore: 0.84
        )
        let weakerPattern = LearnedPattern(
            patternDescription: "PNG files → ~/Pictures/Screenshots",
            fileExtension: "png",
            destinationPath: "~/Pictures/Screenshots",
            occurrenceCount: 5,
            confidenceScore: 0.72
        )

        let snapshots = DefaultPanelEditorialSuggestionFactory.build(
            promotion: promotion,
            insights: [lowerPriorityInsight, highPriorityInsight],
            patterns: [weakerPattern, strongerPattern]
        )

        XCTAssertEqual(
            snapshots.map(\.title),
            [
                promotion.titleText,
                highPriorityInsight.message,
                lowerPriorityInsight.message,
                strongerPattern.patternDescription,
                weakerPattern.patternDescription
            ]
        )
    }

    func testBuildPrefersPatternSnapshotWhenInsightDuplicatesPatternDescription() {
        let duplicatedPattern = LearnedPattern(
            patternDescription: "PDF files → ~/Documents/Finance",
            fileExtension: "pdf",
            destinationPath: "~/Documents/Finance",
            occurrenceCount: 6,
            confidenceScore: 0.82
        )
        let duplicatedInsight = FileInsight(
            message: duplicatedPattern.patternDescription,
            actionLabel: "Create Rule",
            priority: 10,
            iconName: "wand.and.stars"
        )

        let snapshots = DefaultPanelEditorialSuggestionFactory.build(
            promotion: nil,
            insights: [duplicatedInsight],
            patterns: [duplicatedPattern]
        )

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.title, duplicatedPattern.patternDescription)
        XCTAssertEqual(snapshots.first?.source, .pattern)
    }
}
