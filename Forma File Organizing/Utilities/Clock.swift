import Foundation

/// Simple time provider for deterministic tests and schedulers.
protocol Clock {
    var now: Date { get }
    var calendar: Calendar { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
    var calendar: Calendar { .current }
}

struct FixedClock: Clock {
    let now: Date
    let calendar: Calendar

    init(now: Date, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }
}
