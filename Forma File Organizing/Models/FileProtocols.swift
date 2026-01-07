import Foundation

/// Protocol defining the interface for file items that can be evaluated by the rule engine.
///
/// Both production `FileItem` (SwiftData model) and test doubles can conform to this protocol,
/// enabling testability without SwiftData/MainActor complications.
protocol Fileable {
    /// The file name (including extension)
    /// Note: FileItem derives this from path and it is immutable
    var name: String { get }

    /// The file extension (e.g., "pdf", "png")
    /// Note: FileItem derives this from path and it is immutable
    var fileExtension: String { get }

    /// The full file path
    /// Note: FileItem makes this immutable after initialization
    var path: String { get }

    /// The unified destination for this file.
    ///
    /// This replaces the previous dual-field system:
    /// - `suggestedDestination: String?` (display only)
    /// - `destinationBookmarkData: Data?` (file access)
    ///
    /// The `Destination` type encapsulates both, with the security-scoped bookmark
    /// being the source of truth for file access.
    var destination: Destination? { get set }

    /// The organization status of the file
    var status: FileItem.OrganizationStatus { get set }

    /// Human-readable explanation of why this file matched a rule
    var matchReason: String? { get set }

    /// Confidence score (0.0-1.0) indicating how certain the rule match is
    var confidenceScore: Double? { get set }

    /// The UUID of the rule that matched this file (for analytics tracking)
    var matchedRuleID: UUID? { get set }

    /// The creation date of the file
    var creationDate: Date { get }

    /// The last modification date of the file
    var modificationDate: Date { get }

    /// The last access date of the file
    var lastAccessedDate: Date { get }

    /// The size of the file in bytes
    var sizeInBytes: Int64 { get }

    /// The source location of the file (Desktop, Downloads, Documents, etc.)
    /// Used for location-based rule conditions like "move files FROM Desktop"
    var location: FileLocationKind { get }
}

// MARK: - Convenience Extensions

extension Fileable {
    /// The display name for the destination (for UI display).
    /// Returns nil if no destination is set.
    var destinationDisplayName: String? {
        destination?.displayName
    }

    /// Whether this file has a destination assigned.
    var hasDestination: Bool {
        destination != nil
    }

    /// Whether this file is destined for the Trash.
    var isDestinedForTrash: Bool {
        destination?.isTrash ?? false
    }
}
