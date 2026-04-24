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

    private let clock: Clock
    private let rateLimiter: RateLimiter
    
    /// Mapping of standard folder names to their bookmark keys
    private static let sourceFolderBookmarks: [String: String] = [
        "Desktop": "DesktopFolderBookmark",
        "Downloads": "DownloadsFolderBookmark",
        "Documents": "DocumentsFolderBookmark",
        "Pictures": "PicturesFolderBookmark",
        "Music": "MusicFolderBookmark"
    ]

    private enum SourceValidationAccess {
        case metadataOnly
        case readable

        var openFlagCandidates: [Int32] {
            switch self {
            case .metadataOnly:
                [
                    O_EVTONLY | O_NOFOLLOW | O_NONBLOCK,
                    O_RDONLY | O_NOFOLLOW | O_NONBLOCK,
                    O_WRONLY | O_NOFOLLOW | O_NONBLOCK
                ]
            case .readable:
                [O_RDONLY | O_NOFOLLOW | O_NONBLOCK]
            }
        }
    }

    private struct DestinationCopyIdentity {
        let device: dev_t
        let inode: ino_t
    }

    private struct DestinationCopy {
        let fd: Int32
        let temporaryFileName: String
        let identity: DestinationCopyIdentity
    }

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
    private func secureValidateFile(
        at url: URL,
        access: SourceValidationAccess = .readable,
        logOpenFailure: Bool = true
    ) throws -> Int32 {
        let path = url.path

        // O_NOFOLLOW prevents symlink race condition attacks where an attacker
        // replaces the file with a symlink. Same-volume renames only need an FD
        // that can be fstat'd, while cross-volume copy fallback opens a readable FD.
        var fd: Int32 = -1
        var openErrno: Int32 = 0
        for flags in access.openFlagCandidates {
            fd = open(path, flags)
            if fd >= 0 {
                break
            }

            openErrno = errno
            if openErrno == ENOENT || openErrno == ELOOP {
                break
            }
        }

        guard fd >= 0 else {
            // Failed to open - check specific errno
            let err = openErrno
            #if DEBUG
            if logOpenFailure {
                Log.error("SECURITY: Failed to open file descriptor for \(path), errno: \(err)", category: .security)
            }
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

        #if DEBUG
        Log.debug("SECURITY: File validated at \(path), size: \(fileStat.st_size) bytes, perms: \(String(format: "%o", fileStat.st_mode & 0o777))", category: .security)
        #endif

        // Return the open file descriptor
        // Caller MUST close it with defer { close(fd) }
        return fd
    }

    private func openDirectoryDescriptor(at path: String) throws -> Int32 {
        let normalizedPath = pathByResolvingSystemSymlinkAlias(path)
        let pathComponents = normalizedPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        let rootFD = open("/", O_SEARCH | O_NOFOLLOW)
        guard rootFD >= 0 else {
            let err = errno
            throw FormaError.operationFailed("Cannot open move root directory (errno: \(err))")
        }

        var currentFD = rootFD
        var displayComponents: [String] = []

        do {
            for component in pathComponents {
                if component == "." || component.isEmpty {
                    continue
                }

                let componentDisplayPath: String
                if component == ".." {
                    if !displayComponents.isEmpty {
                        displayComponents.removeLast()
                    }
                    componentDisplayPath = makeDisplayPath(from: displayComponents)
                } else {
                    displayComponents.append(component)
                    componentDisplayPath = makeDisplayPath(from: displayComponents)
                }

                let nextFD = try openDirectoryComponent(
                    named: component,
                    relativeTo: currentFD,
                    displayPath: componentDisplayPath
                )
                close(currentFD)
                currentFD = nextFD
            }

            return currentFD
        } catch {
            close(currentFD)
            throw error
        }
    }

    private func openDirectoryComponent(named component: String, relativeTo parentFD: Int32, displayPath: String) throws -> Int32 {
        let fd = component.withCString { componentName in
            openat(parentFD, componentName, O_SEARCH | O_NOFOLLOW)
        }
        guard fd >= 0 else {
            let err = errno
            switch err {
            case ENOENT:
                throw FormaError.fileNotFound(displayPath)
            case EACCES, EPERM:
                throw FormaError.permissionDenied(for: displayPath)
            case ELOOP:
                throw FormaError.fileSystem(.symlinkDetected(displayPath))
            case ENOTDIR:
                if directoryComponentIsSymlink(named: component, relativeTo: parentFD) {
                    throw FormaError.fileSystem(.symlinkDetected(displayPath))
                }
                throw FormaError.operationFailed("Move parent is not a directory: \(displayPath)")
            default:
                throw FormaError.operationFailed("Cannot open move directory component (errno: \(err))")
            }
        }

        var directoryStat = stat()
        guard fstat(fd, &directoryStat) == 0 else {
            let err = errno
            close(fd)
            throw FormaError.operationFailed("Cannot stat move directory component (errno: \(err))")
        }

        guard directoryStat.st_mode & S_IFMT == S_IFDIR else {
            close(fd)
            throw FormaError.operationFailed("Move parent is not a directory: \(displayPath)")
        }

        return fd
    }

    private func directoryComponentIsSymlink(named component: String, relativeTo parentFD: Int32) -> Bool {
        var componentStat = stat()
        let result = component.withCString { componentName in
            fstatat(parentFD, componentName, &componentStat, AT_SYMLINK_NOFOLLOW)
        }

        return result == 0 && componentStat.st_mode & S_IFMT == S_IFLNK
    }

    private func makeDisplayPath(from components: [String]) -> String {
        components.isEmpty ? "/" : "/\(components.joined(separator: "/"))"
    }

    private func pathByResolvingSystemSymlinkAlias(_ path: String) -> String {
        let rawPath = path.hasPrefix("/") ? path : URL(fileURLWithPath: path).path
        let systemSymlinkAliases: [(alias: String, resolved: String)] = [
            ("/var", "/private/var"),
            ("/tmp", "/private/tmp"),
            ("/etc", "/private/etc")
        ]

        for mapping in systemSymlinkAliases {
            if rawPath == mapping.alias {
                return mapping.resolved
            }

            let aliasPrefix = "\(mapping.alias)/"
            if rawPath.hasPrefix(aliasPrefix) {
                return mapping.resolved + rawPath.dropFirst(mapping.alias.count)
            }
        }

        return rawPath
    }

    /// Securely moves a file with TOCTOU protection using POSIX renameatx_np()
    /// Uses file descriptor-based operations to prevent race conditions
    ///
    /// This is the secure approach for production moves. It validates with an
    /// open source FD before moving, uses search-only directory descriptors for
    /// renameatx_np(), refuses destination replacement, and rejects symlinks
    /// encountered during rename.
    ///
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destURL: Destination file URL
    /// - Throws: FormaError if move fails
    private func secureFileMove(from sourceURL: URL, to destURL: URL) throws {
        #if DEBUG
        Log.debug("SECURE FILE MOVE (FD-based): \(sourceURL.path) → \(destURL.path)", category: .fileOperations)
        #endif

        // Step 1: Validate source file and get a metadata descriptor.
        let sourceFD = try secureValidateFile(at: sourceURL, access: .metadataOnly)
        defer { close(sourceFD) }

        #if DEBUG
        Log.debug("Source file validated with FD: \(sourceFD)", category: .fileOperations)
        #endif

        // Step 2: Open directory file descriptors for renameatx_np()
        let sourceDirPath = sourceURL.deletingLastPathComponent().path
        let destDirPath = destURL.deletingLastPathComponent().path
        
        let sourceDirFD = try openDirectoryDescriptor(at: sourceDirPath)
        defer { close(sourceDirFD) }

        let destDirFD = try openDirectoryDescriptor(at: destDirPath)
        defer { close(destDirFD) }

        // Step 3: Extract file names (not full paths)
        let sourceFileName = sourceURL.lastPathComponent
        let destFileName = destURL.lastPathComponent
        
        try verifySourcePathStillMatchesOpenFile(
            sourceFD: sourceFD,
            sourceDirFD: sourceDirFD,
            sourceFileName: sourceFileName,
            sourceURL: sourceURL
        )

        #if DEBUG
        Log.debug("Source dir FD: \(sourceDirFD), dest dir FD: \(destDirFD), file: \(sourceFileName) → \(destFileName)", category: .fileOperations)
        #endif

        // Step 4: Perform atomic no-replace rename using directory descriptors.
        let strictRenameFlags = UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
        let strictRenameErrno = renameUsingDirectoryDescriptors(
            sourceDirFD: sourceDirFD,
            sourceFileName: sourceFileName,
            destDirFD: destDirFD,
            destFileName: destFileName,
            flags: strictRenameFlags
        )

        if strictRenameErrno != 0 {
            #if DEBUG
            Log.error("renameatx_np() failed with errno: \(strictRenameErrno)", category: .fileOperations)
            #endif

            if shouldRetryRenameWithoutStrictFlags(after: strictRenameErrno) {
                let noReplaceRenameErrno = renameUsingDirectoryDescriptors(
                    sourceDirFD: sourceDirFD,
                    sourceFileName: sourceFileName,
                    destDirFD: destDirFD,
                    destFileName: destFileName,
                    flags: UInt32(RENAME_EXCL)
                )

                if noReplaceRenameErrno == 0 {
                    #if DEBUG
                    Log.info("Rename completed with no-replace fallback flags", category: .fileOperations)
                    #endif
                    return
                }

                if shouldUseCopyAndDeleteFallback(after: noReplaceRenameErrno) {
                    #if DEBUG
                    Log.info("Rename unavailable after no-replace retry, falling back to copy+delete", category: .fileOperations)
                    #endif
                    try fallbackCopyAndDelete(
                        from: sourceURL,
                        to: destURL,
                        validatedSourceFD: sourceFD,
                        sourceDirFD: sourceDirFD,
                        sourceFileName: sourceFileName,
                        destDirFD: destDirFD,
                        destFileName: destFileName
                    )
                    return
                }

                try throwRenameError(noReplaceRenameErrno, sourceURL: sourceURL, destURL: destURL)
            }

            if shouldUseCopyAndDeleteFallback(after: strictRenameErrno) {
                #if DEBUG
                Log.info("Cross-device rename unavailable, falling back to copy+delete", category: .fileOperations)
                #endif
                try fallbackCopyAndDelete(
                    from: sourceURL,
                    to: destURL,
                    validatedSourceFD: sourceFD,
                    sourceDirFD: sourceDirFD,
                    sourceFileName: sourceFileName,
                    destDirFD: destDirFD,
                    destFileName: destFileName
                )
                return
            }

            try throwRenameError(strictRenameErrno, sourceURL: sourceURL, destURL: destURL)
        }
        
        #if DEBUG
        Log.debug("SECURITY: Atomic FD-based move completed successfully", category: .security)
        #endif
    }

    private func renameUsingDirectoryDescriptors(
        sourceDirFD: Int32,
        sourceFileName: String,
        destDirFD: Int32,
        destFileName: String,
        flags: UInt32
    ) -> Int32 {
        let result = sourceFileName.withCString { sourceName in
            destFileName.withCString { destName in
                renameatx_np(sourceDirFD, sourceName, destDirFD, destName, flags)
            }
        }

        return result == 0 ? 0 : errno
    }

    private func shouldRetryRenameWithoutStrictFlags(after errorCode: Int32) -> Bool {
        errorCode == ENOTSUP || errorCode == EOPNOTSUPP || errorCode == EINVAL
    }

    private func shouldUseCopyAndDeleteFallback(after errorCode: Int32) -> Bool {
        errorCode == EXDEV || errorCode == ENOTSUP || errorCode == EOPNOTSUPP || errorCode == EINVAL
    }

    private func throwRenameError(_ errorCode: Int32, sourceURL: URL, destURL: URL) throws {
        switch errorCode {
        case ENOENT:
            throw FormaError.fileNotFound(sourceURL.path)
        case EACCES, EPERM:
            throw FormaError.permissionDenied(for: sourceURL.path)
        case EEXIST:
            throw FormaError.fileSystem(.alreadyExists(destURL.path))
        case ENOSPC:
            throw FormaError.fileSystem(.diskFull)
        case EBUSY:
            throw FormaError.fileSystem(.fileInUse(sourceURL.path))
        case ELOOP:
            throw FormaError.fileSystem(.symlinkDetected(sourceURL.path))
        case ENOTCAPABLE:
            throw FormaError.operationFailed("Move path escaped its directory boundary")
        default:
            throw FormaError.operationFailed("renameatx_np() failed with errno \(errorCode)")
        }
    }

    /// Fallback for cross-device moves (different file systems).
    /// Copies from the already validated source FD, then unlinks only if the
    /// source path still resolves to that same open file.
    private func fallbackCopyAndDelete(
        from sourceURL: URL,
        to destURL: URL,
        validatedSourceFD: Int32,
        sourceDirFD: Int32,
        sourceFileName: String,
        destDirFD: Int32,
        destFileName: String
    ) throws {
        let sourceFD = try openReadableSourceFDMatchingValidatedSource(
            sourceURL: sourceURL,
            validatedSourceFD: validatedSourceFD,
            sourceDirFD: sourceDirFD,
            sourceFileName: sourceFileName
        )
        defer { close(sourceFD) }

        let destinationCopy = try copyOpenFileDescriptorToTemporaryFile(
            sourceFD,
            to: destURL,
            destDirFD: destDirFD
        )
        defer { close(destinationCopy.fd) }

        var shouldRemoveTemporaryCopyOnFailure = true
        defer {
            if shouldRemoveTemporaryCopyOnFailure {
                removeDestinationCopyIfStillMatches(
                    destDirFD: destDirFD,
                    destFileName: destinationCopy.temporaryFileName,
                    identity: destinationCopy.identity
                )
            }
        }

        var finalDestinationIdentity = destinationCopy.identity
        var shouldRemoveFinalDestinationOnFailure = false
        defer {
            if shouldRemoveFinalDestinationOnFailure {
                removeDestinationCopyIfStillMatches(
                    destDirFD: destDirFD,
                    destFileName: destFileName,
                    identity: finalDestinationIdentity
                )
            }
        }

        do {
            try verifySourcePathStillMatchesOpenFile(
                sourceFD: sourceFD,
                sourceDirFD: sourceDirFD,
                sourceFileName: sourceFileName,
                sourceURL: sourceURL
            )

            let finalDestinationCopy = try promoteTemporaryDestinationCopy(
                destinationCopy,
                to: destURL,
                destDirFD: destDirFD,
                destFileName: destFileName
            )
            let finalDestinationFDToClose = finalDestinationCopy.fd == destinationCopy.fd ? nil : finalDestinationCopy.fd
            defer {
                if let finalDestinationFDToClose {
                    close(finalDestinationFDToClose)
                }
            }
            finalDestinationIdentity = finalDestinationCopy.identity
            shouldRemoveTemporaryCopyOnFailure = false
            shouldRemoveFinalDestinationOnFailure = true

            try verifyDestinationPathStillMatchesCopy(
                destURL: destURL,
                destDirFD: destDirFD,
                destFileName: destFileName,
                identity: finalDestinationCopy.identity
            )

            try verifySourcePathStillMatchesOpenFile(
                sourceFD: sourceFD,
                sourceDirFD: sourceDirFD,
                sourceFileName: sourceFileName,
                sourceURL: sourceURL
            )

            let unlinkResult = sourceFileName.withCString { sourceName in
                unlinkat(sourceDirFD, sourceName, 0)
            }

            guard unlinkResult == 0 else {
                let err = errno
                switch err {
                case ENOENT:
                    throw FormaError.fileNotFound(sourceURL.path)
                case EACCES, EPERM:
                    throw FormaError.permissionDenied(for: sourceURL.path)
                default:
                    throw FormaError.operationFailed("unlinkat() failed with errno \(err)")
                }
            }
        } catch {
            if !sourceDescriptorStillHasReachableLink(sourceFD) {
                shouldRemoveFinalDestinationOnFailure = false
            }
            throw error
        }

        #if DEBUG
        Log.info("Cross-device FD copy+unlink completed", category: .fileOperations)
        #endif
        shouldRemoveFinalDestinationOnFailure = false
    }

    private func sourceDescriptorStillHasReachableLink(_ sourceFD: Int32) -> Bool {
        var sourceStat = stat()
        guard fstat(sourceFD, &sourceStat) == 0 else {
            return true
        }

        return sourceStat.st_nlink > 0
    }

    private func copyOpenFileDescriptorToTemporaryFile(
        _ sourceFD: Int32,
        to destURL: URL,
        destDirFD: Int32
    ) throws -> DestinationCopy {
        var sourceStat = stat()
        guard fstat(sourceFD, &sourceStat) == 0 else {
            throw FormaError.operationFailed("Cannot stat source file")
        }

        var tempFileName = makeDestinationTempFileName()
        var destFD: Int32 = -1
        for _ in 0..<5 {
            tempFileName = makeDestinationTempFileName()
            destFD = tempFileName.withCString { destName in
                openat(destDirFD, destName, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, sourceStat.st_mode & 0o777)
            }
            if destFD >= 0 {
                break
            }
            if errno != EEXIST {
                break
            }
        }

        guard destFD >= 0 else {
            throw destinationCreateError(errno, destURL: destURL)
        }

        var shouldRemoveDestination = true
        defer {
            if shouldRemoveDestination {
                removeDestinationCopyIfStillMatches(
                    destDirFD: destDirFD,
                    destFileName: tempFileName,
                    identity: destinationIdentity(forOpenFD: destFD)
                )
                close(destFD)
            }
        }

        guard lseek(sourceFD, 0, SEEK_SET) >= 0 else {
            throw FormaError.operationFailed("Cannot rewind source file")
        }

        try copyFileDescriptorContents(sourceFD, to: destFD)

        guard fsync(destFD) == 0 else {
            throw FormaError.operationFailed("Destination sync failed during secure copy (errno: \(errno))")
        }

        let identity = try destinationIdentity(for: destFD)
        shouldRemoveDestination = false
        return DestinationCopy(fd: destFD, temporaryFileName: tempFileName, identity: identity)
    }

    private func makeDestinationTempFileName() -> String {
        ".forma-\(UUID().uuidString).tmp"
    }

    private func destinationCreateError(_ errorCode: Int32, destURL: URL) -> FormaError {
        switch errorCode {
        case EEXIST:
            return FormaError.fileSystem(.alreadyExists(destURL.path))
        case EACCES, EPERM:
            return FormaError.permissionDenied(for: destURL.path)
        case ENOSPC:
            return FormaError.fileSystem(.diskFull)
        case ELOOP:
            return FormaError.fileSystem(.symlinkDetected(destURL.path))
        default:
            return FormaError.operationFailed("Cannot create destination file (errno: \(errorCode))")
        }
    }

    private func destinationIdentity(for fd: Int32) throws -> DestinationCopyIdentity {
        var destStat = stat()
        guard fstat(fd, &destStat) == 0 else {
            throw FormaError.operationFailed("Cannot stat destination copy")
        }
        return DestinationCopyIdentity(device: destStat.st_dev, inode: destStat.st_ino)
    }

    private func destinationIdentity(forOpenFD fd: Int32) -> DestinationCopyIdentity? {
        var destStat = stat()
        guard fstat(fd, &destStat) == 0 else {
            return nil
        }
        return DestinationCopyIdentity(device: destStat.st_dev, inode: destStat.st_ino)
    }

    private func promoteTemporaryDestinationCopy(
        _ destinationCopy: DestinationCopy,
        to destURL: URL,
        destDirFD: Int32,
        destFileName: String
    ) throws -> DestinationCopy {
        try verifyDestinationPathStillMatchesCopy(
            destURL: destURL,
            destDirFD: destDirFD,
            destFileName: destinationCopy.temporaryFileName,
            identity: destinationCopy.identity
        )

        let renameErrno = renameUsingDirectoryDescriptors(
            sourceDirFD: destDirFD,
            sourceFileName: destinationCopy.temporaryFileName,
            destDirFD: destDirFD,
            destFileName: destFileName,
            flags: UInt32(RENAME_EXCL)
        )
        guard renameErrno != 0 else {
            return destinationCopy
        }

        if shouldUseFinalCopyPromotionFallback(after: renameErrno) {
            return try copyTemporaryDestinationToFinalDestination(
                destinationCopy,
                to: destURL,
                destDirFD: destDirFD,
                destFileName: destFileName
            )
        }

        try throwRenameError(renameErrno, sourceURL: destURL, destURL: destURL)
        throw FormaError.operationFailed("Temporary destination promote failed with errno \(renameErrno)")
    }

    private func shouldUseFinalCopyPromotionFallback(after errorCode: Int32) -> Bool {
        errorCode == ENOTSUP || errorCode == EOPNOTSUPP || errorCode == EINVAL
    }

    private func copyTemporaryDestinationToFinalDestination(
        _ destinationCopy: DestinationCopy,
        to destURL: URL,
        destDirFD: Int32,
        destFileName: String
    ) throws -> DestinationCopy {
        var tempStat = stat()
        guard fstat(destinationCopy.fd, &tempStat) == 0 else {
            throw FormaError.operationFailed("Cannot stat temporary destination copy")
        }

        let finalFD = destFileName.withCString { destName in
            openat(destDirFD, destName, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, tempStat.st_mode & 0o777)
        }
        guard finalFD >= 0 else {
            throw destinationCreateError(errno, destURL: destURL)
        }

        var shouldRemoveFinalDestination = true
        defer {
            if shouldRemoveFinalDestination {
                removeDestinationCopyIfStillMatches(
                    destDirFD: destDirFD,
                    destFileName: destFileName,
                    identity: destinationIdentity(forOpenFD: finalFD)
                )
                close(finalFD)
            }
        }

        guard lseek(destinationCopy.fd, 0, SEEK_SET) >= 0 else {
            throw FormaError.operationFailed("Cannot rewind temporary destination copy")
        }

        try copyFileDescriptorContents(destinationCopy.fd, to: finalFD)

        guard fsync(finalFD) == 0 else {
            throw FormaError.operationFailed("Final destination sync failed during secure copy (errno: \(errno))")
        }

        let finalIdentity = try destinationIdentity(for: finalFD)
        removeDestinationCopyIfStillMatches(
            destDirFD: destDirFD,
            destFileName: destinationCopy.temporaryFileName,
            identity: destinationCopy.identity
        )

        shouldRemoveFinalDestination = false
        return DestinationCopy(
            fd: finalFD,
            temporaryFileName: destinationCopy.temporaryFileName,
            identity: finalIdentity
        )
    }

    private func verifyDestinationPathStillMatchesCopy(
        destURL: URL,
        destDirFD: Int32,
        destFileName: String,
        identity: DestinationCopyIdentity
    ) throws {
        guard destinationPathMatchesCopy(destDirFD: destDirFD, destFileName: destFileName, identity: identity) else {
            throw FormaError.operationFailed("Destination copy changed during secure move: \(destURL.path)")
        }
    }

    private func destinationPathMatchesCopy(
        destDirFD: Int32,
        destFileName: String,
        identity: DestinationCopyIdentity
    ) -> Bool {
        var currentStat = stat()
        let statResult = destFileName.withCString { destName in
            fstatat(destDirFD, destName, &currentStat, AT_SYMLINK_NOFOLLOW)
        }

        return statResult == 0 &&
            currentStat.st_dev == identity.device &&
            currentStat.st_ino == identity.inode
    }

    private func removeDestinationCopyIfStillMatches(
        destDirFD: Int32,
        destFileName: String,
        identity: DestinationCopyIdentity?
    ) {
        guard let identity,
              destinationPathMatchesCopy(destDirFD: destDirFD, destFileName: destFileName, identity: identity) else {
            return
        }

        destFileName.withCString { destName in
            _ = unlinkat(destDirFD, destName, 0)
        }
    }

    private func copyFileDescriptorContents(_ sourceFD: Int32, to destFD: Int32) throws {
        if fcopyfile(sourceFD, destFD, nil, copyfile_flags_t(COPYFILE_ALL)) == 0 {
            return
        }

        let metadataCopyErrno = errno
        if metadataCopyErrno == ENOSPC {
            throw FormaError.fileSystem(.diskFull)
        }

        guard shouldRetryCopyWithoutMetadata(after: metadataCopyErrno) else {
            throw FormaError.operationFailed("Metadata-preserving copy failed (errno: \(metadataCopyErrno))")
        }

        guard ftruncate(destFD, 0) == 0 else {
            throw FormaError.operationFailed("Cannot reset destination after metadata copy failed (errno: \(errno))")
        }
        guard lseek(sourceFD, 0, SEEK_SET) >= 0,
              lseek(destFD, 0, SEEK_SET) >= 0 else {
            throw FormaError.operationFailed("Cannot rewind files after metadata copy failed")
        }

        guard fcopyfile(sourceFD, destFD, nil, copyfile_flags_t(COPYFILE_DATA)) == 0 else {
            let dataCopyErrno = errno
            if dataCopyErrno == ENOSPC {
                throw FormaError.fileSystem(.diskFull)
            }
            throw FormaError.operationFailed("Data copy failed after metadata fallback (errno: \(dataCopyErrno))")
        }
    }

    private func shouldRetryCopyWithoutMetadata(after errnoValue: Int32) -> Bool {
        [ENOTSUP, EOPNOTSUPP, EINVAL].contains(errnoValue)
    }

    private func openReadableSourceFDMatchingValidatedSource(
        sourceURL: URL,
        validatedSourceFD: Int32,
        sourceDirFD: Int32,
        sourceFileName: String
    ) throws -> Int32 {
        let readableSourceFD = try secureValidateFile(at: sourceURL, access: .readable)

        do {
            try verifyOpenFileDescriptor(
                readableSourceFD,
                matches: validatedSourceFD,
                sourceURL: sourceURL
            )
            try verifySourcePathStillMatchesOpenFile(
                sourceFD: readableSourceFD,
                sourceDirFD: sourceDirFD,
                sourceFileName: sourceFileName,
                sourceURL: sourceURL
            )
            return readableSourceFD
        } catch {
            close(readableSourceFD)
            throw error
        }
    }

    private func verifyOpenFileDescriptor(
        _ sourceFD: Int32,
        matches validatedSourceFD: Int32,
        sourceURL: URL
    ) throws {
        var sourceStat = stat()
        guard fstat(sourceFD, &sourceStat) == 0 else {
            throw FormaError.operationFailed("Cannot stat readable source file")
        }

        var validatedStat = stat()
        guard fstat(validatedSourceFD, &validatedStat) == 0 else {
            throw FormaError.operationFailed("Cannot stat validated source file")
        }

        guard sourceStat.st_dev == validatedStat.st_dev,
              sourceStat.st_ino == validatedStat.st_ino else {
            Log.error("SECURITY: Source changed before cross-device copy: \(sourceURL.path)", category: .security)
            throw FormaError.operationFailed("Source changed during move")
        }
    }

    private func verifySourcePathStillMatchesOpenFile(
        sourceFD: Int32,
        sourceDirFD: Int32,
        sourceFileName: String,
        sourceURL: URL
    ) throws {
        var openStat = stat()
        guard fstat(sourceFD, &openStat) == 0 else {
            throw FormaError.operationFailed("Cannot stat open source file")
        }

        var pathStat = stat()
        let statResult = sourceFileName.withCString { sourceName in
            fstatat(sourceDirFD, sourceName, &pathStat, AT_SYMLINK_NOFOLLOW)
        }

        guard statResult == 0 else {
            let err = errno
            switch err {
            case ENOENT:
                throw FormaError.fileNotFound(sourceURL.path)
            case ELOOP:
                throw FormaError.fileSystem(.symlinkDetected(sourceURL.path))
            case EACCES, EPERM:
                throw FormaError.permissionDenied(for: sourceURL.path)
            default:
                throw FormaError.operationFailed("Cannot verify source path (errno: \(err))")
            }
        }

        guard openStat.st_dev == pathStat.st_dev,
              openStat.st_ino == pathStat.st_ino else {
            Log.error("SECURITY: Source changed after validation: \(sourceURL.path)", category: .security)
            throw FormaError.operationFailed("Source changed during move")
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

    private let fileManager: FileManaging

    init(
        fileManager: FileManaging = FileManager.default,
        clock: Clock = SystemClock(),
        rateLimiter: RateLimiter? = nil
    ) {
        self.fileManager = fileManager
        self.clock = clock
        self.rateLimiter = rateLimiter ?? TaskRateLimiter(delayNanoseconds: Self.operationDelayNanoseconds)
    }

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
              let bookmarkData = BookmarkStoreProvider.shared.loadBookmark(forKey: bookmarkKey) else {
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

        guard let destinationAccess = SecurityScopedAccess(url: destinationFolderURL) else {
            #if DEBUG
            Log.error("BOOKMARK MOVE: Failed to start security-scoped access to \(destinationFolderURL.path)", category: .security)
            #endif
            throw FormaError.permissionDenied(for: destinationFolderURL.path)
        }

        // Also need access to the source folder
        let sourceFolder = sourceURL.deletingLastPathComponent()
        let sourceFolderName = sourceFolder.lastPathComponent
        let resolvedSourceFolderURL = try resolveSourceFolderBookmark(for: sourceFolderName)

        let sourceAccess: SecurityScopedAccess?
        if isAppSandboxed, let sourceFolderURL = resolvedSourceFolderURL {
            guard let access = SecurityScopedAccess(url: sourceFolderURL) else {
                #if DEBUG
                Log.error("BOOKMARK MOVE: Failed to start source folder security scope", category: .security)
                #endif
                throw FormaError.permissionDenied(for: sourceFolderURL.path)
            }
            sourceAccess = access
        } else {
            sourceAccess = nil
        }

        return try withExtendedLifetime(destinationAccess) {
            try withExtendedLifetime(sourceAccess) {
                try moveFileUsingResolvedBookmark(
                    fileItem,
                    sourceURL: sourceURL,
                    destinationFolderURL: destinationFolderURL,
                    destination: destination,
                    modelContext: modelContext
                )
            }
        }
    }

    private func moveFileUsingResolvedBookmark(
        _ fileItem: FileItem,
        sourceURL: URL,
        destinationFolderURL: URL,
        destination: Destination,
        modelContext: ModelContext?
    ) throws -> MoveResult {
        let destinationURL = destinationFolderURL.appendingPathComponent(fileItem.name)

        #if DEBUG
        Log.debug("BOOKMARK MOVE: destination folder: \(destinationFolderURL.path), final: \(destinationURL.path)", category: .fileOperations)
        #endif

        // Ensure destination folder exists
        try fileManager.createDirectory(
            at: destinationFolderURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // If the file is already at the intended destination, treat this as a successful no-op.
        let normalizedSourcePath = sourceURL.standardizedFileURL.resolvingSymlinksInPath().path
        let normalizedDestinationPath = destinationURL.standardizedFileURL.resolvingSymlinksInPath().path
        if normalizedSourcePath == normalizedDestinationPath {
            Log.info("BOOKMARK MOVE NO-OP: File already at destination '\(destinationURL.path)'", category: .fileOperations)
            return MoveResult(
                success: true,
                originalPath: sourceURL.path,
                destinationPath: sourceURL.path,
                error: nil
            )
        }

        // Check if destination already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            throw FormaError.fileSystem(.alreadyExists(destinationURL.path))
        }

        // Perform the move
        do {
            try secureFileMove(from: sourceURL, to: destinationURL)

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
        let startTime = clock.now
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
            await rateLimiter.sleepIfNeeded(after: index, total: limitedFiles.count)
        }

        #if DEBUG
        let elapsed = clock.now.timeIntervalSince(startTime)
        if limitedFiles.count > 10 {
            Log.debug("Batch move finished in \(elapsed)s", category: .fileOperations)
        }
        #endif

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
            var resultingURL: URL?
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

    /// Resets all saved destination folder bookmarks
    func resetDestinationAccess() {
        // Get all bookmark keys from Keychain
        let allKeychainKeys = BookmarkStoreProvider.shared.listAllBookmarkKeys()

        // Remove all destination bookmarks (those starting with our prefix)
        for key in allKeychainKeys where key.hasPrefix(bookmarkPrefix) {
            do {
                try BookmarkStoreProvider.shared.deleteBookmark(forKey: key)
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
        let keychainKeys = BookmarkStoreProvider.shared.listAllBookmarkKeys()
        let destinationKeychainKeys = keychainKeys.filter { $0.hasPrefix(bookmarkPrefix) }

        Log.debug("Keychain (SecureBookmarkStore):", category: .bookmark)
        if destinationKeychainKeys.isEmpty {
            Log.debug("  No destination folder bookmarks found in Keychain", category: .bookmark)
        } else {
            Log.debug("  Found \(destinationKeychainKeys.count) destination bookmark(s)", category: .bookmark)
            for key in destinationKeychainKeys {
                let folderName = key.replacingOccurrences(of: bookmarkPrefix, with: "")
                if let bookmarkData = BookmarkStoreProvider.shared.loadBookmark(forKey: key) {
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
