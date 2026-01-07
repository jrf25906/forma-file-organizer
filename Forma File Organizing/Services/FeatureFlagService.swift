import Foundation

/// Service for managing user-controllable feature flags.
///
/// Implements a hierarchical toggle system:
/// - **Master toggle**: "AI Features" controls all AI/ML features
/// - **Individual toggles**: Fine-grained control when master is ON
///
/// When master is OFF, all individual features are disabled regardless of their settings.
/// When master is ON, individual settings are respected.
struct FeatureFlagService: Sendable {

    // MARK: - Singleton

    static let shared = FeatureFlagService()

    // MARK: - Feature Definitions

    /// All available feature flags
    enum Feature: String, CaseIterable, Identifiable {
        case patternLearning = "feature.patternLearning"
        case ruleSuggestions = "feature.ruleSuggestions"
        case destinationPrediction = "feature.destinationPrediction"
        case contentScanning = "feature.contentScanning"
        case contextDetection = "feature.contextDetection"
        case analyticsAndInsights = "feature.analyticsAndInsights"
        case storageTrends = "feature.storageTrends"
        case usageStats = "feature.usageStats"
        case storageHealthScore = "feature.storageHealthScore"
        case optimizationRecommendations = "feature.optimizationRecommendations"
        case analyticsReports = "feature.analyticsReports"

        // Automation (v1.4)
        case backgroundMonitoring = "feature.backgroundMonitoring"
        case autoOrganize = "feature.autoOrganize"
        case automationReminders = "feature.automationReminders"

        var id: String { rawValue }

        /// Default value for this feature
        var defaultValue: Bool {
            switch self {
            case .patternLearning: return true
            case .ruleSuggestions: return true
            case .destinationPrediction: return true
            case .contentScanning: return false  // Opt-in due to performance concerns
            case .contextDetection: return true
            case .analyticsAndInsights: return true
            case .storageTrends: return true
            case .usageStats: return true
            case .storageHealthScore: return true
            case .optimizationRecommendations: return true
            case .analyticsReports: return true
            // Automation (v1.4)
            case .backgroundMonitoring: return true
            case .autoOrganize: return false  // Opt-in for initial release
            case .automationReminders: return true
            }
        }

        /// Human-readable name for UI
        var displayName: String {
            switch self {
            case .patternLearning: return "Learn from my organization"
            case .ruleSuggestions: return "Suggest rules automatically"
            case .destinationPrediction: return "Predict destinations"
            case .contentScanning: return "Content scanning"
            case .contextDetection: return "Context detection"
            case .analyticsAndInsights: return "Analytics & Insights"
            case .storageTrends: return "Storage trends"
            case .usageStats: return "Usage statistics"
            case .storageHealthScore: return "Storage health score"
            case .optimizationRecommendations: return "Optimization recommendations"
            case .analyticsReports: return "Analytics reports"
            // Automation (v1.4)
            case .backgroundMonitoring: return "Background monitoring"
            case .autoOrganize: return "Auto-organize files"
            case .automationReminders: return "Smart reminders"
            }
        }

        /// Description for UI
        var description: String {
            switch self {
            case .patternLearning:
                return "Observe how you organize files to learn patterns"
            case .ruleSuggestions:
                return "Show rule suggestions based on learned patterns"
            case .destinationPrediction:
                return "Pre-fill destination based on similar files"
            case .contentScanning:
                return "Allow rules to read file contents for matching (may impact performance)"
            case .contextDetection:
                return "Detect work context and time-based patterns"
            case .analyticsAndInsights:
                return "Enable analytics, trends, health scoring, and insights."
            case .storageTrends:
                return "Track daily storage snapshots and growth/cleanup trends."
            case .usageStats:
                return "Aggregate organization activity and estimate time saved."
            case .storageHealthScore:
                return "Compute a 0–100 health score with factor breakdowns."
            case .optimizationRecommendations:
                return "Suggest cleanup and optimization actions from analytics."
            case .analyticsReports:
                return "Generate weekly analytics reports with PDF export."
            // Automation (v1.4)
            case .backgroundMonitoring:
                return "Periodically scan folders for new files while the app is running."
            case .autoOrganize:
                return "Automatically move files that match rules with high confidence."
            case .automationReminders:
                return "Get notified when files need attention or automation takes action."
            }
        }

        /// SF Symbol icon for UI
        var iconName: String {
            switch self {
            case .patternLearning: return "brain"
            case .ruleSuggestions: return "lightbulb"
            case .destinationPrediction: return "location.magnifyingglass"
            case .contentScanning: return "doc.text.magnifyingglass"
            case .contextDetection: return "clock.badge.checkmark"
            case .analyticsAndInsights: return "chart.pie.fill"
            case .storageTrends: return "chart.line.uptrend.xyaxis"
            case .usageStats: return "chart.bar.xaxis"
            case .storageHealthScore: return "heart.text.square"
            case .optimizationRecommendations: return "lightbulb.2.fill"
            case .analyticsReports: return "doc.richtext"
            // Automation (v1.4)
            case .backgroundMonitoring: return "eye.circle"
            case .autoOrganize: return "bolt.circle"
            case .automationReminders: return "bell.badge"
            }
        }

        /// Dependencies - features that require this feature to be enabled
        var dependencies: [Feature] {
            switch self {
            case .patternLearning:
                return []  // Base feature, no dependencies
            case .ruleSuggestions:
                return [.patternLearning]  // Needs pattern learning to suggest rules
            case .destinationPrediction:
                return [.patternLearning]  // Needs learned history for predictions
            case .contentScanning:
                return []  // Independent feature
            case .contextDetection:
                return []  // Independent feature
            case .analyticsAndInsights:
                return []
            case .storageTrends, .usageStats, .storageHealthScore, .optimizationRecommendations, .analyticsReports:
                return [.analyticsAndInsights]
            // Automation (v1.4)
            case .backgroundMonitoring:
                return []  // Base automation feature
            case .autoOrganize:
                return [.backgroundMonitoring]  // Needs monitoring to auto-organize
            case .automationReminders:
                return [.backgroundMonitoring]  // Needs monitoring for context
            }
        }
    }

    // MARK: - Storage Keys

    private static let masterKey = "feature.masterAI"

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Master toggle for all AI features.
    var masterAIEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.masterKey) != nil {
                return UserDefaults.standard.bool(forKey: Self.masterKey)
            }
            return true
        }
        nonmutating set {
            UserDefaults.standard.set(newValue, forKey: Self.masterKey)
            Log.info("FeatureFlagService: Master AI toggle set to \(newValue)", category: .analytics)
        }
    }

    /// Check if a feature is effectively enabled (respects master toggle and dependencies).
    ///
    /// This is the primary method services should use to check feature availability.
    ///
    /// - Parameter feature: The feature to check
    /// - Returns: `true` if the feature is enabled and usable
    func isEnabled(_ feature: Feature) -> Bool {
        // Master toggle overrides everything
        guard masterAIEnabled else { return false }

        // Check dependencies first
        for dependency in feature.dependencies {
            if !isEnabled(dependency) {
                return false
            }
        }

        // Check individual setting
        return getRawValue(feature)
    }

    /// Get the raw individual setting value (ignores master toggle).
    ///
    /// Use this for UI binding when you want to show the toggle state
    /// even when master is off.
    ///
    /// - Parameter feature: The feature to check
    /// - Returns: The raw toggle value
    func getRawValue(_ feature: Feature) -> Bool {
        Self.loadFeature(feature)
    }

    /// Set a feature's enabled state.
    ///
    /// - Parameters:
    ///   - feature: The feature to set
    ///   - enabled: Whether the feature should be enabled
    func setEnabled(_ feature: Feature, _ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: feature.rawValue)
        Log.info("FeatureFlagService: \(feature.displayName) set to \(enabled)", category: .analytics)
    }

    /// Reset all feature flags to defaults.
    func resetToDefaults() {
        masterAIEnabled = true

        for feature in Feature.allCases {
            setEnabled(feature, feature.defaultValue)
        }

        Log.info("FeatureFlagService: Reset all flags to defaults", category: .analytics)
    }

    // MARK: - Private Helpers

    private static func loadFeature(_ feature: Feature) -> Bool {
        if UserDefaults.standard.object(forKey: feature.rawValue) != nil {
            return UserDefaults.standard.bool(forKey: feature.rawValue)
        }
        return feature.defaultValue
    }
}

// MARK: - Convenience Extensions

extension FeatureFlagService {
    /// Quick check for any AI feature being available.
    ///
    /// Useful for hiding entire UI sections when AI is completely disabled.
    var hasAnyAIFeatureEnabled: Bool {
        guard masterAIEnabled else { return false }
        return Feature.allCases.contains { isEnabled($0) }
    }

    /// Get all features with their current effective state.
    ///
    /// Useful for debugging or displaying a summary.
    var allFeatureStates: [(feature: Feature, rawEnabled: Bool, effectiveEnabled: Bool)] {
        Feature.allCases.map { feature in
            (feature: feature, rawEnabled: getRawValue(feature), effectiveEnabled: isEnabled(feature))
        }
    }
}
