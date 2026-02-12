import XCTest
@testable import Forma_File_Organizing

final class SuggestionSourcePersistenceTests: XCTestCase {

    func testRawValuesRemainStableForPersistence() {
        XCTAssertEqual(SuggestionSource.rule.rawValue, "rule")
        XCTAssertEqual(SuggestionSource.pattern.rawValue, "pattern")
        XCTAssertEqual(SuggestionSource.mlPrediction.rawValue, "mlPrediction")
    }

    func testSuggestionSourceCodableRoundTrip() throws {
        let sources: [SuggestionSource] = [.rule, .pattern, .mlPrediction]

        let data = try JSONEncoder().encode(sources)
        let decoded = try JSONDecoder().decode([SuggestionSource].self, from: data)

        XCTAssertEqual(decoded, sources)
    }
}
