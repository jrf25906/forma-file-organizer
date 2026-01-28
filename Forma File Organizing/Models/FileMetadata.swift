import Foundation

/// A value type representing file metadata, safe to pass between actors.
/// This serves as a Data Transfer Object (DTO) for file system operations.
struct FileMetadata: Fileable, Sendable, Identifiable {
    let id: UUID
    let path: String
    let fileExtension: String
    let sizeInBytes: Int64
    let creationDate: Date
    let modificationDate: Date
    let lastAccessedDate: Date
    /// High-level origin of the file (Desktop, Downloads, etc.)
    let location: FileLocationKind
    /// The unified destination for this file
    var destination: Destination?
    var status: FileItem.OrganizationStatus
    var matchReason: String?
    var confidenceScore: Double?
    var suggestionSourceRaw: String?
    /// The UUID of the rule that matched this file (for analytics tracking)
    var matchedRuleID: UUID?

    /// The file name (including extension), derived from path
    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    /// Human-readable file size, computed from sizeInBytes
    var size: String {
        // Special-case empty files for deterministic formatting in tests and UI
        if sizeInBytes == 0 {
            return "0 bytes"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeInBytes)
    }

    /// Preferred initializer that derives name and extension from path
    init(
        id: UUID = UUID(),
        path: String,
        sizeInBytes: Int64,
        creationDate: Date,
        modificationDate: Date = Date(),
        lastAccessedDate: Date = Date(),
        location: FileLocationKind = .unknown,
        destination: Destination? = nil,
        status: FileItem.OrganizationStatus = .pending,
        matchReason: String? = nil,
        confidenceScore: Double? = nil,
        suggestionSourceRaw: String? = nil,
        matchedRuleID: UUID? = nil
    ) {
        // Validate inputs - use guards instead of preconditions to avoid production crashes
        let validatedPath: String
        let validatedSize: Int64

        // Empty path indicates corrupted data; use sentinel to allow struct creation
        if path.isEmpty {
            Log.error("FileMetadata (preferred init): path cannot be empty - using sentinel path", category: .analytics)
            validatedPath = "<invalid-path-\(UUID().uuidString)>"
        } else {
            validatedPath = path
        }

        // Clamp negative sizes to 0 rather than crashing
        if sizeInBytes < 0 {
            Log.error("FileMetadata (preferred init): sizeInBytes must be >= 0, got \(sizeInBytes) - clamping to 0", category: .analytics)
            validatedSize = 0
        } else {
            validatedSize = sizeInBytes
        }

        self.id = id
        self.path = validatedPath
        self.fileExtension = URL(fileURLWithPath: validatedPath).pathExtension
        self.sizeInBytes = validatedSize
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.lastAccessedDate = lastAccessedDate
        self.location = location
        self.destination = destination
        self.status = status
        self.matchReason = matchReason
        self.suggestionSourceRaw = suggestionSourceRaw
        self.matchedRuleID = matchedRuleID

        // Validate and clamp confidenceScore
        if let score = confidenceScore {
            if score < 0.0 || score > 1.0 {
                Log.warning("FileMetadata: confidenceScore \(score) out of bounds [0.0-1.0], clamping", category: .analytics)
                self.confidenceScore = max(0.0, min(1.0, score))
            } else {
                self.confidenceScore = score
            }
        } else {
            self.confidenceScore = nil
        }
    }
}
