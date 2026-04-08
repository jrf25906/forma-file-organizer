import Foundation
import SwiftData

enum WorkflowRunPrimaryStatus: String, Codable, Sendable, Hashable {
    case queued
    case running
    case succeeded
    case failed
    case canceled
}

enum WorkflowRunRollbackStatus: String, Codable, Sendable, Hashable {
    case notRequested
    case requested
    case inProgress
    case succeeded
    case failed
}

enum WorkflowStepStatus: String, Codable, Sendable, Hashable {
    case pending
    case running
    case succeeded
    case failed
    case skipped
}

enum WorkflowFileDisposition: String, Codable, Sendable, Hashable {
    case pending
    case moved
    case held
    case skipped
    case failed
    case restored
}

enum WorkflowCompensationStatus: String, Codable, Sendable, Hashable {
    case notNeeded
    case available
    case requested
    case applied
    case failed
}

@Model
final class WorkflowRunRecord {
    var id: UUID
    var scopeID: UUID
    var workflowTemplateID: String?
    private var primaryStatusRaw: String
    private var rollbackStatusRaw: String
    var startedAt: Date
    var endedAt: Date?
    var rollbackReason: String?
    var rollbackRequestedAt: Date?
    var rollbackCompletedAt: Date?
    var updatedAt: Date

    var primaryStatus: WorkflowRunPrimaryStatus {
        get { WorkflowRunPrimaryStatus(rawValue: primaryStatusRaw) ?? .running }
        set { primaryStatusRaw = newValue.rawValue }
    }

    var rollbackStatus: WorkflowRunRollbackStatus {
        get { WorkflowRunRollbackStatus(rawValue: rollbackStatusRaw) ?? .notRequested }
        set { rollbackStatusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        scopeID: UUID,
        workflowTemplateID: String?,
        primaryStatus: WorkflowRunPrimaryStatus,
        rollbackStatus: WorkflowRunRollbackStatus = .notRequested,
        startedAt: Date,
        endedAt: Date? = nil,
        rollbackReason: String? = nil,
        rollbackRequestedAt: Date? = nil,
        rollbackCompletedAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.scopeID = scopeID
        self.workflowTemplateID = Self.normalizedOptionalText(workflowTemplateID)
        self.primaryStatusRaw = primaryStatus.rawValue
        self.rollbackStatusRaw = rollbackStatus.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.rollbackReason = Self.normalizedOptionalText(rollbackReason)
        self.rollbackRequestedAt = rollbackRequestedAt
        self.rollbackCompletedAt = rollbackCompletedAt
        self.updatedAt = updatedAt ?? startedAt
    }

    static func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@Model
final class WorkflowStepRunRecord {
    var id: UUID
    var runID: UUID
    var stepID: String
    private var statusRaw: String
    var startedAt: Date?
    var endedAt: Date?
    var errorMessage: String?
    var recordedAt: Date

    var status: WorkflowStepStatus {
        get { WorkflowStepStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        runID: UUID,
        stepID: String,
        status: WorkflowStepStatus,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        errorMessage: String? = nil,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.runID = runID
        self.stepID = Self.normalizedRequiredText(stepID)
        self.statusRaw = status.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.errorMessage = WorkflowRunRecord.normalizedOptionalText(errorMessage)
        self.recordedAt = recordedAt
    }

    static func normalizedRequiredText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@Model
final class WorkflowFileActionRecord {
    var id: UUID
    var runID: UUID
    var stepRunID: UUID?
    var fileIdentity: String
    var sourcePath: String?
    var destinationPath: String?
    private var dispositionRaw: String
    private var compensationStatusRaw: String
    private var compensationPayloadData: Data
    var failureReason: String?
    var recordedAt: Date

    var disposition: WorkflowFileDisposition {
        get { WorkflowFileDisposition(rawValue: dispositionRaw) ?? .pending }
        set { dispositionRaw = newValue.rawValue }
    }

    var compensationStatus: WorkflowCompensationStatus {
        get { WorkflowCompensationStatus(rawValue: compensationStatusRaw) ?? .notNeeded }
        set { compensationStatusRaw = newValue.rawValue }
    }

    var compensationPayload: [String: String]? {
        get {
            guard !compensationPayloadData.isEmpty else { return nil }
            return Self.decode([String: String].self, from: compensationPayloadData)
        }
        set {
            compensationPayloadData = Self.encode(newValue) ?? Data()
        }
    }

    init(
        id: UUID = UUID(),
        runID: UUID,
        stepRunID: UUID? = nil,
        fileIdentity: String,
        sourcePath: String? = nil,
        destinationPath: String? = nil,
        disposition: WorkflowFileDisposition,
        compensationStatus: WorkflowCompensationStatus = .notNeeded,
        compensationPayload: [String: String]? = nil,
        failureReason: String? = nil,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.runID = runID
        self.stepRunID = stepRunID
        self.fileIdentity = Self.normalizedRequiredText(fileIdentity)
        self.sourcePath = Self.normalizedPath(sourcePath)
        self.destinationPath = Self.normalizedPath(destinationPath)
        self.dispositionRaw = disposition.rawValue
        self.compensationStatusRaw = compensationStatus.rawValue
        self.compensationPayloadData = Self.encode(compensationPayload) ?? Data()
        self.failureReason = WorkflowRunRecord.normalizedOptionalText(failureReason)
        self.recordedAt = recordedAt
    }

    static func normalizedRequiredText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedPath(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed).standardizedFileURL.path
    }

    private static func encode<Value: Encodable>(_ value: Value?) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) -> Value? {
        try? JSONDecoder().decode(type, from: data)
    }
}
