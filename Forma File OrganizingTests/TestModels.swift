//
//  TestModels.swift
//  Forma File OrganizingTests
//
//  Created by James Farmer on 11/19/25.
//
//  Test-only models that conform to the Ruleable and Fileable protocols.
//  These enable testing without SwiftData/MainActor complications.

import Foundation
@testable import Forma_File_Organizing

// MARK: - Test Destination Helper

extension Destination {
    /// Creates a mock folder destination for testing.
    ///
    /// The bookmark data is a simple encoding of the display name, which won't work
    /// for real file operations but is sufficient for testing destination assignment
    /// and display logic.
    ///
    /// - Parameter displayName: The folder name to display (e.g., "Documents", "PDFs")
    /// - Returns: A folder destination with mock bookmark data
    static func mockFolder(_ displayName: String) -> Destination {
        let mockData = displayName.data(using: .utf8) ?? Data()
        return .folder(bookmark: mockData, displayName: displayName)
    }
}

// MARK: - TestFileItem

/// Test-only file item that conforms to Fileable.
///
/// This simple class can be created and modified without SwiftData or MainActor,
/// making tests faster and more reliable.
///
/// Note: Unlike FileItem, this allows mutation of name/fileExtension/path for testing flexibility
final class TestFileItem: Fileable {
    var name: String
    var fileExtension: String
    var path: String
    var destination: Destination?
    var status: FileItem.OrganizationStatus
    var matchReason: String?
    var confidenceScore: Double?
    var matchedRuleID: UUID?
    var creationDate: Date
    var modificationDate: Date
    var lastAccessedDate: Date
    var sizeInBytes: Int64
    var location: FileLocationKind
    var rejectedDestination: String?
    var rejectionCount: Int

    init(
        name: String,
        fileExtension: String,
        path: String,
        destination: Destination? = nil,
        status: FileItem.OrganizationStatus = .pending,
        matchReason: String? = nil,
        confidenceScore: Double? = nil,
        matchedRuleID: UUID? = nil,
        creationDate: Date = Date(),
        modificationDate: Date = Date(),
        lastAccessedDate: Date = Date(),
        sizeInBytes: Int64 = 0,
        location: FileLocationKind = .unknown,
        rejectedDestination: String? = nil,
        rejectionCount: Int = 0
    ) {
        self.name = name
        self.fileExtension = fileExtension
        self.path = path
        self.destination = destination
        self.status = status
        self.matchReason = matchReason
        self.confidenceScore = confidenceScore
        self.matchedRuleID = matchedRuleID
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.lastAccessedDate = lastAccessedDate
        self.sizeInBytes = sizeInBytes
        self.location = location
        self.rejectedDestination = rejectedDestination
        self.rejectionCount = rejectionCount
    }

    /// Convenience initializer that derives name and extension from path
    convenience init(
        path: String,
        destination: Destination? = nil,
        status: FileItem.OrganizationStatus = .pending,
        matchReason: String? = nil,
        confidenceScore: Double? = nil,
        matchedRuleID: UUID? = nil,
        creationDate: Date = Date(),
        modificationDate: Date = Date(),
        lastAccessedDate: Date = Date(),
        sizeInBytes: Int64 = 0,
        location: FileLocationKind = .unknown
    ) {
        let url = URL(fileURLWithPath: path)
        self.init(
            name: url.lastPathComponent,
            fileExtension: url.pathExtension,
            path: path,
            destination: destination,
            status: status,
            matchReason: matchReason,
            confidenceScore: confidenceScore,
            matchedRuleID: matchedRuleID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            lastAccessedDate: lastAccessedDate,
            sizeInBytes: sizeInBytes,
            location: location
        )
    }
}

// MARK: - TestRule

/// Test-only rule that conforms to Ruleable.
///
/// This simple struct can be created without SwiftData or MainActor,
/// making tests faster and more reliable.
struct TestRule: Ruleable {
    let id: UUID
    var conditionType: Rule.ConditionType
    var conditionValue: String
    var conditions: [RuleCondition]
    var logicalOperator: Rule.LogicalOperator
    var isEnabled: Bool
    var destination: Destination?
    var actionType: Rule.ActionType
    var sortOrder: Int
    var exclusionConditions: [RuleCondition]

    /// Initializes a test rule with a single condition.
    ///
    /// This convenience initializer automatically populates the `conditions` array
    /// from the provided condition type and value.
    init(
        id: UUID = UUID(),
        conditionType: Rule.ConditionType,
        conditionValue: String,
        isEnabled: Bool = true,
        destination: Destination? = nil,
        actionType: Rule.ActionType = .move,
        sortOrder: Int = 0,
        exclusionConditions: [RuleCondition] = []
    ) {
        self.id = id
        self.conditionType = conditionType
        self.conditionValue = conditionValue
        // Populate conditions array - this is the source of truth for RuleEngine
        if let condition = try? RuleCondition(type: conditionType, value: conditionValue) {
            self.conditions = [condition]
        } else {
            self.conditions = []
        }
        self.logicalOperator = .single
        self.isEnabled = isEnabled
        self.destination = destination
        self.actionType = actionType
        self.sortOrder = sortOrder
        self.exclusionConditions = exclusionConditions
    }

    /// Initializes a test rule with multiple conditions (compound mode).
    init(
        id: UUID = UUID(),
        conditions: [RuleCondition],
        logicalOperator: Rule.LogicalOperator,
        isEnabled: Bool = true,
        destination: Destination? = nil,
        actionType: Rule.ActionType = .move,
        sortOrder: Int = 0,
        exclusionConditions: [RuleCondition] = []
    ) {
        self.id = id
        // Set legacy fields to first condition or defaults
        if let first = conditions.first {
            self.conditionType = first.type
            self.conditionValue = first.value
        } else {
            self.conditionType = .fileExtension
            self.conditionValue = ""
        }
        self.conditions = conditions
        self.logicalOperator = logicalOperator
        self.isEnabled = isEnabled
        self.destination = destination
        self.actionType = actionType
        self.sortOrder = sortOrder
        self.exclusionConditions = exclusionConditions
    }
}
