import XCTest
import SwiftData
@testable import Forma_File_Organizing

/// Integration tests for FileOperationsService using real filesystem operations
final class FileOperationsServiceTests: XCTestCase {
    
    var tempSourceDir: TemporaryDirectory!
    var tempDestDir: TemporaryDirectory!
    
    override func setUp() async throws {
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
        super.tearDown()
    }

    @MainActor
    private func makeServiceAndContext() throws -> (FileOperationsService, ModelContext) {
        let service = FileOperationsService()
        let schema = Schema([FileItem.self, ActivityItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return (service, container.mainContext)
    }
    
    // MARK: - Basic Move Operations
    
    @MainActor
    func testMoveFile_Success() async throws {
        // Skip: This test requires SecureBookmarkStore (Keychain) setup and proper sandboxing
        // which cannot be easily configured in unit tests. Run manually in integration tests.
        throw XCTSkip("Integration test requires SecureBookmarkStore and sandbox setup")
        
        // Given: A source file and destination directory
        let sourceURL = try tempSourceDir.createFile(name: "test.pdf", contents: "PDF content")
        try tempDestDir.createDirectory(name: "Documents")
        
        // Create a FileItem
        let fileItem = createFileItem(
            name: "test.pdf",
            path: sourceURL.path,
            destination: tempDestDir.url.appendingPathComponent("Documents").path
        )
        
        let (service, context) = try makeServiceAndContext()
        
        // Create security-scoped bookmark for destination
        let bookmarkData = try tempDestDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        // Save bookmark with the expected key format
        let topLevelFolder = tempDestDir.url.lastPathComponent
        UserDefaults.standard.set(bookmarkData, forKey: "DestinationFolderBookmark_\(topLevelFolder)")
        
        defer {
            UserDefaults.standard.removeObject(forKey: "DestinationFolderBookmark_\(topLevelFolder)")
        }
        
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
        // Skip: This test requires SecureBookmarkStore (Keychain) setup and proper sandboxing
        throw XCTSkip("Integration test requires SecureBookmarkStore and sandbox setup")
        
        // Given: A source file and nested destination path
        let sourceURL = try tempSourceDir.createFile(name: "document.pdf")
        
        // Create destination path with multiple levels: Documents/Work/Projects
        let nestedPath = "\(tempDestDir.url.lastPathComponent)/Documents/Work/Projects"
        
        let fileItem = createFileItem(
            name: "document.pdf",
            path: sourceURL.path,
            destination: nestedPath
        )
        
        // Setup bookmark
        let bookmarkData = try tempDestDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let topLevelFolder = tempDestDir.url.lastPathComponent
        UserDefaults.standard.set(bookmarkData, forKey: "DestinationFolderBookmark_\(topLevelFolder)")
        
        defer {
            UserDefaults.standard.removeObject(forKey: "DestinationFolderBookmark_\(topLevelFolder)")
        }
        
        // When: Moving the file
        let (service, _) = try makeServiceAndContext()
        let result = try await service.moveFile(fileItem)
        
        // Then: Intermediate directories should be created
        XCTAssertTrue(result.success)
        
        let expectedDir = tempDestDir.url
            .appendingPathComponent("Documents/Work/Projects")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedDir.path))
    }
    
    @MainActor
    func testMoveFile_SourceNotFound() async throws {
        // Given: A FileItem pointing to non-existent file
        let fileItem = createFileItem(
            name: "missing.pdf",
            path: "/nonexistent/missing.pdf",
            destination: "Documents"
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
        // Skip: This test requires SecureBookmarkStore (Keychain) setup and proper sandboxing
        throw XCTSkip("Integration test requires SecureBookmarkStore and sandbox setup")
        
        // Given: Source file and destination that already has a file with same name
        let sourceURL = try tempSourceDir.createFile(name: "duplicate.txt", contents: "source")
        let destDir = try tempDestDir.createDirectory(name: "Documents")
        try "existing".write(
            to: destDir.appendingPathComponent("duplicate.txt"),
            atomically: true,
            encoding: .utf8
        )
        
        let fileItem = createFileItem(
            name: "duplicate.txt",
            path: sourceURL.path,
            destination: "\(tempDestDir.url.lastPathComponent)/Documents"
        )
        
        // Setup bookmark
        let bookmarkData = try tempDestDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let topLevelFolder = tempDestDir.url.lastPathComponent
        UserDefaults.standard.set(bookmarkData, forKey: "DestinationFolderBookmark_\(topLevelFolder)")
        
        defer {
            UserDefaults.standard.removeObject(forKey: "DestinationFolderBookmark_\(topLevelFolder)")
        }
        
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
            if case .operation(.failed(let message, _)) = error {
                XCTAssertTrue(message.contains("destination"))
            } else {
                XCTFail("Expected operation failed error, got \(error)")
            }
        }
    }
    
    // MARK: - Batch Operations
    
    @MainActor
    func testMoveFiles_MultiplFiles() async throws {
        // Skip: This test requires SecureBookmarkStore (Keychain) setup and proper sandboxing
        throw XCTSkip("Integration test requires SecureBookmarkStore and sandbox setup")
        
        // Given: Multiple source files
        let file1URL = try tempSourceDir.createFile(name: "doc1.pdf")
        let file2URL = try tempSourceDir.createFile(name: "doc2.pdf")
        let file3URL = try tempSourceDir.createFile(name: "doc3.pdf")
        
        try tempDestDir.createDirectory(name: "Documents")
        
        let destPath = "\(tempDestDir.url.lastPathComponent)/Documents"
        let fileItems = [
            createFileItem(name: "doc1.pdf", path: file1URL.path, destination: destPath),
            createFileItem(name: "doc2.pdf", path: file2URL.path, destination: destPath),
            createFileItem(name: "doc3.pdf", path: file3URL.path, destination: destPath)
        ]
        
        // Setup bookmark
        let bookmarkData = try tempDestDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let topLevelFolder = tempDestDir.url.lastPathComponent
        UserDefaults.standard.set(bookmarkData, forKey: "DestinationFolderBookmark_\(topLevelFolder)")
        
        defer {
            UserDefaults.standard.removeObject(forKey: "DestinationFolderBookmark_\(topLevelFolder)")
        }
        
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
        // Skip: This test requires SecureBookmarkStore (Keychain) setup and proper sandboxing
        throw XCTSkip("Integration test requires SecureBookmarkStore and sandbox setup")
        
        // Given: Mix of valid and invalid files
        let validURL = try tempSourceDir.createFile(name: "valid.pdf")
        
        try tempDestDir.createDirectory(name: "Documents")
        let destPath = "\(tempDestDir.url.lastPathComponent)/Documents"
        
        let fileItems = [
            createFileItem(name: "valid.pdf", path: validURL.path, destination: destPath),
            createFileItem(name: "missing.pdf", path: "/nonexistent/missing.pdf", destination: destPath)
        ]
        
        // Setup bookmark
        let bookmarkData = try tempDestDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let topLevelFolder = tempDestDir.url.lastPathComponent
        UserDefaults.standard.set(bookmarkData, forKey: "DestinationFolderBookmark_\(topLevelFolder)")
        
        defer {
            UserDefaults.standard.removeObject(forKey: "DestinationFolderBookmark_\(topLevelFolder)")
        }
        
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
        // Skip: This test requires SecureBookmarkStore (Keychain) setup and proper sandboxing
        throw XCTSkip("Integration test requires SecureBookmarkStore and sandbox setup")
        
        // Given: A file and modelContext
        let sourceURL = try tempSourceDir.createFile(name: "tracked.pdf")
        try tempDestDir.createDirectory(name: "Documents")
        
        let fileItem = createFileItem(
            name: "tracked.pdf",
            path: sourceURL.path,
            destination: "\(tempDestDir.url.lastPathComponent)/Documents"
        )
        
        let (service, context) = try makeServiceAndContext()
        
        // Setup bookmark
        let bookmarkData = try tempDestDir.url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let topLevelFolder = tempDestDir.url.lastPathComponent
        UserDefaults.standard.set(bookmarkData, forKey: "DestinationFolderBookmark_\(topLevelFolder)")
        
        defer {
            UserDefaults.standard.removeObject(forKey: "DestinationFolderBookmark_\(topLevelFolder)")
        }
        
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
        destination: String?
    ) -> FileItem {
        let resolvedPath = path.isEmpty ? name : path
        return FileItem(
            path: resolvedPath,
            sizeInBytes: 1024,
            creationDate: Date(),
            destination: destination != nil ? .mockFolder(destination!) : nil,
            status: .ready
        )
    }
}
