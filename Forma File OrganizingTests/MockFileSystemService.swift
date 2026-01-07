import Foundation
@testable import Forma_File_Organizing

final class MockFileSystemService: FileSystemServiceProtocol, @unchecked Sendable {
    var mockFiles: [FileMetadata] = []
    var shouldSucceed: Bool = true
    var mockErrors: [String: Error] = [:]  // For testing error scenarios

    var hasDesktop: Bool = false
    var hasDownloads: Bool = false
    var hasDocuments: Bool = false
    var hasPictures: Bool = false
    var hasMusic: Bool = false

    func getMigrationState() -> BookmarkMigrationState? {
        nil
    }

    func resetDesktopAccess() {
        // No-op for tests
    }

    func scanDesktop() async throws -> [FileMetadata] {
        if shouldSucceed { return mockFiles } else { throw FormaError.fileSystem(.ioError("Mock error", underlying: nil)) }
    }

    func scanDownloads() async throws -> [FileMetadata] {
        if shouldSucceed { return mockFiles } else { throw FormaError.fileSystem(.ioError("Mock error", underlying: nil)) }
    }

    func scanDocuments() async throws -> [FileMetadata] {
        if shouldSucceed { return mockFiles } else { throw FormaError.fileSystem(.ioError("Mock error", underlying: nil)) }
    }

    func scanPictures() async throws -> [FileMetadata] {
        if shouldSucceed { return mockFiles } else { throw FormaError.fileSystem(.ioError("Mock error", underlying: nil)) }
    }

    func scanMusic() async throws -> [FileMetadata] {
        if shouldSucceed { return mockFiles } else { throw FormaError.fileSystem(.ioError("Mock error", underlying: nil)) }
    }

    func scanAllFolders(customFolders: [CustomFolder]) async -> ScanResult {
        return ScanResult(files: mockFiles, errors: mockErrors)
    }

    func scan(baseFolders: [FolderLocation], customFolders: [CustomFolder]) async -> ScanResult {
        return ScanResult(files: mockFiles, errors: mockErrors)
    }

    func hasDesktopAccess() -> Bool { return hasDesktop }
    func hasDownloadsAccess() -> Bool { return hasDownloads }
    func hasDocumentsAccess() -> Bool { return hasDocuments }
    func hasPicturesAccess() -> Bool { return hasPictures }
    func hasMusicAccess() -> Bool { return hasMusic }
    
    func requestDesktopAccess() async throws -> Bool {
        hasDesktop = true
        return true
    }
    
    func requestDownloadsAccess() async throws -> Bool {
        hasDownloads = true
        return true
    }
    
    func requestDocumentsAccess() async throws -> Bool {
        hasDocuments = true
        return true
    }
    
    func requestPicturesAccess() async throws -> Bool {
        hasPictures = true
        return true
    }
    
    func requestMusicAccess() async throws -> Bool {
        hasMusic = true
        return true
    }
}
