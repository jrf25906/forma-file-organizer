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
    
    var container: ModelContainer!
    var modelContext: ModelContext!
    var pipeline: FileScanPipeline!
    var ruleEngine: RuleEngine!
    var mockFileSystem: MockFileSystemService!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: FileItem.self, Rule.self, ActivityItem.self,
                 PersonalMemoryEvent.self, PersonalMemoryPreference.self,
                 LearnedPattern.self, MLTrainingHistory.self,
                 FileMetadataRecord.self, FileOrganizationHistoryEntry.self,
            configurations: config
        )
        await MainActor.run {
            modelContext = ModelContext(container)
            pipeline = FileScanPipeline()
            ruleEngine = RuleEngine()
            mockFileSystem = MockFileSystemService()
        }
    }
    
    override func tearDown() async throws {
        // Allow async TaskGroup/TaskLocal cleanup to complete before deallocating
        // This prevents memory corruption when Swift Concurrency's internal cleanup
        // races with object deallocation during test teardown.
        try await Task.sleep(for: .milliseconds(50))

        // Clear references in reverse dependency order
        await MainActor.run {
            pipeline = nil
            ruleEngine = nil
            mockFileSystem = nil
            modelContext = nil
            container = nil
        }
        try await super.tearDown()
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
            scanOptions: .defaults,
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
            scanOptions: .defaults,
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

    /// Test: Personal memory takes precedence over learned patterns.
    func testPrecedence_PersonalMemoryOverPatterns() async throws {
        let memoryService = PersonalMemoryService(modelContext: modelContext)
        let memoryDestination = Destination.mockFolder("Documents/Invoices")

        for index in 0..<2 {
            _ = try memoryService.recordDecision(
                fileName: "Invoice-\(index).pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: nil,
                sourceSurface: .reviewFlow,
                suggestionSource: .personalMemory,
                suggestedDestination: memoryDestination,
                chosenDestination: memoryDestination,
                confidenceScore: 0.84,
                matchedRuleID: nil
            )
        }

        let pattern = LearnedPattern(
            patternDescription: "PDFs → Archive",
            fileExtension: "pdf",
            destinationPath: "Archive",
            occurrenceCount: 8,
            confidenceScore: 0.9
        )
        modelContext.insert(pattern)
        try modelContext.save()

        mockFileSystem.mockFiles = [
            createMockMetadata(name: "invoice.pdf", ext: "pdf", location: .downloads)
        ]

        let result = await pipeline.scanAndPersist(
            baseFolders: [.downloads],
            scanOptions: .defaults,
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [],
            context: modelContext
        )

        let file = try XCTUnwrap(result.files.first)
        XCTAssertEqual(file.destination?.displayName, "Documents/Invoices", "Personal memory should win over learned pattern")
        XCTAssertEqual(file.originalSuggestedDestination?.displayName, "Documents/Invoices")
        XCTAssertEqual(file.suggestionSource, .personalMemory)
    }

    func testPrecedence_DerivedPersonalMemoryPatternsDoNotApplyAsGenericPatterns() async throws {
        let featureFlags = FeatureFlagService.shared
        featureFlags.resetToDefaults()
        defer { featureFlags.resetToDefaults() }
        featureFlags.setEnabled(.destinationPrediction, false)

        let pattern = LearnedPattern(
            patternDescription: "PDFs from Downloads usually go to Documents/Invoices",
            fileExtension: "pdf",
            destinationPath: "Documents/Invoices",
            occurrenceCount: 8,
            source: .personalMemory,
            confidenceScore: 0.9
        )
        modelContext.insert(pattern)
        try modelContext.save()

        mockFileSystem.mockFiles = [
            createMockMetadata(name: "invoice.pdf", ext: "pdf", location: .downloads)
        ]

        let result = await pipeline.scanAndPersist(
            baseFolders: [.downloads],
            scanOptions: .defaults,
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [],
            context: modelContext
        )

        let file = try XCTUnwrap(result.files.first)
        XCTAssertEqual(file.status, .pending)
        XCTAssertNil(file.destination)
    }

    func testProjectSpaceMemorySuggestion_AppliesForKnownProjectWithDominantRecentDestination() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)

        let tempDir = try TemporaryDirectory()
        let fileURL = try tempDir.createFile(name: "Workspace/Alpha/invoice.pdf", contents: "invoice")
        let dominantFolderURL = try tempDir.createDirectory(name: "Destinations/Alpha Archive")
        let secondaryFolderURL = try tempDir.createDirectory(name: "Destinations/Beta Vault")
        let now = Date()

        let record = makeMetadataRecord(
            path: fileURL.path,
            displayName: fileURL.lastPathComponent,
            projectAssociation: "Alpha"
        )

        addHistoryEntry(
            to: record,
            eventKind: .organized,
            timestamp: now.addingTimeInterval(-3_600),
            toPath: dominantFolderURL.appendingPathComponent("invoice-v1.pdf").path,
            destinationDisplayName: "Alpha Archive"
        )
        addHistoryEntry(
            to: record,
            eventKind: .rekeyed,
            timestamp: now.addingTimeInterval(-2_400),
            toPath: dominantFolderURL.appendingPathComponent("invoice-v2.pdf").path,
            destinationDisplayName: "Alpha Archive"
        )
        addHistoryEntry(
            to: record,
            eventKind: .organized,
            timestamp: now.addingTimeInterval(-1_200),
            toPath: secondaryFolderURL.appendingPathComponent("invoice-v3.pdf").path,
            destinationDisplayName: "Beta Vault"
        )
        try modelContext.save()

        mockFileSystem.mockFiles = [
            createMockMetadata(path: fileURL.path, ext: "pdf", location: .desktop)
        ]

        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [],
            context: modelContext
        )

        let file = try XCTUnwrap(result.files.first(where: { $0.path == fileURL.path }))
        XCTAssertEqual(file.status, .ready)
        XCTAssertEqual(file.suggestionSource, .projectSpaceMemory)
        XCTAssertEqual(file.destination?.displayName, "Alpha Archive")
        XCTAssertEqual(file.originalSuggestedDestination?.displayName, "Alpha Archive")
        XCTAssertNotNil(file.destination?.bookmarkData)
        XCTAssertNotNil(file.matchReason)
        XCTAssertGreaterThan(file.confidenceScore ?? 0, 0.6)
    }

    func testProjectSpaceMemorySuggestion_DoesNotOverrideExplicitRuleOrPersonalMemory() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)

        let tempDir = try TemporaryDirectory()
        let dominantFolderURL = try tempDir.createDirectory(name: "Destinations/Project Archive")
        let explicitRuleFileURL = try tempDir.createFile(name: "Workspace/Alpha/contract.pdf", contents: "contract")
        let personalMemoryFileURL = try tempDir.createFile(name: "Workspace/Alpha/invoice.txt", contents: "invoice")
        let personalMemoryDestinationURL = try tempDir.createDirectory(name: "Destinations/Personal Inbox")
        let personalMemoryDestination = try Destination.folder(
            from: personalMemoryDestinationURL,
            displayName: "Personal Inbox"
        )

        let explicitRuleRecord = makeMetadataRecord(
            path: explicitRuleFileURL.path,
            displayName: explicitRuleFileURL.lastPathComponent,
            projectAssociation: "Alpha"
        )
        let personalMemoryRecord = makeMetadataRecord(
            path: personalMemoryFileURL.path,
            displayName: personalMemoryFileURL.lastPathComponent,
            projectAssociation: "Alpha"
        )

        let now = Date()
        addHistoryEntry(
            to: explicitRuleRecord,
            eventKind: .organized,
            timestamp: now.addingTimeInterval(-3_600),
            toPath: dominantFolderURL.appendingPathComponent("contract-v1.pdf").path,
            destinationDisplayName: "Project Archive"
        )
        addHistoryEntry(
            to: explicitRuleRecord,
            eventKind: .rekeyed,
            timestamp: now.addingTimeInterval(-2_000),
            toPath: dominantFolderURL.appendingPathComponent("contract-v2.pdf").path,
            destinationDisplayName: "Project Archive"
        )
        addHistoryEntry(
            to: personalMemoryRecord,
            eventKind: .organized,
            timestamp: now.addingTimeInterval(-1_800),
            toPath: dominantFolderURL.appendingPathComponent("invoice-v1.txt").path,
            destinationDisplayName: "Project Archive"
        )
        addHistoryEntry(
            to: personalMemoryRecord,
            eventKind: .rekeyed,
            timestamp: now.addingTimeInterval(-1_000),
            toPath: dominantFolderURL.appendingPathComponent("invoice-v2.txt").path,
            destinationDisplayName: "Project Archive"
        )

        let memoryService = PersonalMemoryService(modelContext: modelContext)
        for index in 0..<2 {
            _ = try memoryService.recordDecision(
                fileName: "invoice-\(index).txt",
                fileExtension: "txt",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: nil,
                relativeParentPath: nil,
                sourceSurface: .reviewFlow,
                suggestionSource: .personalMemory,
                suggestedDestination: personalMemoryDestination,
                chosenDestination: personalMemoryDestination,
                confidenceScore: 0.9,
                matchedRuleID: nil
            )
        }
        try modelContext.save()

        let explicitRule = Rule(
            name: "Contracts Rule",
            conditions: [.fileExtension("pdf")],
            logicalOperator: .single,
            actionType: .move,
            destination: .mockFolder("Rule Destination"),
            isEnabled: true
        )
        modelContext.insert(explicitRule)
        try modelContext.save()

        mockFileSystem.mockFiles = [
            createMockMetadata(path: explicitRuleFileURL.path, ext: "pdf", location: .desktop),
            createMockMetadata(path: personalMemoryFileURL.path, ext: "txt", location: .downloads)
        ]

        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop, .downloads],
            scanOptions: .defaults,
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [explicitRule],
            context: modelContext
        )

        let ruleFile = try XCTUnwrap(result.files.first(where: { $0.path == explicitRuleFileURL.path }))
        XCTAssertEqual(ruleFile.destination?.displayName, "Rule Destination")
        XCTAssertEqual(ruleFile.suggestionSource, .rule)
        XCTAssertNotEqual(ruleFile.suggestionSource, .projectSpaceMemory)

        let memoryFile = try XCTUnwrap(result.files.first(where: { $0.path == personalMemoryFileURL.path }))
        XCTAssertEqual(memoryFile.destination?.displayName, "Personal Inbox")
        XCTAssertEqual(memoryFile.suggestionSource, .personalMemory)
        XCTAssertNotEqual(memoryFile.suggestionSource, .projectSpaceMemory)
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
            scanOptions: .defaults,
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
            scanOptions: .defaults,
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
            scanOptions: .defaults,
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
            scanOptions: .defaults,
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
            scanOptions: .defaults,
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
            scanOptions: .defaults,
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
            scanOptions: .defaults,
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
            scanOptions: .defaults,
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
            scanOptions: .defaults,
            fileSystemService: mockFileSystem,
            ruleEngine: ruleEngine,
            rules: [rule2, rule1],
            context: modelContext
        )
        
        // More specific rule should win
        let file = result.files.first!
        XCTAssertEqual(file.destination?.displayName, "Documents/Finance", "More specific rule should win")
    }

    // MARK: - Helper Methods

    @discardableResult
    private func makeMetadataRecord(
        path: String,
        displayName: String,
        projectAssociation: String?
    ) -> FileMetadataRecord {
        let identity = FileMetadataRecord.Identity.pathFallback(path: path)
        let record = FileMetadataRecord(
            canonicalIdentity: identity.canonicalIdentity,
            identityKind: identity.kind,
            lastKnownPath: path,
            displayName: displayName,
            fileExtension: URL(fileURLWithPath: path).pathExtension,
            firstSeenAt: Date(timeIntervalSince1970: 100),
            lastSeenAt: Date(timeIntervalSince1970: 100)
        )
        record.projectAssociation = projectAssociation
        modelContext.insert(record)
        return record
    }

    private func addHistoryEntry(
        to record: FileMetadataRecord,
        eventKind: FileOrganizationHistoryEntry.EventKind,
        timestamp: Date,
        toPath: String,
        destinationDisplayName: String
    ) {
        let entry = FileOrganizationHistoryEntry(
            timestamp: timestamp,
            metadataRecord: record,
            fileIdentitySnapshot: record.canonicalIdentity,
            eventKind: eventKind,
            sourceSurface: .review,
            fromPath: record.lastKnownPath,
            toPath: toPath,
            destinationDisplayName: destinationDisplayName,
            detailsSummary: nil
        )
        modelContext.insert(entry)
        record.historyEntries.append(entry)
    }
    
    /// Create mock FileMetadata for testing
    func createMockMetadata(
        name: String,
        ext: String,
        location: FileLocationKind
    ) -> FileMetadata {
        createMockMetadata(path: "/tmp/\(name)", ext: ext, location: location)
    }

    func createMockMetadata(
        path: String,
        ext: String,
        location: FileLocationKind
    ) -> FileMetadata {
        let normalizedExt = ext.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathURL = URL(fileURLWithPath: path)
        let filename: String
        if normalizedExt.isEmpty {
            filename = pathURL.lastPathComponent
        } else if pathURL.lastPathComponent.lowercased().hasSuffix(".\(normalizedExt.lowercased())") {
            filename = pathURL.lastPathComponent
        } else {
            filename = "\(pathURL.lastPathComponent).\(normalizedExt)"
        }
        let finalPath = pathURL.deletingLastPathComponent().appendingPathComponent(filename).path
        return FileMetadata(
            path: finalPath,
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
