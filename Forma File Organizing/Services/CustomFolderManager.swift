import Foundation
import AppKit
import SwiftData
import Combine

/// Returns the user's real home directory, not the sandbox container.
/// In sandboxed apps, FileManager.default.homeDirectoryForCurrentUser returns
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

/// Service responsible for managing custom folder locations and their security-scoped bookmarks
@MainActor
class CustomFolderManager: ObservableObject {

    // Required for @MainActor + ObservableObject compatibility
    nonisolated(unsafe) let objectWillChange = PassthroughSubject<Void, Never>()

    enum CustomFolderError: LocalizedError {
        case userCancelled
        case bookmarkCreationFailed
        case bookmarkResolutionFailed
        case invalidFolder

        var errorDescription: String? {
            switch self {
            case .userCancelled:
                return "Folder selection was cancelled."
            case .bookmarkCreationFailed:
                return "Failed to create security bookmark for the folder."
            case .bookmarkResolutionFailed:
                return "Failed to access the saved folder location."
            case .invalidFolder:
                return "The selected folder is invalid or inaccessible."
            }
        }
    }

    /// Requests user to select a folder using NSOpenPanel
    func selectFolder() async throws -> (url: URL, bookmarkData: Data) {
        let results = try await selectFolders(allowMultiple: false)
        guard let first = results.first else {
            throw CustomFolderError.userCancelled
        }
        return first
    }

    /// Requests user to select one or more folders using NSOpenPanel
    /// - Parameter allowMultiple: When true, allows selecting multiple folders at once
    /// - Returns: Array of tuples containing URL and bookmark data for each selected folder
    /// NOTE: Uses @MainActor instead of DispatchQueue.main.async to avoid potential deadlocks
    @MainActor
    func selectFolders(allowMultiple: Bool = true) async throws -> [(url: URL, bookmarkData: Data)] {
        return try await withCheckedThrowingContinuation { continuation in
            let openPanel = NSOpenPanel()
            openPanel.message = allowMultiple
                ? "Select folders to monitor (⌘-click to select multiple)"
                : "Select a folder to monitor for file organization"
            openPanel.prompt = allowMultiple ? "Add Folders" : "Select Folder"
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = allowMultiple
            openPanel.canCreateDirectories = false

            openPanel.begin { response in
                if response == .OK {
                    let urls = openPanel.urls
                    guard !urls.isEmpty else {
                        continuation.resume(throwing: CustomFolderError.userCancelled)
                        return
                    }

                    var results: [(url: URL, bookmarkData: Data)] = []
                    var failedCount = 0

                    for url in urls {
                        do {
                            // Create security-scoped bookmark for each folder
                            let bookmarkData = try url.bookmarkData(
                                options: .withSecurityScope,
                                includingResourceValuesForKeys: nil,
                                relativeTo: nil
                            )
                            results.append((url, bookmarkData))
                        } catch {
                            #if DEBUG
                            Log.warning("Failed to create bookmark for \(url.path): \(error)", category: .bookmark)
                            #endif
                            failedCount += 1
                        }
                    }

                    // If at least one succeeded, return those
                    if !results.isEmpty {
                        continuation.resume(returning: results)
                    } else {
                        continuation.resume(throwing: CustomFolderError.bookmarkCreationFailed)
                    }
                } else {
                    continuation.resume(throwing: CustomFolderError.userCancelled)
                }
            }
        }
    }

    /// Creates a CustomFolder from user selection
    func createCustomFolder(name: String? = nil) async throws -> CustomFolder {
        let (url, bookmarkData) = try await selectFolder()

        // Use the folder name from the URL if custom name not provided
        let folderName = name ?? url.lastPathComponent

        let customFolder = try CustomFolder(
            name: folderName,
            path: url.path,
            bookmarkData: bookmarkData
        )

        return customFolder
    }

    /// Creates multiple CustomFolders from user selection (allows multi-select)
    /// - Returns: Array of CustomFolder objects for each selected folder
    func createCustomFolders() async throws -> [CustomFolder] {
        let results = try await selectFolders(allowMultiple: true)

        return try results.map { (url, bookmarkData) in
            try CustomFolder(
                name: url.lastPathComponent,
                path: url.path,
                bookmarkData: bookmarkData
            )
        }
    }

    /// Resolves a URL from a security-scoped bookmark
    func resolveBookmark(from bookmarkData: Data) throws -> URL {
        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                throw CustomFolderError.bookmarkResolutionFailed
            }

            // SECURITY: Validate bookmark resolution
            // Verify the resolved path is within the user's home directory
            // Use realHomeDirectory() to get actual home path (not sandbox container)
            let homeDir = realHomeDirectory()
            guard url.path.hasPrefix(homeDir.path) else {
                #if DEBUG
                Log.warning("Security: Custom folder bookmark points outside home directory. Path: \(url.path)", category: .security)
                #endif
                throw CustomFolderError.invalidFolder
            }

            return url
        } catch {
            if error is CustomFolderError {
                throw error
            }
            throw CustomFolderError.bookmarkResolutionFailed
        }
    }

    /// Validates that a folder path exists and is accessible
    func validateFolder(at path: String) -> Bool {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }

        guard isDirectory.boolValue else {
            return false
        }

        guard fileManager.isReadableFile(atPath: path) else {
            return false
        }

        return true
    }

    /// Gets the URL for a custom folder, handling security-scoped bookmarks
    func getURL(for customFolder: CustomFolder) throws -> URL {
        guard let bookmarkData = customFolder.bookmarkData else {
            throw CustomFolderError.bookmarkResolutionFailed
        }

        return try resolveBookmark(from: bookmarkData)
    }
}
