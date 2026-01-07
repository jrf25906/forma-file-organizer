import Foundation

/// Unified destination representation for file organization.
///
/// This type consolidates what was previously two separate fields:
/// - `suggestedDestination: String?` (display name)
/// - `destinationBookmarkData: Data?` (security-scoped bookmark)
///
/// The bookmark is the **single source of truth** for file access.
/// Display names are derived from the bookmark, not stored separately.
///
/// ## Design Rationale
///
/// macOS sandboxing requires security-scoped bookmarks for persistent folder access.
/// Path strings alone cannot provide secure access outside the sandbox. By making
/// the bookmark the source of truth, we:
/// 1. Eliminate the "dual system" where path and bookmark could get out of sync
/// 2. Ensure file operations always have proper security-scoped access
/// 3. Simplify the codebase by having one canonical destination representation
///
/// ## Usage
///
/// ```swift
/// // Creating a destination from a folder picker
/// let destination = try Destination.folder(from: selectedURL)
///
/// // Displaying in UI
/// Text(destination.displayName)
///
/// // Performing file operations
/// if let url = destination.resolveURL() {
///     // url is ready for security-scoped access
/// }
/// ```
enum Destination: Codable, Equatable, Hashable {
    /// The file will be moved to Trash
    case trash

    /// The file will be moved to a specific folder
    /// - Parameters:
    ///   - bookmark: Security-scoped bookmark data for the folder
    ///   - displayName: Human-readable name (typically the folder name)
    case folder(bookmark: Data, displayName: String)

    // MARK: - Factory Methods

    /// Creates a folder destination from a URL by generating a security-scoped bookmark.
    ///
    /// - Parameter url: The folder URL (must be a directory)
    /// - Throws: If bookmark creation fails
    /// - Returns: A folder destination with the bookmark and display name
    static func folder(from url: URL) throws -> Destination {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let displayName = url.lastPathComponent
        return .folder(bookmark: bookmarkData, displayName: displayName)
    }

    // MARK: - Properties

    /// The display name for this destination (for UI display).
    ///
    /// For trash, returns "Trash".
    /// For folders, returns the stored display name.
    var displayName: String {
        switch self {
        case .trash:
            return "Trash"
        case .folder(_, let name):
            return name
        }
    }

    /// The bookmark data for this destination (for file operations).
    ///
    /// Returns `nil` for trash (which doesn't need a bookmark) or if the bookmark is empty.
    var bookmarkData: Data? {
        switch self {
        case .trash:
            return nil
        case .folder(let bookmark, _):
            // Return nil for empty bookmarks (placeholder destinations without real access)
            return bookmark.isEmpty ? nil : bookmark
        }
    }

    /// Whether this destination points to the Trash.
    var isTrash: Bool {
        if case .trash = self { return true }
        return false
    }

    // MARK: - Bookmark Resolution

    /// Result of resolving a bookmark to a URL.
    struct ResolvedDestination {
        /// The resolved URL (ready for security-scoped access)
        let url: URL

        /// Whether the bookmark was stale and should be refreshed
        let isStale: Bool

        /// The display name (may include warning indicator if stale)
        var displayName: String {
            isStale ? "\(url.lastPathComponent) ⚠️" : url.lastPathComponent
        }
    }

    /// Resolves the bookmark to a URL for file operations.
    ///
    /// - Returns: The resolved URL and staleness status, or `nil` if resolution fails
    /// - Note: Caller is responsible for calling `startAccessingSecurityScopedResource()`
    ///         and `stopAccessingSecurityScopedResource()` on the returned URL
    func resolve() -> ResolvedDestination? {
        guard case .folder(let bookmarkData, _) = self else {
            return nil
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return ResolvedDestination(url: url, isStale: isStale)
        } catch {
            Log.error("Failed to resolve destination bookmark: \(error)", category: .bookmark)
            return nil
        }
    }

    /// Validates that this destination is still accessible.
    ///
    /// - Returns: Validation result with details
    func validate() -> ValidationResult {
        switch self {
        case .trash:
            return .valid

        case .folder(let bookmarkData, let displayName):
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                // Check if folder still exists
                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

                if !exists {
                    return .invalid(reason: "Folder '\(displayName)' no longer exists")
                }

                if !isDirectory.boolValue {
                    return .invalid(reason: "'\(displayName)' is not a folder")
                }

                if isStale {
                    return .stale(url: url)
                }

                return .valid

            } catch {
                return .invalid(reason: "Cannot access '\(displayName)': \(error.localizedDescription)")
            }
        }
    }

    /// Result of destination validation.
    enum ValidationResult: Equatable {
        /// Destination is valid and accessible
        case valid

        /// Bookmark is stale but still usable - should be refreshed
        case stale(url: URL)

        /// Destination is invalid and cannot be used
        case invalid(reason: String)

        /// Whether the destination is usable (valid or stale)
        var isUsable: Bool {
            switch self {
            case .valid, .stale:
                return true
            case .invalid:
                return false
            }
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case bookmark
        case displayName
    }

    private enum DestinationType: String, Codable {
        case trash
        case folder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(DestinationType.self, forKey: .type)

        switch type {
        case .trash:
            self = .trash

        case .folder:
            let bookmark = try container.decode(Data.self, forKey: .bookmark)
            let displayName = try container.decode(String.self, forKey: .displayName)
            self = .folder(bookmark: bookmark, displayName: displayName)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .trash:
            try container.encode(DestinationType.trash, forKey: .type)

        case .folder(let bookmark, let displayName):
            try container.encode(DestinationType.folder, forKey: .type)
            try container.encode(bookmark, forKey: .bookmark)
            try container.encode(displayName, forKey: .displayName)
        }
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        switch self {
        case .trash:
            hasher.combine("trash")
        case .folder(let bookmark, let displayName):
            hasher.combine("folder")
            hasher.combine(bookmark)
            hasher.combine(displayName)
        }
    }
}

// MARK: - CustomStringConvertible

extension Destination: CustomStringConvertible {
    var description: String {
        displayName
    }
}

