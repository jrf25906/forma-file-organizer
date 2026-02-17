import XCTest
@testable import Forma_File_Organizing

@MainActor
final class InsightsServiceTests: XCTestCase {
    var service: InsightsService!
    private var now: Date!
    private var calendar: Calendar!
    
    override func setUp() async throws {
        try await super.setUp()

        let fixedCalendar: Calendar = {
            var value = Calendar(identifier: .gregorian)
            value.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
            return value
        }()
        let fixedNow = fixedCalendar.date(from: DateComponents(year: 2023, month: 11, day: 14, hour: 10, minute: 0)) ?? Date()

        await MainActor.run {
            calendar = fixedCalendar
            now = fixedNow
            service = InsightsService(
                clock: FixedClock(now: fixedNow, calendar: fixedCalendar),
                calendar: fixedCalendar
            )
        }
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            service = nil
            now = nil
            calendar = nil
        }
        try await super.tearDown()
    }
    
    // MARK: - Screenshot Detection Tests
    
    func testDetectScreenshotPattern() async {
        // Given: 5 screenshot files
        let files = [
            createMockFile(name: "Screenshot 2024-01-01.png"),
            createMockFile(name: "Screenshot 2024-01-02.png"),
            createMockFile(name: "Screen Shot 2024-01-03.png"),
            createMockFile(name: "screenshot_12345.png"),
            createMockFile(name: "My Screenshot.png")
        ]

        // When
        let insights = await service.generateInsights(from: files, activities: [], rules: [], now: now)
        
        // Then
        let screenshotInsight = insights.first { $0.message.contains("screenshots") }
        XCTAssertNotNil(screenshotInsight)
        XCTAssertEqual(screenshotInsight?.actionLabel, "Create Rule")
        XCTAssertEqual(screenshotInsight?.iconName, "camera.viewfinder")
        XCTAssertEqual(screenshotInsight?.priority, 8)
    }
    
    func testNoScreenshotInsightWithFewScreenshots() async {
        // Given: Only 3 screenshots (below threshold)
        let files = [
            createMockFile(name: "Screenshot 1.png"),
            createMockFile(name: "Screenshot 2.png"),
            createMockFile(name: "Screenshot 3.png")
        ]

        // When
        let insights = await service.generateInsights(from: files, activities: [], rules: [], now: now)
        
        // Then
        let screenshotInsight = insights.first { $0.message.contains("screenshots") }
        XCTAssertNil(screenshotInsight)
    }
    
    // MARK: - Downloads Accumulation Tests
    
    func testDetectDownloadsAccumulation() async {
        // Given: 15+ files in Downloads
        var files: [FileItem] = []
        for i in 1...16 {
            files.append(createMockFile(name: "file\(i).pdf", path: "/Users/test/Downloads/file\(i).pdf"))
        }

        // When
        let insights = await service.generateInsights(from: files, activities: [], rules: [], now: now)
        
        // Then
        let downloadsInsight = insights.first { $0.message.contains("Downloads") }
        XCTAssertNotNil(downloadsInsight)
        XCTAssertTrue(downloadsInsight!.message.contains("16 files"))
        XCTAssertEqual(downloadsInsight?.actionLabel, "Review Now")
        XCTAssertEqual(downloadsInsight?.iconName, "arrow.down.circle")
    }
    
    // MARK: - Large Files Detection Tests
    
    func testDetectLargeFiles() async {
        // Given: 3 large files (>100MB each)
        let largeSize: Int64 = 150 * 1024 * 1024 // 150MB
        let files = [
            createMockFile(name: "video1.mp4", sizeInBytes: largeSize),
            createMockFile(name: "video2.mp4", sizeInBytes: largeSize),
            createMockFile(name: "archive.zip", sizeInBytes: largeSize)
        ]

        // When
        let insights = await service.generateInsights(from: files, activities: [], rules: [], now: now)
        
        // Then
        let largeFilesInsight = insights.first { $0.message.contains("large files") }
        XCTAssertNotNil(largeFilesInsight)
        XCTAssertEqual(largeFilesInsight?.actionLabel, "Review Files")
        XCTAssertEqual(largeFilesInsight?.priority, 9) // High priority
        XCTAssertEqual(largeFilesInsight?.iconName, "externaldrive.fill")
    }
    
    // MARK: - Rule Opportunity Detection Tests
    
    func testDetectRuleOpportunityFromRepeatedManualMoves() async {
        // Given: User has manually moved 3 PDF files to same destination this week
        let activities = [
            createMockActivity(type: .fileOrganized, fileName: "doc1.pdf", details: "Moved to Documents/Work", fileExtension: "pdf"),
            createMockActivity(type: .fileOrganized, fileName: "doc2.pdf", details: "Moved to Documents/Work", fileExtension: "pdf"),
            createMockActivity(type: .fileOrganized, fileName: "doc3.pdf", details: "Moved to Documents/Work", fileExtension: "pdf")
        ]

        // When
        let insights = await service.generateInsights(from: [], activities: activities, rules: [], now: now)
        
        // Then
        let ruleInsight = insights.first { $0.actionLabel == "Create Rule" }
        XCTAssertNotNil(ruleInsight)
        XCTAssertTrue(ruleInsight!.message.contains("PDF"))
        XCTAssertTrue(ruleInsight!.message.contains("Documents/Work"))
        XCTAssertEqual(ruleInsight?.actionLabel, "Create Rule")
        XCTAssertEqual(ruleInsight?.priority, 10) // Highest priority
        XCTAssertEqual(ruleInsight?.iconName, "wand.and.stars")
    }
    
    func testNoRuleOpportunityWithDifferentDestinations() async {
        // Given: User moved files to different destinations
        let activities = [
            createMockActivity(type: .fileOrganized, fileName: "doc1.pdf", details: "Moved to Documents/Work", fileExtension: "pdf"),
            createMockActivity(type: .fileOrganized, fileName: "doc2.pdf", details: "Moved to Documents/Personal", fileExtension: "pdf"),
            createMockActivity(type: .fileOrganized, fileName: "doc3.pdf", details: "Moved to Documents/Archive", fileExtension: "pdf")
        ]

        // When
        let insights = await service.generateInsights(from: [], activities: activities, rules: [], now: now)
        
        // Then
        let ruleInsight = insights.first { $0.actionLabel == "Create Rule" }
        XCTAssertNil(ruleInsight, "Should not suggest rule when destinations differ")
    }
    
    // MARK: - Activity Summary Tests
    
    func testGenerateWeeklySummaryWithMultipleOrganizations() async {
        // Given: User organized 5 files this week
        let activities = [
            createMockActivity(type: .fileOrganized, fileName: "file1.txt", details: "Organized"),
            createMockActivity(type: .fileOrganized, fileName: "file2.txt", details: "Organized"),
            createMockActivity(type: .fileMoved, fileName: "file3.txt", details: "Moved"),
            createMockActivity(type: .fileOrganized, fileName: "file4.txt", details: "Organized"),
            createMockActivity(type: .fileOrganized, fileName: "file5.txt", details: "Organized")
        ]

        // When
        let insights = await service.generateInsights(from: [], activities: activities, rules: [], now: now)
        
        // Then
        let summaryInsight = insights.first { $0.message.contains("this week") }
        XCTAssertNotNil(summaryInsight)
        XCTAssertTrue(summaryInsight!.message.contains("5 files"))
        XCTAssertEqual(summaryInsight?.iconName, "chart.line.uptrend.xyaxis")
    }
    
    func testNoSummaryWithNoActivity() async {
        // Given: No recent activity
        let activities: [ActivityItem] = []

        // When
        let insights = await service.generateInsights(from: [], activities: activities, rules: [], now: now)
        
        // Then
        let summaryInsight = insights.first { $0.message.contains("this week") }
        XCTAssertNil(summaryInsight)
    }
    
    // MARK: - Duplicate Detection Tests

    func testGenerateInsights_UsesPrecomputedClusters() async {
        // Given: Precomputed clusters from scan pipeline/analytics view model
        let cluster = ProjectCluster(
            clusterType: .projectCode,
            filePaths: [
                "/Users/test/Downloads/P-1024_proposal.pdf",
                "/Users/test/Downloads/P-1024_budget.xlsx",
                "/Users/test/Downloads/P-1024_timeline.png"
            ],
            confidenceScore: 0.92,
            suggestedFolderName: "Project P-1024",
            detectedPattern: "P-1024"
        )

        // When
        let insights = await service.generateInsights(
            from: [],
            activities: [],
            rules: [],
            precomputedClusters: [cluster],
            now: now
        )

        // Then
        let clusterInsight = insights.first { $0.actionLabel == "Organize Together" }
        XCTAssertNotNil(clusterInsight)
        XCTAssertTrue(clusterInsight?.message.contains("P-1024") ?? false)
    }

    func testDetectPossibleDuplicates() async {
        // Given: Multiple files with same names
        let files = [
            createMockFile(name: "document.pdf", path: "/Users/test/Desktop/document.pdf"),
            createMockFile(name: "document.pdf", path: "/Users/test/Downloads/document.pdf"),
            createMockFile(name: "image.jpg", path: "/Users/test/Desktop/image.jpg"),
            createMockFile(name: "image.jpg", path: "/Users/test/Pictures/image.jpg"),
            createMockFile(name: "report.docx", path: "/Users/test/Documents/report.docx"),
            createMockFile(name: "report.docx", path: "/Users/test/Downloads/report.docx")
        ]

        // When
        let insights = await service.generateInsights(from: files, activities: [], rules: [], now: now)
        
        // Then
        let duplicateInsight = insights.first { $0.message.contains("duplicate") }
        XCTAssertNotNil(duplicateInsight)
        XCTAssertEqual(duplicateInsight?.actionLabel, "Review")
        XCTAssertEqual(duplicateInsight?.iconName, "doc.on.doc")
    }

    func testGenerateInsights_ProducesStableIDsForEquivalentInputs() async {
        // Given
        let files = [
            createMockFile(name: "Screenshot 1.png"),
            createMockFile(name: "Screenshot 2.png"),
            createMockFile(name: "Screenshot 3.png"),
            createMockFile(name: "Screenshot 4.png"),
            createMockFile(name: "Screenshot 5.png")
        ]

        // When
        let firstRun = await service.generateInsights(from: files, activities: [], rules: [], now: now)
        let secondRun = await service.generateInsights(from: files, activities: [], rules: [], now: now)

        // Then
        XCTAssertEqual(firstRun.map(\.id), secondRun.map(\.id))
        XCTAssertEqual(Set(firstRun.map(\.id)).count, firstRun.count)
    }
    
    // MARK: - Priority Sorting Tests
    
    func testInsightsSortedByPriority() async {
        // Given: Multiple conditions that trigger insights with different priorities
        let largeFile = createMockFile(name: "large.zip", sizeInBytes: 200 * 1024 * 1024)
        var files = [largeFile]
        for i in 1...6 {
            files.append(createMockFile(name: "Screenshot \(i).png"))
        }

        let activities = [
            createMockActivity(type: .fileOrganized, fileName: "doc1.pdf", details: "Moved to Documents/Work", fileExtension: "pdf"),
            createMockActivity(type: .fileOrganized, fileName: "doc2.pdf", details: "Moved to Documents/Work", fileExtension: "pdf"),
            createMockActivity(type: .fileOrganized, fileName: "doc3.pdf", details: "Moved to Documents/Work", fileExtension: "pdf")
        ]

        // When
        let insights = await service.generateInsights(from: files, activities: activities, rules: [], now: now)
        
        // Then: Should be sorted by priority (highest first)
        XCTAssertGreaterThan(insights.count, 1)
        for i in 0..<(insights.count - 1) {
            XCTAssertGreaterThanOrEqual(insights[i].priority, insights[i + 1].priority,
                                       "Insights should be sorted by priority descending")
        }
        
        // Rule opportunity should be first (priority 10)
        XCTAssertEqual(insights.first?.priority, 10)
        XCTAssertEqual(insights.first?.actionLabel, "Create Rule")
    }
    
    // MARK: - Greeting Tests
    
    func testMorningGreeting() {
        // Test is time-dependent, so we just verify it returns a string
        let greeting = service.generateGreeting(fileCount: 5, now: now)
        XCTAssertNotNil(greeting)
        XCTAssertTrue(greeting!.contains("5 files"))
    }
    
    func testGreetingWithNoFiles() {
        let greeting = service.generateGreeting(fileCount: 0, now: now)
        if let greeting = greeting {
            XCTAssertTrue(greeting.contains("caught up"))
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockFile(
        name: String,
        path: String? = nil,
        sizeInBytes: Int64 = 1024,
        status: FileItem.OrganizationStatus = .pending
    ) -> FileItem {
        let resolvedPath = path ?? "/Users/test/\(name)"
        return FileItem(
            path: resolvedPath,
            sizeInBytes: sizeInBytes,
            creationDate: Date(),
            destination: nil,
            status: status
        )
    }
    
    private func createMockActivity(
        type: ActivityItem.ActivityType,
        fileName: String,
        details: String,
        fileExtension: String? = nil,
        daysAgo: Int = 0
    ) -> ActivityItem {
        let activity = ActivityItem(
            activityType: type,
            fileName: fileName,
            details: details,
            fileExtension: fileExtension
        )
        let baseDate = now ?? Date()
        let baseCalendar = calendar ?? Calendar.current
        if daysAgo > 0 {
            activity.timestamp = baseCalendar.date(byAdding: .day, value: -daysAgo, to: baseDate) ?? baseDate
        } else {
            activity.timestamp = baseDate
        }
        return activity
    }
}
