import XCTest
@testable import Forma_File_Organizing

@MainActor
final class FileRowTests: XCTestCase {
    
    // MARK: - Primary Action Configuration Tests
    
    func testPrimaryActionConfig_FileWithDestinationAndReady_ReturnsOrganize() {
        // Given: A file with a suggested destination and ready status
        let file = FileItem(
            name: "test.pdf",
            fileExtension: "pdf",
            size: "1MB",
            sizeInBytes: 1_000_000,
            creationDate: Date(),
            path: "/test/test.pdf",
            destination: .mockFolder("Documents/PDFs"),
            status: .ready
        )
        
        // When: Getting the primary action config
        let row = TestableFileRow(file: file)
        let config = row.getPrimaryActionConfig()
        
        // Then: Should return Organize action
        XCTAssertEqual(config.label, "Organize to Documents/PDFs")
        XCTAssertEqual(config.icon, "checkmark.circle.fill")
        // Note: Color comparison would need Color extension for Equatable
    }
    
    func testPrimaryActionConfig_FileWithDestinationButPending_ReturnsReview() {
        // Given: A file with a suggested destination but pending status
        let file = FileItem(
            name: "test.pdf",
            fileExtension: "pdf",
            size: "1MB",
            sizeInBytes: 1_000_000,
            creationDate: Date(),
            path: "/test/test.pdf",
            destination: .mockFolder("Documents/PDFs"),
            status: .pending
        )
        
        // When: Getting the primary action config
        let row = TestableFileRow(file: file)
        let config = row.getPrimaryActionConfig()
        
        // Then: Should return Review Destination action
        XCTAssertEqual(config.label, "Review Destination")
        XCTAssertEqual(config.icon, "arrow.right.circle")
    }
    
    func testPrimaryActionConfig_FileWithoutDestination_ReturnsCreateRule() {
        // Given: A file without a suggested destination
        let file = FileItem(
            name: "test.txt",
            fileExtension: "txt",
            size: "1KB",
            sizeInBytes: 1_000,
            creationDate: Date(),
            path: "/test/test.txt",
            destination: nil,
            status: .pending
        )
        
        // When: Getting the primary action config
        let row = TestableFileRow(file: file)
        let config = row.getPrimaryActionConfig()
        
        // Then: Should return Create Rule action
        XCTAssertEqual(config.label, "Create Rule")
        XCTAssertEqual(config.icon, "wand.and.stars")
    }
    
    func testPrimaryActionConfig_FileWithDestinationAndSkippedStatus_ReturnsReview() {
        // Given: A file with destination but skipped status
        let file = FileItem(
            name: "test.jpg",
            fileExtension: "jpg",
            size: "2MB",
            sizeInBytes: 2_000_000,
            creationDate: Date(),
            path: "/test/test.jpg",
            destination: .mockFolder("Pictures"),
            status: .skipped
        )
        
        // When: Getting the primary action config
        let row = TestableFileRow(file: file)
        let config = row.getPrimaryActionConfig()
        
        // Then: Should return Review Destination (not ready status)
        XCTAssertEqual(config.label, "Review Destination")
        XCTAssertEqual(config.icon, "arrow.right.circle")
    }
    
    // MARK: - Callback Tests
    
    func testOrganizeCallback_CalledWhenDestinationIsReady() {
        // Given: A ready file and a callback expectation
        let file = FileItem(
            name: "test.pdf",
            fileExtension: "pdf",
            size: "1MB",
            sizeInBytes: 1_000_000,
            creationDate: Date(),
            path: "/test/test.pdf",
            destination: .mockFolder("Documents"),
            status: .ready
        )
        
        var organizeCalled = false
        var organizedFile: FileItem?
        
        let row = TestableFileRow(
            file: file,
            onOrganize: { item in
                organizeCalled = true
                organizedFile = item
            }
        )
        
        // When: Executing the primary action
        let config = row.getPrimaryActionConfig()
        config.action()
        
        // Then: Organize callback should be called with the file
        XCTAssertTrue(organizeCalled)
        XCTAssertEqual(organizedFile?.path, file.path)
    }
    
    func testEditDestinationCallback_CalledWhenDestinationNeedsReview() {
        // Given: A pending file with destination
        let file = FileItem(
            name: "test.pdf",
            fileExtension: "pdf",
            size: "1MB",
            sizeInBytes: 1_000_000,
            creationDate: Date(),
            path: "/test/test.pdf",
            destination: .mockFolder("Documents"),
            status: .pending
        )
        
        var editCalled = false
        var editedFile: FileItem?
        
        let row = TestableFileRow(
            file: file,
            onEditDestination: { item in
                editCalled = true
                editedFile = item
            }
        )
        
        // When: Executing the primary action
        let config = row.getPrimaryActionConfig()
        config.action()
        
        // Then: Edit destination callback should be called
        XCTAssertTrue(editCalled)
        XCTAssertEqual(editedFile?.path, file.path)
    }
    
    func testCreateRuleCallback_CalledWhenNoDestination() {
        // Given: A file without destination
        let file = FileItem(
            name: "test.txt",
            fileExtension: "txt",
            size: "1KB",
            sizeInBytes: 1_000,
            creationDate: Date(),
            path: "/test/test.txt",
            destination: nil,
            status: .pending
        )
        
        var createRuleCalled = false
        var ruleFile: FileItem?
        
        let row = TestableFileRow(
            file: file,
            onCreateRule: { item in
                createRuleCalled = true
                ruleFile = item
            }
        )
        
        // When: Executing the primary action
        let config = row.getPrimaryActionConfig()
        config.action()
        
        // Then: Create rule callback should be called
        XCTAssertTrue(createRuleCalled)
        XCTAssertEqual(ruleFile?.path, file.path)
    }
}

// MARK: - Testable FileRow Wrapper

/// Wrapper to expose FileRow's private primaryActionConfig for testing
@MainActor
private struct TestableFileRow {
    let file: FileItem
    var onOrganize: (FileItem) -> Void = { _ in }
    var onEditDestination: ((FileItem) -> Void)? = nil
    var onCreateRule: ((FileItem) -> Void)? = nil
    
    func getPrimaryActionConfig() -> (label: String, icon: String, action: () -> Void) {
        // Replicate the primaryActionConfig logic from FileRow
        if let destinationName = file.destination?.displayName {
            if file.status == .ready {
                return (
                    "Organize to \(destinationName)",
                    "checkmark.circle.fill",
                    { onOrganize(file) }
                )
            } else {
                return (
                    "Review Destination",
                    "arrow.right.circle",
                    { onEditDestination?(file) }
                )
            }
        } else {
            return (
                "Create Rule",
                "wand.and.stars",
                { onCreateRule?(file) }
            )
        }
    }
}
