import Foundation

/// Resolves placeholder destinations to real destinations with valid bookmarks.
///
/// Placeholder destinations have display names like "Pictures/Screenshots" but empty
/// bookmark data. This service attempts to resolve them by:
/// 1. Parsing the display name into path components
/// 2. Finding a bookmarked parent folder (e.g., "Pictures")
/// 3. Creating any missing subdirectories (e.g., "Screenshots")
/// 4. Generating a valid security-scoped bookmark for the full path
///
/// ## Usage
///
/// ```swift
/// let resolver = DestinationResolver()
/// if let realDestination = resolver.resolve(placeholderDestination) {
///     // Use realDestination with valid bookmark
/// }
/// ```
///
/// ## Security Notes
///
/// This only works within folders the user has already granted access to.
/// It cannot create folders outside the sandboxed permissions.
final class DestinationResolver {

    // MARK: - Known Folder Mappings

    /// Maps common folder names to their bookmark keys
    private static let folderBookmarkKeys: [String: String] = [
        "Desktop": FormaConfig.Security.desktopBookmarkKey,
        "Downloads": FormaConfig.Security.downloadsBookmarkKey,
        "Documents": FormaConfig.Security.documentsBookmarkKey,
        "Pictures": FormaConfig.Security.picturesBookmarkKey,
        "Music": FormaConfig.Security.musicBookmarkKey
    ]

    /// Maps folder names to their system paths (relative to home)
    private static let folderSystemPaths: [String: String] = [
        "Desktop": "Desktop",
        "Downloads": "Downloads",
        "Documents": "Documents",
        "Pictures": "Pictures",
        "Music": "Music",
        "Movies": "Movies",
        "Library": "Library"
    ]

    // MARK: - Resolution

    /// Attempts to resolve a placeholder destination to a real destination with a valid bookmark.
    ///
    /// - Parameter destination: A destination that may have a placeholder (empty) bookmark
    /// - Returns: A new Destination with a valid bookmark, or nil if resolution fails
    ///
    /// Resolution can fail if:
    /// - The parent folder doesn't have a stored bookmark
    /// - The subfolder cannot be created (permissions, disk space, etc.)
    /// - Bookmark creation fails
    func resolve(_ destination: Destination) -> Destination? {
        // Only resolve folder destinations with empty bookmarks
        guard case .folder(let bookmark, let displayName) = destination,
              bookmark.isEmpty else {
            // Already has a valid bookmark or is trash
            return nil
        }

        Log.info("DestinationResolver: Attempting to resolve placeholder '\(displayName)'", category: .bookmark)

        // Parse the display name into components
        let components = displayName.components(separatedBy: "/").filter { !$0.isEmpty }
        guard !components.isEmpty else {
            Log.warning("DestinationResolver: Empty path components for '\(displayName)'", category: .bookmark)
            return nil
        }

        // Find a parent folder we have access to
        guard let (parentURL, remainingComponents) = findAccessibleParent(components: components) else {
            Log.warning("DestinationResolver: No accessible parent found for '\(displayName)'", category: .bookmark)
            return nil
        }

        // Build the full target path
        var targetURL = parentURL
        for component in remainingComponents {
            targetURL = targetURL.appendingPathComponent(component)
        }

        // Create the directory structure if needed
        do {
            try createDirectoryIfNeeded(at: targetURL, accessingParent: parentURL)
        } catch {
            Log.error("DestinationResolver: Failed to create directory at '\(targetURL.path)': \(error)", category: .bookmark)
            return nil
        }

        // Generate a security-scoped bookmark for the target
        do {
            let newDestination = try Destination.folder(from: targetURL)
            Log.info("DestinationResolver: Successfully resolved '\(displayName)' to '\(targetURL.path)'", category: .bookmark)
            return newDestination
        } catch {
            Log.error("DestinationResolver: Failed to create bookmark for '\(targetURL.path)': \(error)", category: .bookmark)
            return nil
        }
    }

    /// Resolves a destination, returning the original if resolution isn't needed or fails.
    ///
    /// This is a convenience method that always returns a usable destination:
    /// - If the destination has a valid bookmark, returns it unchanged
    /// - If resolution succeeds, returns the new destination with valid bookmark
    /// - If resolution fails, returns the original (which may still fail at operation time)
    func resolveOrKeep(_ destination: Destination) -> Destination {
        resolve(destination) ?? destination
    }

    // MARK: - Validation

    /// Result of checking if a destination can be resolved.
    enum ResolvabilityStatus {
        /// Destination has a valid bookmark (no resolution needed)
        case valid

        /// Destination is a placeholder that CAN be resolved (parent has bookmark)
        case resolvable(parentFolder: String)

        /// Destination is a placeholder that CANNOT be resolved (no parent bookmark)
        case unresolvable(reason: String)

        /// Whether the destination is usable (valid or resolvable)
        var isUsable: Bool {
            switch self {
            case .valid, .resolvable:
                return true
            case .unresolvable:
                return false
            }
        }

        /// Human-readable description for UI display
        var message: String {
            switch self {
            case .valid:
                return "Destination is ready"
            case .resolvable(let parent):
                return "Will create subfolder in \(parent)"
            case .unresolvable(let reason):
                return reason
            }
        }
    }

    /// Checks if a placeholder destination can be resolved without actually resolving it.
    ///
    /// Use this to proactively warn users when creating rules with unresolvable destinations.
    ///
    /// - Parameter destination: The destination to check
    /// - Returns: Status indicating if the destination is valid, resolvable, or unresolvable
    func checkResolvability(_ destination: Destination) -> ResolvabilityStatus {
        // Trash is always valid
        guard case .folder(let bookmark, let displayName) = destination else {
            return .valid
        }

        // If it has a non-empty bookmark, it's already valid
        if !bookmark.isEmpty {
            return .valid
        }

        // It's a placeholder - check if we can resolve it
        let components = displayName.components(separatedBy: "/").filter { !$0.isEmpty }
        guard let firstComponent = components.first else {
            return .unresolvable(reason: "Empty destination path")
        }

        // Check if first component matches a known folder with a stored bookmark
        if let bookmarkKey = Self.folderBookmarkKeys[firstComponent],
           SecureBookmarkStore.loadBookmark(forKey: bookmarkKey) != nil {
            return .resolvable(parentFolder: firstComponent)
        }

        // Check known folders that might have permission
        let knownFolders = Array(Self.folderBookmarkKeys.keys)
        let suggestion = knownFolders.first { displayName.lowercased().contains($0.lowercased()) }

        if let suggestedFolder = suggestion {
            return .unresolvable(
                reason: "Destination '\(displayName)' requires '\(suggestedFolder)' folder access. Grant permission in Settings, or use '\(suggestedFolder)/\(displayName)' as the path."
            )
        }

        return .unresolvable(
            reason: "Destination '\(displayName)' is not within a permitted folder. Use a path like 'Pictures/\(displayName)' or 'Documents/\(displayName)'."
        )
    }

    // MARK: - Private Helpers

    /// Finds an accessible parent folder from the path components.
    ///
    /// - Parameter components: Path components like ["Pictures", "Screenshots", "2024"]
    /// - Returns: A tuple of (parent URL, remaining components to create), or nil if no parent found
    private func findAccessibleParent(components: [String]) -> (URL, [String])? {
        guard let firstComponent = components.first else { return nil }

        // Check if first component is a known folder with a bookmark
        if let bookmarkKey = Self.folderBookmarkKeys[firstComponent],
           let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: bookmarkKey) {

            // Resolve the bookmark to get the URL
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    Log.warning("DestinationResolver: Bookmark for '\(firstComponent)' is stale", category: .bookmark)
                }

                // Return the parent URL and remaining components
                let remaining = Array(components.dropFirst())
                return (url, remaining)
            } catch {
                Log.error("DestinationResolver: Failed to resolve bookmark for '\(firstComponent)': \(error)", category: .bookmark)
            }
        }

        // Try the home directory approach for paths like "Documents/Projects/2024"
        // This handles cases where the user typed a relative path
        let homeDir = realHomeDirectory()

        // Check each prefix of the path to find an accessible parent
        for prefixLength in (1...min(components.count, 2)).reversed() {
            let pathPrefix = components.prefix(prefixLength).joined(separator: "/")
            let potentialParent = homeDir.appendingPathComponent(pathPrefix)

            // Check if we have bookmark access to this path
            if let bookmark = findBookmarkForPath(potentialParent.path) {
                var isStale = false
                if let url = try? URL(
                    resolvingBookmarkData: bookmark,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ) {
                    let remaining = Array(components.dropFirst(prefixLength))
                    return (url, remaining)
                }
            }
        }

        return nil
    }

    /// Finds a stored bookmark that grants access to the given path.
    private func findBookmarkForPath(_ path: String) -> Data? {
        // Check all known bookmark keys
        for (folderName, bookmarkKey) in Self.folderBookmarkKeys {
            if let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: bookmarkKey) {
                var isStale = false
                if let url = try? URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                ) {
                    // Check if the requested path is within this bookmarked folder
                    if path.hasPrefix(url.path) || url.path.hasSuffix("/\(folderName)") && path.contains("/\(folderName)/") {
                        return bookmarkData
                    }
                }
            }
        }
        return nil
    }

    /// Creates a directory at the specified URL if it doesn't exist.
    ///
    /// - Parameters:
    ///   - url: The URL where the directory should be created
    ///   - parentURL: The parent URL with security-scoped access
    private func createDirectoryIfNeeded(at url: URL, accessingParent parentURL: URL) throws {
        let fileManager = FileManager.default

        // Start accessing the parent folder
        guard parentURL.startAccessingSecurityScopedResource() else {
            throw NSError(
                domain: "DestinationResolver",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to access parent folder"]
            )
        }
        defer { parentURL.stopAccessingSecurityScopedResource() }

        // Check if already exists
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                Log.debug("DestinationResolver: Directory already exists at '\(url.path)'", category: .bookmark)
                return
            } else {
                throw NSError(
                    domain: "DestinationResolver",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "A file exists at the destination path"]
                )
            }
        }

        // Create the directory with intermediate directories
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        Log.info("DestinationResolver: Created directory at '\(url.path)'", category: .bookmark)
    }
}

// MARK: - Helper Functions

/// Returns the user's real home directory (not sandbox container)
private func realHomeDirectory() -> URL {
    if let pw = getpwuid(getuid()) {
        let homeDir = String(cString: pw.pointee.pw_dir)
        return URL(fileURLWithPath: homeDir)
    }
    return FileManager.default.homeDirectoryForCurrentUser
}
