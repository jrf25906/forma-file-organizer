import Combine
import Foundation

/// Central dependency container for app-wide services.
///
/// This is the preferred way to access services from ViewModels and Views as we
/// migrate away from scattered `.shared` usage.
@MainActor
final class AppServices: ObservableObject {

    let featureFlags: FeatureFlagService
    let storageService: StorageService
    let ruleEngine: RuleEngine

    /// Lazily initialized to avoid triggering side effects (like notification auth)
    /// in contexts that don't need them (e.g., UI tests).
    lazy var notificationService: NotificationService = .shared

    lazy var quickLookService: QuickLookService = .shared
    lazy var thumbnailService: ThumbnailService = .shared
    lazy var analyticsService: AnalyticsService = .shared
    lazy var reportService: ReportService = .shared
    lazy var insightsService: InsightsService = .shared
    lazy var appReviewEligibility: AppReviewEligibilityProviding = AppReviewEligibilityService()
    lazy var fileSystemService: FileSystemServiceProtocol = FileSystemService()
    lazy var fileScanPipeline: FileScanPipelineProtocol = FileScanPipeline()
    lazy var dashboardScanProvider = DashboardFileScanProvider(
        pipeline: fileScanPipeline,
        fileSystemService: fileSystemService,
        ruleEngine: ruleEngine
    )

    init(
        featureFlags: FeatureFlagService = .shared,
        storageService: StorageService = .shared,
        ruleEngine: RuleEngine = RuleEngine()
    ) {
        self.featureFlags = featureFlags
        self.storageService = storageService
        self.ruleEngine = ruleEngine
    }
}
