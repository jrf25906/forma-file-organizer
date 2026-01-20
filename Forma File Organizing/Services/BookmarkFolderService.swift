import Foundation
import Combine

/// Service that manages bookmark folders as the single source of truth.
///
/// This service replaces the SwiftData-based `CustomFolder` system with
/// direct Keychain reads. It provides:
/// - Observable list of available folders (for SwiftUI binding)
/// - Folder access validation
/// - Enable/disable toggling (stored in UserDefaults)
///
/// ## Architecture
///
/// ```
/// ┌─────────────────────────────────────────────────────┐
/// │                  BookmarkFolderService              │
/// │  (Observable - publishes folder availability)       │
/// └─────────────────────────────────────────────────────┘
///                          │
///                          ▼
/// ┌─────────────────────────────────────────────────────┐
/// │               SecureBookmarkStore                   │
/// │  (Keychain - source of truth for folder access)    │
/// └─────────────────────────────────────────────────────┘
/// ```
///
/// ## Usage
///
/// ```swift
/// // In a SwiftUI view
/// @StateObject var folderService = BookmarkFolderService.shared
///
/// ForEach(folderService.availableFolders) { folder in
///     Text(folder.displayName)
/// }
///
/// // Refresh after permission changes
/// folderService.refresh()
/// ```
@MainActor
final class BookmarkFolderService: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide folder state
    static let shared = BookmarkFolderService()

    // MARK: - Published Properties

    /// All folders that have valid Keychain bookmarks, sorted by priority.
    /// This is the primary data source for the sidebar.
    @Published private(set) var availableFolders: [BookmarkFolder] = []

    /// All folders regardless of bookmark status (for settings/onboarding)
    @Published private(set) var allFolderTypes: [BookmarkFolder.FolderType] = BookmarkFolder.FolderType.allCases

    // MARK: - Initialization

    init() {
        refresh()
    }

    // MARK: - Public Interface

    /// Refreshes the available folders list by checking Keychain for valid bookmarks.
    /// Call this after:
    /// - User grants/revokes folder permission
    /// - App returns from background
    /// - User changes folder enabled state
    func refresh() {
        var folders: [BookmarkFolder] = []

        #if DEBUG
        let allKeychainKeys = SecureBookmarkStore.listAllBookmarkKeys()
        Log.debug("BookmarkFolderService: Keychain contains \(allKeychainKeys.count) bookmark(s)", category: .bookmark, verboseOnly: true)
        #endif

        for folderType in BookmarkFolder.FolderType.allCases {
            let folder = BookmarkFolder(folderType: folderType)
            let hasBookmark = folder.hasValidBookmark

            // Only include folders with valid Keychain bookmarks
            if hasBookmark {
                folders.append(folder)
            }
        }

        // Sort by priority (Desktop first, then Downloads, etc.)
        availableFolders = folders.sorted { $0.sortPriority < $1.sortPriority }

        Log.info("BookmarkFolderService: Refreshed - \(availableFolders.count) folders available", category: .bookmark)
    }

    /// Returns the BookmarkFolder for a specific type, if it has a valid bookmark.
    func folder(for type: BookmarkFolder.FolderType) -> BookmarkFolder? {
        let folder = BookmarkFolder(folderType: type)
        return folder.hasValidBookmark ? folder : nil
    }

    /// Returns enabled folders for scanning (has bookmark AND isEnabled)
    var enabledFolders: [BookmarkFolder] {
        availableFolders.filter { $0.isEnabled }
    }

    /// Returns the FolderLocation array for enabled folders (for FileScanPipeline)
    var enabledFolderLocations: [FolderLocation] {
        enabledFolders.map { $0.folderType.folderLocation }
    }

    /// Checks if a specific folder type has access (valid Keychain bookmark)
    func hasAccess(to folderType: BookmarkFolder.FolderType) -> Bool {
        BookmarkFolder(folderType: folderType).hasValidBookmark
    }

    /// Toggle enabled state for a folder and persist to UserDefaults
    func setEnabled(_ enabled: Bool, for folder: BookmarkFolder) {
        var mutableFolder = folder
        mutableFolder.isEnabled = enabled
        refresh() // Re-publish to update UI
        Log.info("BookmarkFolderService: \(folder.displayName) enabled = \(enabled)", category: .bookmark)
    }

    // MARK: - Bookmark Management

    /// Saves a new bookmark for a folder type.
    /// Called after user grants permission via folder picker.
    func saveBookmark(_ data: Data, for folderType: BookmarkFolder.FolderType) {
        do {
            try SecureBookmarkStore.saveBookmark(data, forKey: folderType.bookmarkKey)
            refresh()
            Log.info("BookmarkFolderService: Saved bookmark for \(folderType.displayName)", category: .bookmark)
        } catch {
            Log.error("BookmarkFolderService: Failed to save bookmark for \(folderType.displayName): \(error)", category: .bookmark)
        }
    }

    /// Removes the bookmark for a folder type.
    /// Called when user explicitly removes a folder.
    func removeBookmark(for folderType: BookmarkFolder.FolderType) {
        do {
            try SecureBookmarkStore.deleteBookmark(forKey: folderType.bookmarkKey)
            refresh()
            Log.info("BookmarkFolderService: Removed bookmark for \(folderType.displayName)", category: .bookmark)
        } catch {
            Log.error("BookmarkFolderService: Failed to remove bookmark for \(folderType.displayName): \(error)", category: .bookmark)
        }
    }

    // MARK: - Diagnostics

    /// Returns diagnostic info about folder state (for debugging)
    func diagnosticInfo() -> String {
        var lines: [String] = ["BookmarkFolderService Diagnostics:"]

        for folderType in BookmarkFolder.FolderType.allCases {
            let folder = BookmarkFolder(folderType: folderType)
            let hasBookmark = folder.hasValidBookmark
            let isEnabled = folder.isEnabled
            let path = folder.path ?? "N/A"

            lines.append("  \(folderType.displayName):")
            lines.append("    - Bookmark: \(hasBookmark ? "✓" : "✗")")
            lines.append("    - Enabled: \(isEnabled ? "✓" : "✗")")
            lines.append("    - Path: \(path)")
        }

        return lines.joined(separator: "\n")
    }
}
