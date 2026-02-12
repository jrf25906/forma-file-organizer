import XCTest
@testable import Forma_File_Organizing

/// Fixture-driven dataset tests for NaturalLanguageRuleParser.
///
/// Fixtures live in `Forma File OrganizingTests/Fixtures/NaturalLanguageRuleParserDataset.json`
/// and define structured expectations for action, completeness, semantic clauses,
/// ambiguity tags, and issue shape.
final class NaturalLanguageRuleParserDatasetTests: XCTestCase {

    private struct DatasetFixture: Decodable {
        let minimumAccuracy: Double
        let cases: [ParserFixtureCase]
    }

    private struct ParserFixtureCase: Decodable {
        let id: String
        let text: String
        let expect: ParserExpectations
    }

    private struct ParserExpectations: Decodable {
        let action: Rule.ActionType?
        let destinationContains: String?
        let isComplete: Bool?
        let isAmbiguous: Bool?
        let hasBlockingError: Bool?
        let minimumConditionCount: Int?
        let requiredConditionTypes: [Rule.ConditionType]?
        let forbiddenConditionTypes: [Rule.ConditionType]?
        let logicalOperator: Rule.LogicalOperator?
        let requiredAmbiguityTags: [String]?
        let requiredIssueSeverities: [String]?
        let requiredIssueKinds: [String]?
    }

    func testDatasetFixtureMeetsTargetAccuracy() throws {
        let parser = NaturalLanguageRuleParser()
        let fixture = try loadDatasetFixture()

        XCTAssertFalse(fixture.cases.isEmpty, "Fixture dataset must contain at least one case")

        var passedCount = 0
        var failures: [String] = []

        for testCase in fixture.cases {
            let parsed = parser.parse(testCase.text)
            let mismatches = evaluate(parsed: parsed, expectations: testCase.expect)

            if mismatches.isEmpty {
                passedCount += 1
            } else {
                failures.append("[\(testCase.id)] \(mismatches.joined(separator: "; "))")
            }
        }

        let accuracy = Double(passedCount) / Double(fixture.cases.count)
        let failureSummary = failures.prefix(12).joined(separator: "\n")

        XCTAssertGreaterThanOrEqual(
            accuracy,
            fixture.minimumAccuracy,
            "Dataset accuracy \(accuracy) is below target \(fixture.minimumAccuracy). Failures:\n\(failureSummary)"
        )
    }

    private func loadDatasetFixture() throws -> DatasetFixture {
        let testFile = URL(fileURLWithPath: #filePath)
        let fixtureURL = testFile
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("NaturalLanguageRuleParserDataset.json")

        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode(DatasetFixture.self, from: data)
    }

    private func evaluate(parsed: NLParsedRule, expectations: ParserExpectations) -> [String] {
        var mismatches: [String] = []

        if let expectedAction = expectations.action, parsed.primaryAction != expectedAction {
            mismatches.append("action expected \(expectedAction.rawValue), got \(parsed.primaryAction?.rawValue ?? "nil")")
        }

        if let expectedDestination = expectations.destinationContains {
            let actual = parsed.destinationPath?.lowercased() ?? ""
            if !actual.contains(expectedDestination.lowercased()) {
                mismatches.append("destination expected to contain '\(expectedDestination)', got '\(parsed.destinationPath ?? "nil")'")
            }
        }

        if let expectedComplete = expectations.isComplete, parsed.isComplete != expectedComplete {
            mismatches.append("isComplete expected \(expectedComplete), got \(parsed.isComplete)")
        }

        if let expectedAmbiguous = expectations.isAmbiguous, parsed.isAmbiguous != expectedAmbiguous {
            mismatches.append("isAmbiguous expected \(expectedAmbiguous), got \(parsed.isAmbiguous)")
        }

        if let expectedBlocking = expectations.hasBlockingError, parsed.hasBlockingError != expectedBlocking {
            mismatches.append("hasBlockingError expected \(expectedBlocking), got \(parsed.hasBlockingError)")
        }

        if let minimumConditionCount = expectations.minimumConditionCount,
           parsed.candidateConditions.count < minimumConditionCount {
            mismatches.append("condition count expected >= \(minimumConditionCount), got \(parsed.candidateConditions.count)")
        }

        let conditionTypes = Set(parsed.candidateConditions.map(\.type))

        if let requiredTypes = expectations.requiredConditionTypes {
            for type in requiredTypes where !conditionTypes.contains(type) {
                mismatches.append("missing condition type \(type.rawValue)")
            }
        }

        if let forbiddenTypes = expectations.forbiddenConditionTypes {
            for type in forbiddenTypes where conditionTypes.contains(type) {
                mismatches.append("forbidden condition type present: \(type.rawValue)")
            }
        }

        if let expectedOperator = expectations.logicalOperator, parsed.logicalOperator != expectedOperator {
            mismatches.append("logical operator expected \(expectedOperator.rawValue), got \(parsed.logicalOperator.rawValue)")
        }

        let ambiguityTags = Set(parsed.clauses.flatMap(\.ambiguityTags))
        if let requiredTags = expectations.requiredAmbiguityTags {
            for rawTag in requiredTags {
                guard let tag = NLAmbiguityTag(rawValue: rawTag) else {
                    mismatches.append("fixture uses unknown ambiguity tag '\(rawTag)'")
                    continue
                }
                if !ambiguityTags.contains(tag) {
                    mismatches.append("missing ambiguity tag \(tag.rawValue)")
                }
            }
        }

        let issueSeverities = Set(parsed.issues.map(\.severity))
        if let requiredSeverities = expectations.requiredIssueSeverities {
            for rawSeverity in requiredSeverities {
                guard let severity = NLParseIssueSeverity(rawValue: rawSeverity) else {
                    mismatches.append("fixture uses unknown issue severity '\(rawSeverity)'")
                    continue
                }
                if !issueSeverities.contains(severity) {
                    mismatches.append("missing issue severity \(severity.rawValue)")
                }
            }
        }

        let issueKinds = Set(parsed.issues.flatMap(\.relatedKinds))
        if let requiredKinds = expectations.requiredIssueKinds {
            for rawKind in requiredKinds {
                guard let kind = NLClauseKind(rawValue: rawKind) else {
                    mismatches.append("fixture uses unknown issue kind '\(rawKind)'")
                    continue
                }
                if !issueKinds.contains(kind) {
                    mismatches.append("missing issue kind \(kind.rawValue)")
                }
            }
        }

        return mismatches
    }
}
