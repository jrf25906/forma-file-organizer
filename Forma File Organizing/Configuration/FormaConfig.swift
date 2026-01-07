import Foundation

struct AnalyticsConfig {
    let retentionDays: Int
    let minSnapshotsForTrends: Int

    // Time-saved heuristics (seconds per operation).
    let secondsPerFileOrganized: Int
    let secondsPerFileInBulkOrganize: Int
    let secondsPerFileWithRuleApplied: Int

    // Health score weights (must sum to 1.0).
    let healthWeightCapacity: Double
    let healthWeightUnorganized: Double
    let healthWeightRuleCoverage: Double
    let healthWeightGrowthTrend: Double
}

/// Centralized configuration for the Forma application.
///
/// All magic numbers, constants, and configuration values should be defined here
/// for maintainability and easy adjustment.
enum FormaConfig {
    
    // MARK: - Limits
    
    enum Limits {
        /// Maximum number of undo actions to keep in memory
        static let maxUndoActions = 20
        
        /// Maximum number of redo actions to keep in memory
        static let maxRedoActions = 20
        
        /// Maximum batch size for file operations to prevent resource exhaustion
        static let maxFileBatchSize = 1000
        
        /// Threshold for considering a file "large" (in MB)
        static let largeFileSizeThresholdMB: Int64 = 10
        
        /// Minimum number of files required to detect project clusters
        static let minFilesForClusterDetection = 5
        
        /// Maximum number of recent activities to display
        static let maxRecentActivities = 10
        
        /// Maximum number of recent files to display
        static let maxRecentFiles = 8
    }
    
    // MARK: - Timing
    
    enum Timing {
        /// Delay between batch file operations (milliseconds)
        static let operationDelayMS: UInt64 = 100
        
        /// Duration to display celebration messages (seconds)
        static let celebrationDurationSec: Duration = .seconds(5)
        
        /// Debounce delay for filter updates (milliseconds)
        static let filterDebounceDelayMS: Duration = .milliseconds(150)

        /// Timeout for file scan operations (prevents indefinite hanging)
        static let scanTimeout: Duration = .seconds(60)

        /// Time constants
        static let secondsInDay: TimeInterval = 86400
        static let secondsInWeek: TimeInterval = 604800
        static let secondsInMonth: TimeInterval = 2592000
    }
    
    // MARK: - Thresholds
    
    enum Thresholds {
        /// Large file size threshold in bytes
        static var largeFileSizeBytes: Int64 {
            Limits.largeFileSizeThresholdMB * 1024 * 1024
        }
    }
    
    // MARK: - UI
    
    enum UI {
        /// Minimum window width
        static let minWindowWidth: CGFloat = 1200
        
        /// Minimum window height
        static let minWindowHeight: CGFloat = 600
        
        /// Ideal window width
        static let idealWindowWidth: CGFloat = 1400
        
        /// Sidebar width when collapsed
        static let sidebarWidthCollapsed: CGFloat = 72
        
        /// Sidebar width when expanded
        static let sidebarWidthExpanded: CGFloat = 256
        
        /// Right panel width
        static let rightPanelMinWidth: CGFloat = 320
        static let rightPanelIdealWidth: CGFloat = 360
        static let rightPanelMaxWidth: CGFloat = 420
        
        /// Animation durations
        static let sidebarAnimationDuration: Double = 0.5
        static let sidebarAnimationDamping: Double = 0.85
        static let organizeAnimationDuration: Double = 0.3
        static let ruleEditorAnimationDuration: Double = 0.2
    }
    
    // MARK: - Storage
    
    enum Storage {
        /// UserDefaults keys
        static let appliedTemplateKey = "appliedTemplate"
        static let bookmarkMigrationStateKey = "BookmarkMigrationState"
        
        /// SwiftData configuration
        static let storeFileName = "default.store"
        static let backupFileName = "default.store.backup"
    }
    
    // MARK: - Security
    
    enum Security {
        /// Bookmark keys for folder access
        static let desktopBookmarkKey = "DesktopFolderBookmark"
        static let downloadsBookmarkKey = "DownloadsFolderBookmark"
        static let documentsBookmarkKey = "DocumentsFolderBookmark"
        static let picturesBookmarkKey = "PicturesFolderBookmark"
        static let musicBookmarkKey = "MusicFolderBookmark"
        
        /// Destination folder bookmark prefix
        static let destinationBookmarkPrefix = "DestinationFolderBookmark_"
    }
    
    // MARK: - Performance

    enum Performance: Sendable {
        /// Whether to enable expensive debug logging
        static let verboseLogging = false

        /// Whether to cache analytics calculations
        static let cacheAnalytics = true

        /// Whether to use file system watching (future feature)
        static let enableFileSystemWatching = false
    }
    
    // MARK: - Features
    
    enum Features {
        /// Whether cluster detection is enabled
        static let enableClusterDetection = true
        
        /// Whether learning from user actions is enabled
        static let enableLearning = true
        
        /// Whether to show debug badges in UI
        static let showDebugInfo = false
    }
    
    // MARK: - Validation
    
    #if DEBUG
    /// Validates that all configuration values are reasonable
    static func validateConfiguration() {
        // Check limits
        assert(Limits.maxUndoActions > 0, "maxUndoActions must be positive")
        assert(Limits.maxRedoActions > 0, "maxRedoActions must be positive")
        assert(Limits.maxFileBatchSize > 0, "maxFileBatchSize must be positive")
        assert(Limits.largeFileSizeThresholdMB > 0, "largeFileSizeThresholdMB must be positive")
        
        // Check timing
        assert(Timing.operationDelayMS > 0, "operationDelayMS must be positive")
        
        // Check UI
        assert(UI.minWindowWidth > 0, "minWindowWidth must be positive")
        assert(UI.minWindowHeight > 0, "minWindowHeight must be positive")
        assert(UI.sidebarWidthCollapsed < UI.sidebarWidthExpanded, "sidebarWidthCollapsed must be less than expanded")
        
        Log.info("FormaConfig: All configuration values validated", category: .general)
    }
    #endif
}

extension FormaConfig {
    static let analytics = AnalyticsConfig(
        retentionDays: 90,
        minSnapshotsForTrends: 7,
        secondsPerFileOrganized: 6,
        secondsPerFileInBulkOrganize: 4,
        secondsPerFileWithRuleApplied: 8,
        healthWeightCapacity: 0.40,
        healthWeightUnorganized: 0.25,
        healthWeightRuleCoverage: 0.20,
        healthWeightGrowthTrend: 0.15
    )
}
