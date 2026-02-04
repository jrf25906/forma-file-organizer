import XCTest
@testable import Forma_File_Organizing

final class StorageServicePerformanceTests: XCTestCase {

    private var storageService: StorageService!

    override func setUp() {
        super.setUp()
        storageService = StorageService.shared
        storageService.invalidateCache()
    }

    override func tearDown() {
        storageService.invalidateCache()
        storageService = nil
        super.tearDown()
    }

    func testLargeFileSet_Performance() {
        // Given: Large set of files (1000 files)
        let files = (0..<1000).map { index in
            FileItem(
                path: "/test/file\(index).pdf",
                sizeInBytes: Int64(index * 1000),
                creationDate: Date()
            )
        }

        // When/Then: Measure performance
        measure {
            _ = storageService.calculateAnalytics(from: files)
        }
    }
}

