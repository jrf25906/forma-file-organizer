import Foundation
import SwiftData

enum TrustedAutomationScopeRunTriggerSource: String, Codable, Sendable, Hashable {
    case manualPreview
    case automaticPass
}

enum TrustedAutomationScopeRunStatus: String, Codable, Sendable, Hashable {
    case completed
    case completedWithBlockers
    case blocked
    case failed
}

@Model
final class TrustedAutomationScopeRunRecord {
    struct HeldBucket: Codable, Hashable, Sendable {
        let bucket: String
        let count: Int
    }

    var id: UUID
    var scopeID: UUID
    private var triggerSourceRaw: String
    private var statusRaw: String
    var startedAt: Date
    var endedAt: Date?
    var matchedCount: Int
    var eligibleCount: Int
    var organizedCount: Int
    var heldCount: Int
    var failedCount: Int
    private var heldBucketsData: Data
    var summaryText: String?
    private var exampleFileNamesData: Data

    var triggerSource: TrustedAutomationScopeRunTriggerSource {
        get { TrustedAutomationScopeRunTriggerSource(rawValue: triggerSourceRaw) ?? .automaticPass }
        set { triggerSourceRaw = newValue.rawValue }
    }

    var status: TrustedAutomationScopeRunStatus {
        get { TrustedAutomationScopeRunStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    var heldBuckets: [HeldBucket] {
        get {
            decode([HeldBucket].self, from: heldBucketsData) ?? []
        }
        set {
            heldBucketsData = encode(newValue) ?? Data()
        }
    }

    var exampleFileNames: [String] {
        get {
            decode([String].self, from: exampleFileNamesData) ?? []
        }
        set {
            exampleFileNamesData = encode(newValue) ?? Data()
        }
    }

    init(
        id: UUID = UUID(),
        scopeID: UUID,
        triggerSource: TrustedAutomationScopeRunTriggerSource,
        status: TrustedAutomationScopeRunStatus,
        matchedCount: Int,
        eligibleCount: Int,
        organizedCount: Int,
        heldCount: Int,
        failedCount: Int,
        heldBuckets: [HeldBucket],
        summaryText: String?,
        exampleFileNames: [String],
        startedAt: Date,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.scopeID = scopeID
        self.triggerSourceRaw = triggerSource.rawValue
        self.statusRaw = status.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.matchedCount = matchedCount
        self.eligibleCount = eligibleCount
        self.organizedCount = organizedCount
        self.heldCount = heldCount
        self.failedCount = failedCount
        self.heldBucketsData = Self.encode(heldBuckets) ?? Data()
        self.summaryText = summaryText
        self.exampleFileNamesData = Self.encode(exampleFileNames) ?? Data()
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) -> Value? {
        Self.decode(type, from: data)
    }

    private func encode<Value: Encodable>(_ value: Value) -> Data? {
        Self.encode(value)
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) -> Value? {
        try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<Value: Encodable>(_ value: Value) -> Data? {
        try? JSONEncoder().encode(value)
    }
}
