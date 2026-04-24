import XCTest
import SwiftData
@testable import Forma_File_Organizing

/// Integration tests for FileOperationsService using real filesystem operations
final class FileOperationsServiceTests: XCTestCase {
	    
	    var tempSourceDir: TemporaryDirectory!
	    var tempDestDir: TemporaryDirectory!
	    private var modelContainer: ModelContainer?

    override func invokeTest() {
        BookmarkStoreProvider.$override.withValue(InMemoryBookmarkStore()) {
            super.invokeTest()
        }
    }
    
    override func setUp() async throws {
        try TestGating.requireIntegration()
        try await super.setUp()

        // Create temporary directories for source and destination
        tempSourceDir = try TemporaryDirectory()
        tempDestDir = try TemporaryDirectory()
    }
    
	    override func tearDown() {
	        tempSourceDir?.cleanup()
	        tempDestDir?.cleanup()
	        tempSourceDir = nil
	        tempDestDir = nil
	        modelContainer = nil
	        super.tearDown()
	    }

	    @MainActor
	    private func makeServiceAndContext() throws -> (FileOperationsService, ModelContext) {
	        let service = FileOperationsService()
	        let schema = Schema([FileItem.self, ActivityItem.self])
	        let config = ModelConfiguration(isStoredInMemoryOnly: true)
	        let container = try ModelContainer(for: schema, configurations: [config])
	        modelContainer = container
	        return (service, container.mainContext)
	    }
    
    // MARK: - Basic Move Operations
    
    @MainActor
    func testMoveFile_Success() async throws {
        // Given: A source file and destination directory
        let sourceURL = try tempSourceDir.createFile(name: "test.pdf", contents: "PDF content")
        try tempDestDir.createDirectory(name: "Documents")
        
        // Create a FileItem
        let destinationURL = tempDestDir.url.appendingPathComponent("Documents")
        let destination = try Destination.folder(from: destinationURL)
        let fileItem = createFileItem(
            name: "test.pdf",
            path: sourceURL.path,
            destination: destination
        )
        
        let (service, context) = try makeServiceAndContext()
        
        // When: Moving the file
        let result = try await service.moveFile(fileItem, modelContext: context)
        
        // Then: Operation should succeed
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        
        // Source file should no longer exist
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        
        // Destination file should exist
        if let destPath = result.destinationPath {
            XCTAssertTrue(FileManager.default.fileExists(atPath: destPath))
        } else {
            XCTFail("Destination path not set")
        }
    }
    
    @MainActor
    func testMoveFile_CreatesIntermediateDirectories() async throws {
        // Given: A source file and nested destination path
        let sourceURL = try tempSourceDir.createFile(name: "document.pdf")
        
        // Create base folder and seed a bookmark for Documents
        let documentsDir = try tempDestDir.createDirectory(name: "Documents")
        let documentsBookmark = try documentsDir.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try BookmarkStoreProvider.shared.saveBookmark(
            documentsBookmark,
            forKey: FormaConfig.Security.documentsBookmarkKey
        )

        let fileItem = createFileItem(
            name: "document.pdf",
            path: sourceURL.path,
            destination: .folder(bookmark: Data(), displayName: "Documents/Work/Projects")
        )
        
        // When: Moving the file
        let (service, _) = try makeServiceAndContext()
        let result = try await service.moveFile(fileItem)
        
        // Then: Intermediate directories should be created
        XCTAssertTrue(result.success)
        
        let expectedDir = documentsDir.appendingPathComponent("Work/Projects")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedDir.path))
    }
    
    @MainActor
    func testMoveFile_SourceNotFound() async throws {
        // Given: A FileItem pointing to non-existent file
        let fileItem = createFileItem(
            name: "missing.pdf",
            path: "/nonexistent/missing.pdf",
            destination: .trash
        )
        
        // When/Then: Should throw notFound error
        do {
            let (service, _) = try makeServiceAndContext()
            _ = try await service.moveFile(fileItem)
            XCTFail("Expected error to be thrown")
        } catch let error as FormaError {
            if case .fileSystem(.notFound) = error {
                // Success
            } else {
                XCTFail("Expected fileSystem notFound error, got \(error)")
            }
        }
    }
    
    @MainActor
    func testMoveFile_DestinationExists() async throws {
        // Given: Source file and destination that already has a file with same name
        let sourceURL = try tempSourceDir.createFile(name: "duplicate.txt", contents: "source")
        let destDir = try tempDestDir.createDirectory(name: "Documents")
        try "existing".write(
            to: destDir.appendingPathComponent("duplicate.txt"),
            atomically: true,
            encoding: .utf8
        )
        
        let destination = try Destination.folder(from: destDir)
        let fileItem = createFileItem(
            name: "duplicate.txt",
            path: sourceURL.path,
            destination: destination
        )
        
        // When/Then: Should throw alreadyExists error
        do {
            let (service, _) = try makeServiceAndContext()
            _ = try await service.moveFile(fileItem)
            XCTFail("Expected error to be thrown")
        } catch let error as FormaError {
            if case .fileSystem(.alreadyExists) = error {
                // Success
            } else {
                XCTFail("Expected fileSystem alreadyExists error, got \(error)")
            }
        }
    }

    @MainActor
    func testMoveFile_DestinationExistsRepeatedly_StaysOnAlreadyExistsPath() async throws {
        // Given: Source file and destination collision
        let sourceURL = try tempSourceDir.createFile(name: "collision.txt", contents: "source")
        let destDir = try tempDestDir.createDirectory(name: "Documents")
        try "existing".write(
            to: destDir.appendingPathComponent("collision.txt"),
            atomically: true,
            encoding: .utf8
        )

        let destination = try Destination.folder(from: destDir)
        let fileItem = createFileItem(
            name: "collision.txt",
            path: sourceURL.path,
            destination: destination
        )

        let (service, _) = try makeServiceAndContext()

        // We cannot directly observe URL security-scope stop calls in XCTest.
        // This regression repeatedly exercises an error path that occurs after
        // destination-folder access begins. If cleanup regresses, this path can
        // eventually shift to permission/access failures.
        for _ in 0..<64 {
            do {
                _ = try await service.moveFile(fileItem)
                XCTFail("Expected alreadyExists error to be thrown")
            } catch let error as FormaError {
                if case .fileSystem(.alreadyExists) = error {
                    // Expected collision path
                } else {
                    XCTFail("Expected fileSystem alreadyExists error, got \(error)")
                }
            }
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    @MainActor
    func testMoveFile_WhenSourceAlreadyAtDestination_ReturnsSuccessfulNoOp() async throws {
        // Given: Source file already lives in the destination folder
        let sourceURL = try tempSourceDir.createFile(name: "already-there.txt", contents: "content")
        let destination = try Destination.folder(from: tempSourceDir.url)
        let fileItem = createFileItem(
            name: "already-there.txt",
            path: sourceURL.path,
            destination: destination
        )

        // When: Moving the file
        let (service, _) = try makeServiceAndContext()
        let result = try await service.moveFile(fileItem)

        // Then: Operation should be treated as successful no-op
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.destinationPath, sourceURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), "No-op should not remove the existing file")
    }

    @MainActor
    func testMoveFile_DestinationContainsIdenticalFile_PreservesSourceAndThrowsAlreadyExists() async throws {
        // Given: Source and destination contain identical files with the same name
        let sourceURL = try tempSourceDir.createFile(name: "dedupe.txt", contents: "identical")
        let destDir = try tempDestDir.createDirectory(name: "Documents")
        let destinationURL = destDir.appendingPathComponent("dedupe.txt")
        try "identical".write(to: destinationURL, atomically: true, encoding: .utf8)

        let destination = try Destination.folder(from: destDir)
        let fileItem = createFileItem(
            name: "dedupe.txt",
            path: sourceURL.path,
            destination: destination
        )

        // When/Then: Organizing should preserve the source and reject the collision
        let (service, _) = try makeServiceAndContext()
        do {
            _ = try await service.moveFile(fileItem)
            XCTFail("Expected alreadyExists error to be thrown")
        } catch let error as FormaError {
            if case .fileSystem(.alreadyExists) = error {
                // Expected collision path
            } else {
                XCTFail("Expected fileSystem alreadyExists error, got \(error)")
            }
        }

        // Then: Source duplicate should not be removed based on a non-atomic equivalence check
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), "Source duplicate should be preserved")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path), "Destination file should remain")
    }

    @MainActor
    func testMoveFile_BookmarkMoveDoesNotUsePathStringMoveItem() async throws {
        // Given: A source file, bookmark-backed destination, and spy file manager
        let sourceURL = try tempSourceDir.createFile(name: "secure-move.txt", contents: "secure")
        let destDir = try tempDestDir.createDirectory(name: "Documents")
        let destination = try Destination.folder(from: destDir)
        let fileItem = createFileItem(
            name: "secure-move.txt",
            path: sourceURL.path,
            destination: destination
        )

        let spyFileManager = MoveTrackingFileManager()
        let service = FileOperationsService(fileManager: spyFileManager)

        // When: Moving the file through the production bookmark path
        let result = try await service.moveFile(fileItem)

        // Then: The move succeeds without falling back to FileManager.moveItem(at:to:)
        XCTAssertTrue(result.success)
        XCTAssertEqual(spyFileManager.moveItemCallCount, 0, "Bookmark moves should route through the secure FD-based move path")
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("secure-move.txt").path))
    }

    @MainActor
    func testMoveFile_SameVolumeUnreadableSourceMovesWithoutReadPermission() async throws {
        // Given: A source file the user can rename but not read directly
        let sourceURL = try tempSourceDir.createFile(name: "rename-only.txt", contents: "private")
        let destDir = try tempDestDir.createDirectory(name: "Documents")
        let destinationURL = destDir.appendingPathComponent("rename-only.txt")

        try FileManager.default.setAttributes([.posixPermissions: 0o200], ofItemAtPath: sourceURL.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: sourceURL.path)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationURL.path)
        }

        let destination = try Destination.folder(from: destDir)
        let fileItem = createFileItem(
            name: "rename-only.txt",
            path: sourceURL.path,
            destination: destination
        )

        // When: Moving on the same volume
        let (service, _) = try makeServiceAndContext()
        let result = try await service.moveFile(fileItem)

        // Then: Rename succeeds without requiring source read permission
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @MainActor
    func testMoveFile_SameVolumeUnopenableSourceFailsClosed() async throws {
        // Given: A source file that cannot be opened but can still be renamed by directory permission
        let sourceURL = try tempSourceDir.createFile(name: "directory-rename-only.txt", contents: "private")
        let destDir = try tempDestDir.createDirectory(name: "Documents")
        let destinationURL = destDir.appendingPathComponent("directory-rename-only.txt")

        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: sourceURL.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: sourceURL.path)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationURL.path)
        }

        let destination = try Destination.folder(from: destDir)
        let fileItem = createFileItem(
            name: "directory-rename-only.txt",
            path: sourceURL.path,
            destination: destination
        )

        // When: Moving on the same volume
        let (service, _) = try makeServiceAndContext()

        do {
            _ = try await service.moveFile(fileItem)
            XCTFail("Expected permissionDenied for an unopenable source")
        } catch let error as FormaError {
            if case .fileSystem(.permissionDenied) = error {
                // Expected fail-closed path
            } else {
                XCTFail("Expected permissionDenied error, got \(error)")
            }
        }

        // Then: The service fails closed instead of moving an unpinned source path
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @MainActor
    func testMoveFile_SourceParentWithoutReadPermissionStillMoves() async throws {
        // Given: A source directory that allows search/write but not directory listing
        let sourceDir = try tempSourceDir.createDirectory(name: "RenameOnlySourceParent")
        let sourceURL = sourceDir.appendingPathComponent("search-only-source.txt")
        try "private".write(to: sourceURL, atomically: true, encoding: .utf8)

        let destDir = try tempDestDir.createDirectory(name: "Documents")
        let destinationURL = destDir.appendingPathComponent("search-only-source.txt")

        try FileManager.default.setAttributes([.posixPermissions: 0o300], ofItemAtPath: sourceDir.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sourceDir.path)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationURL.path)
        }

        let destination = try Destination.folder(from: destDir)
        let fileItem = createFileItem(
            name: "search-only-source.txt",
            path: sourceURL.path,
            destination: destination
        )

        // When: Moving out of a write+execute-only source directory
        let (service, _) = try makeServiceAndContext()
        let result = try await service.moveFile(fileItem)

        // Then: Search-only directory descriptors do not require list permission
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @MainActor
    func testMoveFile_DestinationParentWithoutReadPermissionStillMoves() async throws {
        // Given: A destination directory that allows search/write but not directory listing
        let sourceURL = try tempSourceDir.createFile(name: "search-only-destination.txt", contents: "private")
        let destDir = try tempDestDir.createDirectory(name: "SearchOnlyDocuments")
        let destinationURL = destDir.appendingPathComponent("search-only-destination.txt")
        let destination = try Destination.folder(from: destDir)

        try FileManager.default.setAttributes([.posixPermissions: 0o300], ofItemAtPath: destDir.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: destDir.path)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationURL.path)
        }

        let fileItem = createFileItem(
            name: "search-only-destination.txt",
            path: sourceURL.path,
            destination: destination
        )

        // When: Moving into a write+execute-only destination directory
        let (service, _) = try makeServiceAndContext()
        let result = try await service.moveFile(fileItem)

        // Then: Search-only directory descriptors do not require list permission
        XCTAssertTrue(result.success)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @MainActor
    func testSecureMoveOnDisk_SourceParentSymlinkIsRejected() throws {
        // Given: The source path reaches a real file through a symlinked parent directory
        let realSourceDir = try tempSourceDir.createDirectory(name: "RealSourceParent")
        let sourceURL = realSourceDir.appendingPathComponent("linked-source.txt")
        try "private".write(to: sourceURL, atomically: true, encoding: .utf8)

        let linkedSourceDir = tempSourceDir.url.appendingPathComponent("LinkedSourceParent")
        try FileManager.default.createSymbolicLink(at: linkedSourceDir, withDestinationURL: realSourceDir)

        let symlinkedSourceURL = linkedSourceDir.appendingPathComponent("linked-source.txt")
        let destDir = try tempDestDir.createDirectory(name: "Documents")
        let destinationURL = destDir.appendingPathComponent("linked-source.txt")

        let service = FileOperationsService()

        // When/Then: The secure path rejects the symlinked parent before moving
        XCTAssertThrowsError(
            try service.secureMoveOnDisk(from: symlinkedSourceURL.path, to: destinationURL.path)
        ) { error in
            guard let formaError = error as? FormaError,
                  case .fileSystem(.symlinkDetected) = formaError else {
                return XCTFail("Expected symlinkDetected error, got \(error)")
            }
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @MainActor
    func testSecureMoveOnDisk_DestinationParentSymlinkIsRejected() throws {
        // Given: The destination path reaches a real folder through a symlinked parent directory
        let sourceURL = try tempSourceDir.createFile(name: "linked-destination.txt", contents: "private")
        let realDestDir = try tempDestDir.createDirectory(name: "RealDocuments")
        let linkedDestDir = tempDestDir.url.appendingPathComponent("LinkedDocuments")
        try FileManager.default.createSymbolicLink(at: linkedDestDir, withDestinationURL: realDestDir)

        let destinationURL = linkedDestDir.appendingPathComponent("linked-destination.txt")
        let realDestinationURL = realDestDir.appendingPathComponent("linked-destination.txt")

        let service = FileOperationsService()

        // When/Then: The secure path rejects the symlinked parent before moving
        XCTAssertThrowsError(
            try service.secureMoveOnDisk(from: sourceURL.path, to: destinationURL.path)
        ) { error in
            guard let formaError = error as? FormaError,
                  case .fileSystem(.symlinkDetected) = formaError else {
                return XCTFail("Expected symlinkDetected error, got \(error)")
            }
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: realDestinationURL.path))
    }

    @MainActor
    func testSecureMoveOnDisk_DestinationAncestorSymlinkIsRejected() throws {
        // Given: The destination path has a symlinked ancestor above the final parent directory
        let sourceURL = try tempSourceDir.createFile(name: "linked-ancestor.txt", contents: "private")
        let realAncestor = try tempDestDir.createDirectory(name: "RealAncestor")
        let realDestDir = realAncestor.appendingPathComponent("NestedDocuments")
        try FileManager.default.createDirectory(at: realDestDir, withIntermediateDirectories: true)

        let linkedAncestor = tempDestDir.url.appendingPathComponent("LinkedAncestor")
        try FileManager.default.createSymbolicLink(at: linkedAncestor, withDestinationURL: realAncestor)

        let destinationURL = linkedAncestor
            .appendingPathComponent("NestedDocuments")
            .appendingPathComponent("linked-ancestor.txt")
        let realDestinationURL = realDestDir.appendingPathComponent("linked-ancestor.txt")

        let service = FileOperationsService()

        // When/Then: Component-level checks reject the symlink before opening the directory descriptor
        XCTAssertThrowsError(
            try service.secureMoveOnDisk(from: sourceURL.path, to: destinationURL.path)
        ) { error in
            guard let formaError = error as? FormaError,
                  case .fileSystem(.symlinkDetected) = formaError else {
                return XCTFail("Expected symlinkDetected error, got \(error)")
            }
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: realDestinationURL.path))
    }

    @MainActor
    func testSecureMoveOnDisk_SystemTemporaryDirectoryAliasIsAllowed() throws {
        // Given: macOS exposes common temporary paths through fixed system symlinks such as /var and /tmp
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("FormaSystemAlias-\(UUID().uuidString)")
        let sourceDir = tempRoot.appendingPathComponent("Source")
        let destDir = tempRoot.appendingPathComponent("Destination")

        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sourceURL = sourceDir.appendingPathComponent("temp-alias.txt")
        let destinationURL = destDir.appendingPathComponent("temp-alias.txt")
        try "temporary".write(to: sourceURL, atomically: true, encoding: .utf8)

        let service = FileOperationsService()

        // When: Moving through the system temp alias
        try service.secureMoveOnDisk(from: sourceURL.path, to: destinationURL.path)

        // Then: The fixed system alias is normalized, while arbitrary symlink ancestors remain rejected
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @MainActor
    func testSecureMoveOnDisk_DotDotDoesNotBypassSymlinkAncestorCheck() throws {
        // Given: The destination path includes a symlink component hidden behind a later ".." segment
        let sourceURL = try tempSourceDir.createFile(name: "dotdot-bypass.txt", contents: "private")
        let safeDir = try tempDestDir.createDirectory(name: "Safe")
        let safeLanding = safeDir.appendingPathComponent("Landing")
        let evilLanding = tempDestDir.url
            .appendingPathComponent("Outside")
            .appendingPathComponent("Landing")

        try FileManager.default.createDirectory(at: safeLanding, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: evilLanding, withIntermediateDirectories: true)

        let linkedAncestor = safeDir.appendingPathComponent("LinkedAncestor")
        try FileManager.default.createSymbolicLink(at: linkedAncestor, withDestinationURL: evilLanding)

        let destinationURL = linkedAncestor
            .appendingPathComponent("..")
            .appendingPathComponent("Landing")
            .appendingPathComponent("dotdot-bypass.txt")
        let safeDestinationURL = safeLanding.appendingPathComponent("dotdot-bypass.txt")
        let evilDestinationURL = evilLanding.appendingPathComponent("dotdot-bypass.txt")

        let service = FileOperationsService()

        // When/Then: Lexical normalization must not erase the symlink before the component walk sees it
        XCTAssertThrowsError(
            try service.secureMoveOnDisk(from: sourceURL.path, to: destinationURL.path)
        ) { error in
            guard let formaError = error as? FormaError,
                  case .fileSystem(.symlinkDetected) = formaError else {
                return XCTFail("Expected symlinkDetected error, got \(error)")
            }
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: safeDestinationURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: evilDestinationURL.path))
    }

    @MainActor
    func testMoveFile_DestinationReplacementDuringDuplicateCheckDoesNotDeleteSource() async throws {
        // Given: Source and destination start with identical contents
        let sourceURL = try tempSourceDir.createFile(name: "race.txt", contents: "identical")
        let destDir = try tempDestDir.createDirectory(name: "Documents")
        let destinationURL = destDir.appendingPathComponent("race.txt")
        try "identical".write(to: destinationURL, atomically: true, encoding: .utf8)

        let destination = try Destination.folder(from: destDir)
        let fileItem = createFileItem(
            name: "race.txt",
            path: sourceURL.path,
            destination: destination
        )

        let spyFileManager = MoveTrackingFileManager()
        spyFileManager.beforeRemoveItem = { url in
            if url.path == sourceURL.path {
                try "replaced".write(to: destinationURL, atomically: true, encoding: .utf8)
            }
        }
        let service = FileOperationsService(fileManager: spyFileManager)

        // When/Then: The service should reject the collision without deleting the source
        do {
            _ = try await service.moveFile(fileItem)
            XCTFail("Expected alreadyExists error to be thrown")
        } catch let error as FormaError {
            if case .fileSystem(.alreadyExists) = error {
                // Expected collision path
            } else {
                XCTFail("Expected fileSystem alreadyExists error, got \(error)")
            }
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), "Source must survive destination replacement races")
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), "identical")
    }
    
    @MainActor
    func testMoveFile_NoDestinationSpecified() async throws {
        // Given: A FileItem without destination
        let sourceURL = try tempSourceDir.createFile(name: "test.pdf")
        let fileItem = createFileItem(
            name: "test.pdf",
            path: sourceURL.path,
            destination: nil
        )
        
        // When/Then: Should throw operation failed error
        do {
            let (service, _) = try makeServiceAndContext()
            _ = try await service.moveFile(fileItem)
            XCTFail("Expected error to be thrown")
        } catch let error as FormaError {
            if case .operation(.notReady(let message)) = error {
                XCTAssertTrue(message.contains("destination"))
            } else {
                XCTFail("Expected notReady error, got \(error)")
            }
        }
    }
    
    // MARK: - Batch Operations
    
    @MainActor
    func testMoveFiles_MultiplFiles() async throws {
        // Given: Multiple source files
        let file1URL = try tempSourceDir.createFile(name: "doc1.pdf")
        let file2URL = try tempSourceDir.createFile(name: "doc2.pdf")
        let file3URL = try tempSourceDir.createFile(name: "doc3.pdf")
        
        let destDir = try tempDestDir.createDirectory(name: "Documents")
        let destination = try Destination.folder(from: destDir)
        let fileItems = [
            createFileItem(name: "doc1.pdf", path: file1URL.path, destination: destination),
            createFileItem(name: "doc2.pdf", path: file2URL.path, destination: destination),
            createFileItem(name: "doc3.pdf", path: file3URL.path, destination: destination)
        ]
        
        // When: Moving all files
        let (service, _) = try makeServiceAndContext()
        let results = await service.moveFiles(fileItems)
        
        // Then: All operations should succeed
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.success })
        XCTAssertTrue(results.allSatisfy { $0.error == nil })
    }
    
    @MainActor
    func testMoveFiles_PartialFailure() async throws {
        // Given: Mix of valid and invalid files
        let validURL = try tempSourceDir.createFile(name: "valid.pdf")
        
        let destDir = try tempDestDir.createDirectory(name: "Documents")
        let destination = try Destination.folder(from: destDir)
        
        let fileItems = [
            createFileItem(name: "valid.pdf", path: validURL.path, destination: destination),
            createFileItem(name: "missing.pdf", path: "/nonexistent/missing.pdf", destination: destination)
        ]
        
        // When: Moving files
        let (service, _) = try makeServiceAndContext()
        let results = await service.moveFiles(fileItems)
        
        // Then: One should succeed, one should fail
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.filter { $0.success }.count, 1)
        XCTAssertEqual(results.filter { !$0.success }.count, 1)
        
        // Failed result should have error
        let failedResult = results.first { !$0.success }
        XCTAssertNotNil(failedResult?.error)
    }
    
    // MARK: - Activity Tracking
    
    @MainActor
    func testMoveFile_TracksActivity() async throws {
        // Given: A file and modelContext
        let sourceURL = try tempSourceDir.createFile(name: "tracked.pdf")
        let destDir = try tempDestDir.createDirectory(name: "Documents")
        let destination = try Destination.folder(from: destDir)
        
        let fileItem = createFileItem(
            name: "tracked.pdf",
            path: sourceURL.path,
            destination: destination
        )
        
        let (service, context) = try makeServiceAndContext()
        
        // When: Moving the file with context
        _ = try await service.moveFile(fileItem, modelContext: context)
        
        // Then: Activity should be tracked
        let descriptor = FetchDescriptor<ActivityItem>()
        let activities = try context.fetch(descriptor)
        
        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities.first?.fileName, "tracked.pdf")
        XCTAssertEqual(activities.first?.activityType, .fileOrganized)
    }
    
    // MARK: - Helper Methods
    
    private func createFileItem(
        name: String,
        path: String,
        destination: Destination?
    ) -> FileItem {
        let resolvedPath = path.isEmpty ? name : path
        return FileItem(
            path: resolvedPath,
            sizeInBytes: 1024,
            creationDate: Date(),
            destination: destination,
            status: .ready
        )
    }

    private final class MoveTrackingFileManager: FileManaging {
        private let base = FileManager.default
        var moveItemCallCount = 0
        var beforeRemoveItem: ((URL) throws -> Void)?

        var homeDirectoryForCurrentUser: URL {
            base.homeDirectoryForCurrentUser
        }

        func fileExists(atPath path: String) -> Bool {
            base.fileExists(atPath: path)
        }

        func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
            base.fileExists(atPath: path, isDirectory: isDirectory)
        }

        func createDirectory(at url: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey: Any]?) throws {
            try base.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories, attributes: attributes)
        }

        func removeItem(at url: URL) throws {
            try beforeRemoveItem?(url)
            try base.removeItem(at: url)
        }

        func moveItem(at srcURL: URL, to dstURL: URL) throws {
            moveItemCallCount += 1
            try base.moveItem(at: srcURL, to: dstURL)
        }

        func copyItem(at srcURL: URL, to dstURL: URL) throws {
            try base.copyItem(at: srcURL, to: dstURL)
        }

        func trashItem(at url: URL, resultingItemURL: inout URL?) throws {
            var nsURL: NSURL?
            try base.trashItem(at: url, resultingItemURL: &nsURL)
            resultingItemURL = nsURL as URL?
        }
    }
}
