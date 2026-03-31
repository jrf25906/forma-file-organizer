import Foundation

// MARK: - Error Types

enum AnalyticsError: Error, LocalizedError {
    case insufficientData(required: Int, available: Int)
    case snapshotEncodingFailed(underlyingError: Error)
    case snapshotDecodingFailed(underlyingError: Error)
    case retentionPolicyFailed(underlyingError: Error)
    case reportGenerationFailed(reason: String)
    case pdfExportFailed(underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .insufficientData(let required, let available):
            return "Insufficient data for analysis. Required: \(required) snapshots, available: \(available)."
        case .snapshotEncodingFailed(let error):
            return "Failed to encode snapshot data: \(error.localizedDescription)"
        case .snapshotDecodingFailed(let error):
            return "Failed to decode snapshot data: \(error.localizedDescription)"
        case .retentionPolicyFailed(let error):
            return "Failed to apply retention policy: \(error.localizedDescription)"
        case .reportGenerationFailed(let reason):
            return "Failed to generate report: \(reason)"
        case .pdfExportFailed(let error):
            return "Failed to export PDF: \(error.localizedDescription)"
        }
    }
}

// MARK: - Usage Types

enum UsagePeriod: Equatable, Hashable, Sendable {
    case day
    case week
    case month
    case custom(DateInterval)
}

struct UsageStatistics: Sendable {
    let period: UsagePeriod
    let startDate: Date
    let endDate: Date

    let filesOrganized: Int
    let bulkOperations: Int
    let rulesAppliedByRuleID: [UUID: Int]

    let timeSavedSeconds: Int
    let averageFilesPerDay: Double
}

// MARK: - Trend Types

struct StorageTrendPoint: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let totalBytes: Int64
    let deltaBytes: Int64
}

struct CleanupImpact: Sendable {
    let totalFreedBytes: Int64
    let averageFreedPerWeek: Int64
    let largestSingleCleanupBytes: Int64
}

// MARK: - Health Score Types

enum HealthFactorType: String, Sendable, CaseIterable {
    case capacity
    case unorganized
    case ruleCoverage
    case growthTrend
}

struct HealthFactor: Sendable {
    let type: HealthFactorType
    let description: String
    let rawScore: Double
    let weight: Double
    let impact: Int
}

struct OptimizationRecommendation: Identifiable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let priority: Int
}

struct StorageHealthScore: Sendable {
    let score: Int
    let factors: [HealthFactor]
    let recommendations: [OptimizationRecommendation]

    var grade: String {
        switch score {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 60..<75: return "Fair"
        case 40..<60: return "Needs Attention"
        default: return "Critical"
        }
    }
}

struct FolderSizeAlert: Identifiable, Equatable, Sendable {
    let folderType: BookmarkFolder.FolderType
    let currentBytes: Int64
    let thresholdBytes: Int64

    var id: String {
        folderType.rawValue
    }
}

struct StaleRuleAlert: Identifiable, Equatable, Sendable {
    struct RuleSummary: Identifiable, Equatable, Sendable {
        let id: UUID
        let ruleName: String
        let referenceDate: Date
        let staleDays: Int
        let hasMatchedBefore: Bool
    }

    let thresholdDays: Int
    let rules: [RuleSummary]

    var id: String {
        "stale-rules"
    }
}

enum FolderHealthAlert: Identifiable, Equatable, Sendable {
    case folderSize(FolderSizeAlert)
    case staleRules(StaleRuleAlert)

    var id: String {
        switch self {
        case .folderSize(let alert):
            return "folder.\(alert.folderType.rawValue)"
        case .staleRules:
            return "stale-rules"
        }
    }
}

struct FolderHealthEvaluation: Equatable, Sendable {
    let folderSizeAlerts: [FolderSizeAlert]
    let staleRuleAlert: StaleRuleAlert?

    static let empty = FolderHealthEvaluation(folderSizeAlerts: [], staleRuleAlert: nil)

    var hasActiveAlerts: Bool {
        !folderSizeAlerts.isEmpty || staleRuleAlert != nil
    }

    var activeAlerts: [FolderHealthAlert] {
        var alerts = folderSizeAlerts.map(FolderHealthAlert.folderSize)
        if let staleRuleAlert {
            alerts.append(.staleRules(staleRuleAlert))
        }
        return alerts
    }
}

// MARK: - Report Types

enum ReportPeriod: Equatable, Hashable, Sendable {
    case weekly
    case monthly
    case custom(DateInterval)
}

struct AnalyticsReportSection: Sendable {
    let title: String
    let body: String
    let metrics: [String: String]
}

struct AnalyticsReport: Identifiable, Sendable {
    let id: UUID
    let generatedAt: Date
    let period: ReportPeriod

    let storageTrendPoints: [StorageTrendPoint]
    let usageStatistics: UsageStatistics
    let healthScore: StorageHealthScore
    let recommendations: [OptimizationRecommendation]

    let sections: [AnalyticsReportSection]
}

struct AnalyticsSummary: Sendable {
    let trendPoints: [StorageTrendPoint]
    let usageStatistics: UsageStatistics
    let healthScore: StorageHealthScore
    let folderHealthEvaluation: FolderHealthEvaluation
}
