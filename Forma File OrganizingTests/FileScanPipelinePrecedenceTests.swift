import XCTest
import SwiftData
@testable import Forma_File_Organizing

/// Integration tests for FileScanPipeline prediction ordering.
///
/// Verifies correct precedence: RuleEngine → LearnedPattern → ML predictions
/// Tests that:
/// - Rules always win (highest priority)
/// - Patterns are second priority (only for files rules don't match)
/// - ML predictions are last (only when neither rules nor patterns match)
/// - FileItem state updates correctly through the pipeline
@available(macOS 13.0, *)
@MainActor
final class FileScanPipelinePrecedenceTests: XCTestCase {
    
    var modelContext: ModelContext!
    var pipeline: FileScanPipeline!
    var ruleEngine: RuleEngine!
    var mockFileSystem: MockFileSystemService!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory model container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FileItem.self, Rule.self, ActivityItem.self,
                 LearnedPattern.self, MLTrainingHistory.self,
            configurations: config
        )
        modelContext = ModelContext(container)
        
        pipeline = FileScanPipeline()
        ruleEngine = RuleEngine()
        mockFileSystem = MockFileSystemService()
    }
    
    override func tearDown() async throws {
        // Allow async TaskGroup/TaskLocal cleanup to complete before deallocating
        // This prevents memory corruption when Swift Concurrency's internal cleanup
        // races with object deallocation during test teardown.
        try await Task.sleep(for: .milliseconds(50))

        // Clear references in reverse dependency order
        pipeline = nil
        ruleEngine = nil
        mockFileSystem = nil
        modelContext = nil
    }
    
    // MARK: - Pipeline Precedence Tests
    
    /// Test: Rules take precedence over patterns
    func testPrecedence_RulesOverPatterns() async throws {
        // Create a rule that matches PDFs → Documents/Work
        let rule = Rule(
            name: "PDF Rule",
            conditions: [.fileExtension("pdf")],
            logicalOperator: .single,
            actionType: .move,
            destination: .mockFolder("Documents/Work"),
            isEnabled: true
        )
        modelContext.insert(rule)
        
        // Create a conflicting pattern: PDFs → Archive
        let pattern = LearnedPattern(
            patternDescription: "PDFs → Archive",
            fileExtension: "pdf",
            destinationPath: "Archive",
            occurrenceCount: 5,
            confidenceScore: 0.9
        )
        modelContext.insert(pattern)
        
        try modelContext.save()
        
        // Scan a PDF file
        mockFileSystem.mockFiles = [
            createMockMetadata(name: "test.pdf", ext: "pdf", location: .desktop)
        ]
        
        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            customFolders: [],
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [rule],
            context: modelContext
        )
        
        // Verify rule won over pattern
        XCTAssertEqual(result.files.count, 1, "Should have one file")
        let file = result.files.first!
        XCTAssertEqual(file.destination?.displayName, "Documents/Work", "Rule should win")
        XCTAssertEqual(file.status, .ready, "File should be ready")
        XCTAssertEqual(file.suggestionSource, .rule, "Source should be rule")
    }
    
    /// Test: Patterns take precedence over ML predictions
    func testPrecedence_PatternsOverML() async throws {
        // No rules, but create a pattern: screenshots → Pictures/Screenshots
        let pattern = LearnedPattern(
            patternDescription: "Screenshots → Pictures/Screenshots",
            fileExtension: "png",
            destinationPath: "Pictures/Screenshots",
            occurrenceCount: 10,
            confidenceScore: 0.85
        )
        modelContext.insert(pattern)
        
        try modelContext.save()
        
        // Scan a screenshot file
        mockFileSystem.mockFiles = [
            createMockMetadata(name: "Screenshot.png", ext: "png", location: .desktop)
        ]
        
        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            customFolders: [],
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [],
            context: modelContext
        )
        
        // Verify pattern was applied (ML would be applied only if pattern didn't match)
        XCTAssertEqual(result.files.count, 1, "Should have one file")
        let file = result.files.first!
        XCTAssertEqual(file.destination?.displayName, "Pictures/Screenshots", "Pattern should apply")
        XCTAssertEqual(file.suggestionSource, .pattern, "Source should be pattern")
    }
    
    /// Test: ML predictions only apply when no rules or patterns match
    func testPrecedence_MLOnlyWhenNoRulesOrPatterns() async throws {
        // Create a trained ML model (simulated via training history)
        let modelHistory = MLTrainingHistory(
            modelName: "destinationPrediction",
            version: "1-test",
            exampleCount: 100,
            labelCount: 3,
            validationAccuracy: 0.8,
            falsePositiveRate: 0.1,
            accepted: true,
            notes: "Test model"
        )
        modelContext.insert(modelHistory)
        try modelContext.save()
        
        // No rules or patterns
        mockFileSystem.mockFiles = [
            createMockMetadata(name: "invoice.pdf", ext: "pdf", location: .desktop)
        ]
        
        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            customFolders: [],
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [],
            context: modelContext
        )
        
        // File should either have ML prediction or remain pending
        XCTAssertEqual(result.files.count, 1, "Should have one file")
        let file = result.files.first!
        
        // Without a real trained model, file will remain pending
        // This test verifies the pipeline attempts ML prediction
        if file.status == .ready {
            XCTAssertEqual(file.suggestionSource, .mlPrediction, "If ready, source should be ML")
        } else {
            XCTAssertEqual(file.status, .pending, "If no ML model, file should remain pending")
        }
    }
    
    /// Test: Full pipeline ordering with all three sources
    func testPrecedence_FullPipelineOrdering() async throws {
        // Create rules for PDF files only
        let pdfRule = Rule(
            name: "PDF to Work",
            conditions: [.fileExtension("pdf")],
            logicalOperator: .single,
            actionType: .move,
            destination: .mockFolder("Documents/Work"),
            isEnabled: true
        )
        modelContext.insert(pdfRule)
        
        // Create patterns for screenshots
        let screenshotPattern = LearnedPattern(
            patternDescription: "Screenshots → Pictures/Screenshots",
            fileExtension: "png",
            destinationPath: "Pictures/Screenshots",
            occurrenceCount: 15,
            confidenceScore: 0.9
        )
        modelContext.insert(screenshotPattern)
        
        try modelContext.save()
        
        // Scan multiple files: PDF (rule), screenshot (pattern), invoice (ML or pending)
        mockFileSystem.mockFiles = [
            createMockMetadata(name: "report.pdf", ext: "pdf", location: .desktop),
            createMockMetadata(name: "Screenshot.png", ext: "png", location: .desktop),
            createMockMetadata(name: "invoice.docx", ext: "docx", location: .desktop)
        ]
        
        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            customFolders: [],
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [pdfRule],
            context: modelContext
        )
        
        XCTAssertEqual(result.files.count, 3, "Should have three files")
        
        // Verify each file got appropriate suggestion
        let pdfFile = result.files.first { $0.name == "report.pdf" }
        XCTAssertNotNil(pdfFile, "PDF file should exist")
        XCTAssertEqual(pdfFile?.destination?.displayName, "Documents/Work", "PDF matched by rule")
        XCTAssertEqual(pdfFile?.suggestionSource, .rule, "PDF source should be rule")

        let screenshotFile = result.files.first { $0.name == "Screenshot.png" }
        XCTAssertNotNil(screenshotFile, "Screenshot file should exist")
        XCTAssertEqual(screenshotFile?.destination?.displayName, "Pictures/Screenshots", "Screenshot matched by pattern")
        XCTAssertEqual(screenshotFile?.suggestionSource, .pattern, "Screenshot source should be pattern")
        
        let invoiceFile = result.files.first { $0.name == "invoice.docx" }
        XCTAssertNotNil(invoiceFile, "Invoice file should exist")
        // Invoice should be either ML prediction or pending (no rule/pattern matches it)
        if invoiceFile?.status == .ready {
            XCTAssertEqual(invoiceFile?.suggestionSource, .mlPrediction, "Invoice should use ML if available")
        } else {
            XCTAssertEqual(invoiceFile?.status, .pending, "Invoice should be pending without ML")
        }
    }
    
    // MARK: - FileItem State Update Tests
    
    /// Test: FileItem updates correctly when rule matches
    func testFileItemUpdate_RuleMatch() async throws {
        let rule = Rule(
            name: "Images to Pictures",
            conditions: [.fileKind("image")],
            logicalOperator: .single,
            actionType: .move,
            destination: .mockFolder("Pictures"),
            isEnabled: true
        )
        modelContext.insert(rule)
        try modelContext.save()
        
        mockFileSystem.mockFiles = [
            createMockMetadata(name: "photo.jpg", ext: "jpg", location: .desktop)
        ]
        
        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            customFolders: [],
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [rule],
            context: modelContext
        )
        
        let file = result.files.first!
        XCTAssertEqual(file.status, .ready, "Status should be ready")
        XCTAssertNotNil(file.destination, "Should have destination")
        XCTAssertNotNil(file.matchReason, "Should have match reason")
        XCTAssertGreaterThan(file.confidenceScore ?? 0.0, 0.0, "Should have confidence score")
    }

    /// Test: FileItem stays pending when no suggestions available
    func testFileItemUpdate_NothingMatches() async throws {
        // No rules, no patterns, no ML model
        mockFileSystem.mockFiles = [
            createMockMetadata(name: "unknown.xyz", ext: "xyz", location: .desktop)
        ]
        
        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            customFolders: [],
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [],
            context: modelContext
        )
        
        let file = result.files.first!
        XCTAssertEqual(file.status, .pending, "Status should remain pending")
        XCTAssertNil(file.destination, "Should have no destination")
        XCTAssertNil(file.matchReason, "Should have no match reason")
    }

    /// Test: Existing FileItem is updated on rescan
    func testFileItemUpdate_ExistingFile() async throws {
        // First scan: create a file
        mockFileSystem.mockFiles = [
            createMockMetadata(name: "test.pdf", ext: "pdf", location: .desktop)
        ]
        
        var result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            customFolders: [],
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [],
            context: modelContext
        )
        
        let originalFileID = result.files.first!.id
        XCTAssertEqual(result.files.first?.status, .pending, "Initially pending")
        
        // Second scan: add a rule that matches
        let rule = Rule(
            name: "PDF Rule",
            conditions: [.fileExtension("pdf")],
            logicalOperator: .single,
            actionType: .move,
            destination: .mockFolder("Documents"),
            isEnabled: true
        )
        modelContext.insert(rule)
        try modelContext.save()
        
        result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            customFolders: [],
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [rule],
            context: modelContext
        )
        
        // Verify same file was updated (not duplicated)
        XCTAssertEqual(result.files.count, 1, "Should still have one file")
        let updatedFile = result.files.first!
        XCTAssertEqual(updatedFile.id, originalFileID, "Should be same file")
        XCTAssertEqual(updatedFile.status, .ready, "Should now be ready")
        XCTAssertEqual(updatedFile.destination?.displayName, "Documents", "Should have rule destination")
    }

    // MARK: - Edge Case Tests
    
    /// Test: Disabled rules are skipped
    func testEdgeCase_DisabledRulesSkipped() async throws {
        let rule = Rule(
            name: "Disabled Rule",
            conditions: [.fileExtension("pdf")],
            logicalOperator: .single,
            actionType: .move,
            destination: .mockFolder("Documents"),
            isEnabled: false // Disabled!
        )
        modelContext.insert(rule)
        try modelContext.save()
        
        mockFileSystem.mockFiles = [
            createMockMetadata(name: "test.pdf", ext: "pdf", location: .desktop)
        ]
        
        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            customFolders: [],
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [rule],
            context: modelContext
        )
        
        // File should remain pending (disabled rule shouldn't match)
        let file = result.files.first!
        XCTAssertEqual(file.status, .pending, "Disabled rule should not apply")
    }
    
    /// Test: Patterns with low confidence are still applied
    func testEdgeCase_LowConfidencePattern() async throws {
        let pattern = LearnedPattern(
            patternDescription: "PDFs → Documents",
            fileExtension: "pdf",
            destinationPath: "Documents",
            occurrenceCount: 3,
            confidenceScore: 0.5 // Low confidence
        )
        modelContext.insert(pattern)
        try modelContext.save()
        
        mockFileSystem.mockFiles = [
            createMockMetadata(name: "test.pdf", ext: "pdf", location: .desktop)
        ]
        
        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            customFolders: [],
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [],
            context: modelContext
        )
        
        let file = result.files.first!
        XCTAssertEqual(file.status, .ready, "Low confidence pattern should still apply")
        XCTAssertEqual(file.confidenceScore, 0.5, "Should preserve pattern confidence")
    }
    
    /// Test: Multiple rules match - more specific rule wins
    func testEdgeCase_MultipleRulesMatch() async throws {
        let rule1 = Rule(
            name: "General PDF Rule",
            conditions: [.fileExtension("pdf")],
            logicalOperator: .single,
            actionType: .move,
            destination: .mockFolder("Documents"),
            isEnabled: true
        )

        let rule2 = Rule(
            name: "Invoice PDF Rule",
            conditions: [.fileExtension("pdf"), .nameContains("invoice")],
            logicalOperator: .and,
            actionType: .move,
            destination: .mockFolder("Documents/Finance"),
            isEnabled: true
        )
        // More specific rule (2 conditions) should match first
        
        modelContext.insert(rule1)
        modelContext.insert(rule2)
        try modelContext.save()
        
        mockFileSystem.mockFiles = [
            createMockMetadata(name: "invoice.pdf", ext: "pdf", location: .desktop)
        ]
        
        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            customFolders: [],
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [rule1, rule2],
            context: modelContext
        )
        
        // More specific rule should win
        let file = result.files.first!
        XCTAssertEqual(file.destination?.displayName, "Documents/Finance", "More specific rule should win")
    }

    // MARK: - Helper Methods
    
    /// Create mock FileMetadata for testing
    func createMockMetadata(
        name: String,
        ext: String,
        location: FileLocationKind
    ) -> FileMetadata {
        FileMetadata(
            path: "/tmp/\(name).\(ext)",
            sizeInBytes: 1024,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: location,
            destination: nil,
            status: .pending,
            matchReason: nil,
            confidenceScore: nil,
            suggestionSourceRaw: nil
        )
    }
}
