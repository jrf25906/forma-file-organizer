import Foundation
import AppKit
import Darwin

// MARK: - Real Home Directory Helper

/// Returns the actual user home directory, bypassing sandbox container path.
/// In sandboxed apps, `FileManager.default.homeDirectoryForCurrentUser` returns
/// the sandbox container (e.g., ~/Library/Containers/app.bundle.id/Data).
/// This function uses POSIX getpwuid() to get the real home directory.
private func realHomeDirectory() -> URL {
    if let pw = getpwuid(getuid()) {
        let homeDir = String(cString: pw.pointee.pw_dir)
        return URL(fileURLWithPath: homeDir)
    }
    // Fallback to standard method (shouldn't happen on macOS)
    return FileManager.default.homeDirectoryForCurrentUser
}

/// Result of scanning multiple folders, includes both successful files and errors
struct ScanResult {
    var files: [FileMetadata]
    var errors: [String: Error]  // folder name -> error

    /// Indicates whether the scan was completely successful
    var hasErrors: Bool {
        !errors.isEmpty
    }

    /// Returns a user-friendly error summary
    var errorSummary: String? {
        guard !errors.isEmpty else { return nil }

        let folderNames = errors.keys.sorted().joined(separator: ", ")
        let count = errors.count
        return count == 1
            ? "Failed to scan \(folderNames)"
            : "Failed to scan \(count) folders: \(folderNames)"
    }
}

/// Protocol defining file system operations for mocking
/// Note: Some methods are MainActor-isolated because they work with SwiftUI-bound state
protocol FileSystemServiceProtocol {
    func scanDesktop() async throws -> [FileMetadata]
    func scanDownloads() async throws -> [FileMetadata]
    func scanDocuments() async throws -> [FileMetadata]
    func scanPictures() async throws -> [FileMetadata]
    func scanMusic() async throws -> [FileMetadata]
    @MainActor func scanAllFolders() async -> ScanResult
    func scan(baseFolders: [FolderLocation]) async -> ScanResult

    func hasDesktopAccess() -> Bool
    func hasDownloadsAccess() -> Bool
    func hasDocumentsAccess() -> Bool
    func hasPicturesAccess() -> Bool
    func hasMusicAccess() -> Bool

    func requestDesktopAccess() async throws -> Bool
    func requestDownloadsAccess() async throws -> Bool
    func requestDocumentsAccess() async throws -> Bool
    func requestPicturesAccess() async throws -> Bool
    func requestMusicAccess() async throws -> Bool
    
    func getMigrationState() -> BookmarkMigrationState?
    /// Resets the saved Desktop folder bookmark (used for troubleshooting)
    func resetDesktopAccess()
}

/// Service responsible for scanning directories and reading file metadata
class FileSystemService: FileSystemServiceProtocol {

    // MARK: - Error Type Aliases (for migration compatibility)

    /// Legacy error type - use FormaError directly in new code
    @available(*, deprecated, message: "Use FormaError directly")
    typealias FileSystemError = FormaError

    private let desktopBookmarkKey = "DesktopFolderBookmark"
    private let downloadsBookmarkKey = "DownloadsFolderBookmark"
    private let documentsBookmarkKey = "DocumentsFolderBookmark"
    private let picturesBookmarkKey = "PicturesFolderBookmark"
    private let musicBookmarkKey = "MusicFolderBookmark"
    
    /// The result of bookmark migration (nil if not yet attempted)
    private(set) var migrationState: BookmarkMigrationState?

    // MARK: - Initialization

    /// Initialize FileSystemService and perform one-time migration of bookmarks from UserDefaults to Keychain
    init() {
        migrationState = migrateBookmarksToKeychain()
    }
    
    /// Returns the current migration state (loads from disk if not in memory)
    func getMigrationState() -> BookmarkMigrationState? {
        return migrationState ?? BookmarkMigrationState.load()
    }

    /// Migrates existing bookmarks from UserDefaults to Keychain (runs once on first launch)
    /// - Returns: The migration state indicating success/failure
    private func migrateBookmarksToKeychain() -> BookmarkMigrationState {
        // Check if migration already completed
        if let existingState = BookmarkMigrationState.load() {
            #if DEBUG
            Log.debug("Bookmark migration already completed: \(existingState.debugDescription)", category: .bookmark)
            #endif
            return existingState
        }
        
        let allBookmarkKeys = [
            desktopBookmarkKey,
            downloadsBookmarkKey,
            documentsBookmarkKey,
            picturesBookmarkKey,
            musicBookmarkKey
        ]
        
        #if DEBUG
        Log.info("Starting bookmark migration to Keychain…", category: .bookmark)
        #endif

        do {
            try SecureBookmarkStore.migrateFromUserDefaults(keys: allBookmarkKeys)
            
            // Migration succeeded
            let state = BookmarkMigrationState.success(migratedKeys: allBookmarkKeys)
            state.save()
            
            #if DEBUG
            Log.info("Bookmark migration succeeded: \(state.debugDescription)", category: .bookmark)
            #endif
            
            return state
        } catch {
            // Migration failed - create failure state
            let state = BookmarkMigrationState.failure(failedKeys: allBookmarkKeys, error: error)
            state.save()
            
            Log.error("Bookmark migration failed: \(error.localizedDescription). State: \(state.debugDescription)", category: .bookmark)
            
            return state
        }
    }

    /// Generic method to scan a folder by location kind
    private func scanFolder(folderName: String, bookmarkKey: String, location: FileLocationKind) async throws -> [FileMetadata] {
        let url = try await getFolderURL(folderName: folderName, bookmarkKey: bookmarkKey)
        
        guard url.startAccessingSecurityScopedResource() else {
            throw FormaError.fileSystem(.permissionDenied(folderName))
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        return try await scanDirectory(at: url, location: location)
    }
    
    func scanDesktop() async throws -> [FileMetadata] {
        try await scanFolder(folderName: "Desktop", bookmarkKey: desktopBookmarkKey, location: .desktop)
    }
    
    func scanDownloads() async throws -> [FileMetadata] {
        try await scanFolder(folderName: "Downloads", bookmarkKey: downloadsBookmarkKey, location: .downloads)
    }
    
    func scanDocuments() async throws -> [FileMetadata] {
        try await scanFolder(folderName: "Documents", bookmarkKey: documentsBookmarkKey, location: .documents)
    }
    
    func scanPictures() async throws -> [FileMetadata] {
        try await scanFolder(folderName: "Pictures", bookmarkKey: picturesBookmarkKey, location: .pictures)
    }
    
    func scanMusic() async throws -> [FileMetadata] {
        try await scanFolder(folderName: "Music", bookmarkKey: musicBookmarkKey, location: .music)
    }

    // MARK: - Generic Folder URL Helpers

    /// Gets a folder URL from saved bookmark or requests user to select it
    /// SECURITY: Uses Keychain-based SecureBookmarkStore instead of UserDefaults
    private func getFolderURL(folderName: String, bookmarkKey: String) async throws -> URL {
        // Try to load saved bookmark first from secure Keychain storage
        if let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: bookmarkKey) {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if !isStale {
                    // SECURITY: Validate bookmark resolution (Defense in Depth)
                    // 1. Verify the resolved URL matches the expected folder name
                    guard url.lastPathComponent.lowercased() == folderName.lowercased() else {
                        // Bookmark mismatch - invalidate it to prevent unauthorized access
                        do {
                            try SecureBookmarkStore.deleteBookmark(forKey: bookmarkKey)
                        } catch {
                            Log.error("Failed to delete bookmark '\(bookmarkKey)': \(error.localizedDescription)", category: .bookmark)
                        }
                        #if DEBUG
                        Log.warning("Security: Bookmark mismatch detected. Expected '\\(folderName)', got '\\(url.lastPathComponent)'", category: .security)
                        #endif
                        throw FormaError.fileSystem(.permissionDenied(folderName))
                    }

                    // 2. Verify the resolved path is within the user's home directory
                    // Use realHomeDirectory() to get actual home path (not sandbox container)
                    // and standardizedFileURL to normalize paths for consistent comparison
                    let homeDir = realHomeDirectory()
                    let standardizedHomePath = homeDir.standardizedFileURL.path
                    let standardizedURLPath = url.standardizedFileURL.path
                    guard standardizedURLPath.hasPrefix(standardizedHomePath) else {
                        // Bookmark points outside home directory - invalidate it
                        do {
                            try SecureBookmarkStore.deleteBookmark(forKey: bookmarkKey)
                        } catch {
                            Log.error("Failed to delete bookmark '\(bookmarkKey)': \(error.localizedDescription)", category: .bookmark)
                        }
                        #if DEBUG
                        Log.warning("Security: Bookmark points outside home directory. Home: \(standardizedHomePath), Path: \(standardizedURLPath)", category: .security)
                        #endif
                        throw FormaError.fileSystem(.permissionDenied(folderName))
                    }

                    return url
                }
            } catch {
                // Bookmark is invalid or validation failed, need to request access again
                do {
                    try SecureBookmarkStore.deleteBookmark(forKey: bookmarkKey)
                } catch {
                    Log.error("Failed to delete bookmark '\(bookmarkKey)' after validation error: \(error.localizedDescription)", category: .bookmark)
                }
                // Re-throw permission errors (already converted to FormaError above)
                if case .fileSystem(.permissionDenied) = error as? FormaError {
                    throw error
                }
            }
        }

        // In unit tests, avoid presenting NSOpenPanel and simulate missing permission
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isRunningTests {
            throw FormaError.fileSystem(.permissionDenied(folderName))
        }

        // No valid bookmark, request user to select folder
        return try await requestFolderURL(folderName: folderName, bookmarkKey: bookmarkKey)
    }

    /// Requests user to select a folder using NSOpenPanel
    /// SECURITY: Saves bookmarks to Keychain via SecureBookmarkStore
    /// NOTE: Uses @MainActor instead of DispatchQueue.main.async to avoid potential deadlocks
    /// when called from main thread with Swift concurrency
    @MainActor
    private func requestFolderURL(folderName: String, bookmarkKey: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let openPanel = NSOpenPanel()
            openPanel.message = "Grant Forma access to your \(folderName) folder to organize files"
            openPanel.prompt = "Grant Access"
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.canCreateDirectories = false

            // Pre-select the target folder
            let folderURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(folderName)
            openPanel.directoryURL = folderURL

            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    // Save security-scoped bookmark securely to Keychain
                    do {
                        let bookmarkData = try url.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        // Use SecureBookmarkStore instead of UserDefaults
                        try SecureBookmarkStore.saveBookmark(bookmarkData, forKey: bookmarkKey)
                        continuation.resume(returning: url)
                    } catch {
                        continuation.resume(throwing: FormaError.fileSystem(.ioError("Failed to save bookmark for \(folderName)", underlying: error)))
                    }
                } else {
                    continuation.resume(throwing: FormaError.operation(.cancelled))
                }
            }
        }
    }


    /// Scans a specific directory and returns FileMetadata
    /// - Parameters:
    ///   - url: The folder URL to scan.
    ///   - location: High-level origin classification for files in this directory.
    private func scanDirectory(at url: URL, location: FileLocationKind) async throws -> [FileMetadata] {
        let fileManager = FileManager.default

        // Check if directory exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw FormaError.fileSystem(.notFound(url.path))
        }

        // Check for read permissions
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw FormaError.fileSystem(.permissionDenied(url.path))
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [
                    .fileSizeKey,
                    .creationDateKey,
                    .contentModificationDateKey,
                    .contentAccessDateKey,
                    .isDirectoryKey,
                    .isSymbolicLinkKey  // SECURITY: Detect symlinks
                ],
                options: [.skipsHiddenFiles]
            )

            var fileItems: [FileMetadata] = []
            var skippedDirectories = 0
            var skippedSymlinks = 0

            for fileURL in contents {
                // SECURITY: Check for symlinks and validate them (CWE-61)
                let resourceValues = try fileURL.resourceValues(forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey
                ])

                // Skip directories
                if resourceValues.isDirectory ?? false {
                    skippedDirectories += 1
                    continue
                }

                // SECURITY: Detect and skip symlinks to prevent symlink attacks
                // Defense-in-depth: File organizer should only operate on regular files
                if resourceValues.isSymbolicLink ?? false {
                    skippedSymlinks += 1
                    #if DEBUG
                    Log.warning("SECURITY: Skipping symlink: \(fileURL.path)", category: .security)

                    // Additional validation: Check where the symlink points
                    let resolvedURL = fileURL.resolvingSymlinksInPath()
                    let homeDir = FileManager.default.homeDirectoryForCurrentUser

                    if !resolvedURL.path.hasPrefix(homeDir.path) {
                        Log.error("SYMLINK ATTACK: Symlink escapes home directory. Link: \(fileURL.path), Target: \(resolvedURL.path)", category: .security)
                    }
                    #endif
                    continue
                }

                // Get file metadata
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                let creationDate = attributes[.creationDate] as? Date ?? Date()
                let modificationDate = attributes[.modificationDate] as? Date ?? Date()

                // Try to get last access date from resource values
                let accessResourceValues = try? fileURL.resourceValues(forKeys: [.contentAccessDateKey])
                let lastAccessedDate: Date
                if let accessDate = accessResourceValues?.contentAccessDate {
                    lastAccessedDate = accessDate
                } else {
                    Log.warning("Could not get access date for \(fileURL.lastPathComponent), using current date", category: .filesystem)
                    lastAccessedDate = Date()
                }

                let fileItem = FileMetadata(
                    path: fileURL.path,
                    sizeInBytes: fileSize,
                    creationDate: creationDate,
                    modificationDate: modificationDate,
                    lastAccessedDate: lastAccessedDate,
                    location: location,
                    destination: nil,
                    status: .pending
                )

                fileItems.append(fileItem)
            }

            #if DEBUG
            Log.debug("SCAN RESULTS FOR \(url.lastPathComponent): total=\(contents.count), dirsSkipped=\(skippedDirectories), symlinksSkipped=\(skippedSymlinks), files=\(fileItems.count)", category: .filesystem)
            #endif

            return fileItems

        } catch {
            throw FormaError.fileSystem(.ioError("Failed to scan \(url.lastPathComponent)", underlying: error))
        }
    }

    /// Formats file size in a human-readable format
    private func formatFileSize(_ bytes: Int64) -> String {
        // Handle zero bytes specially to avoid "Zero bytes" output
        if bytes == 0 {
            return "0 bytes"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .binary  // Use binary (1024-based) calculations
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Reset Functions

    /// Resets the saved Desktop folder bookmark (useful for troubleshooting)
    /// SECURITY: Now removes from Keychain instead of UserDefaults
    func resetDesktopAccess() {
        do {
            try SecureBookmarkStore.deleteBookmark(forKey: desktopBookmarkKey)
        } catch {
            Log.error("Failed to delete bookmark '\(desktopBookmarkKey)': \(error.localizedDescription)", category: .bookmark)
        }
    }

    /// Resets the saved Downloads folder bookmark (useful for troubleshooting)
    func resetDownloadsAccess() {
        do {
            try SecureBookmarkStore.deleteBookmark(forKey: downloadsBookmarkKey)
        } catch {
            Log.error("Failed to delete bookmark '\(downloadsBookmarkKey)': \(error.localizedDescription)", category: .bookmark)
        }
    }

    /// Resets the saved Documents folder bookmark (useful for troubleshooting)
    func resetDocumentsAccess() {
        do {
            try SecureBookmarkStore.deleteBookmark(forKey: documentsBookmarkKey)
        } catch {
            Log.error("Failed to delete bookmark '\(documentsBookmarkKey)': \(error.localizedDescription)", category: .bookmark)
        }
    }

    /// Resets all folder bookmarks
    func resetAllAccess() {
        resetDesktopAccess()
        resetDownloadsAccess()
        resetDocumentsAccess()
        do {
            try SecureBookmarkStore.deleteBookmark(forKey: picturesBookmarkKey)
        } catch {
            Log.error("Failed to delete bookmark '\(picturesBookmarkKey)': \(error.localizedDescription)", category: .bookmark)
        }
        do {
            try SecureBookmarkStore.deleteBookmark(forKey: musicBookmarkKey)
        } catch {
            Log.error("Failed to delete bookmark '\(musicBookmarkKey)': \(error.localizedDescription)", category: .bookmark)
        }
    }

    /// Scans a custom folder using security-scoped bookmark
    func scanCustomFolder(url: URL, bookmarkData: Data) async throws -> [FileMetadata] {
        // Resolve bookmark and start accessing security-scoped resource
        var isStale = false
        let resolvedURL: URL

        do {
            resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw FormaError.fileSystem(.ioError("Failed to resolve bookmark for custom folder", underlying: error))
        }

        if isStale {
            throw FormaError.data(.corruptedData("Bookmark is stale. Please re-add this folder."))
        }

        // SECURITY: Validate custom folder bookmark resolution
        // 1. Verify the resolved URL matches the expected path
        guard resolvedURL.path == url.path else {
            #if DEBUG
            Log.warning("Security: Custom folder bookmark mismatch. Expected '\(url.path)', got '\(resolvedURL.path)'", category: .security)
            #endif
            throw FormaError.validation(.invalidDestination("Bookmark verification failed. Please re-add this folder."))
        }

        // 2. Verify the resolved path is within the user's home directory (app runtime only)
        // Use realHomeDirectory() to get actual home path (not sandbox container)
        let homeDir = realHomeDirectory()
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isRunningTests {
            guard resolvedURL.path.hasPrefix(homeDir.path) else {
                #if DEBUG
                Log.warning("Security: Custom folder bookmark points outside home directory. Home: \(homeDir.path), Path: \(resolvedURL.path)", category: .security)
                #endif
                throw FormaError.fileSystem(.permissionDenied(resolvedURL.path))
            }
        }

        guard resolvedURL.startAccessingSecurityScopedResource() else {
            throw FormaError.fileSystem(.permissionDenied(resolvedURL.path))
        }

        defer {
            resolvedURL.stopAccessingSecurityScopedResource()
        }

        // Treat all custom folders as `.custom` origin
        return try await scanDirectory(at: resolvedURL, location: .custom)
    }

    /// Scans all folders that have valid Keychain bookmarks.
    /// Returns ScanResult containing both successful files and any errors that occurred.
    func scanAllFolders() async -> ScanResult {
        // Scan all standard folders that have valid bookmarks
        var baseFolders: [FolderLocation] = []
        if hasDesktopAccess() { baseFolders.append(.desktop) }
        if hasDownloadsAccess() { baseFolders.append(.downloads) }
        if hasDocumentsAccess() { baseFolders.append(.documents) }
        if hasPicturesAccess() { baseFolders.append(.pictures) }
        if hasMusicAccess() { baseFolders.append(.music) }

        return await scan(baseFolders: baseFolders)
    }

    /// Scans the specified base folders.
    /// If baseFolders is empty, defaults to Desktop + Downloads for compatibility.
    func scan(baseFolders: [FolderLocation]) async -> ScanResult {
        var allFiles: [FileMetadata] = []
        var errors: [String: Error] = [:]

        let folders = baseFolders.isEmpty ? [.desktop, .downloads] : baseFolders

        for folder in folders {
            do {
                let scanned: [FileMetadata]
                switch folder {
                case .home:
                    // No direct mapping yet; treat as no-op here and let callers filter
                    continue
                case .desktop:
                    scanned = try await scanDesktop()
                case .downloads:
                    scanned = try await scanDownloads()
                case .documents:
                    scanned = try await scanDocuments()
                case .pictures:
                    scanned = try await scanPictures()
                case .music:
                    scanned = try await scanMusic()
                }
                allFiles.append(contentsOf: scanned)
            } catch {
                errors[folder.displayName] = error
            }
        }

        return ScanResult(files: allFiles, errors: errors)
    }
    // MARK: - Permission Checks

    func hasDesktopAccess() -> Bool {
        return hasAccess(key: desktopBookmarkKey)
    }

    func hasDownloadsAccess() -> Bool {
        return hasAccess(key: downloadsBookmarkKey)
    }

    func hasDocumentsAccess() -> Bool {
        return hasAccess(key: documentsBookmarkKey)
    }

    func hasPicturesAccess() -> Bool {
        return hasAccess(key: picturesBookmarkKey)
    }

    func hasMusicAccess() -> Bool {
        return hasAccess(key: musicBookmarkKey)
    }

    /// Checks if we have valid access to a folder bookmark
    /// SECURITY: Now checks Keychain via SecureBookmarkStore
    private func hasAccess(key: String) -> Bool {
        guard let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: key) else { return false }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // SECURITY: Validate bookmark even in permission checks
            // Verify the resolved path is within the user's home directory
            // Use realHomeDirectory() for actual home (not sandbox container)
            let homeDir = realHomeDirectory()
            let standardizedHomePath = homeDir.standardizedFileURL.path
            let standardizedURLPath = url.standardizedFileURL.path
            guard standardizedURLPath.hasPrefix(standardizedHomePath) else {
                // Invalid bookmark - remove it
                do {
                    try SecureBookmarkStore.deleteBookmark(forKey: key)
                } catch {
                    Log.error("Failed to delete bookmark '\(key)': \(error.localizedDescription)", category: .bookmark)
                }
                return false
            }

            return !isStale
        } catch {
            return false
        }
    }

    // MARK: - Public Access Request Methods

    func requestDesktopAccess() async throws -> Bool {
        let _ = try await requestFolderURL(folderName: "Desktop", bookmarkKey: desktopBookmarkKey)
        return true
    }

    func requestDownloadsAccess() async throws -> Bool {
        let _ = try await requestFolderURL(folderName: "Downloads", bookmarkKey: downloadsBookmarkKey)
        return true
    }

    func requestDocumentsAccess() async throws -> Bool {
        let _ = try await requestFolderURL(folderName: "Documents", bookmarkKey: documentsBookmarkKey)
        return true
    }

    func requestPicturesAccess() async throws -> Bool {
        let _ = try await requestFolderURL(folderName: "Pictures", bookmarkKey: picturesBookmarkKey)
        return true
    }

    func requestMusicAccess() async throws -> Bool {
        let _ = try await requestFolderURL(folderName: "Music", bookmarkKey: musicBookmarkKey)
        return true
    }
}
