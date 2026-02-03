import XCTest
@testable import Forma_File_Organizing

/// Security tests for rate limiting in batch file operations
/// Tests defense against resource exhaustion (CWE-400)
final class RateLimitingTests: XCTestCase {

    var testDirectory: URL!

    private let delayNanoseconds: UInt64 = 100_000_000 // 100ms

    private final class MutableClock: Clock {
        var now: Date
        var calendar: Calendar

        init(now: Date, calendar: Calendar = .current) {
            self.now = now
            self.calendar = calendar
        }

        func advance(by interval: TimeInterval) {
            now = now.addingTimeInterval(interval)
        }
    }

    private final class TestRateLimiter: RateLimiter, @unchecked Sendable {
        private(set) var sleepCalls = 0
        private let clock: MutableClock?
        private let delaySeconds: TimeInterval

        init(clock: MutableClock? = nil, delayNanoseconds: UInt64) {
            self.clock = clock
            self.delaySeconds = TimeInterval(delayNanoseconds) / 1_000_000_000
        }

        func sleepIfNeeded(after index: Int, total: Int) async {
            guard total > 1, index < total - 1 else { return }
            sleepCalls += 1
            clock?.advance(by: delaySeconds)
        }
    }

    override func setUp() async throws {
        try TestGating.requirePerformance()
        try await super.setUp()

        // Create temporary test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RateLimitingTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up test directory
        if let testDirectory = testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
        try await super.tearDown()
    }

    // MARK: - Batch Size Limiting Tests

    /// Test that batch size is limited to maxBatchSize (1000 files)
    /// Security: Prevents resource exhaustion from processing unlimited files
    @MainActor
    func testBatchSizeLimitEnforced() async throws {
        // Given: 2000 test files (exceeds limit of 1000)
        let fileOperationsService = FileOperationsService()
        let fileCount = 2000
        let files = createMockFiles(count: fileCount)

        // When: Process the batch
        let results = await fileOperationsService.moveFiles(files)

        // Then: Only 1000 files should be processed
        XCTAssertEqual(results.count, 1000, "Batch size should be limited to 1000 files")
        XCTAssertLessThan(results.count, fileCount, "Not all files should be processed when exceeding limit")
    }

    /// Test that batches under the limit process all files
    @MainActor
    func testBatchUnderLimitProcessesAll() async throws {
        // Given: 500 test files (under limit of 1000)
        let fileOperationsService = FileOperationsService()
        let fileCount = 500
        let files = createMockFiles(count: fileCount)

        // When: Process the batch
        let results = await fileOperationsService.moveFiles(files)

        // Then: All files should be processed
        XCTAssertEqual(results.count, fileCount, "All files under limit should be processed")
    }

    /// Test that exactly maxBatchSize files are processed correctly
    @MainActor
    func testExactBatchSizeLimit() async throws {
        // Given: Exactly 1000 test files (at limit)
        let fileOperationsService = FileOperationsService()
        let fileCount = 1000
        let files = createMockFiles(count: fileCount)

        // When: Process the batch
        let results = await fileOperationsService.moveFiles(files)

        // Then: All 1000 files should be processed
        XCTAssertEqual(results.count, 1000, "Exactly 1000 files should be processed")
    }

    /// Test edge case: Empty batch
    @MainActor
    func testEmptyBatch() async throws {
        // Given: Empty array
        let fileOperationsService = FileOperationsService()
        let files: [FileItem] = []

        // When: Process the batch
        let results = await fileOperationsService.moveFiles(files)

        // Then: Should return empty results
        XCTAssertEqual(results.count, 0, "Empty batch should return empty results")
    }

    /// Test edge case: Single file
    @MainActor
    func testSingleFileBatch() async throws {
        // Given: Single file
        let fileOperationsService = FileOperationsService()
        let files = createMockFiles(count: 1)

        // When: Process the batch
        let results = await fileOperationsService.moveFiles(files)

        // Then: Should process one file
        XCTAssertEqual(results.count, 1, "Single file should be processed")
    }

    // MARK: - Rate Limiting Delay Tests

    /// Test that rate limiting delay is applied between operations
    /// Security: Prevents disk I/O saturation and resource exhaustion
    @MainActor
    func testRateLimitingDelayApplied() async throws {
        // Given: 10 test files with destinations set
        let clock = MutableClock(now: Date(timeIntervalSince1970: 0))
        let rateLimiter = TestRateLimiter(clock: clock, delayNanoseconds: delayNanoseconds)
        let fileOperationsService = FileOperationsService(clock: clock, rateLimiter: rateLimiter)
        let fileCount = 10
        let files = createMockFilesWithDestinations(count: fileCount)

        // When: Process the batch
        let startTime = clock.now
        let results = await fileOperationsService.moveFiles(files)

        // Then: Delay should be applied between operations
        XCTAssertEqual(rateLimiter.sleepCalls, fileCount - 1, "Should sleep between each operation")
        let elapsed = clock.now.timeIntervalSince(startTime)
        let expectedDelay = TimeInterval(fileCount - 1) * (TimeInterval(delayNanoseconds) / 1_000_000_000)
        XCTAssertEqual(elapsed, expectedDelay, accuracy: 0.0001, "Clock should advance by total delay time")

        XCTAssertEqual(results.count, fileCount, "All files should be processed")
    }

    /// Test that no delay is added after the last file
    @MainActor
    func testNoDelayAfterLastFile() async throws {
        // Given: 2 test files
        let clock = MutableClock(now: Date(timeIntervalSince1970: 0))
        let rateLimiter = TestRateLimiter(clock: clock, delayNanoseconds: delayNanoseconds)
        let fileOperationsService = FileOperationsService(clock: clock, rateLimiter: rateLimiter)
        let files = createMockFilesWithDestinations(count: 2)

        // When: Process the batch
        let startTime = clock.now
        _ = await fileOperationsService.moveFiles(files)

        // Then: Should only have 1 delay (100ms), not 2
        XCTAssertEqual(rateLimiter.sleepCalls, 1, "Should not add delay after last file")
        let elapsed = clock.now.timeIntervalSince(startTime)
        let expectedDelay = TimeInterval(delayNanoseconds) / 1_000_000_000
        XCTAssertEqual(elapsed, expectedDelay, accuracy: 0.0001)
    }

    /// Test that single file has no delay
    @MainActor
    func testSingleFileNoDelay() async throws {
        // Given: Single file
        let clock = MutableClock(now: Date(timeIntervalSince1970: 0))
        let rateLimiter = TestRateLimiter(clock: clock, delayNanoseconds: delayNanoseconds)
        let fileOperationsService = FileOperationsService(clock: clock, rateLimiter: rateLimiter)
        let files = createMockFilesWithDestinations(count: 1)

        // When: Process the batch
        let startTime = clock.now
        _ = await fileOperationsService.moveFiles(files)

        // Then: Should complete with no delay
        XCTAssertEqual(rateLimiter.sleepCalls, 0, "Single file should have no rate limiting delay")
        let elapsed = clock.now.timeIntervalSince(startTime)
        XCTAssertEqual(elapsed, 0, accuracy: 0.0001)
    }

    // MARK: - Resource Exhaustion Protection Tests

    /// Test that large batches don't cause memory issues
    /// Security: Prevents memory exhaustion attacks
    @MainActor
    func testLargeBatchMemoryStability() async throws {
        // Given: Very large batch (5000 files, but limited to 1000)
        let fileOperationsService = FileOperationsService()
        let files = createMockFiles(count: 5000)

        // When: Process the batch
        let memoryBefore = getMemoryUsage()
        let results = await fileOperationsService.moveFiles(files)
        let memoryAfter = getMemoryUsage()

        // Then: Memory growth should be bounded
        let memoryGrowth = memoryAfter - memoryBefore
        let maxAcceptableGrowth: Int64 = 100_000_000 // 100MB

        XCTAssertLessThan(
            memoryGrowth,
            maxAcceptableGrowth,
            "Memory growth should be bounded even with large input"
        )

        XCTAssertEqual(results.count, 1000, "Only 1000 files should be processed")
    }

    /// Test that processing doesn't freeze the system
    /// Security: Ensures UI remains responsive during batch operations
    @MainActor
    func testBatchOperationResponsiveness() async throws {
        // Given: Moderate batch size
        let rateLimiter = TestRateLimiter(delayNanoseconds: delayNanoseconds)
        let fileOperationsService = FileOperationsService(rateLimiter: rateLimiter)
        let files = createMockFiles(count: 50)

        // When: Process the batch
        _ = await fileOperationsService.moveFiles(files)

        // Then: Should apply rate limiting between operations
        XCTAssertEqual(rateLimiter.sleepCalls, 49, "Should sleep between each of 50 files")
    }

    // MARK: - Error Handling Tests

    /// Test that errors don't bypass rate limiting
    @MainActor
    func testErrorsRespectRateLimiting() async throws {
        // Given: Files that will cause errors (no destination)
        let rateLimiter = TestRateLimiter(delayNanoseconds: delayNanoseconds)
        let fileOperationsService = FileOperationsService(rateLimiter: rateLimiter)
        let files = createMockFiles(count: 10)
        // Don't set destinations - will cause errors

        // When: Process the batch
        let results = await fileOperationsService.moveFiles(files)

        // Then: Rate limiting should still apply despite errors
        XCTAssertEqual(rateLimiter.sleepCalls, 9, "Rate limiting should apply even when operations fail")

        // All operations should fail but still return results
        XCTAssertEqual(results.count, 10, "Should return results for all files")
        XCTAssertTrue(
            results.allSatisfy { !$0.success },
            "All operations should fail without destinations"
        )
    }

    // MARK: - Helper Methods

    /// Creates mock FileItem objects for testing
    private func createMockFiles(count: Int) -> [FileItem] {
        return (1...count).map { index in
            FileItem(
                path: testDirectory.appendingPathComponent("test-file-\(index).txt").path,
                sizeInBytes: 1024,
                creationDate: Date(),
                modificationDate: Date()
            )
        }
    }

    /// Creates mock FileItem objects with valid destinations
    private func createMockFilesWithDestinations(count: Int) -> [FileItem] {
        let files = createMockFiles(count: count)

        // Create actual test files
        for file in files {
            let fileURL = URL(fileURLWithPath: file.path)
            try? "test content".write(to: fileURL, atomically: true, encoding: .utf8)

            // Set destination to Downloads (common folder)
            file.destination = .mockFolder("Downloads")
        }

        return files
    }

    /// Gets current memory usage in bytes
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        }

        return 0
    }
}

// MARK: - Performance Tests

/// Performance benchmarks for rate limiting
/// Run with: xcodebuild test -scheme "Forma File Organizing" -only-testing:RateLimitingPerformanceTests
final class RateLimitingPerformanceTests: XCTestCase {
#if swift(<6.0)

    var fileOperationsService: FileOperationsService!

    override func setUp() async throws {
        try TestGating.requirePerformance()
        try await super.setUp()
        await MainActor.run {
            fileOperationsService = FileOperationsService()
        }
    }

    /// Benchmark: 100 files with rate limiting
    func testPerformanceBatch100Files() throws {
        let files = (1...100).map { index in
            FileItem(
                path: "/tmp/test-\(index).txt",
                sizeInBytes: 1024,
                creationDate: Date(),
                modificationDate: Date()
            )
        }

        measure {
            let expectation = XCTestExpectation(description: "Process 100 files")

            Task {
                _ = await fileOperationsService.moveFiles(files)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 30.0)
        }
    }

    /// Benchmark: 1000 files with rate limiting (max batch)
    func testPerformanceBatch1000Files() throws {
        let files = (1...1000).map { index in
            FileItem(
                path: "/tmp/test-\(index).txt",
                sizeInBytes: 1024,
                creationDate: Date(),
                modificationDate: Date()
            )
        }

        measure {
            let expectation = XCTestExpectation(description: "Process 1000 files")

            Task {
                _ = await fileOperationsService.moveFiles(files)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 200.0)
        }
    }

#else

    func testPerformanceBatch100Files() throws {
        throw XCTSkip("Disabled under Swift 6 strict concurrency (uses non-Sendable SwiftData models in Task/measure closures).")
    }

    func testPerformanceBatch1000Files() throws {
        throw XCTSkip("Disabled under Swift 6 strict concurrency (uses non-Sendable SwiftData models in Task/measure closures).")
    }

#endif
}
