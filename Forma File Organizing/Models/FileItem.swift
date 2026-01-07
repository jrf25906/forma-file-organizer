import Foundation
import SwiftData
import SwiftUI

@Model
final class FileItem: Fileable {
    // MARK: - Stored Properties

    /// The unique file path - immutable after initialization
    /// This is the source of truth for file identity
    @Attribute(.unique) private(set) var path: String

    /// Backing storage for high-level origin of the file (Desktop, Downloads, etc.).
    /// Stored as a raw string for migration-friendly persistence.
    /// Use the `location` computed property for type-safe access.
    private var locationRaw: String?

    /// The file name including extension
    /// Stored for SwiftData predicate queries, but derived from path at initialization
    /// WARNING: Do not modify directly - use updatePath() method
    private(set) var name: String

    /// The file extension without the dot (e.g., "pdf", "png")
    /// Stored for SwiftData predicate queries, but derived from path at initialization
    /// WARNING: Do not modify directly - use updatePath() method
    private(set) var fileExtension: String

    /// The file size in bytes - this is the source of truth for size
    /// Must be >= 0
    /// Note: While immutable in practice, SwiftData requires 'var' for change tracking
    private(set) var sizeInBytes: Int64

    /// Note: While immutable in practice, SwiftData requires 'var' for change tracking
    private(set) var creationDate: Date
    private(set) var modificationDate: Date
    private(set) var lastAccessedDate: Date

    // MARK: - Destination Storage (SwiftData-compatible primitives)

    /// Whether the destination is Trash. SwiftData cannot persist enums with associated values,
    /// so we decompose `Destination` into these three primitives.
    private var _destinationIsTrash: Bool = false

    /// Security-scoped bookmark data for folder destinations.
    private var _destinationBookmarkData: Data?

    /// Display name for folder destinations (e.g., "Documents/Finance").
    private var _destinationDisplayName: String?

    /// The unified destination for this file.
    ///
    /// This computed property reconstructs the `Destination` enum from the underlying
    /// SwiftData-compatible storage fields. SwiftData cannot persist enums with associated
    /// values directly, so we store the components separately.
    ///
    /// The `Destination` type encapsulates:
    /// - `.trash` for files destined for the Trash
    /// - `.folder(bookmark:displayName:)` for files destined for a specific folder
    var destination: Destination? {
        get {
            if _destinationIsTrash {
                return .trash
            }
            guard let bookmark = _destinationBookmarkData,
                  let displayName = _destinationDisplayName else {
                return nil
            }
            return .folder(bookmark: bookmark, displayName: displayName)
        }
        set {
            switch newValue {
            case .trash:
                _destinationIsTrash = true
                _destinationBookmarkData = nil
                _destinationDisplayName = nil
            case .folder(let bookmark, let displayName):
                _destinationIsTrash = false
                _destinationBookmarkData = bookmark
                _destinationDisplayName = displayName
            case nil:
                _destinationIsTrash = false
                _destinationBookmarkData = nil
                _destinationDisplayName = nil
            }
        }
    }

    /// Raw storage for organization status.
    /// SwiftData cannot reliably persist nested enums directly, so we store as String.
    /// Use the `status` computed property for type-safe access.
    /// Note: `private(set)` allows predicates to read this property while preventing external writes.
    private(set) var statusRaw: String

    /// Type-safe accessor for organization status
    var status: OrganizationStatus {
        get {
            OrganizationStatus(rawValue: statusRaw) ?? .pending
        }
        set {
            statusRaw = newValue.rawValue
        }
    }

    /// Human-readable explanation of why this file matched a rule
    var matchReason: String?
    
    /// Confidence score (0.0-1.0) indicating how certain the rule match is
    /// - 0.9+ (High): Multiple conditions matched, strong pattern
    /// - 0.6-0.89 (Medium): Single strong condition
    /// - <0.6 (Low): Generic match, weak pattern
        var confidenceScore: Double? {
        didSet {
            if let score = confidenceScore, (score < 0.0 || score > 1.0) {
                Log.warning("FileItem: confidenceScore \(score) out of bounds [0.0-1.0], clamping", category: .analytics)
                confidenceScore = max(0.0, min(1.0, score))
            }
        }
    }
    
    /// The destination that was rejected by the user (for learning purposes)
    /// When user skips or rejects a suggestion, we store it here to learn from the rejection
    var rejectedDestination: String?
    
    /// Number of times suggestions for this file have been rejected
    /// Used by the learning system to avoid bad patterns
    var rejectionCount: Int

    /// The error message from the last failed organization attempt.
    /// Populated when organization fails so users can understand why.
    /// Cleared when organization succeeds or file is reset.
    var lastOrganizeError: String?

    /// Raw storage for suggestion source (Phase 3)
    /// "rule", "pattern", or "mlPrediction"
    var suggestionSourceRaw: String?

    /// The UUID of the rule that matched this file (for analytics tracking v1.2.0)
    var matchedRuleID: UUID?

    // MARK: - Computed Properties
    
    /// Type-safe accessor for suggestion source
    var suggestionSource: SuggestionSource {
        get {
            guard let raw = suggestionSourceRaw,
                  let source = SuggestionSource(rawValue: raw) else {
                return .rule // Default for legacy data
            }
            return source
        }
        set {
            suggestionSourceRaw = newValue.rawValue
        }
    }

    /// Type-safe view over the raw location string.
    /// Falls back to `.unknown` for missing or unrecognized values to avoid crashes
    /// when loading legacy data.
    var location: FileLocationKind {
        get {
            if let raw = locationRaw, let kind = FileLocationKind(rawValue: raw) {
                return kind
            }
            return .unknown
        }
        set {
            locationRaw = newValue.rawValue
        }
    }

    // MARK: - Destination Convenience Properties

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

    /// Human-readable file size, computed from sizeInBytes
    /// This ensures size and sizeInBytes are always consistent
    var size: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }

    // MARK: - Initialization

    /// Creates a new FileItem from a file path
    /// This is the preferred way to create FileItem instances
    ///
    /// - Parameters:
    ///   - path: The full file path (must be non-empty)
    ///   - sizeInBytes: The file size in bytes (must be >= 0)
    ///   - creationDate: When the file was created
    ///   - modificationDate: When the file was last modified
    ///   - lastAccessedDate: When the file was last accessed
    ///   - location: The source location kind (Desktop, Downloads, etc.)
    ///   - destination: Optional unified destination for organization
    ///   - status: Current organization status
    ///
    /// - Note: name and fileExtension are derived from the path
    init(
        path: String,
        sizeInBytes: Int64,
        creationDate: Date,
        modificationDate: Date = Date(),
        lastAccessedDate: Date = Date(),
        location: FileLocationKind = .unknown,
        destination: Destination? = nil,
        status: OrganizationStatus = .pending
    ) {
        // Validate inputs - use guards instead of preconditions to avoid production crashes
        // Compute validated values first (can't access self until all properties are set)
        let validatedPath: String
        let validatedSize: Int64

        // Empty path indicates corrupted data; use sentinel to allow model instantiation
        if path.isEmpty {
            Log.error("FileItem: path cannot be empty - using sentinel path", category: .analytics)
            validatedPath = "<invalid-path-\(UUID().uuidString)>"
        } else {
            validatedPath = path
        }

        // Clamp negative sizes to 0 rather than crashing
        if sizeInBytes < 0 {
            Log.error("FileItem: sizeInBytes must be >= 0, got \(sizeInBytes) - clamping to 0", category: .analytics)
            validatedSize = 0
        } else {
            validatedSize = sizeInBytes
        }

        // Derive name and extension from validated path
        let url = URL(fileURLWithPath: validatedPath)

        // Initialize all stored properties
        self.path = validatedPath
        self.locationRaw = location.rawValue
        self.name = url.lastPathComponent
        self.fileExtension = url.pathExtension
        self.sizeInBytes = validatedSize
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.lastAccessedDate = lastAccessedDate
        self.statusRaw = status.rawValue
        self.rejectionCount = 0

        // Initialize destination storage (decomposed for SwiftData compatibility)
        switch destination {
        case .trash:
            self._destinationIsTrash = true
            self._destinationBookmarkData = nil
            self._destinationDisplayName = nil
        case .folder(let bookmark, let displayName):
            self._destinationIsTrash = false
            self._destinationBookmarkData = bookmark
            self._destinationDisplayName = displayName
        case nil:
            self._destinationIsTrash = false
            self._destinationBookmarkData = nil
            self._destinationDisplayName = nil
        }

        // Validate derived values (now safe to access self)
        self.validateConsistency()
    }

    /// Legacy initializer for backwards compatibility
    /// - Warning: This initializer is deprecated. Use init(path:sizeInBytes:...) instead
    ///
    /// This exists to support existing code, but validates that name/extension match the path
    @available(*, deprecated, message: "Use init(path:sizeInBytes:...) instead")
    init(
        name: String,
        fileExtension: String,
        size: String,
        sizeInBytes: Int64,
        creationDate: Date,
        modificationDate: Date = Date(),
        lastAccessedDate: Date = Date(),
        path: String,
        location: FileLocationKind = .unknown,
        destination: Destination? = nil,
        status: OrganizationStatus = .pending
    ) {
        // Validate inputs - use guards instead of preconditions to avoid production crashes
        // Compute validated values first (can't access self until all properties are set)
        let validatedPath: String
        let validatedSize: Int64

        // Empty path indicates corrupted data; use sentinel to allow model instantiation
        if path.isEmpty {
            Log.error("FileItem (legacy init): path cannot be empty - using sentinel path", category: .analytics)
            validatedPath = "<invalid-path-\(UUID().uuidString)>"
        } else {
            validatedPath = path
        }

        // Clamp negative sizes to 0 rather than crashing
        if sizeInBytes < 0 {
            Log.error("FileItem (legacy init): sizeInBytes must be >= 0, got \(sizeInBytes) - clamping to 0", category: .analytics)
            validatedSize = 0
        } else {
            validatedSize = sizeInBytes
        }

        // Derive correct values from the validated path
        let url = URL(fileURLWithPath: validatedPath)
        let derivedName = url.lastPathComponent
        let derivedExtension = url.pathExtension

        #if DEBUG
        // Validate consistency in debug builds
        if derivedName != name {
            Log.warning("FileItem: name mismatch - using '\(derivedName)' from path instead of provided '\(name)'", category: .analytics)
        }
        if derivedExtension != fileExtension {
            Log.warning("FileItem: extension mismatch - using '\(derivedExtension)' from path instead of provided '\(fileExtension)'", category: .analytics)
        }
        // Note: We ignore the 'size' parameter as it's now computed from sizeInBytes
        #endif

        // Initialize all stored properties
        self.path = validatedPath
        self.locationRaw = location.rawValue
        self.name = derivedName
        self.fileExtension = derivedExtension
        self.sizeInBytes = validatedSize
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.lastAccessedDate = lastAccessedDate
        self.statusRaw = status.rawValue
        self.rejectionCount = 0

        // Initialize destination storage (decomposed for SwiftData compatibility)
        switch destination {
        case .trash:
            self._destinationIsTrash = true
            self._destinationBookmarkData = nil
            self._destinationDisplayName = nil
        case .folder(let bookmark, let displayName):
            self._destinationIsTrash = false
            self._destinationBookmarkData = bookmark
            self._destinationDisplayName = displayName
        case nil:
            self._destinationIsTrash = false
            self._destinationBookmarkData = nil
            self._destinationDisplayName = nil
        }

        // Validate derived values (now safe to access self)
        self.validateConsistency()
    }

    // MARK: - Validation

    /// Validates that derived properties match the source of truth (path)
    private func validateConsistency() {
        let url = URL(fileURLWithPath: path)
        assert(name == url.lastPathComponent, "FileItem: name '\(name)' doesn't match path component '\(url.lastPathComponent)'")
        assert(fileExtension == url.pathExtension, "FileItem: extension '\(fileExtension)' doesn't match path extension '\(url.pathExtension)'")
    }

    // MARK: - Controlled Mutation

    /// Updates the path and automatically re-derives name and fileExtension
    /// This is the ONLY safe way to change a FileItem's path after initialization
    ///
    /// - Warning: This should only be used when a file is moved on disk.
    ///            Changing the path breaks the unique constraint in SwiftData.
    ///
    /// - Parameter newPath: The new file path (must be non-empty)
    /// - Returns: True if update succeeded, false if validation failed
    @discardableResult
    internal func updatePath(_ newPath: String) -> Bool {
        guard !newPath.isEmpty else {
            #if DEBUG
            Log.error("FileItem.updatePath failed: newPath cannot be empty", category: .filesystem)
            #endif
            return false
        }

        // Update path
        self.path = newPath

        // Re-derive name and extension from new path
        let url = URL(fileURLWithPath: newPath)
        self.name = url.lastPathComponent
        self.fileExtension = url.pathExtension

        // Validate consistency
        validateConsistency()
        return true
    }

    /// Updates metadata that may change (for file refreshes)
    /// Path, name, and extension remain immutable
    /// - Returns: True if update succeeded, false if validation failed
    @discardableResult
    internal func updateMetadata(
        sizeInBytes: Int64,
        modificationDate: Date,
        lastAccessedDate: Date
    ) -> Bool {
        guard sizeInBytes >= 0 else {
            #if DEBUG
            Log.error("FileItem.updateMetadata failed: sizeInBytes must be >= 0, got \(sizeInBytes)", category: .filesystem)
            #endif
            return false
        }

        self.sizeInBytes = sizeInBytes
        self.modificationDate = modificationDate
        self.lastAccessedDate = lastAccessedDate
        return true
    }

    // MARK: - Status Types

    enum OrganizationStatus: String, Codable {
        case pending
        case ready
        case completed
        case skipped

        var badgeStatus: StatusBadge.Status {
            switch self {
            case .pending:
                return .neutral
            case .ready:
                return .warning
            case .completed:
                return .success
            case .skipped:
                return .neutral
            }
        }

        var badgeText: String {
            switch self {
            case .pending:
                return "Pending"
            case .ready:
                return "Ready"
            case .completed:
                return "Done"
            case .skipped:
                return "Skipped"
            }
        }
    }

    // MARK: - Computed UI Properties

    /// The SF Symbol icon name for this file type.
    /// Delegates to FileItemPresenter for the actual logic.
    var iconName: String {
        FileItemPresenter.icon(for: self)
    }

    /// The file type category.
    var category: FileTypeCategory {
        FileTypeCategory.category(for: fileExtension)
    }

    // MARK: - Age Categories

    /// Age categorization for files.
    /// Used by FileItemPresenter for color calculations.
    enum AgeCategory {
        case fresh      // < 24 hours
        case recent     // 1-7 days
        case old        // 7-30 days
        case veryOld    // > 30 days
    }
}

// MARK: - Equatable Conformance
extension FileItem: Equatable {
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        // Path is the unique identifier, but we check other properties for completeness
        lhs.path == rhs.path &&
        lhs.status == rhs.status &&
        lhs.destination == rhs.destination &&
        lhs.sizeInBytes == rhs.sizeInBytes
    }
}

// MARK: - Factory Methods
extension FileItem {
    /// Creates a FileItem from FileMetadata (preferred way to convert).
    /// This initializer assumes that metadata has already been validated.
    static func from(_ metadata: FileMetadata) -> FileItem {
        let item = FileItem(
            path: metadata.path,
            sizeInBytes: metadata.sizeInBytes,
            creationDate: metadata.creationDate,
            modificationDate: metadata.modificationDate,
            lastAccessedDate: metadata.lastAccessedDate,
            location: metadata.location,
            destination: metadata.destination,
            status: metadata.status
        )
        item.matchReason = metadata.matchReason
        item.confidenceScore = metadata.confidenceScore
        item.suggestionSourceRaw = metadata.suggestionSourceRaw
        item.matchedRuleID = metadata.matchedRuleID
        return item
    }

    /// Simple error type for FileItem creation failures
    struct CreationError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Safe factory method with detailed error reporting
    /// Use this when you need to know why creation failed
    /// - Returns: Result containing FileItem or creation error
    static func create(
        path: String,
        sizeInBytes: Int64,
        creationDate: Date,
        modificationDate: Date = Date(),
        lastAccessedDate: Date = Date(),
        destination: Destination? = nil,
        status: OrganizationStatus = .pending
    ) -> Result<FileItem, CreationError> {
        // Validate inputs with detailed messages
        guard !path.isEmpty else {
            return .failure(CreationError(message: "Cannot create FileItem: path is empty"))
        }

        guard sizeInBytes >= 0 else {
            return .failure(CreationError(message: "Cannot create FileItem: sizeInBytes must be >= 0, got \(sizeInBytes)"))
        }

        // Attempt creation (now safe due to pre-validation)
        let item = FileItem(
            path: path,
            sizeInBytes: sizeInBytes,
            creationDate: creationDate,
            modificationDate: modificationDate,
            lastAccessedDate: lastAccessedDate,
            destination: destination,
            status: status
        )

        return .success(item)
    }
}

// MARK: - Mock Data
extension FileItem {
    /// Creates a mock destination for testing purposes.
    /// In production, destinations should be created from actual folder picker URLs.
    static func mockDestination(displayName: String) -> Destination {
        // Create mock bookmark data (won't work for actual file operations, but fine for UI testing)
        let mockData = displayName.data(using: .utf8) ?? Data()
        return .folder(bookmark: mockData, displayName: displayName)
    }

    static var mocks: [FileItem] {
        [
            FileItem(
                path: "/Users/test/Desktop/Invoice_2025_01.pdf",
                sizeInBytes: 1_258_291,
                creationDate: Date(),
                destination: mockDestination(displayName: "Documents/Finance"),
                status: .ready
            ),
            FileItem(
                path: "/Users/test/Desktop/Screenshot 2025-11-18.png",
                sizeInBytes: 4_718_592,
                creationDate: Date().addingTimeInterval(-3600),
                destination: mockDestination(displayName: "Pictures/Screenshots"),
                status: .ready
            ),
            FileItem(
                path: "/Users/test/Downloads/Project_Proposal_v2.docx",
                sizeInBytes: 250_880,
                creationDate: Date().addingTimeInterval(-86400),
                destination: mockDestination(displayName: "Documents/Work"),
                status: .pending
            ),
            FileItem(
                path: "/Users/test/Downloads/Design_Assets.zip",
                sizeInBytes: 152_043_520,
                creationDate: Date().addingTimeInterval(-12000),
                destination: nil,
                status: .pending
            ),
            FileItem(
                path: "/Users/test/Desktop/Meeting_Notes.txt",
                sizeInBytes: 2_048,
                creationDate: Date().addingTimeInterval(-4000),
                destination: mockDestination(displayName: "Documents/Notes"),
                status: .ready
            )
        ]
    }

    /// Deterministic data set for UI tests.
    static var uiTestMocks: [FileItem] {
        [
            FileItem(
                path: "/Users/test/Desktop/UITest_File_1_WithSuggestion.pdf",
                sizeInBytes: 1_000_000,
                creationDate: Date(),
                destination: mockDestination(displayName: "Documents/UITests/One"),
                status: .pending
            ),
            FileItem(
                path: "/Users/test/Desktop/UITest_File_2_NoSuggestion.txt",
                sizeInBytes: 2_048,
                creationDate: Date().addingTimeInterval(-60),
                destination: nil,
                status: .pending
            ),
            FileItem(
                path: "/Users/test/Desktop/UITest_File_3_WithSuggestion.mov",
                sizeInBytes: 15 * 1024 * 1024,
                creationDate: Date().addingTimeInterval(-120),
                destination: mockDestination(displayName: "Movies/UITests"),
                status: .pending
            )
        ]
    }
}
