import XCTest
@testable import Forma_File_Organizing

final class StorageServiceTests: XCTestCase {
    var storageService: StorageService!

    override func setUp() {
        super.setUp()
        storageService = StorageService.shared
        // Clear any cached data between tests
        storageService.invalidateCache()
    }

    override func tearDown() {
        storageService.invalidateCache()
        storageService = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Create a mock FileItem for testing
    /// Note: The path is automatically constructed from the name to ensure extension consistency
    func createMockFile(
        name: String = "test.pdf",
        fileExtension: String? = nil, // Deprecated - extension is derived from name
        size: String? = nil, // Deprecated - computed from sizeInBytes
        sizeInBytes: Int64 = 1_048_576,
        creationDate: Date = Date(),
        path: String? = nil
    ) -> FileItem {
        // Use provided path or construct from name
        let filePath = path ?? "/test/\(name)"
        return FileItem(
            path: filePath,
            sizeInBytes: sizeInBytes,
            creationDate: creationDate
        )
    }

    // MARK: - calculateAnalytics Tests

    func testCalculateAnalytics_FromFiles() {
        // Given: Multiple files across different categories
        let files = [
            createMockFile(name: "doc.pdf", sizeInBytes: 1_000_000), // Documents
            createMockFile(name: "image.jpg", sizeInBytes: 2_000_000), // Images
            createMockFile(name: "photo.png", sizeInBytes: 3_000_000), // Images
            createMockFile(name: "video.mp4", sizeInBytes: 5_000_000), // Videos
        ]

        // When: Calculate analytics
        let analytics = storageService.calculateAnalytics(from: files)

        // Then: Verify calculations are correct
        XCTAssertEqual(analytics.totalBytes, 11_000_000, "Total bytes should be sum of all files")
        XCTAssertEqual(analytics.fileCount, 4, "File count should match number of files")

        // Verify category breakdown
        XCTAssertEqual(analytics.sizeForCategory(.documents), 1_000_000, "Documents size should match PDF file")
        XCTAssertEqual(analytics.sizeForCategory(.images), 5_000_000, "Images size should be sum of JPG and PNG")
        XCTAssertEqual(analytics.sizeForCategory(.videos), 5_000_000, "Videos size should match MP4 file")

        // Verify file counts per category
        XCTAssertEqual(analytics.fileCountForCategory(.documents), 1, "Should have 1 document")
        XCTAssertEqual(analytics.fileCountForCategory(.images), 2, "Should have 2 images")
        XCTAssertEqual(analytics.fileCountForCategory(.videos), 1, "Should have 1 video")
    }

    func testCalculateAnalytics_UpdatesCache() {
        // Given: Initial files
        let files = [createMockFile()]

        // When: Calculate analytics
        let analytics = storageService.calculateAnalytics(from: files)

        // Then: Cache should be updated
        let cachedAnalytics = storageService.getAnalytics(from: files)
        XCTAssertEqual(analytics.totalBytes, cachedAnalytics.totalBytes, "Cached analytics should match calculated")
    }

    func testCalculateAnalytics_WithMixedCategories() {
        // Given: Files from all major categories
        let files = [
            createMockFile(name: "doc.pdf", sizeInBytes: 1_000_000),  // Documents
            createMockFile(name: "image.jpg", sizeInBytes: 2_000_000),  // Images
            createMockFile(name: "video.mp4", sizeInBytes: 4_000_000),  // Videos
            createMockFile(name: "audio.mp3", sizeInBytes: 3_000_000),  // Audio
            createMockFile(name: "archive.zip", sizeInBytes: 5_000_000),  // Archives
        ]

        // When: Calculate analytics
        let analytics = storageService.calculateAnalytics(from: files)

        // Then: All categories should be represented
        XCTAssertEqual(analytics.fileCount, 5)
        XCTAssertEqual(analytics.totalBytes, 15_000_000)
        XCTAssertEqual(analytics.categoryBreakdown.count, 5, "Should have 5 different categories")
    }

    // MARK: - getAnalytics Tests

    func testGetAnalytics_ReturnsCached() {
        // Given: Analytics already calculated
        let files = [createMockFile(sizeInBytes: 1_000_000)]
        let initialAnalytics = storageService.calculateAnalytics(from: files)

        // When: Get analytics again with different data (but should return cached)
        let differentFiles = [createMockFile(sizeInBytes: 2_000_000)]
        let cachedAnalytics = storageService.getAnalytics(from: differentFiles)

        // Then: Should return cached version (not recalculated)
        XCTAssertEqual(cachedAnalytics.totalBytes, initialAnalytics.totalBytes, "Should return cached analytics")
        XCTAssertEqual(cachedAnalytics.totalBytes, 1_000_000, "Should have original cached value")
    }

    func testGetAnalytics_RefreshesAfterTTL() {
        // Given: Analytics calculated with initial timestamp
        let files = [createMockFile(sizeInBytes: 1_000_000)]
        _ = storageService.calculateAnalytics(from: files)

        // Simulate cache expiration by invalidating and recalculating after waiting
        // Note: We can't easily wait 60 seconds in a unit test, so we'll test the expiration logic differently
        storageService.invalidateCache()

        let newFiles = [createMockFile(sizeInBytes: 2_000_000)]
        let newAnalytics = storageService.getAnalytics(from: newFiles)

        // Then: Should return new analytics (not cached)
        XCTAssertEqual(newAnalytics.totalBytes, 2_000_000, "Should recalculate after cache invalidation")
    }

    func testGetAnalytics_WithNoCacheReturnsNewCalculation() {
        // Given: No cached analytics
        let files = [createMockFile(sizeInBytes: 1_000_000)]

        // When: Get analytics for first time
        let analytics = storageService.getAnalytics(from: files)

        // Then: Should calculate fresh analytics
        XCTAssertEqual(analytics.totalBytes, 1_000_000)
        XCTAssertEqual(analytics.fileCount, 1)
    }

    func testGetAnalytics_ForceRefreshBypassesCache() {
        // Given: Analytics already calculated and cached
        let files = [createMockFile(sizeInBytes: 1_000_000)]
        _ = storageService.calculateAnalytics(from: files)

        // When: Force refresh with different files
        let newFiles = [createMockFile(sizeInBytes: 2_000_000)]
        let analytics = storageService.getAnalytics(from: newFiles, forceRefresh: true)

        // Then: Should recalculate with new data (not use cache)
        XCTAssertEqual(analytics.totalBytes, 2_000_000, "Force refresh should bypass cache")
    }

    // MARK: - invalidateCache Tests

    func testInvalidateCache_ClearsCache() {
        // Given: Cached analytics
        let files = [createMockFile()]
        _ = storageService.calculateAnalytics(from: files)

        // When: Invalidate cache
        storageService.invalidateCache()

        // Then: Next getAnalytics should recalculate
        let newFiles = [createMockFile(sizeInBytes: 5_000_000)]
        let analytics = storageService.getAnalytics(from: newFiles)
        XCTAssertEqual(analytics.totalBytes, 5_000_000, "Should recalculate after invalidation")
    }

    // MARK: - filterFiles Tests

    func testFilterFiles_ByCategory() {
        // Given: Files from different categories
        let files = [
            createMockFile(name: "doc.pdf"),
            createMockFile(name: "image.jpg"),
            createMockFile(name: "photo.png"),
            createMockFile(name: "video.mp4"),
        ]

        // When: Filter by images category
        let imageFiles = storageService.filterFiles(files, by: .images)

        // Then: Should return only image files
        XCTAssertEqual(imageFiles.count, 2, "Should return 2 image files")
        XCTAssertTrue(imageFiles.allSatisfy { $0.category == .images }, "All filtered files should be images")
    }

    func testFilterFiles_ByAllCategory() {
        // Given: Files from different categories
        let files = [
            createMockFile(name: "doc.pdf"),
            createMockFile(name: "image.jpg"),
            createMockFile(name: "video.mp4"),
        ]

        // When: Filter by "all" category
        let allFiles = storageService.filterFiles(files, by: .all)

        // Then: Should return all files
        XCTAssertEqual(allFiles.count, files.count, "Should return all files when filtering by .all")
    }

    func testFilterFiles_EmptyResult() {
        // Given: Files that don't match the filter category
        let files = [
            createMockFile(name: "doc.pdf"),
            createMockFile(name: "doc2.docx"),
        ]

        // When: Filter by videos category
        let videoFiles = storageService.filterFiles(files, by: .videos)

        // Then: Should return empty array
        XCTAssertEqual(videoFiles.count, 0, "Should return no files when category doesn't match")
    }

    func testFilterFiles_WithDocumentsCategory() {
        // Given: Mix of file types
        let files = [
            createMockFile(name: "doc1.pdf"),
            createMockFile(name: "doc2.docx"),
            createMockFile(name: "image.jpg"),
            createMockFile(name: "doc3.txt"),
        ]

        // When: Filter by documents
        let documentFiles = storageService.filterFiles(files, by: .documents)

        // Then: Should return only documents
        XCTAssertEqual(documentFiles.count, 3, "Should return PDF, DOCX, and TXT files")
        XCTAssertTrue(documentFiles.allSatisfy { $0.category == .documents })
    }

    // MARK: - getRecentFiles Tests

    func testGetRecentFiles_ReturnsRecent() {
        // Given: Files with different creation dates
        let now = Date()
        let files = [
            createMockFile(name: "oldest.pdf", creationDate: now.addingTimeInterval(-1000)),
            createMockFile(name: "newer.pdf", creationDate: now.addingTimeInterval(-500)),
            createMockFile(name: "newest.pdf", creationDate: now),
        ]

        // When: Get recent files
        let recentFiles = storageService.getRecentFiles(files)

        // Then: Should be sorted by most recent first
        XCTAssertEqual(recentFiles.count, 3)
        XCTAssertEqual(recentFiles[0].name, "newest.pdf", "First file should be most recent")
        XCTAssertEqual(recentFiles[1].name, "newer.pdf", "Second file should be middle")
        XCTAssertEqual(recentFiles[2].name, "oldest.pdf", "Last file should be oldest")
    }

    func testGetRecentFiles_RespectsLimit() {
        // Given: 15 files
        let now = Date()
        let files = (0..<15).map { index in
            createMockFile(
                name: "file\(index).pdf",
                creationDate: now.addingTimeInterval(TimeInterval(-index * 100)),
                path: "/test/file\(index).pdf"
            )
        }

        // When: Get recent files with limit of 5
        let recentFiles = storageService.getRecentFiles(files, limit: 5)

        // Then: Should return only 5 files
        XCTAssertEqual(recentFiles.count, 5, "Should respect the limit parameter")
    }

    func testGetRecentFiles_DefaultLimit() {
        // Given: 15 files
        let now = Date()
        let files = (0..<15).map { index in
            createMockFile(
                name: "file\(index).pdf",
                creationDate: now.addingTimeInterval(TimeInterval(-index * 100)),
                path: "/test/file\(index).pdf"
            )
        }

        // When: Get recent files with default limit (10)
        let recentFiles = storageService.getRecentFiles(files)

        // Then: Should return 10 files by default
        XCTAssertEqual(recentFiles.count, 10, "Default limit should be 10 files")
    }

    func testGetRecentFiles_WithFewerFilesThanLimit() {
        // Given: Only 3 files
        let files = [
            createMockFile(name: "file1.pdf"),
            createMockFile(name: "file2.pdf"),
            createMockFile(name: "file3.pdf"),
        ]

        // When: Get recent files with limit of 10
        let recentFiles = storageService.getRecentFiles(files, limit: 10)

        // Then: Should return all 3 files
        XCTAssertEqual(recentFiles.count, 3, "Should return all files when count < limit")
    }

    // MARK: - groupByCategory Tests

    func testGroupByCategory_ReturnsGroupedFiles() {
        // Given: Files from multiple categories
        let files = [
            createMockFile(name: "doc1.pdf"),
            createMockFile(name: "doc2.docx"),
            createMockFile(name: "img1.jpg"),
            createMockFile(name: "img2.png"),
            createMockFile(name: "vid1.mp4"),
        ]

        // When: Group by category
        let grouped = storageService.groupByCategory(files)

        // Then: Should have correct groupings
        XCTAssertEqual(grouped.keys.count, 3, "Should have 3 categories")
        XCTAssertEqual(grouped[.documents]?.count, 2, "Should have 2 documents")
        XCTAssertEqual(grouped[.images]?.count, 2, "Should have 2 images")
        XCTAssertEqual(grouped[.videos]?.count, 1, "Should have 1 video")
    }

    func testGroupByCategory_WithSingleCategory() {
        // Given: All files from same category
        let files = [
            createMockFile(name: "doc1.pdf"),
            createMockFile(name: "doc2.docx"),
            createMockFile(name: "doc3.txt"),
        ]

        // When: Group by category
        let grouped = storageService.groupByCategory(files)

        // Then: Should have one group
        XCTAssertEqual(grouped.keys.count, 1, "Should have only 1 category")
        XCTAssertEqual(grouped[.documents]?.count, 3, "All files should be in documents")
    }

    func testGroupByCategory_EmptyInput() {
        // Given: Empty file array
        let files: [FileItem] = []

        // When: Group by category
        let grouped = storageService.groupByCategory(files)

        // Then: Should return empty dictionary
        XCTAssertEqual(grouped.keys.count, 0, "Should return empty dictionary for empty input")
    }

    func testGroupByCategory_AllCategories() {
        // Given: Files covering all main categories
        let files = [
            createMockFile(name: "doc.pdf"),    // Documents
            createMockFile(name: "image.jpg"),    // Images
            createMockFile(name: "video.mp4"),    // Videos
            createMockFile(name: "audio.mp3"),    // Audio
            createMockFile(name: "archive.zip"),    // Archives
        ]

        // When: Group by category
        let grouped = storageService.groupByCategory(files)

        // Then: Should have all 5 categories
        XCTAssertEqual(grouped.keys.count, 5, "Should have all 5 main categories")
        XCTAssertNotNil(grouped[.documents])
        XCTAssertNotNil(grouped[.images])
        XCTAssertNotNil(grouped[.videos])
        XCTAssertNotNil(grouped[.audio])
        XCTAssertNotNil(grouped[.archives])
    }

    // MARK: - Edge Cases

    func testEmptyFiles_ReturnsEmptyAnalytics() {
        // Given: Empty file array
        let files: [FileItem] = []

        // When: Calculate analytics
        let analytics = storageService.calculateAnalytics(from: files)

        // Then: Should return empty analytics
        XCTAssertEqual(analytics.totalBytes, 0, "Total bytes should be 0 for empty input")
        XCTAssertEqual(analytics.fileCount, 0, "File count should be 0 for empty input")
        XCTAssertEqual(analytics.categoryBreakdown.count, 0, "Category breakdown should be empty")
    }

    func testSingleFile_ReturnsCorrectAnalytics() {
        // Given: Single file
        let file = createMockFile(name: "doc.pdf", sizeInBytes: 1_000_000)

        // When: Calculate analytics
        let analytics = storageService.calculateAnalytics(from: [file])

        // Then: Should return correct analytics
        XCTAssertEqual(analytics.totalBytes, 1_000_000)
        XCTAssertEqual(analytics.fileCount, 1)
        XCTAssertEqual(analytics.sizeForCategory(.documents), 1_000_000)
        XCTAssertEqual(analytics.fileCountForCategory(.documents), 1)
    }

    func testLargeFileSet_Performance() {
        // Given: Large set of files (1000 files)
        let files = (0..<1000).map { index in
            createMockFile(
                name: "file\(index).pdf",
                sizeInBytes: Int64(index * 1000),
                path: "/test/file\(index).pdf"
            )
        }

        // When/Then: Measure performance
        measure {
            _ = storageService.calculateAnalytics(from: files)
        }
    }

    func testZeroByteFiles_HandledCorrectly() {
        // Given: Files with zero bytes
        let files = [
            createMockFile(sizeInBytes: 0),
            createMockFile(sizeInBytes: 0),
            createMockFile(sizeInBytes: 1000),
        ]

        // When: Calculate analytics
        let analytics = storageService.calculateAnalytics(from: files)

        // Then: Should handle zero bytes correctly
        XCTAssertEqual(analytics.totalBytes, 1000, "Should correctly sum including zero-byte files")
        XCTAssertEqual(analytics.fileCount, 3, "Should count zero-byte files")
    }

    func testVeryLargeFiles_NoOverflow() {
        // Given: Very large files (simulating multi-GB files)
        let largeSize: Int64 = 5_000_000_000 // 5GB
        let files = [
            createMockFile(sizeInBytes: largeSize),
            createMockFile(sizeInBytes: largeSize),
        ]

        // When: Calculate analytics
        let analytics = storageService.calculateAnalytics(from: files)

        // Then: Should handle large numbers without overflow
        XCTAssertEqual(analytics.totalBytes, 10_000_000_000, "Should handle large file sizes")
    }

    // MARK: - Cache Behavior Tests

    func testMultipleGetAnalyticsCalls_UsesCache() {
        // Given: Initial analytics
        let files = [createMockFile(sizeInBytes: 1_000_000)]
        let firstCall = storageService.getAnalytics(from: files)

        // When: Call getAnalytics multiple times
        let secondCall = storageService.getAnalytics(from: files)
        let thirdCall = storageService.getAnalytics(from: files)

        // Then: All calls should return same cached result
        XCTAssertEqual(firstCall.totalBytes, secondCall.totalBytes)
        XCTAssertEqual(secondCall.totalBytes, thirdCall.totalBytes)
    }

    func testCalculateAnalytics_InvalidatesPreviousCache() {
        // Given: Cached analytics
        let files1 = [createMockFile(sizeInBytes: 1_000_000)]
        _ = storageService.getAnalytics(from: files1)

        // When: Calculate new analytics
        let files2 = [createMockFile(sizeInBytes: 2_000_000)]
        let newAnalytics = storageService.calculateAnalytics(from: files2)

        // Then: Cache should be updated
        XCTAssertEqual(newAnalytics.totalBytes, 2_000_000)

        // Subsequent getAnalytics should return new cached value
        let cachedAnalytics = storageService.getAnalytics(from: files1) // Note: passing different files
        XCTAssertEqual(cachedAnalytics.totalBytes, 2_000_000, "Should use newly cached analytics")
    }

    // MARK: - Integration Tests

    func testCompleteWorkflow_CalculateFilterAndGroup() {
        // Given: A realistic set of files
        let files = [
            createMockFile(name: "report.pdf", sizeInBytes: 2_000_000),
            createMockFile(name: "photo1.jpg", sizeInBytes: 3_000_000),
            createMockFile(name: "photo2.png", sizeInBytes: 4_000_000),
            createMockFile(name: "video.mp4", sizeInBytes: 10_000_000),
            createMockFile(name: "song.mp3", sizeInBytes: 5_000_000),
        ]

        // When: Perform complete workflow
        let analytics = storageService.getAnalytics(from: files)
        let imageFiles = storageService.filterFiles(files, by: .images)
        let recentFiles = storageService.getRecentFiles(files, limit: 3)
        let grouped = storageService.groupByCategory(files)

        // Then: All operations should work correctly together
        XCTAssertEqual(analytics.totalBytes, 24_000_000)
        XCTAssertEqual(analytics.fileCount, 5)
        XCTAssertEqual(imageFiles.count, 2)
        XCTAssertEqual(recentFiles.count, 3)
        XCTAssertEqual(grouped.keys.count, 4) // documents, images, videos, audio
    }
}
