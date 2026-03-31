import XCTest
@testable import Forma_File_Organizing

@MainActor
final class FileRowTests: XCTestCase {
    
    // MARK: - Primary Action Configuration Tests
    
    func testPrimaryActionConfig_FileWithDestinationAndReady_ReturnsOrganize() {
        // Given: A file with a suggested destination and ready status
        let file = FileItem(
            path: "/test/test.pdf",
            sizeInBytes: 1_000_000,
            creationDate: Date(),
            destination: .mockFolder("Documents/PDFs"),
            status: .ready
        )
        
        // When: Getting the primary action config
        let config = FileRowActionConfig.resolve(
            file: file,
            onOrganize: { _ in },
            onEditDestination: nil,
            onCreateRule: nil
        )
        
        // Then: Should return Organize action
        XCTAssertEqual(config.label, "Organize")
        XCTAssertEqual(config.icon, "checkmark.circle.fill")
        // Note: Color comparison would need Color extension for Equatable
    }
    
    func testPrimaryActionConfig_FileWithDestinationButPending_ReturnsReview() {
        // Given: A file with a suggested destination but pending status
        let file = FileItem(
            path: "/test/test.pdf",
            sizeInBytes: 1_000_000,
            creationDate: Date(),
            destination: .mockFolder("Documents/PDFs"),
            status: .pending
        )
        
        // When: Getting the primary action config
        let config = FileRowActionConfig.resolve(
            file: file,
            onOrganize: { _ in },
            onEditDestination: nil,
            onCreateRule: nil
        )
        
        // Then: Should return Review action and route to destination editing
        XCTAssertEqual(config.label, "Review")
        XCTAssertEqual(config.icon, "slider.horizontal.3")
    }
    
    func testPrimaryActionConfig_FileWithoutDestination_ReturnsCreateRule() {
        // Given: A file without a suggested destination
        let file = FileItem(
            path: "/test/test.txt",
            sizeInBytes: 1_000,
            creationDate: Date(),
            destination: nil,
            status: .pending
        )
        
        // When: Getting the primary action config
        let config = FileRowActionConfig.resolve(
            file: file,
            onOrganize: { _ in },
            onEditDestination: nil,
            onCreateRule: nil
        )
        
        // Then: Should return Create Rule action
        XCTAssertEqual(config.label, "Set Destination")
        XCTAssertEqual(config.icon, "folder.badge.plus")
    }
    
    func testPrimaryActionConfig_FileWithDestinationAndSkippedStatus_ReturnsReview() {
        // Given: A file with destination but skipped status
        let file = FileItem(
            path: "/test/test.jpg",
            sizeInBytes: 2_000_000,
            creationDate: Date(),
            destination: .mockFolder("Pictures"),
            status: .skipped
        )
        
        // When: Getting the primary action config
        let config = FileRowActionConfig.resolve(
            file: file,
            onOrganize: { _ in },
            onEditDestination: nil,
            onCreateRule: nil
        )
        
        // Then: Should return Review action and route to destination editing
        XCTAssertEqual(config.label, "Review")
        XCTAssertEqual(config.icon, "slider.horizontal.3")
    }
    
    // MARK: - Callback Tests
    
    func testOrganizeCallback_CalledWhenDestinationIsReady() {
        // Given: A ready file and a callback expectation
        let file = FileItem(
            path: "/test/test.pdf",
            sizeInBytes: 1_000_000,
            creationDate: Date(),
            destination: .mockFolder("Documents"),
            status: .ready
        )
        
        var organizeCalled = false
        var organizedFile: FileItem?
        
        let config = FileRowActionConfig.resolve(
            file: file,
            onOrganize: { item in
                organizeCalled = true
                organizedFile = item
            },
            onEditDestination: nil,
            onCreateRule: nil
        )
        
        // When: Executing the primary action
        config.action()
        
        // Then: Organize callback should be called with the file
        XCTAssertTrue(organizeCalled)
        XCTAssertEqual(organizedFile?.path, file.path)
    }
    
    func testEditDestinationCallback_CalledWhenDestinationNeedsReview() {
        // Given: A pending file with destination
        let file = FileItem(
            path: "/test/test.pdf",
            sizeInBytes: 1_000_000,
            creationDate: Date(),
            destination: .mockFolder("Documents"),
            status: .pending
        )
        
        var editCalled = false
        var editedFile: FileItem?
        
        let config = FileRowActionConfig.resolve(
            file: file,
            onOrganize: { _ in },
            onEditDestination: { item in
                editCalled = true
                editedFile = item
            },
            onCreateRule: nil
        )
        
        // When: Executing the primary action
        config.action()
        
        // Then: Edit destination callback should be called
        XCTAssertTrue(editCalled)
        XCTAssertEqual(editedFile?.path, file.path)
    }
    
    func testCreateRuleCallback_CalledWhenNoDestination() {
        // Given: A file without destination
        let file = FileItem(
            path: "/test/test.txt",
            sizeInBytes: 1_000,
            creationDate: Date(),
            destination: nil,
            status: .pending
        )
        
        var createRuleCalled = false
        var ruleFile: FileItem?
        
        let config = FileRowActionConfig.resolve(
            file: file,
            onOrganize: { _ in },
            onEditDestination: nil,
            onCreateRule: { item in
                createRuleCalled = true
                ruleFile = item
            }
        )
        
        // When: Executing the primary action
        config.action()
        
        // Then: Create rule callback should be called
        XCTAssertTrue(createRuleCalled)
        XCTAssertEqual(ruleFile?.path, file.path)
    }

    func testAccessibilityStateValue_IncludesProcessingActivity() {
        let value = FileRowAccessibilityState.value(
            view: "card",
            isSelected: true,
            isFocused: false,
            status: .ready,
            activity: .processing
        )

        XCTAssertEqual(
            value,
            "view=card;selected=1;focused=0;status=ready;activity=processing"
        )
    }

    func testAccessibilityStateValue_IncludesErrorActivity() {
        let value = FileRowAccessibilityState.value(
            view: "grid",
            isSelected: false,
            isFocused: true,
            status: .pending,
            activity: .error
        )

        XCTAssertEqual(
            value,
            "view=grid;selected=0;focused=1;status=pending;activity=error"
        )
    }
}

// MARK: - Test Helpers
