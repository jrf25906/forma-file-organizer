//
//  RuleConditionTypeSafetyTests.swift
//  Forma File OrganizingTests
//
//  Tests demonstrating the type safety improvements to RuleCondition.
//

import XCTest
@testable import Forma_File_Organizing

final class RuleConditionTypeSafetyTests: XCTestCase {

    // MARK: - Type-Safe Construction Tests

    func testFileExtensionCondition() throws {
        let condition = try RuleCondition(type: .fileExtension, value: "pdf")

        // Type-safe accessors
        XCTAssertEqual(condition.textValue, "pdf")
        XCTAssertNil(condition.daysValue)
        XCTAssertNil(condition.sizeValue)

        // Legacy compatibility
        XCTAssertEqual(condition.type, .fileExtension)
        XCTAssertEqual(condition.value, "pdf")
    }

    func testDateOlderThanCondition() throws {
        let condition = try RuleCondition(type: .dateOlderThan, value: "7")

        // Type-safe accessors
        XCTAssertEqual(condition.daysValue, 7)
        XCTAssertNil(condition.textValue)
        XCTAssertNil(condition.sizeValue)
        XCTAssertNil(condition.extensionFilter)

        // Legacy compatibility
        XCTAssertEqual(condition.type, .dateOlderThan)
        XCTAssertEqual(condition.value, "7")
    }

    func testDateOlderThanWithExtensionCondition() throws {
        let condition = try RuleCondition(type: .dateOlderThan, value: "dmg:7")

        // Type-safe accessors
        XCTAssertEqual(condition.daysValue, 7)
        XCTAssertEqual(condition.extensionFilter, "dmg")
        XCTAssertNil(condition.textValue)
        XCTAssertNil(condition.sizeValue)

        // Legacy compatibility
        XCTAssertEqual(condition.type, .dateOlderThan)
        XCTAssertEqual(condition.value, "dmg:7")
    }

    func testSizeLargerThanCondition() throws {
        let condition = try RuleCondition(type: .sizeLargerThan, value: "100MB")

        // Type-safe accessors
        XCTAssertEqual(condition.sizeValue, 100 * 1024 * 1024)
        XCTAssertNil(condition.daysValue)
        XCTAssertNil(condition.textValue)

        // Legacy compatibility
        XCTAssertEqual(condition.type, .sizeLargerThan)
        XCTAssertEqual(condition.value, "100MB")
    }

    func testSizeLargerThanVariousFormats() throws {
        // Test KB
        let kb = try RuleCondition(type: .sizeLargerThan, value: "500KB")
        XCTAssertEqual(kb.sizeValue, 500 * 1024)

        // Test GB
        let gb = try RuleCondition(type: .sizeLargerThan, value: "1.5GB")
        XCTAssertEqual(gb.sizeValue, Int64(1.5 * 1024 * 1024 * 1024))

        // Test TB
        let tb = try RuleCondition(type: .sizeLargerThan, value: "2TB")
        XCTAssertEqual(tb.sizeValue, 2 * 1024 * 1024 * 1024 * 1024)
    }

    // MARK: - Validation Tests

    func testInvalidDaysValue() {
        XCTAssertThrowsError(try RuleCondition(type: .dateOlderThan, value: "abc")) { error in
            guard case RuleCondition.ValidationError.invalidDays = error else {
                XCTFail("Expected invalidDays error, got \(error)")
                return
            }
        }
    }

    func testZeroDaysValue() {
        XCTAssertThrowsError(try RuleCondition(type: .dateOlderThan, value: "0")) { error in
            guard case RuleCondition.ValidationError.invalidDays = error else {
                XCTFail("Expected invalidDays error for zero days, got \(error)")
                return
            }
        }
    }

    func testNegativeDaysValue() {
        XCTAssertThrowsError(try RuleCondition(type: .dateModifiedOlderThan, value: "-5")) { error in
            guard case RuleCondition.ValidationError.invalidDays = error else {
                XCTFail("Expected invalidDays error for negative days, got \(error)")
                return
            }
        }
    }

    func testInvalidSizeValue() {
        XCTAssertThrowsError(try RuleCondition(type: .sizeLargerThan, value: "abc")) { error in
            guard case RuleCondition.ValidationError.invalidSize = error else {
                XCTFail("Expected invalidSize error, got \(error)")
                return
            }
        }
    }

    func testEmptyTextValue() {
        XCTAssertThrowsError(try RuleCondition(type: .fileExtension, value: "")) { error in
            guard case RuleCondition.ValidationError.emptyValue = error else {
                XCTFail("Expected emptyValue error, got \(error)")
                return
            }
        }
    }

    func testEmptyTextValueWithWhitespace() {
        XCTAssertThrowsError(try RuleCondition(type: .nameContains, value: "   ")) { error in
            guard case RuleCondition.ValidationError.emptyValue = error else {
                XCTFail("Expected emptyValue error, got \(error)")
                return
            }
        }
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = try RuleCondition(type: .dateOlderThan, value: "dmg:7")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RuleCondition.self, from: data)

        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value, original.value)
        XCTAssertEqual(decoded.daysValue, original.daysValue)
        XCTAssertEqual(decoded.extensionFilter, original.extensionFilter)
    }

    func testEncodeDecodeSizeLargerThan() throws {
        let original = try RuleCondition(type: .sizeLargerThan, value: "100MB")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RuleCondition.self, from: data)

        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.sizeValue, original.sizeValue)
        XCTAssertEqual(decoded.value, original.value)
    }

    func testEncodeDecodeArray() throws {
        let conditions = [
            try RuleCondition(type: .fileExtension, value: "pdf"),
            try RuleCondition(type: .dateOlderThan, value: "7"),
            try RuleCondition(type: .sizeLargerThan, value: "100MB")
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(conditions)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([RuleCondition].self, from: data)

        XCTAssertEqual(decoded.count, conditions.count)
        for (original, decodedCondition) in zip(conditions, decoded) {
            XCTAssertEqual(decodedCondition.type, original.type)
            XCTAssertEqual(decodedCondition.value, original.value)
        }
    }

    // MARK: - Equatable and Hashable Tests

    func testEquatable() throws {
        let condition1 = try RuleCondition(type: .fileExtension, value: "pdf")
        let condition2 = try RuleCondition(type: .fileExtension, value: "pdf")
        let condition3 = try RuleCondition(type: .fileExtension, value: "jpg")

        XCTAssertEqual(condition1, condition2)
        XCTAssertNotEqual(condition1, condition3)
    }

    func testHashable() throws {
        let condition1 = try RuleCondition(type: .fileExtension, value: "pdf")
        let condition2 = try RuleCondition(type: .fileExtension, value: "pdf")

        var set = Set<RuleCondition>()
        set.insert(condition1)
        set.insert(condition2)

        XCTAssertEqual(set.count, 1) // Should be deduplicated
    }

    // MARK: - Direct Construction Tests (using enum cases)

    func testDirectConstructionFileExtension() {
        let condition = RuleCondition.fileExtension("pdf")

        XCTAssertEqual(condition.textValue, "pdf")
        XCTAssertEqual(condition.type, .fileExtension)
        XCTAssertEqual(condition.value, "pdf")
    }

    func testDirectConstructionDateOlderThan() {
        let condition = RuleCondition.dateOlderThan(days: 7, extension: "dmg")

        XCTAssertEqual(condition.daysValue, 7)
        XCTAssertEqual(condition.extensionFilter, "dmg")
        XCTAssertEqual(condition.type, .dateOlderThan)
        XCTAssertEqual(condition.value, "dmg:7")
    }

    func testDirectConstructionSizeLargerThan() {
        let bytes: Int64 = 100 * 1024 * 1024 // 100MB
        let condition = RuleCondition.sizeLargerThan(bytes: bytes)

        XCTAssertEqual(condition.sizeValue, bytes)
        XCTAssertEqual(condition.type, .sizeLargerThan)
        XCTAssertEqual(condition.value, "100MB")
    }

    // MARK: - Pattern Matching Tests

    func testPatternMatching() throws {
        let condition = try RuleCondition(type: .dateOlderThan, value: "7")

        switch condition {
        case .dateOlderThan(let days, let ext):
            XCTAssertEqual(days, 7)
            XCTAssertNil(ext)
        default:
            XCTFail("Pattern matching failed")
        }
    }

    func testPatternMatchingSizeLargerThan() throws {
        let condition = try RuleCondition(type: .sizeLargerThan, value: "100MB")

        switch condition {
        case .sizeLargerThan(let bytes):
            XCTAssertEqual(bytes, 100 * 1024 * 1024)
        default:
            XCTFail("Pattern matching failed")
        }
    }
}
