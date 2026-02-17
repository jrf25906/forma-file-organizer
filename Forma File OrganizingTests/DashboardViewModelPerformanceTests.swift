import XCTest
@testable import Forma_File_Organizing

@MainActor
final class DashboardViewModelPerformanceTests: XCTestCase {

    private var viewModel: DashboardViewModel!
    private var mockService: MockFileSystemService!
    private var mockPipeline: MockFileScanPipeline!

    override func setUp() async throws {
        try await super.setUp()

        await MainActor.run {
            mockService = MockFileSystemService()
            mockPipeline = MockFileScanPipeline()
            viewModel = DashboardViewModel(
                services: AppServices(),
                fileSystemService: mockService,
                fileScanPipeline: mockPipeline
            )
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            viewModel = nil
            mockService = nil
            mockPipeline = nil
        }
        try await super.tearDown()
    }

    func testLargeSelectionPerformance() {
        // Given: Create 100 files
        let files = (0..<100).map { index in
            FileItem(
                path: "/f/\(index).txt",
                sizeInBytes: 1_000,
                creationDate: Date(),
                destination: nil,
                status: .pending
            )
        }

        viewModel._testSetFiles(files)
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .all
        viewModel.selectCategory(.all)

        // When: Select all
        let start = Date()
        viewModel.selectAll()
        let duration = Date().timeIntervalSince(start)

        // Then: Should complete quickly and have all files selected
        XCTAssertEqual(viewModel.selectedFileIDs.count, 100)
        XCTAssertLessThan(duration, 0.1) // Should take less than 100ms
        XCTAssertTrue(viewModel.isSelectionMode)
    }

    func testBulkSkip100Files() {
        // Given: Create 100 files
        let files = (0..<100).map { index in
            FileItem(
                path: "/f/\(index).txt",
                sizeInBytes: 1_000,
                creationDate: Date(),
                destination: nil,
                status: .pending
            )
        }

        viewModel._testSetFiles(files)
        viewModel.selectedFolder = .home
        viewModel.selectAll()

        // When: Skip all
        let start = Date()
        viewModel.skipSelectedFiles()
        let duration = Date().timeIntervalSince(start)

        // Then: All should be skipped
        XCTAssertEqual(files.filter { $0.status == .skipped }.count, 100)
        XCTAssertLessThan(duration, 0.5) // Should take less than 500ms
        XCTAssertEqual(viewModel.undoStack.count, FormaConfig.Limits.maxUndoActions)
    }
}
