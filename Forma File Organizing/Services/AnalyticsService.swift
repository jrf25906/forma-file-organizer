import Foundation
import SwiftData

/// Aggregates analytics, trends, and health scoring.
///
/// SwiftData models and `ModelContext` are not `Sendable` in Swift 6, so analytics aggregation
/// stays on the main actor to avoid crossing actor boundaries with model objects.
/// Aggregates analytics, trends, and health scoring.
///
/// Uses `ModelContainer` to create isolated `ModelContext`s for background processing
/// to avoid blocking the main thread.
final class AnalyticsService: Sendable {
    static let shared = AnalyticsService()

    private init() {}
}

// MARK: - Public API

extension AnalyticsService {
    // MARK: Storage Snapshots

    func recordDailySnapshotIfNeeded(
        container: ModelContainer,
        storageService: StorageService = .shared,
        now: Date = Date()
    ) async throws {
        // Run on detached task to avoid main actor
        try await Task.detached {
            let modelContext = ModelContext(container)
            guard FeatureFlagService.shared.isEnabled(.analyticsAndInsights),
                  FeatureFlagService.shared.isEnabled(.storageTrends) else {
                return
            }

            let today = now.startOfDayLocal
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today

        var existingDescriptor = FetchDescriptor<StorageSnapshot>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        existingDescriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(existingDescriptor), !existing.isEmpty {
            return
        }

        // Fetch latest analytics from files
        let files = try modelContext.fetch(FetchDescriptor<FileItem>())
        let analytics = storageService.calculateAnalytics(from: files)
        let breakdownData = try analytics.encodedCategoryBreakdown()

        // Compute delta vs last snapshot
        var lastSnapshotDescriptor = FetchDescriptor<StorageSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        lastSnapshotDescriptor.fetchLimit = 1
        let lastSnapshot = try modelContext.fetch(lastSnapshotDescriptor).first
        let delta = lastSnapshot.map { analytics.totalBytes - $0.totalBytes }

        let snapshot = StorageSnapshot(
            date: today,
            totalBytes: analytics.totalBytes,
            fileCount: analytics.fileCount,
            categoryBreakdownData: breakdownData,
            deltaBytesSincePrevious: delta
        )

        modelContext.insert(snapshot)
        try modelContext.save()

            try self.pruneOldSnapshots(modelContext: modelContext, now: today)
        }.value
    }

    func fetchSnapshots(
        in range: DateInterval,
        modelContext: ModelContext
    ) async throws -> [StorageSnapshot] {
        let descriptor = FetchDescriptor<StorageSnapshot>(
            predicate: #Predicate { $0.date >= range.start && $0.date <= range.end },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: Trends & Cleanup Impact

    func computeStorageTrend(
        in range: DateInterval,
        modelContext: ModelContext
    ) async throws -> [StorageTrendPoint] {
        let snapshots = try await fetchSnapshots(in: range, modelContext: modelContext).sorted { $0.date < $1.date }
        guard !snapshots.isEmpty else { return [] }

        var points: [StorageTrendPoint] = []
        var previous: StorageSnapshot?

        for snapshot in snapshots {
            let delta = snapshot.deltaBytesSincePrevious ?? (previous.map { snapshot.totalBytes - $0.totalBytes } ?? 0)
            points.append(StorageTrendPoint(id: snapshot.id, date: snapshot.date, totalBytes: snapshot.totalBytes, deltaBytes: delta))
            previous = snapshot
        }

        return points
    }

    func computeCleanupImpact(
        in range: DateInterval,
        modelContext: ModelContext
    ) async throws -> CleanupImpact {
        let trendPoints = try await computeStorageTrend(in: range, modelContext: modelContext)
        guard !trendPoints.isEmpty else {
            return CleanupImpact(totalFreedBytes: 0, averageFreedPerWeek: 0, largestSingleCleanupBytes: 0)
        }

        let freed = trendPoints
            .map { $0.deltaBytes }
            .filter { $0 < 0 }
            .map { abs($0) }

        let totalFreed = freed.reduce(Int64(0), +)
        let weeks = max(1, Int(range.duration / FormaConfig.Timing.secondsInWeek))
        let average = Int64(totalFreed / Int64(weeks))
        let largest = freed.max() ?? 0

        return CleanupImpact(
            totalFreedBytes: totalFreed,
            averageFreedPerWeek: average,
            largestSingleCleanupBytes: largest
        )
    }

    // MARK: Usage Statistics

    func fetchUsageStatistics(
        for period: UsagePeriod,
        modelContext: ModelContext
    ) async throws -> UsageStatistics {
        let interval = period.asDateInterval(reference: Date())
        let descriptor = FetchDescriptor<ActivityItem>(
            predicate: #Predicate { $0.timestamp >= interval.start && $0.timestamp <= interval.end }
        )
        let activities = try modelContext.fetch(descriptor)

        let organizedCount = activities.filter { $0.activityType == .fileOrganized || $0.activityType == .fileMoved }.count
        let bulkActivities = activities.filter { $0.activityType == .bulkOrganized }
        let ruleAppliedActivities = activities.filter { $0.activityType == .ruleApplied }

        // Build rulesAppliedByRuleID from ruleApplied activities (v1.2.0)
        // Each ruleApplied activity stores the ruleID and affectedFileCount
        var rulesAppliedByRuleID: [UUID: Int] = [:]
        for activity in ruleAppliedActivities {
            if let ruleID = activity.ruleID {
                let matchCount = activity.affectedFileCount ?? 1
                rulesAppliedByRuleID[ruleID, default: 0] += matchCount
            }
        }

        // Calculate time saved using actual file counts (v1.2.0)
        // - Individual file operations: count the operations
        // - Bulk operations: use affectedFileCount to get actual files processed
        // - Rule applications: use affectedFileCount to get files matched
        let config = FormaConfig.analytics

        let bulkFilesProcessed = bulkActivities.compactMap { $0.affectedFileCount }.reduce(0, +)
        let ruleFilesMatched = ruleAppliedActivities.compactMap { $0.affectedFileCount }.reduce(0, +)

        let timeSaved = (organizedCount * config.secondsPerFileOrganized)
            + (bulkFilesProcessed * config.secondsPerFileInBulkOrganize)
            + (ruleFilesMatched * config.secondsPerFileWithRuleApplied)

        let daysBetween = Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
        let dayCount = max(1, daysBetween + 1)

        return UsageStatistics(
            period: period,
            startDate: interval.start,
            endDate: interval.end,
            filesOrganized: organizedCount,
            bulkOperations: bulkActivities.count,
            rulesAppliedByRuleID: rulesAppliedByRuleID,
            timeSavedSeconds: timeSaved,
            averageFilesPerDay: Double(organizedCount) / Double(dayCount)
        )
    }

    // MARK: Health Score

    func computeHealthScore(
        currentAnalytics: StorageAnalytics,
        snapshots: [StorageSnapshot],
        usage: UsageStatistics,
        modelContext: ModelContext
    ) async throws -> StorageHealthScore {
        let config = FormaConfig.analytics
        var factors: [HealthFactor] = []
        var totalPenalty = 0

        // Capacity factor
        let capacityRaw = capacityScore(usedBytes: currentAnalytics.totalBytes)
        let capacityPenalty = Int((1.0 - capacityRaw) * config.healthWeightCapacity * 100)
        factors.append(
            HealthFactor(
                type: .capacity,
                description: "Disk space utilization",
                rawScore: capacityRaw,
                weight: config.healthWeightCapacity,
                impact: -capacityPenalty
            )
        )
        totalPenalty += capacityPenalty

        // Unorganized factor
        let unorganizedCounts = try unorganizedCounts(modelContext: modelContext)
        let unorganizedRaw: Double
        if unorganizedCounts.total == 0 {
            unorganizedRaw = 1.0
        } else {
            unorganizedRaw = 1.0 - (Double(unorganizedCounts.unorganized) / Double(unorganizedCounts.total))
        }
        let unorganizedPenalty = Int((1.0 - unorganizedRaw) * config.healthWeightUnorganized * 100)
        factors.append(
            HealthFactor(
                type: .unorganized,
                description: "Files needing organization",
                rawScore: unorganizedRaw,
                weight: config.healthWeightUnorganized,
                impact: -unorganizedPenalty
            )
        )
        totalPenalty += unorganizedPenalty

        // Rule coverage factor
        let totalOps = usage.filesOrganized + usage.bulkOperations
        let rulesTriggered = usage.rulesAppliedByRuleID.values.reduce(0, +)
        let coverageRaw = totalOps == 0 ? 1.0 : Double(rulesTriggered) / Double(totalOps)
        let coveragePenalty = Int((1.0 - coverageRaw) * config.healthWeightRuleCoverage * 100)
        factors.append(
            HealthFactor(
                type: .ruleCoverage,
                description: "Automation coverage",
                rawScore: coverageRaw,
                weight: config.healthWeightRuleCoverage,
                impact: -coveragePenalty
            )
        )
        totalPenalty += coveragePenalty

        // Growth trend factor (simple average delta over window)
        let deltas = snapshots.compactMap { $0.deltaBytesSincePrevious }
        let averageDelta = deltas.isEmpty ? 0.0 : Double(deltas.reduce(0, +)) / Double(deltas.count)
        let growthRaw: Double
        if averageDelta <= 0 {
            growthRaw = 1.0
        } else {
            // Penalize sustained growth; normalize gently
            growthRaw = max(0.0, 1.0 - min(1.0, averageDelta / Double(max(currentAnalytics.totalBytes, 1))))
        }
        let growthPenalty = Int((1.0 - growthRaw) * config.healthWeightGrowthTrend * 100)
        factors.append(
            HealthFactor(
                type: .growthTrend,
                description: "Storage growth trend",
                rawScore: growthRaw,
                weight: config.healthWeightGrowthTrend,
                impact: -growthPenalty
            )
        )
        totalPenalty += growthPenalty

        let score = max(0, min(100, 100 - totalPenalty))

        let recommendations: [OptimizationRecommendation]
        if FeatureFlagService.shared.isEnabled(.optimizationRecommendations) {
            let activities = try modelContext.fetch(FetchDescriptor<ActivityItem>())
            recommendations = InsightsService.generateOptimizationRecommendations(
                snapshots: snapshots,
                usage: usage,
                recentActivities: activities
            )
        } else {
            recommendations = []
        }

        return StorageHealthScore(
            score: score,
            factors: factors,
            recommendations: recommendations
        )
    }

    // MARK: Combined Summary

    func loadAnalyticsSummary(
        for period: UsagePeriod,
        container: ModelContainer
    ) async throws -> AnalyticsSummary {
        try await Task.detached {
            let modelContext = ModelContext(container)
            guard FeatureFlagService.shared.isEnabled(.analyticsAndInsights) else {
                throw AnalyticsError.reportGenerationFailed(reason: "Analytics disabled by feature flag.")
            }

            let interval = period.asDateInterval(reference: Date())
            let trendPoints = try await self.computeStorageTrend(in: interval, modelContext: modelContext)
            let usageStats = try await self.fetchUsageStatistics(for: period, modelContext: modelContext)

            let files = try modelContext.fetch(FetchDescriptor<FileItem>())
            let currentAnalytics = StorageService.shared.calculateAnalytics(from: files)

            // Ensure at least some history for health scoring
            let snapshots: [StorageSnapshot]
            if trendPoints.isEmpty {
                snapshots = []
            } else {
                snapshots = try await self.fetchSnapshots(in: interval, modelContext: modelContext)
            }

            let healthScore = try await self.computeHealthScore(
                currentAnalytics: currentAnalytics,
                snapshots: snapshots,
                usage: usageStats,
                modelContext: modelContext
            )

            return AnalyticsSummary(
                trendPoints: trendPoints,
                usageStatistics: usageStats,
                healthScore: healthScore
            )
        }.value
    }

    // MARK: - Productivity Health Report

    /// Compute the "Big Three" productivity metrics.
    func computeProductivityMetrics(
        for period: UsagePeriod,
        container: ModelContainer
    ) async throws -> ProductivityMetrics {
        try await Task.detached {
            let modelContext = ModelContext(container)
            let interval = period.asDateInterval(reference: Date())

            // Space reclaimed: sum of negative deltas (cleanup)
            let snapshots = try await self.fetchSnapshots(in: interval, modelContext: modelContext)
            let spaceReclaimed = snapshots
                .compactMap { $0.deltaBytesSincePrevious }
                .filter { $0 < 0 }
                .map { abs($0) }
                .reduce(Int64(0), +)

            // Time saved: from usage statistics
            let usage = try await self.fetchUsageStatistics(for: period, modelContext: modelContext)

            // Organization score: ratio of completed to total files
            let (unorganized, total) = try self.unorganizedCounts(modelContext: modelContext)
            let organizationScore: Int
            if total == 0 {
                organizationScore = 100
            } else {
                organizationScore = Int((Double(total - unorganized) / Double(total)) * 100)
            }

            // Optional: Compute previous period for comparison
            let previousPeriod = try? await self.computePreviousPeriodMetrics(
                for: period,
                modelContext: modelContext
            )

            return ProductivityMetrics(
                spaceReclaimedBytes: spaceReclaimed,
                timeSavedSeconds: usage.timeSavedSeconds,
                organizationScore: organizationScore,
                previousPeriod: previousPeriod
            )
        }.value
    }

    /// Compute automation efficiency timeline (manual vs automated actions over time).
    func computeAutomationEfficiencyTimeline(
        for period: UsagePeriod,
        container: ModelContainer
    ) async throws -> [AutomationEfficiencyPoint] {
        try await Task.detached {
            let modelContext = ModelContext(container)
            let interval = period.asDateInterval(reference: Date())
            let descriptor = FetchDescriptor<ActivityItem>(
                predicate: #Predicate { $0.timestamp >= interval.start && $0.timestamp <= interval.end },
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            let activities = try modelContext.fetch(descriptor)

            // Group activities by day
            let calendar = Calendar.current
            var dayBuckets: [Date: (manual: Int, automated: Int)] = [:]

            for activity in activities {
                let dayStart = calendar.startOfDay(for: activity.timestamp)

                let isAutomated = self.isAutomatedAction(activity.activityType)
                let isManual = self.isManualAction(activity.activityType)

                if isAutomated || isManual {
                    var bucket = dayBuckets[dayStart] ?? (manual: 0, automated: 0)
                    let count = activity.affectedFileCount ?? 1

                    if isAutomated {
                        bucket.automated += count
                    } else {
                        bucket.manual += count
                    }
                    dayBuckets[dayStart] = bucket
                }
            }

            // Convert to sorted array of points
            return dayBuckets
                .map { date, counts in
                    AutomationEfficiencyPoint(
                        date: date,
                        manualActions: counts.manual,
                        automatedActions: counts.automated
                    )
                }
                .sorted { $0.date < $1.date }
        }.value
    }

    /// Build a storage treemap from current analytics.
    func buildStorageTreemap(
        from analytics: StorageAnalytics,
        files: [FileItem],
        largeFileThreshold: Int64 = 500_000_000 // 500 MB
    ) -> TreemapNode {
        var categoryNodes: [TreemapNode] = []

        // Group files by category
        var filesByCategory: [FileTypeCategory: [FileItem]] = [:]
        for file in files {
            let category = file.category
            filesByCategory[category, default: []].append(file)
        }

        for (category, categoryFiles) in filesByCategory {
            let categoryBytes = analytics.categoryBreakdown[category] ?? 0
            guard categoryBytes > 0 else { continue }

            // Find large files within this category
            let largeFiles = categoryFiles
                .filter { $0.sizeInBytes >= largeFileThreshold }
                .sorted { $0.sizeInBytes > $1.sizeInBytes }
                .prefix(5) // Top 5 large files per category

            if largeFiles.isEmpty {
                // Simple category node without children
                categoryNodes.append(TreemapNode.categoryNode(category, bytes: categoryBytes))
            } else {
                // Category with large file children
                var children: [TreemapNode] = largeFiles.map { file in
                    TreemapNode.fileNode(
                        name: file.name,
                        bytes: file.sizeInBytes,
                        category: category
                    )
                }

                // Add "Other" node for remaining bytes
                let largeFilesBytes = largeFiles.map(\.sizeInBytes).reduce(0, +)
                let otherBytes = categoryBytes - largeFilesBytes
                if otherBytes > 0 {
                    children.append(TreemapNode(
                        label: "Other \(category.displayName)",
                        bytes: otherBytes,
                        category: category
                    ))
                }

                categoryNodes.append(TreemapNode(
                    label: category.displayName,
                    bytes: categoryBytes,
                    children: children,
                    category: category
                ))
            }
        }

        // Sort by size descending
        categoryNodes.sort { $0.bytes > $1.bytes }

        return TreemapNode(
            label: "Storage",
            bytes: analytics.totalBytes,
            children: categoryNodes
        )
    }

    /// Compute staleness calendar for the last 365 days.
    func computeStalenessCalendar(
        files: [FileItem],
        referenceDate: Date = Date()
    ) -> [DayStaleness] {
        let calendar = Calendar.current

        // Build staleness data for each day going back 365 days
        var dayData: [Date: DayStaleness] = [:]

        // Initialize all 365 days
        for dayOffset in 0..<365 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: referenceDate.startOfDayLocal) else { continue }
            dayData[date] = DayStaleness(date: date)
        }

        // Analyze files and assign to their last-accessed day
        for file in files {
            // Use last accessed date (non-optional in FileItem model)
            let accessDate = file.lastAccessedDate
            let dayStart = calendar.startOfDay(for: accessDate)

            // Only include files accessed within the last 365 days
            guard let existing = dayData[dayStart] else { continue }

            let level = StalenessLevel.from(lastAccessed: accessDate, referenceDate: referenceDate)

            var fileCounts = existing.fileCounts
            var byteCounts = existing.byteCounts

            fileCounts[level, default: 0] += 1
            byteCounts[level, default: 0] += file.sizeInBytes

            dayData[dayStart] = DayStaleness(
                id: existing.id,
                date: dayStart,
                fileCounts: fileCounts,
                byteCounts: byteCounts
            )
        }

        return dayData.values.sorted { $0.date < $1.date }
    }

    /// Generate complete Productivity Health Report.
    func generateProductivityHealthReport(
        for period: UsagePeriod,
        container: ModelContainer
    ) async throws -> ProductivityHealthReport {
        try await Task.detached {
            let modelContext = ModelContext(container)
        guard FeatureFlagService.shared.isEnabled(.analyticsAndInsights) else {
            throw AnalyticsError.reportGenerationFailed(reason: "Analytics disabled by feature flag.")
        }

        // Fetch all required data
        let files = try modelContext.fetch(FetchDescriptor<FileItem>())
        let analytics = StorageService.shared.calculateAnalytics(from: files)

        let metrics = try await self.computeProductivityMetrics(for: period, container: container)
        let automationTimeline = try await self.computeAutomationEfficiencyTimeline(for: period, container: container)
        let storageTreemap = self.buildStorageTreemap(from: analytics, files: files)
        let stalenessCalendar = self.computeStalenessCalendar(files: files)

        // Generate smart insights
        let insights = try await self.generateSmartInsights(
            files: files,
            analytics: analytics,
            automationTimeline: automationTimeline,
            stalenessCalendar: stalenessCalendar,
            modelContext: modelContext
        )

            return ProductivityHealthReport(
                period: period,
                generatedAt: Date(),
                metrics: metrics,
                automationTimeline: automationTimeline,
                storageTreemap: storageTreemap,
                stalenessCalendar: stalenessCalendar,
                insights: insights
            )
        }.value
    }

    /// Generate smart actionable insights based on current data.
    func generateSmartInsights(
        files: [FileItem],
        analytics: StorageAnalytics,
        automationTimeline: [AutomationEfficiencyPoint],
        stalenessCalendar: [DayStaleness],
        modelContext: ModelContext
    ) async throws -> [SmartInsight] {
        var insights: [SmartInsight] = []

        // 1. Screenshot accumulation insight
        let screenshotFiles = files.filter { $0.name.lowercased().contains("screenshot") }
        let staleScreenshots = screenshotFiles.filter { file in
            let level = StalenessLevel.from(lastAccessed: file.lastAccessedDate)
            return level.rawValue >= StalenessLevel.recent.rawValue
        }

        if staleScreenshots.count >= 10 {
            let percentage = Int((Double(staleScreenshots.count) / Double(max(screenshotFiles.count, 1))) * 100)
            insights.append(SmartInsight(
                title: "Screenshot Buildup Detected",
                detail: "\(percentage)% of your screenshots (\(staleScreenshots.count) files) haven't been touched in over a week.",
                icon: "camera.fill",
                actionLabel: "Auto-Archive Screenshots",
                actionType: .archiveScreenshots,
                priority: .high,
                category: .cleanup
            ))
        }

        // 2. Downloads folder growth insight
        let downloadFiles = files.filter { $0.path.contains("Downloads") }
        let downloadBytes = downloadFiles.map(\.sizeInBytes).reduce(0, +)
        if downloadBytes > 1_000_000_000 { // > 1 GB
            let formattedSize = ByteCountFormatter.string(fromByteCount: downloadBytes, countStyle: .file)
            insights.append(SmartInsight(
                title: "Downloads Folder Growing",
                detail: "Your Downloads folder contains \(formattedSize). Consider reviewing large or old files.",
                icon: "arrow.down.circle.fill",
                actionLabel: "Review Large Files",
                actionType: .cleanDownloads,
                priority: .medium,
                category: .cleanup
            ))
        }

        // 3. Automation success insight (celebration)
        let totalManual = automationTimeline.map(\.manualActions).reduce(0, +)
        let totalAuto = automationTimeline.map(\.automatedActions).reduce(0, +)
        let automationRate = totalManual + totalAuto > 0
            ? Double(totalAuto) / Double(totalManual + totalAuto)
            : 0

        if automationRate >= 0.7 && totalAuto >= 10 {
            let percentage = Int(automationRate * 100)
            insights.append(SmartInsight(
                title: "Automation is Working!",
                detail: "Your rules handled \(percentage)% of file organization this period. Nice work setting things up!",
                icon: "wand.and.stars",
                priority: .low,
                category: .celebration
            ))
        } else if automationRate < 0.3 && totalManual >= 20 {
            insights.append(SmartInsight(
                title: "Automation Opportunity",
                detail: "You organized \(totalManual) files manually. Creating rules could save you significant time.",
                icon: "lightbulb.fill",
                actionLabel: "Enable Automation",
                actionType: .enableAutomation,
                priority: .medium,
                category: .automation
            ))
        }

        // 4. Digital dust insight
        let digitalDustCount = stalenessCalendar.map(\.digitalDustCount).reduce(0, +)
        if digitalDustCount >= 50 {
            insights.append(SmartInsight(
                title: "Digital Dust Accumulating",
                detail: "You have \(digitalDustCount) files untouched for 6+ months. Time for a cleanup?",
                icon: "leaf.fill",
                actionLabel: "Nudge Me to Clean",
                priority: .medium,
                category: .cleanup
            ))
        }

        // Sort by priority (high first)
        return insights.sorted { $0.priority > $1.priority }
    }
}

// MARK: - Helpers

private extension AnalyticsService {
    /// Compute metrics for the previous period (for delta comparison).
    func computePreviousPeriodMetrics(
        for period: UsagePeriod,
        modelContext: ModelContext
    ) async throws -> PreviousPeriodMetrics {
        let calendar = Calendar.current
        let now = Date()

        // Calculate the previous period's interval
        let previousInterval: DateInterval
        switch period {
        case .day:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now.startOfDayLocal)!
            previousInterval = DateInterval(start: yesterday, end: now.startOfDayLocal.addingTimeInterval(-1))
        case .week:
            let twoWeeksAgo = calendar.date(byAdding: .day, value: -13, to: now.startOfDayLocal)!
            let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now.startOfDayLocal)!
            previousInterval = DateInterval(start: twoWeeksAgo, end: oneWeekAgo)
        case .month:
            let twoMonthsAgo = calendar.date(byAdding: .day, value: -59, to: now.startOfDayLocal)!
            let oneMonthAgo = calendar.date(byAdding: .day, value: -30, to: now.startOfDayLocal)!
            previousInterval = DateInterval(start: twoMonthsAgo, end: oneMonthAgo)
        case .custom(let interval):
            let duration = interval.duration
            let start = interval.start.addingTimeInterval(-duration)
            previousInterval = DateInterval(start: start, end: interval.start.addingTimeInterval(-1))
        }

        // Compute metrics for previous period
        let snapshots = try await fetchSnapshots(in: previousInterval, modelContext: modelContext)
        let spaceReclaimed = snapshots
            .compactMap { $0.deltaBytesSincePrevious }
            .filter { $0 < 0 }
            .map { abs($0) }
            .reduce(Int64(0), +)

        let previousPeriodUsage = UsagePeriod.custom(previousInterval)
        let usage = try await fetchUsageStatistics(for: previousPeriodUsage, modelContext: modelContext)

        // For organization score, we use current state (can't go back in time)
        // This is a limitation - we just reuse current score for comparison
        let (unorganized, total) = try unorganizedCounts(modelContext: modelContext)
        let organizationScore = total == 0 ? 100 : Int((Double(total - unorganized) / Double(total)) * 100)

        return PreviousPeriodMetrics(
            spaceReclaimedBytes: spaceReclaimed,
            timeSavedSeconds: usage.timeSavedSeconds,
            organizationScore: organizationScore
        )
    }

    /// Check if an activity type represents an automated action.
    func isAutomatedAction(_ type: ActivityItem.ActivityType) -> Bool {
        switch type {
        case .automationAutoOrganized, .ruleApplied, .patternApplied:
            return true
        default:
            return false
        }
    }

    /// Check if an activity type represents a manual action.
    func isManualAction(_ type: ActivityItem.ActivityType) -> Bool {
        switch type {
        case .fileOrganized, .fileMoved, .bulkOrganized:
            return true
        default:
            return false
        }
    }

    func pruneOldSnapshots(modelContext: ModelContext, now: Date) throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -FormaConfig.analytics.retentionDays, to: now.startOfDayLocal) ?? now
        let oldDescriptor = FetchDescriptor<StorageSnapshot>(
            predicate: #Predicate { $0.date < cutoff }
        )
        let oldSnapshots = try modelContext.fetch(oldDescriptor)
        for snapshot in oldSnapshots {
            modelContext.delete(snapshot)
        }
        if !oldSnapshots.isEmpty {
            try modelContext.save()
        }
    }

    func capacityScore(usedBytes: Int64) -> Double {
        let path = NSHomeDirectory()
        guard
            let attributes = try? FileManager.default.attributesOfFileSystem(forPath: path),
            let total = attributes[.systemSize] as? NSNumber,
            total.int64Value > 0
        else {
            return 1.0
        }

        let used = Double(usedBytes)
        let totalBytes = Double(total.int64Value)
        return max(0.0, min(1.0, 1.0 - (used / totalBytes)))
    }

    func unorganizedCounts(modelContext: ModelContext) throws -> (unorganized: Int, total: Int) {
        let descriptor = FetchDescriptor<FileItem>()
        let files = try modelContext.fetch(descriptor)
        let unorganized = files.filter { $0.status != .completed }.count
        return (unorganized, files.count)
    }
}

// MARK: - Date Helpers

extension Date {
    var startOfDayLocal: Date {
        Calendar.current.startOfDay(for: self)
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

private extension UsagePeriod {
    func asDateInterval(reference: Date) -> DateInterval {
        let calendar = Calendar.current
        switch self {
        case .day:
            let start = reference.startOfDayLocal
            let end = calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? reference
            return DateInterval(start: start, end: end)
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: reference.startOfDayLocal) ?? reference.startOfDayLocal
            return DateInterval(start: start, end: reference)
        case .month:
            let start = calendar.date(byAdding: .day, value: -29, to: reference.startOfDayLocal) ?? reference.startOfDayLocal
            return DateInterval(start: start, end: reference)
        case .custom(let interval):
            return interval
        }
    }
}
