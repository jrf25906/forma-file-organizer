import Foundation

/// Protocol for rate limiting async operations.
protocol RateLimiter: Sendable {
    func sleepIfNeeded(after index: Int, total: Int) async
}

/// Production rate limiter that uses Task.sleep between operations.
struct TaskRateLimiter: RateLimiter {
    let delayNanoseconds: UInt64

    func sleepIfNeeded(after index: Int, total: Int) async {
        guard total > 1, index < total - 1 else { return }
        try? await Task.sleep(nanoseconds: delayNanoseconds)
    }
}
