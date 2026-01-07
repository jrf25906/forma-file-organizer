import Foundation
import SwiftUI
import SwiftData
import Combine

/// Manages storage analytics, insights, and file organization metrics.
/// Responsible for:
/// - Storage analytics (total size, file counts, trends)
/// - Organization score and health metrics
/// - Activity tracking and pattern detection
/// - Project cluster detection
/// - Learned pattern management
@MainActor
class AnalyticsDashboardViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Storage analytics for all files
    @Published private(set) var storageAnalytics: StorageAnalytics = .empty

    /// Storage analytics for currently filtered view
    @Published private(set) var filteredStorageAnalytics: StorageAnalytics = .empty

    /// Recent activities (last 10)
    @Published private(set) var recentActivities: [ActivityItem] = []

    /// Detected project clusters
    @Published private(set) var detectedClusters: [ProjectCluster] = []

    /// Whether cluster detection is in progress
    @Published private(set) var isDetectingClusters: Bool = false

    // MARK: - Dependencies

    private let storageService: StorageService
    private let insightsService: InsightsService
    private let contextDetectionService: ContextDetectionService
    private let learningService: LearningService

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        storageService: StorageService,
        insightsService: InsightsService,
        contextDetectionService: ContextDetectionService = ContextDetectionService(),
        learningService: LearningService = LearningService()
    ) {
        self.storageService = storageService
        self.insightsService = insightsService
        self.contextDetectionService = contextDetectionService
        self.learningService = learningService
    }

    convenience init(services: AppServices) {
        self.init(
            storageService: services.storageService,
            insightsService: services.insightsService
        )
    }

    // MARK: - Analytics

    /// Update analytics from all files
    func updateAnalytics(from allFiles: [FileItem]) {
        storageAnalytics = storageService.calculateAnalytics(from: allFiles)
    }

    /// Update analytics for filtered view
    func updateFilteredAnalytics(from filteredFiles: [FileItem]) {
        filteredStorageAnalytics = StorageAnalytics.calculate(from: filteredFiles)
    }

    /// Force refresh analytics (recalculate from scratch)
    func refreshAnalytics(from allFiles: [FileItem]) {
        storageAnalytics = storageService.getAnalytics(from: allFiles, forceRefresh: true)
    }

    // MARK: - Activity Tracking

    /// Load recent activities from SwiftData
    func loadActivities(from context: ModelContext) {
        let descriptor = FetchDescriptor<ActivityItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            let activities = try context.fetch(descriptor)
            recentActivities = Array(activities.prefix(10))
            Log.info("Successfully loaded \(recentActivities.count) recent activities", category: .analytics)

            // Detect and persist learned patterns
            detectAndPersistPatterns(from: activities, context: context)
        } catch {
            Log.error("Failed to load activities: \(error.localizedDescription)", category: .analytics)
            recentActivities = []
        }
    }

    /// Add a new activity
    func addActivity(_ activity: ActivityItem, context: ModelContext) {
        context.insert(activity)
        do {
            try context.save()
        } catch {
            Log.error("Failed to save activity to SwiftData: \(error.localizedDescription)", category: .analytics)
        }
        loadActivities(from: context)
    }

    // MARK: - Cluster Detection

    /// Detect project clusters from files
    func detectClusters(from allFiles: [FileItem], context: ModelContext) async {
        guard allFiles.count >= 5 else {
            detectedClusters = []
            return
        }

        isDetectingClusters = true
        defer { isDetectingClusters = false }

        #if DEBUG
        Log.debug("Detecting clusters from \(allFiles.count) files...", category: .analytics)
        #endif

        // Run detection
        let clusters = contextDetectionService.detectClusters(from: allFiles)

        #if DEBUG
        Log.info("Detected \(clusters.count) clusters", category: .analytics)
        for cluster in clusters {
            Log.debug("Cluster: \(cluster.clusterType.displayName) — \(cluster.fileCount) files (\(cluster.confidenceLevel) confidence)", category: .analytics)
        }
        #endif

        // Save clusters to SwiftData
        let existingDescriptor = FetchDescriptor<ProjectCluster>(
            predicate: #Predicate<ProjectCluster> { !$0.isDismissed && !$0.isOrganized }
        )
        let existingClusterNames: Set<String> = {
            guard let existing = try? context.fetch(existingDescriptor) else { return [] }
            return Set(existing.map { $0.suggestedFolderName })
        }()

        for cluster in clusters {
            if !existingClusterNames.contains(cluster.suggestedFolderName) {
                context.insert(cluster)
            }
        }

        do {
            try context.save()
        } catch {
            Log.error("Failed to save clusters: \(error.localizedDescription)", category: .analytics)
        }

        // Update published state
        detectedClusters = clusters.filter { $0.shouldShow }
    }

    /// Dismiss a cluster
    func dismissCluster(_ cluster: ProjectCluster, context: ModelContext) {
        cluster.dismiss()
        detectedClusters.removeAll { $0.id == cluster.id }
        do {
            try context.save()
        } catch {
            Log.error("Failed to save cluster dismissal: \(error.localizedDescription)", category: .analytics)
        }
    }

    // MARK: - Pattern Detection

    /// Detect patterns from activities and persist to SwiftData
    private func detectAndPersistPatterns(from activities: [ActivityItem], context: ModelContext) {
        guard activities.count >= 3 else { return }

        let detectedPatterns = learningService.detectPatterns(from: activities)
        let worthyPatterns = detectedPatterns.filter { learningService.shouldSuggestPattern($0) }

        guard !worthyPatterns.isEmpty else { return }

        #if DEBUG
        Log.debug("Detected \(worthyPatterns.count) worthy patterns from \(activities.count) activities", category: .analytics)
        #endif

        // Fetch existing patterns to avoid duplicates
        let existingDescriptor = FetchDescriptor<LearnedPattern>()
        let existingPatterns: [LearnedPattern]
        do {
            existingPatterns = try context.fetch(existingDescriptor)
        } catch {
            Log.error("Failed to fetch existing patterns: \(error.localizedDescription)", category: .analytics)
            return
        }

        let existingDescriptions = Set(existingPatterns.map { $0.patternDescription })

        var insertedCount = 0
        for pattern in worthyPatterns {
            guard !existingDescriptions.contains(pattern.patternDescription) else { continue }
            guard !pattern.convertedToRule else { continue }

            context.insert(pattern)
            insertedCount += 1
        }

        if insertedCount > 0 {
            do {
                try context.save()
                Log.info("Persisted \(insertedCount) new learned patterns to SwiftData", category: .analytics)

                // Log activity for new patterns
                let activityService = ActivityLoggingService(modelContext: context)
                for pattern in worthyPatterns where !existingDescriptions.contains(pattern.patternDescription) {
                    activityService.logPatternLearned(
                        patternDescription: pattern.patternDescription,
                        confidence: pattern.confidenceScore
                    )
                }
            } catch {
                Log.error("Failed to save learned patterns: \(error.localizedDescription)", category: .analytics)
            }
        }
    }

    /// Create a rule from a learned pattern
    func createRuleFromPattern(_ pattern: LearnedPattern, context: ModelContext) -> Bool {
        let rule = learningService.convertPatternToRule(pattern)

        context.insert(rule)
        pattern.markAsConverted(ruleId: rule.id)

        do {
            try context.save()
            Log.info("Created rule from pattern: \(pattern.patternDescription)", category: .pipeline)
            return true
        } catch {
            Log.error("Failed to save rule from pattern: \(error.localizedDescription)", category: .pipeline)
            return false
        }
    }
}
