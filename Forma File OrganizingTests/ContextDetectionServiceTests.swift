import XCTest
@testable import Forma_File_Organizing

@MainActor
final class ContextDetectionServiceTests: XCTestCase {
    
    var service: ContextDetectionService!
    
    override func setUp() {
        super.setUp()
        service = ContextDetectionService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    // MARK: - Project Code Detection Tests
    
    func testDetectsProjectCodePattern_P_Number() {
        // Given: Files with P-1024 project code
        let files = [
            createFile(name: "P-1024_proposal.pdf"),
            createFile(name: "P-1024_budget.xlsx"),
            createFile(name: "P-1024_timeline.png"),
        ]

        // When: Detecting clusters
        let clusters = service.detectClusters(from: files)

        // Then: Should detect at least one project code cluster
        // Note: Other cluster types (temporal, nameSimilarity) may also be detected
        let projectCodeClusters = clusters.filter { $0.clusterType == .projectCode }
        XCTAssertEqual(projectCodeClusters.count, 1, "Should detect exactly one project code cluster")

        let cluster = projectCodeClusters.first!
        XCTAssertEqual(cluster.clusterType, .projectCode)
        XCTAssertEqual(cluster.fileCount, 3)
        XCTAssertEqual(cluster.detectedPattern, "P-1024")
        XCTAssertGreaterThanOrEqual(cluster.confidenceScore, 0.8, "Project code should have high confidence")
        XCTAssertEqual(cluster.suggestedFolderName, "Project P-1024")
    }
    
    func testDetectsJiraCodePattern() {
        // Given: Files with JIRA-456 pattern
        let files = [
            createFile(name: "JIRA-456_requirements.doc"),
            createFile(name: "JIRA-456_mockup.png"),
            createFile(name: "JIRA-456_notes.txt"),
        ]

        // When
        let clusters = service.detectClusters(from: files)

        // Then: Filter to project code clusters (other types may also be detected)
        let projectCodeClusters = clusters.filter { $0.clusterType == .projectCode }
        XCTAssertEqual(projectCodeClusters.count, 1, "Should detect exactly one project code cluster")
        let cluster = projectCodeClusters.first!
        XCTAssertEqual(cluster.clusterType, .projectCode)
        XCTAssertEqual(cluster.detectedPattern, "JIRA-456")
    }
    
    func testDetectsClientCodePattern() {
        // Given: Files with CLIENT_ABC pattern
        let files = [
            createFile(name: "CLIENT_ABC_contract.pdf"),
            createFile(name: "CLIENT_ABC_invoice.xlsx"),
            createFile(name: "CLIENT_ABC_presentation.pptx"),
        ]

        // When
        let clusters = service.detectClusters(from: files)

        // Then: Filter to project code clusters (other types may also be detected)
        let projectCodeClusters = clusters.filter { $0.clusterType == .projectCode }
        XCTAssertEqual(projectCodeClusters.count, 1, "Should detect exactly one project code cluster")
        let cluster = projectCodeClusters.first!
        XCTAssertEqual(cluster.clusterType, .projectCode)
        XCTAssertEqual(cluster.detectedPattern, "CLIENT_ABC")
    }
    
    func testDoesNotDetectProjectCodeWithTooFewFiles() {
        // Given: Only 2 files with same project code
        let files = [
            createFile(name: "P-1024_proposal.pdf"),
            createFile(name: "P-1024_budget.xlsx"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then: Should not detect cluster (needs minimum 3 files)
        XCTAssertEqual(clusters.count, 0, "Should not detect cluster with only 2 files")
    }
    
    // MARK: - Temporal Clustering Tests
    
    func testDetectsTemporalCluster_TightWindow() {
        // Given: Files modified within 1 minute of each other
        // Note: timeSpan must be < 60 seconds for 0.85 confidence (not <=)
        let baseDate = Date()
        let files = [
            createFile(name: "design_v1.sketch", modDate: baseDate),
            createFile(name: "design_v2.sketch", modDate: baseDate.addingTimeInterval(20)),  // 20 seconds later
            createFile(name: "design_v3.sketch", modDate: baseDate.addingTimeInterval(45)),  // 45 seconds later (total span < 60s)
        ]

        // When
        let clusters = service.detectClusters(from: files)

        // Then: Should detect temporal cluster with high confidence
        let temporalClusters = clusters.filter { $0.clusterType == .temporal }
        XCTAssertEqual(temporalClusters.count, 1, "Should detect exactly one temporal cluster")

        let cluster = temporalClusters.first!
        XCTAssertEqual(cluster.fileCount, 3)
        XCTAssertGreaterThanOrEqual(cluster.confidenceScore, 0.80, "Tight temporal grouping should have high confidence")
    }
    
    func testDetectsTemporalCluster_LooseWindow() {
        // Given: Files modified within 5 minutes of each other
        let baseDate = Date()
        let files = [
            createFile(name: "file1.txt", modDate: baseDate),
            createFile(name: "file2.txt", modDate: baseDate.addingTimeInterval(180)),  // 3 minutes
            createFile(name: "file3.txt", modDate: baseDate.addingTimeInterval(240)),  // 4 minutes
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then: Should detect temporal cluster with lower confidence
        let temporalClusters = clusters.filter { $0.clusterType == .temporal }
        XCTAssertEqual(temporalClusters.count, 1)
        
        let cluster = temporalClusters.first!
        XCTAssertEqual(cluster.fileCount, 3)
        XCTAssertLessThan(cluster.confidenceScore, 0.80, "Loose temporal grouping should have lower confidence")
    }
    
    func testDoesNotDetectTemporalClusterWhenGapTooLarge() {
        // Given: Files with gap > 5 minutes
        let baseDate = Date()
        let files = [
            createFile(name: "file1.txt", modDate: baseDate),
            createFile(name: "file2.txt", modDate: baseDate.addingTimeInterval(360)),  // 6 minutes - too large
            createFile(name: "file3.txt", modDate: baseDate.addingTimeInterval(720)),  // 12 minutes
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then: Should not detect temporal cluster
        let temporalClusters = clusters.filter { $0.clusterType == .temporal }
        XCTAssertEqual(temporalClusters.count, 0, "Should not cluster files with large time gaps")
    }
    
    // MARK: - Name Similarity Tests
    
    func testDetectsNameSimilarityCluster_VersionSequence() {
        // Given: Files with version numbers
        let files = [
            createFile(name: "report_v1.docx"),
            createFile(name: "report_v2.docx"),
            createFile(name: "report_v3.docx"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then: Should detect name similarity cluster
        let similarityClusters = clusters.filter { $0.clusterType == .nameSimilarity }
        XCTAssertGreaterThanOrEqual(similarityClusters.count, 1, "Should detect at least one similarity cluster")
        
        let cluster = similarityClusters.first!
        XCTAssertEqual(cluster.fileCount, 3)
        XCTAssertGreaterThanOrEqual(cluster.confidenceScore, 0.5)
        XCTAssertTrue(cluster.suggestedFolderName.contains("report"), "Folder name should be based on common prefix")
    }
    
    func testDetectsNameSimilarityCluster_DraftFinalVersions() {
        // Given: Files with draft/final/revised variations
        let files = [
            createFile(name: "presentation_draft.pptx"),
            createFile(name: "presentation_final.pptx"),
            createFile(name: "presentation_revised.pptx"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then
        let similarityClusters = clusters.filter { $0.clusterType == .nameSimilarity }
        XCTAssertGreaterThanOrEqual(similarityClusters.count, 1)
        
        let cluster = similarityClusters.first!
        XCTAssertEqual(cluster.fileCount, 3)
    }
    
    func testDoesNotDetectSimilarityForDissimilarNames() {
        // Given: Files with very different names
        let files = [
            createFile(name: "budget.xlsx"),
            createFile(name: "vacation_photos.zip"),
            createFile(name: "meeting_notes.txt"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then: Should not detect name similarity cluster
        let similarityClusters = clusters.filter { $0.clusterType == .nameSimilarity }
        XCTAssertEqual(similarityClusters.count, 0, "Should not cluster dissimilar names")
    }
    
    // MARK: - Date Stamp Detection Tests
    
    func testDetectsDateStampCluster_ISO8601Format() {
        // Given: Files with ISO 8601 date format (YYYY-MM-DD)
        let files = [
            createFile(name: "2024-11-15_report.pdf"),
            createFile(name: "2024-11-15_data.xlsx"),
            createFile(name: "2024-11-15_summary.txt"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then: Should detect date stamp cluster
        let dateStampClusters = clusters.filter { $0.clusterType == .dateStamp }
        XCTAssertEqual(dateStampClusters.count, 1)
        
        let cluster = dateStampClusters.first!
        XCTAssertEqual(cluster.fileCount, 3)
        XCTAssertEqual(cluster.detectedPattern, "2024-11-15")
        XCTAssertTrue(cluster.suggestedFolderName.contains("2024-11-15"))
    }
    
    func testDetectsDateStampCluster_CompactFormat() {
        // Given: Files with compact date format (YYYYMMDD)
        let files = [
            createFile(name: "20241115_backup.zip"),
            createFile(name: "20241115_notes.txt"),
            createFile(name: "20241115_log.csv"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then
        let dateStampClusters = clusters.filter { $0.clusterType == .dateStamp }
        XCTAssertGreaterThanOrEqual(dateStampClusters.count, 1)
    }
    
    // MARK: - Multiple Cluster Detection Tests
    
    func testDetectsMultipleClustersOfDifferentTypes() {
        // Given: Files that form clusters of different types
        let baseDate = Date()
        let files = [
            // Project code cluster
            createFile(name: "P-1024_proposal.pdf"),
            createFile(name: "P-1024_budget.xlsx"),
            createFile(name: "P-1024_timeline.png"),
            
            // Temporal cluster (different time window)
            createFile(name: "design1.sketch", modDate: baseDate.addingTimeInterval(-1000)),
            createFile(name: "design2.sketch", modDate: baseDate.addingTimeInterval(-950)),
            createFile(name: "design3.sketch", modDate: baseDate.addingTimeInterval(-900)),
            
            // Date stamp cluster
            createFile(name: "2024-11-15_report1.pdf"),
            createFile(name: "2024-11-15_report2.pdf"),
            createFile(name: "2024-11-15_report3.pdf"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then: Should detect multiple clusters
        XCTAssertGreaterThanOrEqual(clusters.count, 2, "Should detect multiple clusters")
        
        let projectClusters = clusters.filter { $0.clusterType == .projectCode }
        let dateStampClusters = clusters.filter { $0.clusterType == .dateStamp }
        
        XCTAssertGreaterThanOrEqual(projectClusters.count, 1, "Should detect project code cluster")
        XCTAssertGreaterThanOrEqual(dateStampClusters.count, 1, "Should detect date stamp cluster")
    }
    
    // MARK: - Confidence Scoring Tests
    
    func testHighConfidenceForManyFiles() {
        // Given: Large number of files with same project code
        let files = (1...10).map { i in
            createFile(name: "P-1024_file\(i).pdf")
        }
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then: Should have very high confidence
        XCTAssertEqual(clusters.count, 1)
        let cluster = clusters.first!
        XCTAssertGreaterThanOrEqual(cluster.confidenceScore, 0.85, "Large clusters should have very high confidence")
    }
    
    func testMediumConfidenceForMinimalFiles() {
        // Given: Exactly 3 files (minimum)
        let files = [
            createFile(name: "P-1024_file1.pdf"),
            createFile(name: "P-1024_file2.pdf"),
            createFile(name: "P-1024_file3.pdf"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then: Should have medium-high confidence
        XCTAssertEqual(clusters.count, 1)
        let cluster = clusters.first!
        XCTAssertGreaterThanOrEqual(cluster.confidenceScore, 0.5)
    }
    
    // MARK: - Edge Cases
    
    func testReturnsEmptyForInsufficientFiles() {
        // Given: Less than 5 total files
        let files = [
            createFile(name: "file1.txt"),
            createFile(name: "file2.txt"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then: Should return empty (not enough files to analyze)
        XCTAssertEqual(clusters.count, 0)
    }
    
    func testHandlesEmptyFileList() {
        // Given: Empty file list
        let files: [FileItem] = []
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then: Should return empty array
        XCTAssertEqual(clusters.count, 0)
    }
    
    func testFiltersLowConfidenceClusters() {
        // Given: Files that might create weak patterns
        let files = [
            createFile(name: "file1.txt"),
            createFile(name: "file2.txt"),
            createFile(name: "file3.txt"),
            createFile(name: "document.pdf"),
            createFile(name: "image.png"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        
        // Then: Low confidence clusters should be filtered out
        for cluster in clusters {
            XCTAssertGreaterThanOrEqual(cluster.confidenceScore, 0.5, "All returned clusters should have confidence >= 0.5")
        }
    }
    
    // MARK: - Common Prefix / Name Similarity Edge Cases
    
    func testNameSimilarityClusterWithMixedLengthNames_UsesSharedPrefix() {
        // Given: One longer name and two shorter names that should still be clustered
        let files = [
            createFile(name: "report_v1_draft.docx"),
            createFile(name: "report.docx"),
            createFile(name: "report_v2.docx"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        let similarityClusters = clusters.filter { $0.clusterType == .nameSimilarity }
        
        // Then: Should detect a similarity cluster with "report" as the base name
        XCTAssertEqual(similarityClusters.count, 1, "Should detect exactly one name similarity cluster")
        let cluster = similarityClusters.first!
        XCTAssertEqual(cluster.fileCount, 3)
        XCTAssertEqual(cluster.suggestedFolderName, "report")
    }
    
    func testNameSimilarityClusterTrimsToWordBoundary() {
        // Given: Names that share a "Project Alpha - " prefix
        let files = [
            createFile(name: "Project Alpha - Draft 1.docx"),
            createFile(name: "Project Alpha - Final.docx"),
            createFile(name: "Project Alpha - Notes.docx"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        let similarityClusters = clusters.filter { $0.clusterType == .nameSimilarity }
        
        // Then: Suggested name should trim trailing punctuation/space to the word boundary
        XCTAssertEqual(similarityClusters.count, 1)
        let cluster = similarityClusters.first!
        XCTAssertEqual(cluster.suggestedFolderName, "Project Alpha")
    }
    
    func testNameSimilarityClusterWithNoCommonPrefixFallsBackToRelatedFiles() {
        // Given: Highly similar names with different leading characters
        let files = [
            createFile(name: "report_v1.docx"),
            createFile(name: "xeport_v2.docx"),
            createFile(name: "zeport_v3.docx"),
        ]
        
        // When
        let clusters = service.detectClusters(from: files)
        let similarityClusters = clusters.filter { $0.clusterType == .nameSimilarity }
        
        // Then: With no true common prefix, we should fall back to a generic label
        XCTAssertEqual(similarityClusters.count, 1)
        let cluster = similarityClusters.first!
        XCTAssertEqual(cluster.suggestedFolderName, "Related Files")
    }
    
    // MARK: - Helper Methods
    
    private func createFile(
        name: String,
        modDate: Date = Date()
    ) -> FileItem {
        return FileItem(
            path: "/Users/test/Downloads/\(name)",
            sizeInBytes: 1024,
            creationDate: modDate.addingTimeInterval(-3600),  // Created 1 hour before modification
            modificationDate: modDate,
            lastAccessedDate: modDate
        )
    }
}
