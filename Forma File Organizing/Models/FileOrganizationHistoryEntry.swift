import Foundation
import SwiftData

@Model
final class FileOrganizationHistoryEntry {
    enum EventKind: String, Codable, Sendable {
        case scanned
        case organized
        case rekeyed
        case undone
        case noted
    }

    enum SourceSurface: String, Codable, Sendable {
        case scan
        case organize
        case undo
        case inspector
    }

    var id: UUID
    var timestamp: Date
    private var eventKindRaw: String
    private var sourceSurfaceRaw: String
    var fileIdentitySnapshot: String
    var metadataRecord: FileMetadataRecord
    var fromPath: String?
    var toPath: String?
    var destinationDisplayName: String?
    var matchedRuleID: UUID?
    var detailsSummary: String?

    var eventKind: EventKind {
        get { EventKind(rawValue: eventKindRaw) ?? .noted }
        set { eventKindRaw = newValue.rawValue }
    }

    var sourceSurface: SourceSurface {
        get { SourceSurface(rawValue: sourceSurfaceRaw) ?? .inspector }
        set { sourceSurfaceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        metadataRecord: FileMetadataRecord,
        fileIdentitySnapshot: String,
        eventKind: EventKind,
        sourceSurface: SourceSurface,
        fromPath: String? = nil,
        toPath: String? = nil,
        destinationDisplayName: String? = nil,
        matchedRuleID: UUID? = nil,
        detailsSummary: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventKindRaw = eventKind.rawValue
        self.sourceSurfaceRaw = sourceSurface.rawValue
        self.fileIdentitySnapshot = fileIdentitySnapshot
        self.metadataRecord = metadataRecord
        self.fromPath = Self.normalizedPath(fromPath)
        self.toPath = Self.normalizedPath(toPath)
        self.destinationDisplayName = FileMetadataRecord.normalizedOptionalText(destinationDisplayName)
        self.matchedRuleID = matchedRuleID
        self.detailsSummary = FileMetadataRecord.normalizedOptionalText(detailsSummary)
    }

    static func normalizedPath(_ value: String?) -> String? {
        guard let value else { return nil }
        return FileMetadataRecord.normalizedPath(value)
    }
}
