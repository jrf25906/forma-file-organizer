import XCTest
@testable import Forma_File_Organizing

/// Synthetic dataset-based tests for NaturalLanguageRuleParser.
///
/// The goal is to cover a wide variety of phrasings and assert that the
/// parser behaves reasonably on at least 200 examples, achieving a
/// coarse-grained success rate of 70%+.
final class NaturalLanguageRuleParserDatasetTests: XCTestCase {

    private struct NLExample {
        let text: String
        let expectedAction: Rule.ActionType?
        let expectedDestinationContains: String?
        let expectsConditions: Bool
        let shouldBeComplete: Bool
    }

    private func syntheticExamples() -> [NLExample] {
        var examples: [NLExample] = []

        // Hand-authored core examples that exercise common patterns.
        examples.append(NLExample(
            text: "Move pdf files older than 30 days to Archive",
            expectedAction: .move,
            expectedDestinationContains: "Archive",
            expectsConditions: true,
            shouldBeComplete: true
        ))
        examples.append(NLExample(
            text: "Delete screenshots from last week",
            expectedAction: .delete,
            expectedDestinationContains: nil,
            expectsConditions: true,
            shouldBeComplete: true
        ))
        examples.append(NLExample(
            text: "Move images larger than 500MB to Archives",
            expectedAction: .move,
            expectedDestinationContains: "Archives",
            expectsConditions: true,
            shouldBeComplete: true
        ))
        examples.append(NLExample(
            text: "Organize work documents by month",
            expectedAction: .move,
            expectedDestinationContains: nil,
            expectsConditions: true,
            shouldBeComplete: false
        ))
        examples.append(NLExample(
            text: "Organize stuff",
            expectedAction: .move,
            expectedDestinationContains: nil,
            expectsConditions: false,
            shouldBeComplete: false
        ))
        examples.append(NLExample(
            text: "Copy invoices to Documents/Invoices",
            expectedAction: .copy,
            expectedDestinationContains: "Documents/Invoices",
            expectsConditions: true,
            shouldBeComplete: true
        ))
        examples.append(NLExample(
            text: "Move downloaded zip archives to Downloads/Archives",
            expectedAction: .move,
            expectedDestinationContains: "Downloads/Archives",
            expectsConditions: true,
            shouldBeComplete: true
        ))
        examples.append(NLExample(
            text: "Delete dmg installers older than 14 days",
            expectedAction: .delete,
            expectedDestinationContains: nil,
            expectsConditions: true,
            shouldBeComplete: true
        ))
        examples.append(NLExample(
            text: "Move project files named \"final\" to Projects/Final",
            expectedAction: .move,
            expectedDestinationContains: "Projects/Final",
            expectsConditions: true,
            shouldBeComplete: true
        ))
        examples.append(NLExample(
            text: "Delete temporary files starting with temp_",
            expectedAction: .delete,
            expectedDestinationContains: nil,
            expectsConditions: true,
            shouldBeComplete: true
        ))

        // Systematic variations over a small set of extensions and time windows.
        let fileTypes = ["pdf", "png", "jpg", "zip", "mp4"]
        let dayWindows = stride(from: 7, through: 140, by: 7) // 7,14,...,140

        for days in dayWindows {
            for ext in fileTypes {
                examples.append(NLExample(
                    text: "Move \(ext) files older than \(days) days to Archive",
                    expectedAction: .move,
                    expectedDestinationContains: "Archive",
                    expectsConditions: true,
                    shouldBeComplete: true
                ))

                examples.append(NLExample(
                    text: "Delete \(ext) files older than \(days) days",
                    expectedAction: .delete,
                    expectedDestinationContains: nil,
                    expectsConditions: true,
                    shouldBeComplete: true
                ))
            }
        }

        // Variations on "last week" / "last month" for different nouns.
        let lastRangeNouns = ["screenshots", "photos", "videos", "documents"]
        for noun in lastRangeNouns {
            examples.append(NLExample(
                text: "Delete \(noun) from last week",
                expectedAction: .delete,
                expectedDestinationContains: nil,
                expectsConditions: true,
                shouldBeComplete: true
            ))
            examples.append(NLExample(
                text: "Move \(noun) from last month to Archive",
                expectedAction: .move,
                expectedDestinationContains: "Archive",
                expectsConditions: true,
                shouldBeComplete: true
            ))
        }

        // Colloquial / slightly messy phrasing.
        let colloquials: [NLExample] = [
            NLExample(
                text: "sweep up old screenshots into Archive",
                expectedAction: .move,
                expectedDestinationContains: "Archive",
                expectsConditions: true,
                shouldBeComplete: true
            ),
            NLExample(
                text: "trash any dmg older than 30 days",
                expectedAction: .delete,
                expectedDestinationContains: nil,
                expectsConditions: true,
                shouldBeComplete: true
            ),
            NLExample(
                text: "file work invoices in Documents/Work/Invoices",
                expectedAction: .move,
                expectedDestinationContains: "Documents/Work/Invoices",
                expectsConditions: true,
                shouldBeComplete: true
            ),
            NLExample(
                text: "get rid of zip backups from last month",
                expectedAction: .delete,
                expectedDestinationContains: nil,
                expectsConditions: true,
                shouldBeComplete: true
            ),
            NLExample(
                text: "sort photos into Archive",
                expectedAction: .move,
                expectedDestinationContains: "Archive",
                expectsConditions: true,
                shouldBeComplete: true
            )
        ]
        examples.append(contentsOf: colloquials)

        // Name-based patterns for invoices, reports, contracts, etc.
        let nameKeywords = ["invoice", "report", "contract", "draft", "final"]
        for keyword in nameKeywords {
            examples.append(NLExample(
                text: "Move files with \(keyword) in the name to Documents/\(keyword.capitalized)s",
                expectedAction: .move,
                expectedDestinationContains: "Documents/\(keyword.capitalized)s",
                expectsConditions: true,
                shouldBeComplete: true
            ))

            examples.append(NLExample(
                text: "Delete old \(keyword) files older than 365 days",
                expectedAction: .delete,
                expectedDestinationContains: nil,
                expectsConditions: true,
                shouldBeComplete: true
            ))
        }

        // A mix of intentionally incomplete instructions.
        let incompleteExamples: [NLExample] = [
            NLExample(
                text: "Move everything",
                expectedAction: .move,
                expectedDestinationContains: nil,
                expectsConditions: false,
                shouldBeComplete: false
            ),
            NLExample(
                text: "Delete",
                expectedAction: .delete,
                expectedDestinationContains: nil,
                expectsConditions: false,
                shouldBeComplete: false
            ),
            NLExample(
                text: "Organize downloads",
                expectedAction: .move,
                expectedDestinationContains: nil,
                expectsConditions: false,
                shouldBeComplete: false
            )
        ]
        examples.append(contentsOf: incompleteExamples)

        // Additional structured variations to comfortably exceed 200 examples.
        let baseFolders = ["Archive", "Documents/Work", "Pictures/Screenshots"]
        for folder in baseFolders {
            for ext in fileTypes {
                examples.append(NLExample(
                    text: "Move \(ext) files to \(folder)",
                    expectedAction: .move,
                    expectedDestinationContains: folder,
                    expectsConditions: true,
                    shouldBeComplete: true
                ))
            }
        }

        return examples
    }

    func testSyntheticDatasetAchievesTargetParseRate() {
        let parser = NaturalLanguageRuleParser()
        let examples = syntheticExamples()

        XCTAssertGreaterThanOrEqual(examples.count, 200, "Dataset should contain at least 200 examples (got \(examples.count))")

        var passedCount = 0

        for example in examples {
            let parsed = parser.parse(example.text)
            var examplePassed = true

            if let expectedAction = example.expectedAction {
                if parsed.primaryAction != expectedAction {
                    examplePassed = false
                }
            }

            if let expectedDest = example.expectedDestinationContains {
                if let actualDest = parsed.destinationPath {
                    if !actualDest.lowercased().contains(expectedDest.lowercased()) {
                        examplePassed = false
                    }
                } else {
                    examplePassed = false
                }
            }

            if example.expectsConditions && parsed.candidateConditions.isEmpty {
                examplePassed = false
            }

            if example.shouldBeComplete != parsed.isComplete {
                examplePassed = false
            }

            if examplePassed {
                passedCount += 1
            }
        }

        let accuracy = Double(passedCount) / Double(examples.count)
        XCTAssertGreaterThanOrEqual(accuracy, 0.7, "Parser should achieve at least 70% success rate on synthetic dataset; got \(accuracy)")
    }
}
