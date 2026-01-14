import Foundation

/// Represents a contextual insight about file organization patterns and opportunities
struct FileInsight: Identifiable, Equatable {
    let id: UUID
    let message: String
    let detail: String?
    let actionLabel: String?
    let action: (() -> Void)?
    let priority: Int
    let iconName: String

    init(id: UUID = UUID(),
         message: String,
         detail: String? = nil,
         actionLabel: String? = nil,
         action: (() -> Void)? = nil,
         priority: Int = 0,
         iconName: String = "lightbulb.fill") {
        self.id = id
        self.message = message
        self.detail = detail
        self.actionLabel = actionLabel
        self.action = action
        self.priority = priority
        self.iconName = iconName
    }

    static func == (lhs: FileInsight, rhs: FileInsight) -> Bool {
        lhs.id == rhs.id &&
        lhs.message == rhs.message &&
        lhs.detail == rhs.detail &&
        lhs.actionLabel == rhs.actionLabel &&
        lhs.priority == rhs.priority &&
        lhs.iconName == rhs.iconName
    }
}

/// Service for generating contextual insights and suggestions about file organization
///
/// Note: This service is @MainActor-isolated because it depends on @MainActor services
/// (LearningService, ContextDetectionService) that work with SwiftData @Model objects.
@MainActor
class InsightsService {
    static let shared = InsightsService()
    
    private let learningService = LearningService()
    private let contextDetectionService = ContextDetectionService()
    
    private init() {}
    
    /// Generate insights from current file state, activities, and rules (async version with parallel execution)
    func generateInsights(
        from files: [FileItem],
        activities: [ActivityItem],
        rules: [Rule]
    ) async -> [FileInsight] {
        let insightId = PerformanceMonitor.shared.begin(.insightGeneration, metadata: "\(files.count) files, \(activities.count) activities")

        var insights: [FileInsight] = []
        insights.append(contentsOf: detectFilePatterns(files))
        insights.append(contentsOf: detectStorageIssues(files))
        insights.append(contentsOf: detectRuleOpportunities(from: activities, files: files))
        insights.append(contentsOf: detectProjectClusters(files))
        if let summary = generateActivitySummary(from: activities) {
            insights.append(summary)
        }

        // Sort by priority (higher = more important)
        let result = insights.sorted { $0.priority > $1.priority }

        PerformanceMonitor.shared.end(.insightGeneration, id: insightId, metadata: "\(result.count) insights")
        return result
    }

    // MARK: - Pattern Detection
    
    /// Detect common file patterns that could benefit from organization
    private func detectFilePatterns(_ files: [FileItem]) -> [FileInsight] {
        var insights: [FileInsight] = []
        
        // Screenshot accumulation
        let screenshots = files.filter { 
            $0.name.localizedCaseInsensitiveContains("screenshot") ||
            $0.name.localizedCaseInsensitiveContains("screen shot")
        }
        if screenshots.count >= 5 {
            insights.append(FileInsight(
                message: "You have \(screenshots.count) screenshots waiting - set up auto-organization?",
                actionLabel: "Create Rule",
                priority: 8,
                iconName: "camera.viewfinder"
            ))
        }
        
        // Downloads accumulation - only count files that actually need review
        // (pending status or no destination, excluding completed)
        let downloadsFiles = files.filter { file in
            let isinBenDownloads = file.path.contains("/Downloads/")
            let isNotCompleted = file.status != .completed
            let needsReview = file.status == .pending || file.status == .ready || file.destination == nil
            return isinBenDownloads && isNotCompleted && needsReview
        }
        if downloadsFiles.count >= 15 {
            insights.append(FileInsight(
                message: "\(downloadsFiles.count) files in Downloads need review",
                actionLabel: "Review Now",
                priority: 7,
                iconName: "arrow.down.circle"
            ))
        }
        
        // Unorganized files of same type
        let extensionGroups = Dictionary(grouping: files.filter { $0.status == .pending || $0.status == .ready }, by: { $0.fileExtension })
        for (ext, groupFiles) in extensionGroups where groupFiles.count >= 5 {
            insights.append(FileInsight(
                message: "\(groupFiles.count) \(ext.uppercased()) files need organization",
                actionLabel: "Create Rule",
                priority: 6,
                iconName: "doc.text"
            ))
        }
        
        return insights
    }
    
    // MARK: - Storage Detection
    
    /// Detect storage-related issues like large files
    private func detectStorageIssues(_ files: [FileItem]) -> [FileInsight] {
        var insights: [FileInsight] = []
        
        // Large files detection (>100MB)
        let largeFiles = files.filter { $0.sizeInBytes > 100 * 1024 * 1024 }
        if largeFiles.count >= 3 {
            let totalSize = largeFiles.reduce(0) { $0 + $1.sizeInBytes }
            let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
            insights.append(FileInsight(
                message: "\(largeFiles.count) large files taking up \(formattedSize)",
                actionLabel: "Review Files",
                priority: 9,
                iconName: "externaldrive.fill"
            ))
        }
        
        // Many small duplicate-named files (potential duplicates)
        let nameCounts = Dictionary(grouping: files, by: { $0.name }).filter { $0.value.count > 1 }
        if nameCounts.count >= 3 {
            insights.append(FileInsight(
                message: "Possible duplicate files detected",
                actionLabel: "Review",
                priority: 5,
                iconName: "doc.on.doc"
            ))
        }
        
        return insights
    }
    
    // MARK: - Rule Opportunities
    
    /// Analyze recent manual file moves to suggest automation rules using LearningService
    private func detectRuleOpportunities(from activities: [ActivityItem], files: [FileItem]) -> [FileInsight] {
        var insights: [FileInsight] = []
        
        // Use LearningService to detect patterns
        let detectedPatterns = learningService.detectPatterns(from: activities)
        
        // Convert high-confidence patterns into insights
        for pattern in detectedPatterns where learningService.shouldSuggestPattern(pattern) {
            // Determine priority based on confidence
            let priority: Int
            if pattern.confidenceScore >= 0.7 {
                priority = 10 // High confidence
            } else if pattern.confidenceScore >= 0.5 {
                priority = 8  // Medium confidence
            } else {
                priority = 6  // Low confidence (shouldn't normally reach here due to shouldSuggest)
            }
            
            insights.append(FileInsight(
                message: pattern.patternDescription,
                actionLabel: "Create Rule",
                priority: priority,
                iconName: "wand.and.stars"
            ))
        }
        
        return insights
    }
    
    /// Detect learned patterns using the learning service
    /// - Parameter activities: Array of ActivityItem to analyze
    /// - Returns: Array of LearnedPattern objects
    func detectLearnedPatterns(from activities: [ActivityItem]) -> [LearnedPattern] {
        return learningService.detectPatterns(from: activities)
            .filter { learningService.shouldSuggestPattern($0) }
    }
    
    // MARK: - Context Detection

    /// Detect project clusters using context detection algorithms
    private func detectProjectClusters(_ files: [FileItem]) -> [FileInsight] {
        var insights: [FileInsight] = []

        // Only detect clusters if we have enough files to analyze
        guard files.count >= 5 else { return insights }

        let clusters = contextDetectionService.detectClusters(from: files)

        // Convert clusters into insights
        for cluster in clusters where cluster.shouldShow {
            // Priority based on confidence and file count
            let priority: Int
            if cluster.confidenceScore >= 0.8 {
                priority = 9  // High confidence clusters are very important
            } else if cluster.confidenceScore >= 0.6 {
                priority = 7  // Medium confidence
            } else {
                priority = 5  // Lower confidence
            }

            insights.append(FileInsight(
                message: cluster.displayDescription,
                actionLabel: "Organize Together",
                priority: priority,
                iconName: cluster.clusterType.iconName
            ))
        }

        return insights
    }

    // Async helper variants were removed for Swift 6 Sendable correctness.
    
    /// Detect project clusters using the context detection service
    /// - Parameter files: Array of FileItem to analyze
    /// - Returns: Array of ProjectCluster objects
    func detectContextClusters(from files: [FileItem]) -> [ProjectCluster] {
        return contextDetectionService.detectClusters(from: files)
            .filter { $0.shouldShow }
    }
    
    // MARK: - Activity Summaries
    
    /// Generate a summary of recent activity
    private func generateActivitySummary(from activities: [ActivityItem]) -> FileInsight? {
        let thisWeek = activities.filter { 
            Calendar.current.isDate($0.timestamp, equalTo: Date(), toGranularity: .weekOfYear)
        }
        
        let organizedCount = thisWeek.filter { 
            $0.activityType == .fileOrganized || $0.activityType == .fileMoved 
        }.count
        
        guard organizedCount > 0 else { return nil }
        
        let message: String
        if organizedCount == 1 {
            message = "Organized 1 file this week"
        } else {
            message = "Organized \(organizedCount) files this week, keep it up!"
        }
        
        return FileInsight(
            message: message,
            actionLabel: nil,
            priority: 2,
            iconName: "chart.line.uptrend.xyaxis"
        )
    }
    
    // MARK: - Helper: Time-Based Greetings
    
    /// Generate a contextual greeting based on time of day
    func generateGreeting(fileCount: Int) -> String? {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        
        switch hour {
        case 5..<12:
            timeOfDay = "Good morning"
        case 12..<17:
            timeOfDay = "Good afternoon"
        case 17..<22:
            timeOfDay = "Good evening"
        default:
            return nil // Don't show greeting late at night
        }
        
        if fileCount > 0 {
            return "\(timeOfDay)! \(fileCount) file\(fileCount == 1 ? "" : "s") need\(fileCount == 1 ? "s" : "") your attention"
        } else {
            return "\(timeOfDay)! You're all caught up"
        }
    }

    /// Generate optimization recommendations from analytics signals.
    static nonisolated func generateOptimizationRecommendations(
        snapshots: [StorageSnapshot],
        usage: UsageStatistics,
        recentActivities: [ActivityItem]
    ) -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []

        if let latestDelta = snapshots.last?.deltaBytesSincePrevious, latestDelta > 0 {
            let formatted = ByteCountFormatter.string(fromByteCount: latestDelta, countStyle: .file)
            recommendations.append(
                OptimizationRecommendation(
                    id: UUID(),
                    title: "Storage is growing",
                    detail: "Storage increased by \(formatted) since the last snapshot. Consider cleaning large downloads or archives.",
                    priority: 1
                )
            )
        }

        if usage.filesOrganized == 0 {
            recommendations.append(
                OptimizationRecommendation(
                    id: UUID(),
                    title: "Start organizing",
                    detail: "No files were organized in this period. Run a scan and apply a rule to start improving your storage health.",
                    priority: 2
                )
            )
        }

        if usage.timeSavedSeconds > 0 && usage.rulesAppliedByRuleID.isEmpty {
            recommendations.append(
                OptimizationRecommendation(
                    id: UUID(),
                    title: "Increase automation",
                    detail: "Rules were rarely applied. Enable rule suggestions or create a rule from recent activity to save more time.",
                    priority: 3
                )
            )
        }

        if recentActivities.contains(where: { $0.activityType == .duplicateDeleted }) {
            recommendations.append(
                OptimizationRecommendation(
                    id: UUID(),
                    title: "Keep removing duplicates",
                    detail: "Duplicates were deleted recently. Run a duplicate scan to reclaim more space.",
                    priority: 4
                )
            )
        }

        return recommendations.sorted { $0.priority < $1.priority }
    }
}
