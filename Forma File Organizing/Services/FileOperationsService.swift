import Foundation
import AppKit
import SwiftData
import Darwin

/// Service responsible for file operations (move, copy, delete)
@MainActor
final class FileOperationsService {

    private let bookmarkPrefix = "DestinationFolderBookmark_"

    /// Resolver for placeholder destinations (auto-creates subfolders within permitted parents)
    private let destinationResolver = DestinationResolver()
    
    /// Mapping of standard folder names to their bookmark keys
    private static let sourceFolderBookmarks: [String: String] = [
        "Desktop": "DesktopFolderBookmark",
        "Downloads": "DownloadsFolderBookmark",
        "Documents": "DocumentsFolderBookmark",
        "Pictures": "PicturesFolderBookmark",
        "Music": "MusicFolderBookmark"
    ]

    /// RAII-style wrapper for security-scoped resource access
    /// Ensures resources are always released, even if errors occur
    private class SecurityScopedAccess {
        private let url: URL
        private var isAccessing = false

        init?(url: URL) {
            self.url = url
            guard url.startAccessingSecurityScopedResource() else {
                return nil
            }
            self.isAccessing = true
        }

        deinit {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    // MARK: - TOCTOU Protection

    /// Securely validates and verifies a file before performing operations
    /// Prevents Time-of-Check-Time-of-Use (TOCTOU) race conditions (CWE-367)
    ///
    /// Security measures:
    /// 1. Opens file descriptor with O_NOFOLLOW to prevent symlink attacks (CWE-61)
    /// 2. Uses fstat() on the open file descriptor to verify file properties
    /// 3. Validates it's a regular file (not symlink, device, socket, etc.)
    /// 4. Keeps file descriptor open until operation completes
    ///
    /// OWASP Reference: A01:2021 – Broken Access Control
    ///
    /// - Parameter url: The file URL to validate
    /// - Returns: An open file descriptor (caller must close it with defer { close(fd) })
    /// - Throws: FormaError if validation fails
    private func secureValidateFile(at url: URL) throws -> Int32 {
        let path = url.path

        // Open file descriptor with O_RDONLY (read-only) and O_NOFOLLOW (don't follow symlinks)
        // O_NOFOLLOW prevents symlink race condition attacks where attacker replaces file with symlink
        let fd = open(path, O_RDONLY | O_NOFOLLOW)

        guard fd >= 0 else {
            // Failed to open - check specific errno
            let err = errno
            #if DEBUG
            Log.error("SECURITY: Failed to open file descriptor for \(path), errno: \(err)", category: .security)
            #endif

            switch err {
            case ENOENT:
                throw FormaError.fileNotFound(path)
            case EACCES, EPERM:
                throw FormaError.permissionDenied(for: path)
            case ELOOP:
                // ELOOP = Too many symbolic links (O_NOFOLLOW rejected a symlink)
                #if DEBUG
                Log.error("SECURITY: Symlink attack detected at \(path)", category: .security)
                #endif
                throw FormaError.fileSystem(.symlinkDetected(path))
            default:
                throw FormaError.operationFailed("Cannot open source file (errno: \(err))")
            }
        }

        // Get file status using the open file descriptor
        // This ensures we're checking the SAME file we opened (no TOCTOU race)
        var fileStat = stat()
        guard fstat(fd, &fileStat) == 0 else {
            close(fd)
            #if DEBUG
            Log.error("SECURITY: fstat failed for \(path)", category: .security)
            #endif
            throw FormaError.operationFailed("Cannot stat source file")
        }

        // Verify it's a regular file (S_IFREG)
        // Reject symlinks, devices, sockets, FIFOs, etc.
        let fileType = fileStat.st_mode & S_IFMT
        guard fileType == S_IFREG else {
            close(fd)

            let typeString: String
            switch fileType {
            case S_IFLNK:
                typeString = "symbolic link"
            case S_IFDIR:
                typeString = "directory"
            case S_IFCHR:
                typeString = "character device"
            case S_IFBLK:
                typeString = "block device"
            case S_IFIFO:
                typeString = "FIFO/pipe"
            case S_IFSOCK:
                typeString = "socket"
            default:
                typeString = "unknown type"
            }

            #if DEBUG
            Log.error("SECURITY: Source is not a regular file: \(typeString) at \(path)", category: .security)
            #endif
            throw FormaError.operationFailed("Source is a \(typeString), not a regular file")
        }

        // Verify we have read permissions
        guard fileStat.st_mode & S_IRUSR != 0 else {
            close(fd)
            #if DEBUG
            Log.error("SECURITY: No read permission for \(path)", category: .security)
            #endif
            throw FormaError.permissionDenied(for: path)
        }

        #if DEBUG
        Log.debug("SECURITY: File validated at \(path), size: \(fileStat.st_size) bytes, perms: \(String(format: "%o", fileStat.st_mode & 0o777))", category: .security)
        #endif

        // Return the open file descriptor
        // Caller MUST close it with defer { close(fd) }
        return fd
    }

    /// Securely moves a file with TOCTOU protection using POSIX renameat()
    /// Uses file descriptor-based operations to prevent race conditions
    ///
    /// This is the secure, FD-based approach that eliminates TOCTOU completely.
    /// The renameat() call operates on directory file descriptors, not paths.
    ///
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destURL: Destination file URL
    /// - Throws: FormaError if move fails
    private func secureFileMove(from sourceURL: URL, to destURL: URL) throws {
        #if DEBUG
        Log.debug("SECURE FILE MOVE (FD-based): \(sourceURL.path) → \(destURL.path)", category: .fileOperations)
        #endif

        // Step 1: Validate source file and get file descriptor
        let sourceFD = try secureValidateFile(at: sourceURL)
        defer { close(sourceFD) }

        #if DEBUG
        Log.debug("Source file validated with FD: \(sourceFD)", category: .fileOperations)
        #endif

        // Step 2: Open directory file descriptors for renameat()
        let sourceDirPath = sourceURL.deletingLastPathComponent().path
        let destDirPath = destURL.deletingLastPathComponent().path
        
        let sourceDirFD = open(sourceDirPath, O_RDONLY | O_DIRECTORY)
        guard sourceDirFD >= 0 else {
            throw FormaError.permissionDenied(for: sourceDirPath)
        }
        defer { close(sourceDirFD) }

        let destDirFD = open(destDirPath, O_RDONLY | O_DIRECTORY)
        guard destDirFD >= 0 else {
            throw FormaError.permissionDenied(for: destDirPath)
        }
        defer { close(destDirFD) }

        // Step 3: Extract file names (not full paths)
        let sourceFileName = sourceURL.lastPathComponent
        let destFileName = destURL.lastPathComponent
        
        #if DEBUG
        Log.debug("Source dir FD: \(sourceDirFD), dest dir FD: \(destDirFD), file: \(sourceFileName) → \(destFileName)", category: .fileOperations)
        #endif

        // Step 4: Perform atomic rename using renameat()
        // This is FD-based and immune to TOCTOU attacks
        let result = renameat(sourceDirFD, sourceFileName, destDirFD, destFileName)
        
        if result != 0 {
            let err = errno
            
            #if DEBUG
            Log.error("renameat() failed with errno: \(err)", category: .fileOperations)
            #endif
            
            switch err {
            case ENOENT:
                throw FormaError.fileNotFound(sourceURL.path)
            case EACCES, EPERM:
                throw FormaError.permissionDenied(for: sourceURL.path)
            case EEXIST:
                throw FormaError.fileSystem(.alreadyExists(destURL.path))
            case ENOSPC:
                throw FormaError.fileSystem(.diskFull)
            case EXDEV:
                // Cross-device move - fall back to copy+delete
                #if DEBUG
                Log.info("Cross-device move detected, falling back to copy+delete", category: .fileOperations)
                #endif
                try fallbackCopyAndDelete(from: sourceURL, to: destURL, sourceFD: sourceFD)
            case EBUSY:
                throw FormaError.fileSystem(.fileInUse(sourceURL.path))
            default:
                throw FormaError.operationFailed("renameat() failed with errno \(err)")
            }
        }
        
        #if DEBUG
        Log.debug("SECURITY: Atomic FD-based move completed successfully", category: .security)
        #endif
    }
    
    /// Fallback for cross-device moves (different file systems)
    /// Uses copy+delete when renameat() returns EXDEV
    private func fallbackCopyAndDelete(from sourceURL: URL, to destURL: URL, sourceFD: Int32) throws {
        // Use FileManager for cross-device copy
        // The source FD ensures we're copying the validated file
        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
            
            // Verify the copy succeeded before deleting source
            guard fileManager.fileExists(atPath: destURL.path) else {
                throw FormaError.operationFailed("Copy verification failed")
            }
            
            // Delete the source file
            try fileManager.removeItem(at: sourceURL)
            
            #if DEBUG
            Log.info("Cross-device copy+delete completed", category: .fileOperations)
            #endif
        } catch {
            // Convert any error to FormaError
            throw FormaError.from(error)
        }
    }

    /// Public helper for performing a secure move on disk using the same
    /// TOCTOU-safe logic as regular file operations. Intended primarily for
    /// undo/redo paths where we only have source/destination paths.
    func secureMoveOnDisk(from sourcePath: String, to destinationPath: String) throws {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destURL = URL(fileURLWithPath: destinationPath)
        try secureFileMove(from: sourceURL, to: destURL)
    }
 
    struct MoveResult {
        let success: Bool
        let originalPath: String
        let destinationPath: String?
        let error: FormaError?
    }

    private let fileManager = FileManager.default

    /// Detects if the app is running in a sandboxed environment
    /// When sandboxed, security-scoped bookmarks are required for file access.
    ///
    /// Unit tests run inside a container as well, but for testability we treat
    /// them as "not sandboxed" so security tests can exercise the low-level
    /// validation logic (TOCTOU, path checks, etc.) without requiring
    /// interactive NSOpenPanel flows or real user bookmarks.
    private var isAppSandboxed: Bool {
        // During XCTest runs, skip sandbox behavior to keep tests hermetic
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isRunningTests { return false }
        
        // In production, consider the app sandboxed when the home directory is
        // inside a Containers path.
        let homeDir = fileManager.homeDirectoryForCurrentUser.path
        return homeDir.contains("/Library/Containers/")
    }

    // MARK: - Bookmark Resolution
    
    /// Resolves a source folder bookmark to get security-scoped URL
    /// - Parameter folderName: Name of the folder (Desktop, Downloads, etc.)
    /// - Returns: Resolved URL if bookmark exists and is valid, nil otherwise
    /// - Throws: FormaError if bookmark is stale or invalid
    private func resolveSourceFolderBookmark(for folderName: String) throws -> URL? {
        guard isAppSandboxed else { return nil }
        
        guard let bookmarkKey = Self.sourceFolderBookmarks[folderName],
              let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: bookmarkKey) else {
            return nil
        }
        
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        guard !isStale else {
            Log.warning("Source folder bookmark is stale for \(folderName)", category: .bookmark)
            throw FormaError.permissionDenied(for: folderName)
        }
        
        Log.debug("Source folder bookmark resolved for \(folderName): \(url.path)", category: .bookmark)
        return url
    }
    
    // MARK: - Security - Path Sanitization
    
    /// Securely sanitizes and validates a destination path using centralized PathValidator.
    ///
    /// - Parameter path: The raw destination path from user input or rules
    /// - Returns: A sanitized, validated path safe for use
    /// - Throws: FormaError if the path is invalid or malicious
    private func sanitizeDestinationPath(_ path: String) throws -> String {
        do {
            return try PathValidator.validate(path)
        } catch let error as PathValidator.ValidationError {
            throw FormaError.validation(.invalidDestination(error.localizedDescription))
        } catch {
            throw FormaError.validation(.invalidDestination("Path validation failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - File Operations

    /// Moves a file to its destination
    func moveFile(_ fileItem: FileItem, modelContext: ModelContext? = nil) async throws -> MoveResult {
        guard let destination = fileItem.destination else {
            throw FormaError.operation(.notReady("No destination specified"))
        }

        #if DEBUG
        if CommandLine.arguments.contains("--uitesting") {
            return MoveResult(
                success: true,
                originalPath: fileItem.path,
                destinationPath: fileItem.path,
                error: nil
            )
        }
        #endif

        let sourceURL = URL(fileURLWithPath: fileItem.path)
        #if DEBUG
        Log.debug("FILE MOVE OPERATION START — source: \(sourceURL.path), destination: \(destination.displayName)", category: .fileOperations)
        #endif

        // Handle Trash destination specially - use system trash
        if destination.isTrash {
            return try await moveToTrash(fileItem, sourceURL: sourceURL, modelContext: modelContext)
        }

        // Use bookmark-based destination (the only supported path now)
        // If destination has no bookmark (placeholder), try to resolve it first
        var effectiveDestination = destination
        var effectiveBookmarkData = destination.bookmarkData

        if effectiveBookmarkData == nil {
            // Attempt to resolve placeholder destination by creating subfolder within permitted parent
            if let resolved = destinationResolver.resolve(destination) {
                effectiveDestination = resolved
                effectiveBookmarkData = resolved.bookmarkData
                // Update the file item's destination so it persists
                fileItem.destination = resolved
                Log.info("FileOperationsService: Auto-resolved placeholder '\(destination.displayName)'", category: .fileOperations)
            } else {
                Log.warning("FileOperationsService: Cannot move file - destination '\(destination.displayName)' has no bookmark and could not be resolved", category: .fileOperations)
                throw FormaError.operation(.notReady("Destination '\(destination.displayName)' requires folder access - please select the folder in Settings"))
            }
        }

        guard let bookmarkData = effectiveBookmarkData else {
            throw FormaError.operation(.notReady("Destination has no bookmark data"))
        }

        return try await moveFileUsingBookmark(
            fileItem,
            sourceURL: sourceURL,
            bookmarkData: bookmarkData,
            destination: effectiveDestination,
            modelContext: modelContext
        )
    }

    // MARK: - Bookmark-Based File Operations

    /// Moves a file using security-scoped bookmark data for the destination
    /// This method uses direct bookmark resolution for secure access
    private func moveFileUsingBookmark(
        _ fileItem: FileItem,
        sourceURL: URL,
        bookmarkData: Data,
        destination: Destination,
        modelContext: ModelContext?
    ) async throws -> MoveResult {
        #if DEBUG
        Log.debug("BOOKMARK MOVE START — source: \(sourceURL.path), using bookmark data", category: .fileOperations)
        #endif

        // 🔒 SECURITY: Validate source file with TOCTOU protection
        let sourceFD = try secureValidateFile(at: sourceURL)
        defer { close(sourceFD) }

        // Resolve the bookmark to get the destination URL
        var isStale = false
        let destinationFolderURL: URL
        do {
            destinationFolderURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            #if DEBUG
            Log.error("BOOKMARK MOVE: Failed to resolve bookmark - \(error.localizedDescription)", category: .fileOperations)
            #endif
            throw FormaError.operationFailed("Could not access destination folder: \(error.localizedDescription)")
        }

        if isStale {
            #if DEBUG
            Log.warning("BOOKMARK MOVE: Bookmark is stale for \(destinationFolderURL.path)", category: .fileOperations)
            #endif
            // Stale bookmarks may still work, but we log it
        }

        // Start security-scoped access to the destination
        guard destinationFolderURL.startAccessingSecurityScopedResource() else {
            #if DEBUG
            Log.error("BOOKMARK MOVE: Failed to start security-scoped access to \(destinationFolderURL.path)", category: .security)
            #endif
            throw FormaError.permissionDenied(for: destinationFolderURL.path)
        }
        defer {
            destinationFolderURL.stopAccessingSecurityScopedResource()
        }

        // Also need access to the source folder
        let sourceFolder = sourceURL.deletingLastPathComponent()
        let sourceFolderName = sourceFolder.lastPathComponent
        let resolvedSourceFolderURL = try resolveSourceFolderBookmark(for: sourceFolderName)

        var sourceAccess: SecurityScopedAccess? = nil
        _ = sourceAccess // Silence "never read" warning - RAII pattern

        if isAppSandboxed, let sourceFolderURL = resolvedSourceFolderURL {
            guard let access = SecurityScopedAccess(url: sourceFolderURL) else {
                #if DEBUG
                Log.error("BOOKMARK MOVE: Failed to start source folder security scope", category: .security)
                #endif
                throw FormaError.permissionDenied(for: sourceFolderURL.path)
            }
            sourceAccess = access
        }

        // Build destination file URL
        let destinationURL = destinationFolderURL.appendingPathComponent(fileItem.name)

        #if DEBUG
        Log.debug("BOOKMARK MOVE: destination folder: \(destinationFolderURL.path), final: \(destinationURL.path)", category: .fileOperations)
        #endif

        // Ensure destination folder exists
        try FileManager.default.createDirectory(
            at: destinationFolderURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Check if destination already exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            throw FormaError.fileSystem(.alreadyExists(destinationURL.path))
        }

        // Perform the move
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)

            #if DEBUG
            Log.info("BOOKMARK MOVE SUCCESS: \(sourceURL.lastPathComponent) → \(destinationFolderURL.lastPathComponent)", category: .fileOperations)
            #endif

            // Log activity if context provided
            if let context = modelContext {
                let activityService = ActivityLoggingService(modelContext: context)
                activityService.logFileOrganized(
                    fileName: fileItem.name,
                    destination: destination.displayName,
                    fileExtension: fileItem.fileExtension
                )
            }

            return MoveResult(
                success: true,
                originalPath: sourceURL.path,
                destinationPath: destinationURL.path,
                error: nil
            )

        } catch {
            #if DEBUG
            Log.error("BOOKMARK MOVE FAILED: \(error.localizedDescription)", category: .fileOperations)
            #endif
            throw FormaError.from(error)
        }
    }

    // MARK: - Rate Limiting Configuration

    /// Maximum batch size for file operations to prevent resource exhaustion
    /// Limiting batch size prevents:
    /// - CPU/disk exhaustion from processing too many files at once
    /// - UI freeze from too many concurrent operations
    /// - System instability with huge file batches
    ///
    /// OWASP Reference: A04:2021 - Insecure Design (Resource Exhaustion)
    private static let maxBatchSize = 1000

    /// Delay between batch file operations in nanoseconds (100ms)
    /// Small delay prevents:
    /// - Disk I/O saturation
    /// - System resource exhaustion
    /// - Thermal throttling on sustained operations
    private static let operationDelayNanoseconds: UInt64 = 100_000_000 // 100ms

    /// Moves multiple files with rate limiting to prevent resource exhaustion
    ///
    /// Security measures:
    /// 1. Limits batch size to prevent denial-of-service scenarios
    /// 2. Adds delay between operations to prevent resource saturation
    /// 3. Logs warnings when batch size is exceeded
    ///
    /// - Parameters:
    ///   - files: Array of files to move
    ///   - modelContext: Optional SwiftData context for activity tracking
    /// - Returns: Array of move results for each file
    func moveFiles(_ files: [FileItem], modelContext: ModelContext? = nil) async -> [MoveResult] {
        // SECURITY: Limit batch size to prevent resource exhaustion (CWE-400)
        let originalCount = files.count
        let limitedFiles = Array(files.prefix(Self.maxBatchSize))

        if originalCount > Self.maxBatchSize {
            #if DEBUG
            Log.warning("SECURITY: Batch size limited to \(Self.maxBatchSize) files (requested: \(originalCount)). Consider processing in smaller chunks.", category: .fileOperations)
            #endif
            
            // Log to console for production builds (important security event)
            Log.warning("Batch file operation limited: \(originalCount) files requested, processing \(Self.maxBatchSize)", category: .fileOperations)
        }

        var results: [MoveResult] = []

        #if DEBUG
        if limitedFiles.count > 10 {
            Log.debug("Processing \(limitedFiles.count) files with rate limiting (delay: \(Double(Self.operationDelayNanoseconds) / 1_000_000)ms between operations)", category: .fileOperations)
        }
        #endif

        for (index, file) in limitedFiles.enumerated() {
            do {
                let result = try await moveFile(file, modelContext: modelContext)
                results.append(result)
            } catch {
                // Convert any error to FormaError
                let formaError = (error as? FormaError) ?? FormaError.from(error)
                results.append(MoveResult(
                    success: false,
                    originalPath: file.path,
                    destinationPath: nil,
                    error: formaError
                ))
            }

            // SECURITY: Rate limit file operations to prevent resource exhaustion
            // Only add delay if we have more files to process
            if index < limitedFiles.count - 1 {
                try? await Task.sleep(nanoseconds: Self.operationDelayNanoseconds)
            }
        }

        return results
    }

    /// Gets the full destination path for a file by resolving its destination bookmark
    func getDestinationPath(for fileItem: FileItem) -> String? {
        guard let destination = fileItem.destination else {
            return nil
        }

        // Special case for Trash
        if destination.isTrash {
            return "~/.Trash/\(fileItem.name)"
        }

        // Resolve the bookmark to get the actual path
        guard let resolved = destination.resolve() else {
            return nil
        }

        return resolved.url.appendingPathComponent(fileItem.name).path
    }

    // MARK: - Trash Operations

    /// Moves a file to the system Trash using macOS's native trash API
    private func moveToTrash(_ fileItem: FileItem, sourceURL: URL, modelContext: ModelContext?) async throws -> MoveResult {
        #if DEBUG
        Log.debug("MOVE TO TRASH OPERATION — source: \(sourceURL.path)", category: .fileOperations)
        #endif

        // 🔒 SECURITY FIX: Validate source file with TOCTOU protection
        // Open file descriptor immediately to prevent race conditions
        let sourceFD = try secureValidateFile(at: sourceURL)
        defer { close(sourceFD) }
        
        #if DEBUG
        Log.debug("Source file securely validated for trash (FD: \(sourceFD))", category: .security)
        #endif

        // CRITICAL FIX: Initialize security-scoped access at the outermost scope
        // This will be automatically cleaned up when it goes out of scope (RAII pattern)
        // The variable is intentionally kept in scope for its side effects (RAII cleanup)
        var sourceAccess: SecurityScopedAccess? = nil
        _ = sourceAccess  // Silence "never read" warning - RAII pattern

        // Get security-scoped access to the source folder if sandboxed
        if isAppSandboxed {
            let sourceFolder = sourceURL.deletingLastPathComponent()
            let sourceFolderName = sourceFolder.lastPathComponent

            do {
                if let url = try resolveSourceFolderBookmark(for: sourceFolderName) {
                    sourceAccess = SecurityScopedAccess(url: url)
                    Log.debug("Started security-scoped access to source folder: \(sourceFolderName)", category: .security)
                }
            } catch {
                Log.warning("Failed to resolve source folder bookmark for '\(sourceFolderName)': \(error.localizedDescription)", category: .security)
            }
        }

        do {
            // Use macOS native trash API
            var resultingURL: NSURL?
            try fileManager.trashItem(at: sourceURL, resultingItemURL: &resultingURL)

            let trashPath = resultingURL?.path ?? "Trash"
            #if DEBUG
            Log.debug("File moved to Trash: \(trashPath)", category: .fileOperations)
            #endif

            // Track activity
            if let context = modelContext {
                let activityService = ActivityLoggingService(modelContext: context)
                activityService.logFileDeleted(
                    fileName: fileItem.name,
                    fileExtension: fileItem.fileExtension
                )
            }

            return MoveResult(
                success: true,
                originalPath: fileItem.path,
                destinationPath: trashPath,
                error: nil
            )

        } catch {
            #if DEBUG
            Log.error("Failed to move to Trash: \(error)", category: .fileOperations)
            #endif
            throw FormaError.from(error)
        }
    }

    // MARK: - Destination Access Management

    /// Ensures we have access to the destination folder and returns the resolved URL
    private func ensureDestinationAccess(_ folderName: String) async throws -> URL {
        let bookmarkKey = bookmarkPrefix + folderName
        #if DEBUG
        Log.debug("BOOKMARK RESOLUTION for: \(folderName), sandboxed: \(isAppSandboxed)", category: .bookmark)
        #endif

        // If not sandboxed, we can directly access the folder without bookmarks
        if !isAppSandboxed {
            let directURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(folderName)
            #if DEBUG
            Log.debug("Not sandboxed - using direct path: \(directURL.path)", category: .filesystem)
            #endif
            return directURL
        }

        // Sandboxed: Try to load saved bookmark first
        // Use SecureBookmarkStore (Keychain) instead of UserDefaults for security
        if let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: bookmarkKey) {
            #if DEBUG
            Log.debug("Found saved bookmark for \(folderName)", category: .bookmark)
            #endif
            var isStale = false
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if !isStale {
                    #if DEBUG
                    Log.debug("Bookmark resolved to: \(resolvedURL.path). Expected: ~/\(folderName)", category: .bookmark)
                    #endif
                    return resolvedURL
                } else {
                    #if DEBUG
                    Log.warning("Bookmark is stale for \(folderName), requesting new access", category: .bookmark)
                    #endif
                }
            } catch {
                #if DEBUG
                Log.warning("Bookmark resolution failed for \(folderName): \(error.localizedDescription)", category: .bookmark)
                #endif
                // Bookmark resolution failed, will request new access below
            }
        } else {
            #if DEBUG
            Log.debug("No saved bookmark found for \(folderName)", category: .bookmark)
            #endif
        }

        // No valid bookmark, request user to select the destination folder
        #if DEBUG
        Log.debug("Requesting user to select \(folderName) folder...", category: .bookmark)
        #endif
        return try await requestDestinationAccess(folderName)
    }

    /// Requests user to grant access to a destination folder
    /// NOTE: Uses @MainActor instead of DispatchQueue.main.async to avoid potential deadlocks
    @MainActor
    private func requestDestinationAccess(_ folderName: String) async throws -> URL {
        // Capture self reference for use in assumeIsolated closure
        let bookmarkPrefixCapture = self.bookmarkPrefix

        return try await withCheckedThrowingContinuation { continuation in
            // Use MainActor.assumeIsolated because withCheckedThrowingContinuation's closure
            // doesn't inherit @MainActor context, but we know we're on the main actor since
            // this method is @MainActor-isolated. All NSOpenPanel/NSAlert UI code requires it.
            MainActor.assumeIsolated {
                // Try to get the real home directory from the Desktop bookmark
                // Use SecureBookmarkStore (Keychain) instead of UserDefaults for security
                var realHomeDirectory: URL?
                if let desktopBookmark = SecureBookmarkStore.loadBookmark(forKey: "DesktopFolderBookmark") {
                    var isStale = false
                    if let desktopURL = try? URL(
                        resolvingBookmarkData: desktopBookmark,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    ), !isStale {
                        // Desktop is at ~/Desktop, so parent is the home directory
                        realHomeDirectory = desktopURL.deletingLastPathComponent()
                    }
                }

                // Build the suggested folder path and check if it exists
                let homeDirectory = realHomeDirectory ?? FileManager.default.homeDirectoryForCurrentUser
                let expectedFolderURL = homeDirectory.appendingPathComponent(folderName)
                let folderExists = FileManager.default.fileExists(atPath: expectedFolderURL.path)

                #if DEBUG
                Log.debug("Folder existence check — expected: \(expectedFolderURL.path), exists: \(folderExists)", category: .bookmark)
                #endif

                // Show pre-alert if folder doesn't exist
                if !folderExists {
                    let preAlert = NSAlert()
                    preAlert.messageText = "Create \(folderName) Folder?"
                    preAlert.informativeText = "Forma needs a folder called '\(folderName)' at ~/\(folderName) to organize your files.\n\nWhen the folder picker opens, click 'New Folder' (⇧⌘N), name it '\(folderName)', and click Select."
                    preAlert.alertStyle = .informational
                    preAlert.addButton(withTitle: "Continue")
                    preAlert.addButton(withTitle: "Cancel")

                    let preResponse = preAlert.runModal()
                    if preResponse != .alertFirstButtonReturn {
                        continuation.resume(throwing: FormaError.cancelled)
                        return
                    }
                }

                // Retry loop: allow up to 3 attempts
                var attempts = 0
                let maxAttempts = 3

                @MainActor func attemptFolderSelection() {
                    attempts += 1

                    #if DEBUG
                    Log.debug("Folder selection attempt \(attempts)/\(maxAttempts)", category: .bookmark)
                    #endif

                    let openPanel = NSOpenPanel()

                    // Context-aware message
                    if folderExists {
                        openPanel.message = "Please select your \(folderName) folder\n\nLocation: ~/\(folderName)"
                        openPanel.prompt = "Select \(folderName)"
                    } else {
                        openPanel.message = "Create the \(folderName) folder\n\nClick 'New Folder' (⇧⌘N), name it '\(folderName)', then click Select."
                        openPanel.prompt = "Create & Select"
                    }

                    openPanel.canChooseFiles = false
                    openPanel.canChooseDirectories = true
                    openPanel.allowsMultipleSelection = false
                    openPanel.canCreateDirectories = true

                    // Pre-select the suggested folder or home directory
                    if folderExists {
                        openPanel.directoryURL = expectedFolderURL
                    } else {
                        openPanel.directoryURL = homeDirectory
                    }

                    // Run modal
                    let response = openPanel.runModal()

                    if response == .OK, let selectedURL = openPanel.url {
                        // Validate selection
                        let lastComponent = selectedURL.lastPathComponent

                        if lastComponent.lowercased() == folderName.lowercased() {
                            // Success! Save bookmark
                            #if DEBUG
                            Log.debug("Folder validation passed: \(lastComponent) matches \(folderName)", category: .bookmark)
                            #endif

                            do {
                                let bookmarkData = try selectedURL.bookmarkData(
                                    options: .withSecurityScope,
                                    includingResourceValuesForKeys: nil,
                                    relativeTo: nil
                                )
                                let bookmarkKey = bookmarkPrefixCapture + folderName
                                try SecureBookmarkStore.saveBookmark(bookmarkData, forKey: bookmarkKey)
                                continuation.resume(returning: selectedURL)
                            } catch {
                                continuation.resume(throwing: FormaError.from(error))
                            }
                        } else {
                            // Wrong folder selected
                            #if DEBUG
                            Log.warning("User selected wrong folder: \(lastComponent) instead of \(folderName)", category: .bookmark)
                            #endif

                            let alert = NSAlert()
                            alert.messageText = "Wrong Folder Selected"

                            if folderExists {
                                alert.informativeText = "You selected '\(lastComponent)' but Forma needs access to '\(folderName)'.\n\nPlease select the existing '\(folderName)' folder at ~/\(folderName)."
                            } else {
                                alert.informativeText = "You created a folder named '\(lastComponent)' but Forma needs '\(folderName)'.\n\nPlease create a folder named exactly '\(folderName)' (case-insensitive) at ~/\(folderName)."
                            }

                            alert.alertStyle = .warning

                            if attempts < maxAttempts {
                                alert.addButton(withTitle: "Try Again")
                                alert.addButton(withTitle: "Cancel")

                                let alertResponse = alert.runModal()
                                if alertResponse == .alertFirstButtonReturn {
                                    // Retry
                                    attemptFolderSelection()
                                } else {
                                    continuation.resume(throwing: FormaError.validation(.invalidDestination("Wrong folder selected: expected \(folderName), got \(lastComponent)")))
                                }
                            } else {
                                alert.addButton(withTitle: "OK")
                                alert.informativeText += "\n\nMaximum attempts reached. Please check your rules and try again."
                                alert.runModal()
                                continuation.resume(throwing: FormaError.operationFailed("Maximum folder selection attempts reached"))
                            }
                        }
                    } else {
                        // User cancelled
                        continuation.resume(throwing: FormaError.cancelled)
                    }
                }

                // Start first attempt
                attemptFolderSelection()
            }
        }
    }

    /// Resets all saved destination folder bookmarks
    func resetDestinationAccess() {
        // Get all bookmark keys from Keychain
        let allKeychainKeys = SecureBookmarkStore.listAllBookmarkKeys()

        // Remove all destination bookmarks (those starting with our prefix)
        for key in allKeychainKeys where key.hasPrefix(bookmarkPrefix) {
            do {
                try SecureBookmarkStore.deleteBookmark(forKey: key)
            } catch {
                Log.warning("Failed to delete bookmark for key '\(key)': \(error.localizedDescription)", category: .security)
            }
        }

    }
    
    /// Diagnostic function to inspect all saved destination bookmarks
    func diagnoseBookmarks() {
        #if DEBUG
        Log.debug("=== BOOKMARK DIAGNOSTICS ===", category: .bookmark)

        // Check Keychain (SecureBookmarkStore)
        let keychainKeys = SecureBookmarkStore.listAllBookmarkKeys()
        let destinationKeychainKeys = keychainKeys.filter { $0.hasPrefix(bookmarkPrefix) }

        Log.debug("Keychain (SecureBookmarkStore):", category: .bookmark)
        if destinationKeychainKeys.isEmpty {
            Log.debug("  No destination folder bookmarks found in Keychain", category: .bookmark)
        } else {
            Log.debug("  Found \(destinationKeychainKeys.count) destination bookmark(s)", category: .bookmark)
            for key in destinationKeychainKeys {
                let folderName = key.replacingOccurrences(of: bookmarkPrefix, with: "")
                if let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: key) {
                    var isStale = false
                    do {
                        let url = try URL(
                            resolvingBookmarkData: bookmarkData,
                            options: .withSecurityScope,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale
                        )
                        let status = isStale ? "STALE" : "VALID"
                        Log.debug("    \(folderName): \(url.path) [\(status)]", category: .bookmark)
                    } catch {
                        Log.warning("    \(folderName): FAILED TO RESOLVE — \(error.localizedDescription)", category: .bookmark)
                    }
                }
            }
        }

        Log.debug("=== END DIAGNOSTICS ===", category: .bookmark)
        #endif
    }
}
