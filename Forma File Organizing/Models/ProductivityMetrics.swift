import Foundation

// MARK: - Productivity Metrics

/// Comprehensive productivity metrics for the Health Report view.
struct ProductivityMetrics: Sendable {
    /// Space freed during the period (sum of negative snapshot deltas)
    let spaceReclaimedBytes: Int64

    /// Estimated time saved in seconds based on file operations
    let timeSavedSeconds: Int

    /// Organization score from 0-100 (ratio of organized to pending files)
    let organizationScore: Int

    /// Previous period's metrics for comparison (optional)
    let previousPeriod: PreviousPeriodMetrics?

    /// Formatted space reclaimed (e.g., "2.4 GB")
    var formattedSpaceReclaimed: String {
        ByteCountFormatter.string(fromByteCount: spaceReclaimedBytes, countStyle: .file)
    }

    /// Formatted time saved (e.g., "45 min" or "1h 30m")
    var formattedTimeSaved: String {
        let hours = timeSavedSeconds / 3600
        let minutes = (timeSavedSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "< 1 min"
        }
    }

    /// Grade based on organization score
    var organizationGrade: String {
        switch organizationScore {
        case 90...100: return "A+"
        case 85..<90: return "A"
        case 80..<85: return "B+"
        case 75..<80: return "B"
        case 70..<75: return "C+"
        case 60..<70: return "C"
        default: return "Needs Work"
        }
    }
}

/// Previous period metrics for delta comparison.
struct PreviousPeriodMetrics: Sendable {
    let spaceReclaimedBytes: Int64
    let timeSavedSeconds: Int
    let organizationScore: Int
}

// MARK: - Automation Efficiency

/// A point in the automation efficiency timeline (manual vs automated).
struct AutomationEfficiencyPoint: Identifiable, Sendable {
    let id: UUID
    let date: Date

    /// Number of manual file operations (user-initiated)
    let manualActions: Int

    /// Number of automated operations (rule-based, auto-organized)
    let automatedActions: Int

    /// Total actions for this point
    var totalActions: Int {
        manualActions + automatedActions
    }

    /// Automation percentage (0.0 to 1.0)
    var automationRate: Double {
        guard totalActions > 0 else { return 0 }
        return Double(automatedActions) / Double(totalActions)
    }

    init(id: UUID = UUID(), date: Date, manualActions: Int, automatedActions: Int) {
        self.id = id
        self.date = date
        self.manualActions = manualActions
        self.automatedActions = automatedActions
    }
}

// MARK: - Staleness Tracking (Calendar Heatmap)

/// Level of staleness for files (how long since last accessed).
enum StalenessLevel: Int, CaseIterable, Sendable {
    case fresh = 0          // Accessed within 7 days
    case recent = 1         // 7-30 days
    case aging = 2          // 1-3 months
    case stale = 3          // 3-6 months
    case digitalDust = 4    // 6+ months (red zone)

    var displayName: String {
        switch self {
        case .fresh: return "Fresh"
        case .recent: return "Recent"
        case .aging: return "Aging"
        case .stale: return "Stale"
        case .digitalDust: return "Digital Dust"
        }
    }

    /// Compute staleness level from a date.
    static func from(lastAccessed: Date?, referenceDate: Date = Date()) -> StalenessLevel {
        guard let lastAccessed else { return .stale }

        let daysSinceAccess = Calendar.current.dateComponents([.day], from: lastAccessed, to: referenceDate).day ?? 0

        switch daysSinceAccess {
        case ..<7: return .fresh
        case 7..<30: return .recent
        case 30..<90: return .aging
        case 90..<180: return .stale
        default: return .digitalDust
        }
    }
}

/// Staleness data for a single day (used in calendar heatmap).
struct DayStaleness: Identifiable, Sendable {
    let id: UUID
    let date: Date

    /// Number of files at each staleness level
    let fileCounts: [StalenessLevel: Int]

    /// Total bytes at each staleness level
    let byteCounts: [StalenessLevel: Int64]

    /// Dominant staleness level for this day (for coloring)
    var dominantLevel: StalenessLevel {
        // Weight by both count and concern level
        var maxScore = 0
        var dominant: StalenessLevel = .fresh

        for level in StalenessLevel.allCases {
            let count = fileCounts[level] ?? 0
            // Higher staleness levels get exponentially more weight
            let score = count * (1 << level.rawValue)
            if score > maxScore {
                maxScore = score
                dominant = level
            }
        }

        return dominant
    }

    /// Total files this day
    var totalFiles: Int {
        fileCounts.values.reduce(0, +)
    }

    /// Files in the "Digital Dust" category
    var digitalDustCount: Int {
        fileCounts[.digitalDust] ?? 0
    }

    init(id: UUID = UUID(), date: Date, fileCounts: [StalenessLevel: Int] = [:], byteCounts: [StalenessLevel: Int64] = [:]) {
        self.id = id
        self.date = date
        self.fileCounts = fileCounts
        self.byteCounts = byteCounts
    }
}

// MARK: - Treemap Data

/// A node in the storage treemap.
struct TreemapNode: Identifiable, Sendable {
    let id: UUID
    let label: String
    let bytes: Int64
    let children: [TreemapNode]
    let category: FileTypeCategory?

    /// Formatted size string
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Whether this is a leaf node
    var isLeaf: Bool {
        children.isEmpty
    }

    /// Percentage of parent (calculated during layout)
    var percentage: Double = 0

    init(
        id: UUID = UUID(),
        label: String,
        bytes: Int64,
        children: [TreemapNode] = [],
        category: FileTypeCategory? = nil
    ) {
        self.id = id
        self.label = label
        self.bytes = bytes
        self.children = children
        self.category = category
    }

    /// Create a leaf node for a category.
    static func categoryNode(_ category: FileTypeCategory, bytes: Int64) -> TreemapNode {
        TreemapNode(
            label: category.displayName,
            bytes: bytes,
            category: category
        )
    }

    /// Create a leaf node for a large file.
    static func fileNode(name: String, bytes: Int64, category: FileTypeCategory?) -> TreemapNode {
        TreemapNode(
            label: name,
            bytes: bytes,
            category: category
        )
    }
}

// MARK: - Smart Insights

/// An actionable insight for the user.
struct SmartInsight: Identifiable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let icon: String
    let actionLabel: String?
    let actionType: ActionType?
    let priority: Priority
    let category: Category

    enum Priority: Int, Sendable, Comparable {
        case low = 0
        case medium = 1
        case high = 2

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    enum Category: String, Sendable {
        case cleanup          // Suggestions to free space
        case organization     // Ways to better organize
        case automation       // Automation opportunities
        case celebration      // Positive reinforcement
    }

    enum ActionType: Sendable {
        case archiveScreenshots
        case reviewLargeFiles
        case cleanDownloads
        case createRule(suggestedPattern: String)
        case enableAutomation
        case reviewFolder(path: URL)
    }

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        icon: String = "lightbulb.fill",
        actionLabel: String? = nil,
        actionType: ActionType? = nil,
        priority: Priority = .medium,
        category: Category = .organization
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.icon = icon
        self.actionLabel = actionLabel
        self.actionType = actionType
        self.priority = priority
        self.category = category
    }
}

// MARK: - Complete Report

/// Complete productivity health report for display.
struct ProductivityHealthReport: Sendable {
    let period: UsagePeriod
    let generatedAt: Date

    /// The "Big Three" impact metrics
    let metrics: ProductivityMetrics

    /// Automation efficiency timeline
    let automationTimeline: [AutomationEfficiencyPoint]

    /// Treemap root node for storage visualization
    let storageTreemap: TreemapNode

    /// Calendar heatmap data (365 days)
    let stalenessCalendar: [DayStaleness]

    /// Smart actionable insights
    let insights: [SmartInsight]

    /// Overall automation rate across the period
    var overallAutomationRate: Double {
        let totalManual = automationTimeline.map(\.manualActions).reduce(0, +)
        let totalAuto = automationTimeline.map(\.automatedActions).reduce(0, +)
        let total = totalManual + totalAuto
        guard total > 0 else { return 0 }
        return Double(totalAuto) / Double(total)
    }

    /// Total "Digital Dust" files found
    var totalDigitalDust: Int {
        stalenessCalendar.map(\.digitalDustCount).reduce(0, +)
    }
}
