import AppKit
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

    // MARK: - Resolution

    enum MaterializationError: LocalizedError {
        case unresolvable(reason: String)
        case creationFailed(displayName: String)

        var errorDescription: String? {
            switch self {
            case .unresolvable(let reason):
                return reason
            case .creationFailed(let displayName):
                return "Could not create '\(displayName)'. Check folder permissions and try again."
            }
        }
    }

    struct SuggestedAccessPlan: Equatable {
        let requestedDisplayPath: String
        let requestedURL: URL
        let initialDirectoryURL: URL
        let initialDirectoryLabel: String
        let missingPathComponents: [String]

        var missingPath: String? {
            guard !missingPathComponents.isEmpty else { return nil }
            return missingPathComponents.joined(separator: "/")
        }

        var suggestedFolderName: String? {
            missingPathComponents.first
        }

        var panelMessage: String {
            if let missingPath {
                return "Grant access to \(initialDirectoryLabel) so Forma can create \"\(missingPath)\" for the suggested destination \"\(requestedDisplayPath)\"."
            }

            return "Grant access to \"\(requestedDisplayPath)\" so Forma can use it as the destination."
        }
    }

    enum AccessGrantError: LocalizedError {
        case cancelled

        var errorDescription: String? {
            switch self {
            case .cancelled:
                return "Folder selection was cancelled."
            }
        }
    }

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

        guard let normalizedDisplayName = normalizedDisplayName(for: displayName),
              !normalizedDisplayName.isEmpty else {
            Log.warning("DestinationResolver: Empty path components for '\(displayName)'", category: .bookmark)
            return nil
        }

        Log.info("DestinationResolver: Attempting to resolve placeholder '\(normalizedDisplayName)'", category: .bookmark)

        let components = pathComponents(for: normalizedDisplayName)

        // Find a parent folder we have access to
        guard let (parentURL, remainingComponents) = findAccessibleParent(components: components) else {
            Log.warning("DestinationResolver: No accessible parent found for '\(normalizedDisplayName)'", category: .bookmark)
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
            let newDestination = try Destination.folder(from: targetURL, displayName: normalizedDisplayName)
            Log.info("DestinationResolver: Successfully resolved '\(normalizedDisplayName)' to '\(targetURL.path)'", category: .bookmark)
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

    /// Resolves placeholder destinations during explicit rule-save flows.
    /// Unlike `resolveOrKeep`, this surfaces actionable errors when a destination
    /// cannot be materialized, so editors can block save with precise feedback.
    func materializeForExplicitSave(_ destination: Destination?) throws -> Destination? {
        guard let destination else { return nil }
        guard !destination.isTrash else { return destination }

        if destination.bookmarkData != nil {
            return destination
        }

        if let resolved = resolve(destination) {
            return resolved
        }

        switch checkResolvability(destination) {
        case .valid:
            return destination
        case .resolvable:
            throw MaterializationError.creationFailed(displayName: destination.displayName)
        case .unresolvable(let reason):
            throw MaterializationError.unresolvable(reason: reason)
        }
    }

    @MainActor
    func requestDestinationAccess(forSuggestedPath suggestedPath: String?) async throws -> Destination {
        let panel = NSOpenPanel()
        let accessPlan = suggestedAccessPlan(for: suggestedPath)

        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.level = .modalPanel

        if let accessPlan {
            panel.directoryURL = accessPlan.initialDirectoryURL
            panel.message = accessPlan.panelMessage
            panel.prompt = "Grant Access"
            if let suggestedFolderName = accessPlan.suggestedFolderName {
                panel.nameFieldStringValue = suggestedFolderName
            }
        } else {
            panel.directoryURL = realHomeDirectory()
            panel.message = "Choose a destination folder."
            panel.prompt = "Choose Folder"
        }

        let response = await panel.begin()
        guard response == .OK, let selectedURL = panel.url else {
            throw AccessGrantError.cancelled
        }

        return try materializeGrantedDestination(from: selectedURL, suggestedPath: suggestedPath)
    }

    func suggestedAccessPlan(for suggestedPath: String?) -> SuggestedAccessPlan? {
        guard let rawSuggestedPath = suggestedPath,
              let normalizedDisplayPath = normalizedDisplayName(for: rawSuggestedPath),
              !normalizedDisplayPath.isEmpty else {
            return nil
        }

        let requestedURL = requestedURL(
            forSuggestedPath: rawSuggestedPath,
            normalizedDisplayPath: normalizedDisplayPath
        )
        let initialDirectoryURL = nearestExistingDirectory(for: requestedURL)
        let missingPathComponents = missingPathComponents(
            from: initialDirectoryURL,
            to: requestedURL
        )

        return SuggestedAccessPlan(
            requestedDisplayPath: normalizedDisplayPath,
            requestedURL: requestedURL,
            initialDirectoryURL: initialDirectoryURL,
            initialDirectoryLabel: accessLabel(for: initialDirectoryURL),
            missingPathComponents: missingPathComponents
        )
    }

    func materializeGrantedDestination(from selectedURL: URL, suggestedPath: String?) throws -> Destination {
        let standardizedSelectedURL = selectedURL.standardizedFileURL

        if let accessPlan = suggestedAccessPlan(for: suggestedPath) {
            let requestedURL = accessPlan.requestedURL.standardizedFileURL
            let targetURL = preferredGrantedTargetURL(
                selectedURL: standardizedSelectedURL,
                requestedURL: requestedURL
            )

            if targetURL != standardizedSelectedURL {
                try createDirectoryIfNeededAfterGrant(
                    at: targetURL,
                    grantedFolderURL: standardizedSelectedURL
                )
                return try Destination.folder(
                    from: targetURL,
                    displayName: accessPlan.requestedDisplayPath
                )
            }

            return try Destination.folder(
                from: standardizedSelectedURL,
                displayName: destinationDisplayName(for: standardizedSelectedURL)
            )
        }

        return try Destination.folder(
            from: standardizedSelectedURL,
            displayName: destinationDisplayName(for: standardizedSelectedURL)
        )
    }

    /// Attempts to resolve a placeholder destination only if the directory already exists.
    /// This avoids creating new folders during prediction or preview flows.
    func resolveIfExists(_ destination: Destination) -> Destination? {
        guard case .folder(let bookmark, let displayName) = destination,
              bookmark.isEmpty else {
            return nil
        }

        guard let normalizedDisplayName = normalizedDisplayName(for: displayName),
              !normalizedDisplayName.isEmpty else { return nil }

        let components = pathComponents(for: normalizedDisplayName)

        guard let (parentURL, remainingComponents) = findAccessibleParent(components: components) else {
            return nil
        }

        var targetURL = parentURL
        for component in remainingComponents {
            targetURL = targetURL.appendingPathComponent(component)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        do {
            return try Destination.folder(from: targetURL, displayName: normalizedDisplayName)
        } catch {
            Log.error("DestinationResolver: Failed to create bookmark for existing '\(targetURL.path)': \(error)", category: .bookmark)
            return nil
        }
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

        guard let normalizedDisplayName = normalizedDisplayName(for: displayName),
              !normalizedDisplayName.isEmpty else {
            return .unresolvable(reason: "Empty destination path")
        }

        let components = pathComponents(for: normalizedDisplayName)
        guard let firstComponent = components.first else {
            return .unresolvable(reason: "Empty destination path")
        }

        // Check if first component matches a known folder with a stored bookmark
        if let bookmarkKey = Self.folderBookmarkKeys[firstComponent],
           BookmarkStoreProvider.shared.loadBookmark(forKey: bookmarkKey) != nil {
            return .resolvable(parentFolder: firstComponent)
        }

        // Check known folders that might have permission
        let knownFolders = Array(Self.folderBookmarkKeys.keys)
        let suggestion = knownFolders.first { normalizedDisplayName.lowercased().contains($0.lowercased()) }

        if let suggestedFolder = suggestion {
            return .unresolvable(
                reason: "Destination '\(normalizedDisplayName)' requires '\(suggestedFolder)' folder access. Grant permission in Settings, or use '\(suggestedFolder)/\(normalizedDisplayName)' as the path."
            )
        }

        return .unresolvable(
            reason: "Destination '\(normalizedDisplayName)' is not within a permitted folder. Use a path like 'Pictures/\(normalizedDisplayName)' or 'Documents/\(normalizedDisplayName)'."
        )
    }

    // MARK: - Private Helpers

    private func normalizedDisplayName(for displayName: String) -> String? {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let expanded = NSString(string: trimmed).expandingTildeInPath
        if expanded.hasPrefix("/") {
            let absoluteURL = URL(fileURLWithPath: expanded).standardizedFileURL
            let candidateHomePaths = Set([
                realHomeDirectory().standardizedFileURL.path,
                FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
            ]).sorted { $0.count > $1.count }

            for homePath in candidateHomePaths {
                if absoluteURL.path == homePath {
                    return nil
                }

                if absoluteURL.path.hasPrefix(homePath + "/") {
                    return String(absoluteURL.path.dropFirst(homePath.count + 1))
                }
            }
        }

        return trimmed
    }

    private func pathComponents(for displayName: String) -> [String] {
        displayName.components(separatedBy: "/").filter { !$0.isEmpty }
    }

    private func requestedURL(forSuggestedPath suggestedPath: String, normalizedDisplayPath: String) -> URL {
        let trimmedSuggestedPath = suggestedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedSuggestedPath = NSString(string: trimmedSuggestedPath).expandingTildeInPath

        if expandedSuggestedPath.hasPrefix("/") {
            let absoluteURL = URL(fileURLWithPath: expandedSuggestedPath).standardizedFileURL

            if let knownRootRelativePath = canonicalHomeRelativePathIfKnownRoot(for: absoluteURL) {
                return realHomeDirectory()
                    .appendingPathComponent(knownRootRelativePath)
                    .standardizedFileURL
            }

            return absoluteURL
        }

        let expanded = NSString(string: normalizedDisplayPath).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL
        }

        return realHomeDirectory()
            .appendingPathComponent(normalizedDisplayPath)
            .standardizedFileURL
    }

    private func canonicalHomeRelativePathIfKnownRoot(for absoluteURL: URL) -> String? {
        let candidateHomePaths = Set([
            realHomeDirectory().standardizedFileURL.path,
            FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        ]).sorted { $0.count > $1.count }

        for homePath in candidateHomePaths {
            guard absoluteURL.path.hasPrefix(homePath + "/") else { continue }

            let relativePath = String(absoluteURL.path.dropFirst(homePath.count + 1))
            guard let firstComponent = pathComponents(for: relativePath).first,
                  Self.folderBookmarkKeys[firstComponent] != nil else {
                return nil
            }

            return relativePath
        }

        return nil
    }

    private func nearestExistingDirectory(for requestedURL: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = requestedURL.standardizedFileURL

        while true {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return candidate
            }

            let parent = candidate.deletingLastPathComponent().standardizedFileURL
            if parent.path == candidate.path {
                return candidate
            }
            candidate = parent
        }
    }

    private func missingPathComponents(from initialDirectoryURL: URL, to requestedURL: URL) -> [String] {
        let initialComponents = initialDirectoryURL.standardizedFileURL.pathComponents
        let requestedComponents = requestedURL.standardizedFileURL.pathComponents

        guard requestedComponents.starts(with: initialComponents) else {
            return []
        }

        return Array(requestedComponents.dropFirst(initialComponents.count))
    }

    private func accessLabel(for url: URL) -> String {
        let home = realHomeDirectory().standardizedFileURL
        if url.standardizedFileURL.path == home.path {
            return "your home folder"
        }

        return "\"\(destinationDisplayName(for: url))\""
    }

    private func destinationDisplayName(for url: URL) -> String {
        let homeURL = realHomeDirectory().standardizedFileURL
        let standardizedURL = url.standardizedFileURL

        if standardizedURL.path.hasPrefix(homeURL.path + "/") {
            return String(standardizedURL.path.dropFirst(homeURL.path.count + 1))
        }

        return standardizedURL.lastPathComponent
    }

    private func preferredGrantedTargetURL(selectedURL: URL, requestedURL: URL) -> URL {
        let standardizedSelectedURL = selectedURL.standardizedFileURL
        let standardizedRequestedURL = requestedURL.standardizedFileURL

        if standardizedSelectedURL.path == standardizedRequestedURL.path {
            return standardizedRequestedURL
        }

        if standardizedRequestedURL.path.hasPrefix(standardizedSelectedURL.path + "/") {
            return standardizedRequestedURL
        }

        if standardizedSelectedURL.path.hasPrefix(standardizedRequestedURL.path + "/") {
            return standardizedSelectedURL
        }

        return standardizedSelectedURL
    }

    /// Finds an accessible parent folder from the path components.
    ///
    /// - Parameter components: Path components like ["Pictures", "Screenshots", "2024"]
    /// - Returns: A tuple of (parent URL, remaining components to create), or nil if no parent found
    private func findAccessibleParent(components: [String]) -> (URL, [String])? {
        guard let firstComponent = components.first else { return nil }

        // Check if first component is a known folder with a bookmark
        if let bookmarkKey = Self.folderBookmarkKeys[firstComponent],
           let bookmarkData = BookmarkStoreProvider.shared.loadBookmark(forKey: bookmarkKey) {

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
            if let bookmarkData = BookmarkStoreProvider.shared.loadBookmark(forKey: bookmarkKey) {
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

    private func createDirectoryIfNeededAfterGrant(at url: URL, grantedFolderURL: URL) throws {
        let fileManager = FileManager.default
        let didStartAccessing = grantedFolderURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                grantedFolderURL.stopAccessingSecurityScopedResource()
            }
        }

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return
            }

            throw NSError(
                domain: "DestinationResolver",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "A file already exists at \(url.lastPathComponent)."]
            )
        }

        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        Log.info("DestinationResolver: Created granted destination at '\(url.path)'", category: .bookmark)
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
