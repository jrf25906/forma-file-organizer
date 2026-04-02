import Foundation

/// Determines when to prompt the user for an App Store review.
protocol AppReviewEligibilityProviding {
    /// Record that files were successfully organized.
    func recordSuccessfulOperation(count: Int)
    /// Whether all eligibility conditions are met for a review request.
    func shouldRequestReview() -> Bool
    /// Mark that a review was just requested.
    func markReviewRequested()
}

/// Tracks usage milestones via UserDefaults and decides when to trigger
/// Apple's `requestReview` prompt.
///
/// Eligibility requires all of:
/// - Feature flag `.appStoreReviewPrompt` is enabled
/// - At least `FormaConfig.ReviewPrompt.minSuccessfulOperations` files organized
/// - At least `FormaConfig.ReviewPrompt.minDaysSinceFirstUse` days since first use
/// - At least `FormaConfig.ReviewPrompt.minDaysBetweenRequests` days since last prompt
/// - Fewer than `FormaConfig.ReviewPrompt.maxLifetimeRequests` lifetime prompts
struct AppReviewEligibilityService: AppReviewEligibilityProviding {

    private enum Keys {
        static let totalSuccessfulOps = "forma.review.totalSuccessfulOps"
        static let firstUseDateSeconds = "forma.review.firstUseDateSeconds"
        static let lastRequestDateSeconds = "forma.review.lastRequestDateSeconds"
        static let requestCount = "forma.review.requestCount"
    }

    private let defaults: UserDefaults
    private let now: @Sendable () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping @Sendable () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
    }

    // MARK: - AppReviewEligibilityProviding

    func recordSuccessfulOperation(count: Int) {
        guard count > 0 else { return }

        let current = defaults.integer(forKey: Keys.totalSuccessfulOps)
        defaults.set(current + count, forKey: Keys.totalSuccessfulOps)

        // Set first-use date once
        if defaults.double(forKey: Keys.firstUseDateSeconds) == 0 {
            defaults.set(now().timeIntervalSince1970, forKey: Keys.firstUseDateSeconds)
        }

        Log.debug(
            "AppReviewEligibility: recorded \(count) ops (total: \(current + count))",
            category: .review
        )
    }

    func shouldRequestReview() -> Bool {
        guard FeatureFlagService.shared.isEnabled(.appStoreReviewPrompt) else {
            return false
        }

        let totalOps = defaults.integer(forKey: Keys.totalSuccessfulOps)
        guard totalOps >= FormaConfig.ReviewPrompt.minSuccessfulOperations else {
            return false
        }

        let firstUseSeconds = defaults.double(forKey: Keys.firstUseDateSeconds)
        guard firstUseSeconds > 0 else { return false }
        let daysSinceFirstUse = now().timeIntervalSince1970 - firstUseSeconds
        guard daysSinceFirstUse >= Double(FormaConfig.ReviewPrompt.minDaysSinceFirstUse) * FormaConfig.Timing.secondsInDay else {
            return false
        }

        let lifetimeRequests = defaults.integer(forKey: Keys.requestCount)
        guard lifetimeRequests < FormaConfig.ReviewPrompt.maxLifetimeRequests else {
            return false
        }

        let lastRequestSeconds = defaults.double(forKey: Keys.lastRequestDateSeconds)
        if lastRequestSeconds > 0 {
            let daysSinceLastRequest = now().timeIntervalSince1970 - lastRequestSeconds
            guard daysSinceLastRequest >= Double(FormaConfig.ReviewPrompt.minDaysBetweenRequests) * FormaConfig.Timing.secondsInDay else {
                return false
            }
        }

        Log.info("AppReviewEligibility: all conditions met, will request review", category: .review, verboseOnly: false)
        return true
    }

    func markReviewRequested() {
        defaults.set(now().timeIntervalSince1970, forKey: Keys.lastRequestDateSeconds)
        let current = defaults.integer(forKey: Keys.requestCount)
        defaults.set(current + 1, forKey: Keys.requestCount)
        Log.info("AppReviewEligibility: review requested (count: \(current + 1))", category: .review, verboseOnly: false)
    }
}
