import XCTest
@testable import Forma_File_Organizing

final class MetadataProjectAssociationResolverTests: XCTestCase {
    func testNormalizeLabel_TrimsButPreservesCaseAndPunctuation() throws {
        let resolver = MetadataProjectAssociationResolver()

        let normalized = resolver.normalizeLabel("  Project: Alpha!  ")

        XCTAssertEqual(normalized, "Project: Alpha!")
    }

    func testExplicitDestination_RequiresExactProjectsParentMatch() throws {
        let resolver = MetadataProjectAssociationResolver()

        let qualifyingContext = ProjectAssociationWriteContext(
            resolvedExplicitDestinationFolderPath: "/Users/jane/Documents/Projects/Alpha",
            explicitSourceMode: false,
            inferredCandidates: []
        )
        let resolved = resolver.resolveCandidate(from: qualifyingContext)

        XCTAssertEqual(resolved?.projectAssociation, "Alpha")
        XCTAssertEqual(resolved?.normalizedLabel, "Alpha")
        XCTAssertEqual(resolved?.sourceSummaryCategory, .destinationFolder)

        let nonQualifyingPrefixContext = ProjectAssociationWriteContext(
            resolvedExplicitDestinationFolderPath: "/Users/jane/Documents/Projects Archive/Alpha",
            explicitSourceMode: false,
            inferredCandidates: []
        )
        XCTAssertNil(resolver.resolveCandidate(from: nonQualifyingPrefixContext))

        let nonQualifyingDescendantContext = ProjectAssociationWriteContext(
            resolvedExplicitDestinationFolderPath: "/Users/jane/Documents/Projects/Alpha/Assets",
            explicitSourceMode: false,
            inferredCandidates: []
        )
        XCTAssertNil(resolver.resolveCandidate(from: nonQualifyingDescendantContext))
    }

    func testResolveCandidate_PrefersExplicitDestinationOverInference() throws {
        let resolver = MetadataProjectAssociationResolver()

        let context = ProjectAssociationWriteContext(
            resolvedExplicitDestinationFolderPath: "/Users/jane/Documents/Projects/Alpha",
            explicitSourceMode: false,
            inferredCandidates: [
                .init(suggestedFolderName: "Beta", normalizedLabel: "Beta", confidence: 0.95)
            ]
        )

        let resolved = resolver.resolveCandidate(from: context)

        XCTAssertEqual(resolved?.projectAssociation, "Alpha")
        XCTAssertEqual(resolved?.sourceSummaryCategory, .destinationFolder)
    }

    func testResolveCandidate_RequiresStrongWinnerForInference() throws {
        let resolver = MetadataProjectAssociationResolver()

        let belowThresholdContext = ProjectAssociationWriteContext(
            resolvedExplicitDestinationFolderPath: nil,
            explicitSourceMode: false,
            inferredCandidates: [
                .init(suggestedFolderName: "Alpha", normalizedLabel: "Alpha", confidence: 0.79)
            ]
        )
        XCTAssertNil(resolver.resolveCandidate(from: belowThresholdContext))

        let weakMarginContext = ProjectAssociationWriteContext(
            resolvedExplicitDestinationFolderPath: nil,
            explicitSourceMode: false,
            inferredCandidates: [
                .init(suggestedFolderName: "Alpha", normalizedLabel: "Alpha", confidence: 0.90),
                .init(suggestedFolderName: "Beta", normalizedLabel: "Beta", confidence: 0.76)
            ]
        )
        XCTAssertNil(resolver.resolveCandidate(from: weakMarginContext))

        let strongWinnerContext = ProjectAssociationWriteContext(
            resolvedExplicitDestinationFolderPath: nil,
            explicitSourceMode: false,
            inferredCandidates: [
                .init(suggestedFolderName: "  Alpha  ", normalizedLabel: "Alpha", confidence: 0.90),
                .init(suggestedFolderName: "Beta", normalizedLabel: "Beta", confidence: 0.74)
            ]
        )

        let resolved = resolver.resolveCandidate(from: strongWinnerContext)

        XCTAssertEqual(resolved?.projectAssociation, "  Alpha  ")
        XCTAssertEqual(resolved?.normalizedLabel, "Alpha")
        XCTAssertEqual(resolved?.sourceSummaryCategory, .relatedFilePattern)
    }
}
