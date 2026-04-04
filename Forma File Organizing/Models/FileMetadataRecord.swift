import Foundation
import SwiftData

@Model
final class FileMetadataRecord {
    enum IdentityKind: String, Codable, Sendable {
        case resourceIdentifier
        case pathFallback
    }

    enum OrganizationStatus: String, Codable, Sendable {
        case unknown
        case organized
        case rekeyed
        case undone
    }

    struct Identity: Equatable, Hashable, Sendable {
        let kind: IdentityKind
        let canonicalIdentity: String
        let normalizedPath: String
        let resourceIdentifier: String?
        let volumeIdentifier: String?

        static func resourceBacked(
            resourceIdentifier: String,
            volumeIdentifier: String,
            path: String
        ) -> Identity {
            let normalizedPath = Self.normalizedPath(path)
            return Identity(
                kind: .resourceIdentifier,
                canonicalIdentity: "resource|\(volumeIdentifier)|\(resourceIdentifier)",
                normalizedPath: normalizedPath,
                resourceIdentifier: resourceIdentifier,
                volumeIdentifier: volumeIdentifier
            )
        }

        static func pathFallback(path: String) -> Identity {
            let normalizedPath = Self.normalizedPath(path)
            return Identity(
                kind: .pathFallback,
                canonicalIdentity: "path|\(normalizedPath)",
                normalizedPath: normalizedPath,
                resourceIdentifier: nil,
                volumeIdentifier: nil
            )
        }

        private static func normalizedPath(_ path: String) -> String {
            URL(fileURLWithPath: path).standardizedFileURL.path
        }
    }

    @Attribute(.unique) var canonicalIdentity: String
    private var identityKindRaw: String
    var lastKnownPath: String
    var displayName: String
    var fileExtension: String
    var firstSeenAt: Date
    var lastSeenAt: Date
    var lastOrganizedAt: Date?
    var organizationCount: Int
    private var latestOrganizationStatusRaw: String
    var tags: [String]
    var projectAssociation: String?
    var notesSummary: String?

    @Relationship(deleteRule: .cascade, inverse: \FileOrganizationHistoryEntry.metadataRecord)
    var historyEntries: [FileOrganizationHistoryEntry] = []

    var identityKind: IdentityKind {
        get { IdentityKind(rawValue: identityKindRaw) ?? .pathFallback }
        set { identityKindRaw = newValue.rawValue }
    }

    var latestOrganizationStatus: OrganizationStatus {
        get { OrganizationStatus(rawValue: latestOrganizationStatusRaw) ?? .unknown }
        set { latestOrganizationStatusRaw = newValue.rawValue }
    }

    init(
        canonicalIdentity: String,
        identityKind: IdentityKind,
        lastKnownPath: String,
        displayName: String,
        fileExtension: String,
        firstSeenAt: Date,
        lastSeenAt: Date,
        lastOrganizedAt: Date? = nil,
        organizationCount: Int = 0,
        latestOrganizationStatus: OrganizationStatus = .unknown,
        tags: [String] = [],
        projectAssociation: String? = nil,
        notesSummary: String? = nil
    ) {
        self.canonicalIdentity = canonicalIdentity
        self.identityKindRaw = identityKind.rawValue
        self.lastKnownPath = Self.normalizedPath(lastKnownPath)
        self.displayName = Self.normalizedDisplayName(displayName)
        self.fileExtension = fileExtension.lowercased()
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.lastOrganizedAt = lastOrganizedAt
        self.organizationCount = organizationCount
        self.latestOrganizationStatusRaw = latestOrganizationStatus.rawValue
        self.tags = tags.map(Self.normalizedTag).filter { !$0.isEmpty }
        self.projectAssociation = Self.normalizedOptionalText(projectAssociation)
        self.notesSummary = Self.normalizedOptionalText(notesSummary)
    }

    static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    static func normalizedDisplayName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedTag(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
