import Foundation

/// Represents a folder that can be scanned for file organization.
///
/// This struct replaces the SwiftData `CustomFolder` model with a simpler
/// architecture where Keychain is the single source of truth for folder access.
///
/// ## Architecture
///
/// Previously, folder state was split between:
/// - **Keychain**: Security-scoped bookmark data (required for sandbox access)
/// - **SwiftData**: CustomFolder model with duplicate bookmark + metadata
///
/// This dual-storage caused sync issues: deleting SwiftData would leave
/// orphaned Keychain bookmarks, and the sidebar wouldn't show folders
/// that had valid Keychain access.
///
/// Now, `BookmarkFolder` reads directly from Keychain:
/// - **Keychain** (`SecureBookmarkStore`): Bookmark data (source of truth)
/// - **UserDefaults**: Only the `isEnabled` toggle state
///
/// ## Usage
///
/// ```swift
/// // Get all folders with valid Keychain bookmarks
/// let service = BookmarkFolderService.shared
/// let folders = service.availableFolders
///
/// // Check if a specific folder has access
/// if let desktop = service.folder(for: .desktop) {
///     print("Desktop accessible: \(desktop.displayName)")
/// }
/// ```
struct BookmarkFolder: Identifiable, Equatable, Hashable {

    // MARK: - Folder Types

    /// Standard macOS folder types with known bookmark keys
    enum FolderType: String, CaseIterable, Codable {
        case desktop
        case downloads
        case documents
        case pictures
        case music

        /// The Keychain key used to store this folder's bookmark
        var bookmarkKey: String {
            switch self {
            case .desktop: return FormaConfig.Security.desktopBookmarkKey
            case .downloads: return FormaConfig.Security.downloadsBookmarkKey
            case .documents: return FormaConfig.Security.documentsBookmarkKey
            case .pictures: return FormaConfig.Security.picturesBookmarkKey
            case .music: return FormaConfig.Security.musicBookmarkKey
            }
        }

        /// Human-readable display name
        var displayName: String {
            switch self {
            case .desktop: return "Desktop"
            case .downloads: return "Downloads"
            case .documents: return "Documents"
            case .pictures: return "Pictures"
            case .music: return "Music"
            }
        }

        /// SF Symbol icon name
        var iconName: String {
            switch self {
            case .desktop: return "desktopcomputer"
            case .downloads: return "arrow.down.circle"
            case .documents: return "doc.fill"
            case .pictures: return "photo.fill"
            case .music: return "music.note"
            }
        }

        /// Sort priority (lower = appears first in sidebar)
        var sortPriority: Int {
            switch self {
            case .desktop: return 1
            case .downloads: return 2
            case .documents: return 3
            case .pictures: return 4
            case .music: return 5
            }
        }

        /// Maps to FolderLocation for scanning
        var folderLocation: FolderLocation {
            switch self {
            case .desktop: return .desktop
            case .downloads: return .downloads
            case .documents: return .documents
            case .pictures: return .pictures
            case .music: return .music
            }
        }
    }

    // MARK: - Properties

    /// Unique identifier (derived from bookmark key for stability)
    let id: String

    /// The folder type (determines bookmark key, display name, icon)
    let folderType: FolderType

    /// The Keychain key where the bookmark is stored
    var bookmarkKey: String { folderType.bookmarkKey }

    /// Human-readable display name
    var displayName: String { folderType.displayName }

    /// SF Symbol icon name
    var iconName: String { folderType.iconName }

    /// Sort priority for sidebar ordering
    var sortPriority: Int { folderType.sortPriority }

    /// Whether this folder is enabled for scanning.
    /// Stored in UserDefaults (not Keychain) since it's user preference, not security data.
    var isEnabled: Bool {
        get {
            // Default to true if not explicitly disabled
            let key = "BookmarkFolder.isEnabled.\(bookmarkKey)"
            if UserDefaults.standard.object(forKey: key) == nil {
                return true // Default enabled
            }
            return UserDefaults.standard.bool(forKey: key)
        }
        set {
            let key = "BookmarkFolder.isEnabled.\(bookmarkKey)"
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    // MARK: - Initialization

    /// Creates a BookmarkFolder for a standard folder type.
    init(folderType: FolderType) {
        self.id = folderType.bookmarkKey
        self.folderType = folderType
    }

    // MARK: - Bookmark Access

    /// Loads the security-scoped bookmark data from Keychain.
    /// Returns nil if no bookmark exists for this folder.
    var bookmarkData: Data? {
        SecureBookmarkStore.loadBookmark(forKey: bookmarkKey)
    }

    /// Whether this folder has a valid bookmark in Keychain.
    var hasValidBookmark: Bool {
        bookmarkData != nil
    }

    /// Resolves the bookmark to a URL for file access.
    /// - Returns: Tuple of (URL, isStale) or nil if resolution fails
    func resolveURL() -> (url: URL, isStale: Bool)? {
        guard let data = bookmarkData else { return nil }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (url, isStale)
        } catch {
            Log.error("BookmarkFolder: Failed to resolve \(displayName) bookmark: \(error)", category: .bookmark)
            return nil
        }
    }

    /// The resolved file path, or nil if bookmark cannot be resolved.
    var path: String? {
        resolveURL()?.url.path
    }

    // MARK: - Equatable & Hashable

    static func == (lhs: BookmarkFolder, rhs: BookmarkFolder) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - CustomStringConvertible

extension BookmarkFolder: CustomStringConvertible {
    var description: String {
        "\(displayName) (\(hasValidBookmark ? "accessible" : "no bookmark"))"
    }
}
