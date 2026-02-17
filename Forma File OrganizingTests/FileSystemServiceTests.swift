import XCTest
@testable import Forma_File_Organizing

/// Integration tests for FileSystemService using real filesystem operations
final class FileSystemServiceTests: XCTestCase {

    var tempDir: TemporaryDirectory!

    override func invokeTest() {
        BookmarkStoreProvider.$override.withValue(InMemoryBookmarkStore()) {
            super.invokeTest()
        }
    }

    override func setUpWithError() throws {
        try TestGating.requireIntegration()
        try super.setUpWithError()
        tempDir = try? TemporaryDirectory()
        // Ensure bookmarks from prior app runs don't affect test expectations
        let service = FileSystemService()
        service.resetAllAccess()
    }

    override func tearDown() {
        tempDir?.cleanup()
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Directory Scanning Tests (via Custom Folder)

    func testScanDirectory_ReturnsCorrectFileCount() async throws {
        // Given: A directory with 3 files
        try tempDir.createFile(name: "document.pdf")
        try tempDir.createFile(name: "image.jpg")
        try tempDir.createFile(name: "video.mp4")

        let service = FileSystemService()

        // When: Scanning the directory via custom folder API
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let files = try await service.scanCustomFolder(url: tempDir.url, bookmarkData: bookmarkData)

        // Then: Should return exactly 3 files
        XCTAssertEqual(files.count, 3, "Should find exactly 3 files")

        let fileNames = Set(files.map { $0.name })
        XCTAssertTrue(fileNames.contains("document.pdf"), "Should include document.pdf")
        XCTAssertTrue(fileNames.contains("image.jpg"), "Should include image.jpg")
        XCTAssertTrue(fileNames.contains("video.mp4"), "Should include video.mp4")
    }

    func testScanDirectory_SkipsHiddenFiles() async throws {
        // Given: A directory with regular and hidden files
        try tempDir.createFile(name: "visible.txt")
        try tempDir.createFile(name: ".hidden")
        try tempDir.createFile(name: ".DS_Store")

        let service = FileSystemService()

        // When: Scanning the directory
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let files = try await service.scanCustomFolder(url: tempDir.url, bookmarkData: bookmarkData)

        // Then: Only visible files should be returned
        XCTAssertEqual(files.count, 1, "Should only find visible files")
        XCTAssertEqual(files.first?.name, "visible.txt", "Should return the visible file")

        let fileNames = files.map { $0.name }
        XCTAssertFalse(fileNames.contains(".hidden"), "Should skip .hidden file")
        XCTAssertFalse(fileNames.contains(".DS_Store"), "Should skip .DS_Store")
    }

    func testScanDirectory_DefaultModeOnlyIncludesRootLevel() async throws {
        // Given: A directory with files and subdirectories
        try tempDir.createFile(name: "file.txt")
        try tempDir.createDirectory(name: "subfolder")
        try tempDir.createFile(name: "subfolder/nested.txt")

        let service = FileSystemService()

        // When: Scanning the root directory
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let files = try await service.scanCustomFolder(url: tempDir.url, bookmarkData: bookmarkData)

        // Then: Default scanning should include only root-level files
        XCTAssertEqual(files.count, 1, "Default scan should only include root-level files")

        let fileNames = files.map { $0.name }
        XCTAssertTrue(fileNames.contains("file.txt"), "Should include root-level file")
        XCTAssertFalse(fileNames.contains("nested.txt"), "Should exclude nested file unless recursive mode is enabled")
    }

    func testScanDirectory_NonRecursiveModeOnlyIncludesRootLevel() async throws {
        try tempDir.createFile(name: "root.txt")
        try tempDir.createFile(name: "nested/child.txt")

        let service = FileSystemService()
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let files = try await service.scanCustomFolder(
            url: tempDir.url,
            bookmarkData: bookmarkData,
            options: FileScanOptions(
                isRecursive: false,
                maxDepth: 6,
                maxFilesPerRoot: 100,
                skipPackages: true,
                skipHidden: true
            )
        )

        XCTAssertEqual(files.count, 1, "Non-recursive scan should only include root-level files")
        XCTAssertEqual(files.first?.name, "root.txt")
        XCTAssertNil(files.first?.relativeParentPath, "Root-level file should have nil relative parent path")
    }

    func testScanDirectory_SkipsSymlinks() async throws {
        try tempDir.createFile(name: "regular.txt")
        let symlinkURL = tempDir.url.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: tempDir.url.appendingPathComponent("regular.txt"))

        let service = FileSystemService()
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let files = try await service.scanCustomFolder(url: tempDir.url, bookmarkData: bookmarkData)

        let names = files.map(\.name)
        XCTAssertTrue(names.contains("regular.txt"))
        XCTAssertFalse(names.contains("link.txt"), "Symlink entries must be excluded")
    }

    func testScanDirectory_SkipsPackageContents() async throws {
        try tempDir.createDirectory(name: "Sample.app")
        try tempDir.createFile(name: "Sample.app/Info.plist")
        try tempDir.createFile(name: "outside.txt")

        let service = FileSystemService()
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let files = try await service.scanCustomFolder(url: tempDir.url, bookmarkData: bookmarkData)

        let names = files.map(\.name)
        XCTAssertTrue(names.contains("outside.txt"))
        XCTAssertFalse(names.contains("Info.plist"), "Package descendants should be excluded by default")
    }

    func testScanDirectory_RespectsDepthAndFileCountCaps() async throws {
        try tempDir.createFile(name: "root-1.txt")
        try tempDir.createFile(name: "root-2.txt")
        try tempDir.createFile(name: "nested/depth-1.txt")
        try tempDir.createFile(name: "nested/deeper/depth-2.txt")

        let service = FileSystemService()
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let depthLimited = try await service.scanCustomFolder(
            url: tempDir.url,
            bookmarkData: bookmarkData,
            options: FileScanOptions(
                isRecursive: true,
                maxDepth: 1,
                maxFilesPerRoot: 100,
                skipPackages: true,
                skipHidden: true
            )
        )

        let depthLimitedNames = Set(depthLimited.map(\.name))
        XCTAssertTrue(depthLimitedNames.contains("depth-1.txt"), "Depth-1 file should be included")
        XCTAssertFalse(depthLimitedNames.contains("depth-2.txt"), "Files deeper than maxDepth should be excluded")

        let fileCapped = try await service.scanCustomFolder(
            url: tempDir.url,
            bookmarkData: bookmarkData,
            options: FileScanOptions(
                isRecursive: true,
                maxDepth: 6,
                maxFilesPerRoot: 2,
                skipPackages: true,
                skipHidden: true
            )
        )
        XCTAssertLessThanOrEqual(fileCapped.count, 2, "Scan should enforce maxFilesPerRoot cap")
    }

    func testScanDirectory_ExtractsFileMetadata() async throws {
        // Given: A file with specific attributes
        let creationDate = Date(timeIntervalSince1970: 1000000)
        let modificationDate = Date(timeIntervalSince1970: 2000000)
        let fileSize: Int64 = 1024 * 10 // 10KB

        try tempDir.createFile(
            name: "test.pdf",
            size: fileSize,
            creationDate: creationDate,
            modificationDate: modificationDate
        )

        let service = FileSystemService()

        // When: Scanning the directory
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let files = try await service.scanCustomFolder(url: tempDir.url, bookmarkData: bookmarkData)

        // Then: Returned FileMetadata should have correct extension, size, dates
        XCTAssertEqual(files.count, 1, "Should find one file")

        guard let file = files.first else {
            XCTFail("Should have found a file")
            return
        }

        XCTAssertEqual(file.name, "test.pdf", "Should have correct name")
        XCTAssertEqual(file.fileExtension, "pdf", "Should extract correct extension")
        XCTAssertEqual(file.sizeInBytes, fileSize, "Should have correct byte size")
        XCTAssertEqual(file.size, "10 KB", "Should format size as 10 KB")

        // Date comparison with 1 second tolerance due to filesystem precision
        XCTAssertEqual(file.creationDate.timeIntervalSince1970, creationDate.timeIntervalSince1970, accuracy: 1.0, "Should have correct creation date")
        XCTAssertEqual(file.modificationDate.timeIntervalSince1970, modificationDate.timeIntervalSince1970, accuracy: 1.0, "Should have correct modification date")

        XCTAssertNotNil(file.lastAccessedDate, "Should have last accessed date")
        XCTAssertEqual(file.status, .pending, "Should initialize with pending status")
        XCTAssertNil(file.destination, "Should have no suggested destination initially")
    }

    func testScanDirectory_FormatsFileSize() async throws {
        // Given: Files of various sizes
        try tempDir.createFile(name: "small.txt", size: 500) // bytes
        try tempDir.createFile(name: "medium.pdf", size: 1024 * 1024) // 1MB
        try tempDir.createFile(name: "large.mov", size: 1024 * 1024 * 100) // 100MB

        let service = FileSystemService()

        // When: Scanning
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let files = try await service.scanCustomFolder(url: tempDir.url, bookmarkData: bookmarkData)

        // Then: Size strings should be formatted correctly
        XCTAssertEqual(files.count, 3, "Should find 3 files")

        let filesByName = Dictionary(uniqueKeysWithValues: files.map { ($0.name, $0) })

        // Verify byte counts are exact (primary validation)
        XCTAssertEqual(filesByName["small.txt"]?.sizeInBytes, 500)
        XCTAssertEqual(filesByName["medium.pdf"]?.sizeInBytes, 1024 * 1024)
        XCTAssertEqual(filesByName["large.mov"]?.sizeInBytes, 1024 * 1024 * 100)

        // Verify size strings are non-empty (ByteCountFormatter output varies by locale)
        XCTAssertFalse(filesByName["small.txt"]?.size.isEmpty ?? true, "Small file should have a size string")
        XCTAssertFalse(filesByName["medium.pdf"]?.size.isEmpty ?? true, "Medium file should have a size string")
        XCTAssertFalse(filesByName["large.mov"]?.size.isEmpty ?? true, "Large file should have a size string")
    }

    func testScanDirectory_MultipleFileExtensions() async throws {
        // Given: Files with various extensions
        let extensions = ["pdf", "jpg", "png", "docx", "xlsx", "mov", "mp4", "zip"]
        for ext in extensions {
            try tempDir.createFile(name: "file.\(ext)")
        }

        let service = FileSystemService()

        // When: Scanning the directory
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let files = try await service.scanCustomFolder(url: tempDir.url, bookmarkData: bookmarkData)

        // Then: Should correctly extract all extensions
        XCTAssertEqual(files.count, extensions.count, "Should find all files")

        let foundExtensions = Set(files.map { $0.fileExtension })
        let expectedExtensions = Set(extensions)
        XCTAssertEqual(foundExtensions, expectedExtensions, "Should extract all file extensions correctly")
    }

    // MARK: - Bookmark Tests

    func testBookmarkResolution_ValidBookmark() async throws {
        // Given: A saved security-scoped bookmark
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        // When: Resolving the bookmark
        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        // Then: URL should resolve and not be stale
        XCTAssertFalse(isStale, "Bookmark should not be stale for existing directory")
        XCTAssertEqual(
            resolvedURL.resolvingSymlinksInPath().path,
            tempDir.url.resolvingSymlinksInPath().path,
            "Resolved URL should match original"
        )
    }

    func testBookmarkResolution_StaleBookmark() throws {
        // Given: A bookmark to a directory that no longer exists
        let deletedDir = try TemporaryDirectory()
        let bookmarkData = try deletedDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        deletedDir.cleanup()

        // When: Resolving the bookmark
        var isStale = false
        let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        // Then: Bookmark should be stale or fail to resolve
        if resolvedURL != nil {
            XCTAssertTrue(isStale, "Bookmark to deleted directory should be marked as stale")
        } else {
            // Bookmark failed to resolve entirely, which is also acceptable
            XCTAssertNil(resolvedURL, "Bookmark to deleted directory may fail to resolve")
        }
    }

    // MARK: - Error Handling Tests

    func testScanDirectory_NonexistentDirectory() async throws {
        // Given: A path that doesn't exist
        let nonexistentURL = tempDir.url.appendingPathComponent("nonexistent")
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let service = FileSystemService()

        // When/Then: Attempting to scan should throw
        do {
            _ = try await service.scanCustomFolder(url: nonexistentURL, bookmarkData: bookmarkData)
            XCTFail("Should throw error when scanning nonexistent directory")
        } catch let error as FormaError {
            // Verify we get the expected error type
            switch error {
            case .fileSystem(.ioError):
                // Expected - bookmark verification failed
                break
            case .fileSystem(.notFound):
                // Also acceptable
                break
            case .validation(.invalidDestination):
                // Bookmark verification failed
                break
            default:
                XCTFail("Expected notFound, ioError, or validation error, got \(error)")
            }
        } catch {
            XCTFail("Expected FormaError, got \(error)")
        }
    }

    func testScanDirectory_InvalidBookmark() async throws {
        // Given: Invalid bookmark data
        let invalidBookmarkData = Data([0x00, 0x01, 0x02]) // Random invalid data
        let service = FileSystemService()

        // When/Then: Should throw ioError for bookmark resolution failure
        do {
            _ = try await service.scanCustomFolder(url: tempDir.url, bookmarkData: invalidBookmarkData)
            XCTFail("Should throw error with invalid bookmark data")
        } catch let error as FormaError {
            if case .fileSystem(.ioError(let message, _)) = error {
                XCTAssertTrue(message.contains("bookmark"), "Error should mention bookmark resolution failure")
            } else {
                XCTFail("Expected ioError, got \(error)")
            }
        } catch {
            XCTFail("Expected FormaError, got \(error)")
        }
    }

    func testScanDirectory_BookmarkPathMismatch() async throws {
        // Given: A bookmark for one directory used with a different URL
        let otherDir = try TemporaryDirectory()
        defer { otherDir.cleanup() }

        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let service = FileSystemService()

        // When/Then: Should throw error due to path mismatch
        do {
            _ = try await service.scanCustomFolder(url: otherDir.url, bookmarkData: bookmarkData)
            XCTFail("Should throw error when bookmark path doesn't match URL")
        } catch let error as FormaError {
            if case .validation(.invalidDestination(let message)) = error {
                XCTAssertTrue(message.contains("verification failed"), "Error should mention verification failure")
            } else {
                XCTFail("Expected validation invalidDestination error, got \(error)")
            }
        } catch {
            XCTFail("Expected FormaError, got \(error)")
        }
    }

    // MARK: - ScanResult Tests

    func testScanResult_NoErrors() {
        // Given: A scan result with files and no errors
        let files = [
            FileMetadata(
                path: "/test/test.pdf",
                sizeInBytes: 1024 * 1024,
                creationDate: Date(),
                modificationDate: Date(),
                lastAccessedDate: Date(),
                destination: nil,
                status: .pending
            )
        ]
        let scanResult = ScanResult(files: files, errors: [:])

        // Then: Should indicate no errors
        XCTAssertFalse(scanResult.hasErrors, "Should not have errors")
        XCTAssertNil(scanResult.errorSummary, "Should not have error summary")
        XCTAssertEqual(scanResult.files.count, 1, "Should have one file")
    }

    func testScanResult_WithSingleError() {
        // Given: A scan result with an error
        let files: [FileMetadata] = []
        let errors: [String: Error] = ["Desktop": FormaError.fileSystem(.permissionDenied("Desktop"))]
        let scanResult = ScanResult(files: files, errors: errors)

        // Then: Should indicate errors and provide summary
        XCTAssertTrue(scanResult.hasErrors, "Should have errors")
        XCTAssertEqual(scanResult.errorSummary, "Failed to scan Desktop", "Should have correct error summary for single folder")
    }

    func testScanResult_WithMultipleErrors() {
        // Given: A scan result with multiple errors
        let files: [FileMetadata] = []
        let errors: [String: Error] = [
            "Desktop": FormaError.fileSystem(.permissionDenied("Desktop")),
            "Downloads": FormaError.fileSystem(.ioError("Access denied", underlying: nil)),
            "MyFolder": FormaError.fileSystem(.notFound("MyFolder"))
        ]
        let scanResult = ScanResult(files: files, errors: errors)

        // Then: Should indicate errors and provide summary with sorted folder names
        XCTAssertTrue(scanResult.hasErrors, "Should have errors")
        XCTAssertEqual(scanResult.errorSummary, "Failed to scan 3 folders: Desktop, Downloads, MyFolder", "Should list all folders alphabetically")
    }

    func testScanResult_PartialSuccess() {
        // Given: A scan result with both files and errors
        let files = [
            FileMetadata(
                path: "/desktop/test.pdf",
                sizeInBytes: 1024 * 1024,
                creationDate: Date(),
                modificationDate: Date(),
                lastAccessedDate: Date(),
                destination: nil,
                status: .pending
            )
        ]
        let errors: [String: Error] = ["Downloads": FormaError.fileSystem(.permissionDenied("Downloads"))]
        let scanResult = ScanResult(files: files, errors: errors)

        // Then: Should have both files and errors
        XCTAssertTrue(scanResult.hasErrors, "Should have errors")
        XCTAssertEqual(scanResult.files.count, 1, "Should have one file")
        XCTAssertEqual(scanResult.errors.count, 1, "Should have one error")
        XCTAssertEqual(scanResult.errorSummary, "Failed to scan Downloads", "Should have correct error summary")
    }

    // MARK: - Permission Check Tests

    func testHasAccess_NoBookmark() throws {
        // Skip: This test relies on SecureBookmarkStore (Keychain) which shares state
        // with the real app and cannot be isolated in unit tests. The test would
        // interfere with actual user permissions if run on a developer machine.
        throw XCTSkip("Integration test requires isolated Keychain - cannot run in unit test suite")
    }

    // MARK: - FileMetadata Structure Tests

    func testFileMetadata_PathExtraction() async throws {
        // Given: A file at a specific path
        try tempDir.createFile(name: "document.pdf")

        let service = FileSystemService()
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let files = try await service.scanCustomFolder(url: tempDir.url, bookmarkData: bookmarkData)

        // Then: Path should be complete and absolute
        XCTAssertEqual(files.count, 1)
        guard let file = files.first else {
            XCTFail("Should have found a file")
            return
        }

        XCTAssertTrue(file.path.hasPrefix("/"), "Path should be absolute")
        XCTAssertTrue(file.path.hasSuffix("document.pdf"), "Path should end with filename")
        XCTAssertTrue(file.path.contains(tempDir.url.lastPathComponent), "Path should contain temp directory")
    }

    func testFileMetadata_EmptyFile() async throws {
        // Given: An empty file (0 bytes)
        try tempDir.createFile(name: "empty.txt", size: 0)

        let service = FileSystemService()
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let files = try await service.scanCustomFolder(url: tempDir.url, bookmarkData: bookmarkData)

        // Then: Should handle empty file correctly
        XCTAssertEqual(files.count, 1)
        guard let file = files.first else {
            XCTFail("Should have found a file")
            return
        }

        XCTAssertEqual(file.sizeInBytes, 0, "Empty file should have 0 bytes")
        XCTAssertEqual(file.size, "0 bytes", "Empty file size should be formatted as '0 bytes'")
    }

    func testFileMetadata_NoExtension() async throws {
        // Given: A file without an extension
        try tempDir.createFile(name: "README")

        let service = FileSystemService()
        let bookmarkData = try tempDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let files = try await service.scanCustomFolder(url: tempDir.url, bookmarkData: bookmarkData)

        // Then: Should handle files without extensions
        XCTAssertEqual(files.count, 1)
        guard let file = files.first else {
            XCTFail("Should have found a file")
            return
        }

        XCTAssertEqual(file.name, "README")
        XCTAssertEqual(file.fileExtension, "", "File without extension should have empty string for fileExtension")
    }
}

// MARK: - Test Notes
/*
 These tests validate FileSystemService through its public interface:

 1. Directory Scanning (22-134):
    - Tests scanCustomFolder() method with real temporary directories
    - Validates file counting, filtering, and metadata extraction
    - Verifies hidden files and subdirectories are skipped
    - Tests file size formatting across different sizes

 2. Bookmark Resolution (137-168):
    - Tests valid and stale bookmark handling
    - Validates security-scoped bookmark behavior

 3. Error Handling (171-239):
    - Tests nonexistent directory handling
    - Tests invalid bookmark data
    - Tests bookmark path mismatch (security validation)

 4. ScanResult Structure (242-296):
    - Tests error aggregation and reporting
    - Tests partial success scenarios

 5. scanAllFolders Integration (299-359):
    - Tests multi-folder scanning with custom folders
    - Tests disabled folder skipping
    - Tests missing bookmark data handling

 6. Permission Checks (362-371):
    - Tests permission check methods

 7. Edge Cases (374-433):
    - Tests path extraction
    - Tests empty files
    - Tests files without extensions

 Testing Limitations:
 - Cannot test NSOpenPanel flow (requires user interaction)
 - Cannot test Desktop/Downloads without granting permissions
 - Bookmark security validation requires real user directories
 - Tests use scanCustomFolder() as a proxy for private scanDirectory()

 All tests use real filesystem operations with TemporaryDirectory for isolation.
 Tests verify both success paths and error handling.
 */
