import XCTest
@testable import Forma_File_Organizing

@MainActor
final class FilterViewModelTests: XCTestCase {
    func testFilterViewModel_SelectedFolderFiltersStandardLocation() {
        let now = Date()
        let desktopFile = FileItem(
            path: "/Users/test/Desktop/a.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            destination: nil,
            status: .pending
        )
        let downloadsFile = FileItem(
            path: "/Users/test/Downloads/b.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .downloads,
            destination: nil,
            status: .pending
        )

        let viewModel = FilterViewModel()
        viewModel.updateSourceFiles([desktopFile, downloadsFile])

        viewModel.selectedFolder = .desktop
        viewModel.applyFilterImmediately()

        XCTAssertEqual(viewModel.filteredFiles.count, 1)
        XCTAssertEqual(viewModel.filteredFiles.first?.path, desktopFile.path)
    }
}
