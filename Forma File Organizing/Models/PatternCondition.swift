import Foundation

// MARK: - Pattern Condition

/// Represents a single condition within a learned pattern.
/// Supports compound patterns like "PDF + name contains 'invoice' → Finance"
/// Marked Sendable as it contains only value types and is safe for concurrent use.
enum PatternCondition: Codable, Hashable, Sendable {
    // Note: Equatable is implemented manually below to ensure nonisolated access
    case fileExtension(String)
    case nameContains(String)
    case nameStartsWith(String)
    case nameEndsWith(String)
    case sizeRange(minBytes: Int64, maxBytes: Int64)
    case timeOfDay(startHour: Int, endHour: Int)
    case dayOfWeek([Int]) // 1 = Sunday, 7 = Saturday

    // MARK: - Codable Implementation

    private enum CodingKeys: String, CodingKey {
        case type
        case stringValue
        case minBytes, maxBytes
        case startHour, endHour
        case days
    }

    private enum ConditionTypeCode: String, Codable {
        case fileExtension
        case nameContains
        case nameStartsWith
        case nameEndsWith
        case sizeRange
        case timeOfDay
        case dayOfWeek
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ConditionTypeCode.self, forKey: .type)

        switch type {
        case .fileExtension:
            let value = try container.decode(String.self, forKey: .stringValue)
            self = .fileExtension(value)
        case .nameContains:
            let value = try container.decode(String.self, forKey: .stringValue)
            self = .nameContains(value)
        case .nameStartsWith:
            let value = try container.decode(String.self, forKey: .stringValue)
            self = .nameStartsWith(value)
        case .nameEndsWith:
            let value = try container.decode(String.self, forKey: .stringValue)
            self = .nameEndsWith(value)
        case .sizeRange:
            let minBytes = try container.decode(Int64.self, forKey: .minBytes)
            let maxBytes = try container.decode(Int64.self, forKey: .maxBytes)
            self = .sizeRange(minBytes: minBytes, maxBytes: maxBytes)
        case .timeOfDay:
            let start = try container.decode(Int.self, forKey: .startHour)
            let end = try container.decode(Int.self, forKey: .endHour)
            self = .timeOfDay(startHour: start, endHour: end)
        case .dayOfWeek:
            let days = try container.decode([Int].self, forKey: .days)
            self = .dayOfWeek(days)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .fileExtension(let value):
            try container.encode(ConditionTypeCode.fileExtension, forKey: .type)
            try container.encode(value, forKey: .stringValue)
        case .nameContains(let value):
            try container.encode(ConditionTypeCode.nameContains, forKey: .type)
            try container.encode(value, forKey: .stringValue)
        case .nameStartsWith(let value):
            try container.encode(ConditionTypeCode.nameStartsWith, forKey: .type)
            try container.encode(value, forKey: .stringValue)
        case .nameEndsWith(let value):
            try container.encode(ConditionTypeCode.nameEndsWith, forKey: .type)
            try container.encode(value, forKey: .stringValue)
        case .sizeRange(let minBytes, let maxBytes):
            try container.encode(ConditionTypeCode.sizeRange, forKey: .type)
            try container.encode(minBytes, forKey: .minBytes)
            try container.encode(maxBytes, forKey: .maxBytes)
        case .timeOfDay(let start, let end):
            try container.encode(ConditionTypeCode.timeOfDay, forKey: .type)
            try container.encode(start, forKey: .startHour)
            try container.encode(end, forKey: .endHour)
        case .dayOfWeek(let days):
            try container.encode(ConditionTypeCode.dayOfWeek, forKey: .type)
            try container.encode(days, forKey: .days)
        }
    }

    // MARK: - Description

    var displayDescription: String {
        switch self {
        case .fileExtension(let ext):
            return ".\(ext) files"
        case .nameContains(let text):
            return "name contains '\(text)'"
        case .nameStartsWith(let text):
            return "name starts with '\(text)'"
        case .nameEndsWith(let text):
            return "name ends with '\(text)'"
        case .sizeRange(let min, let max):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "\(formatter.string(fromByteCount: min)) - \(formatter.string(fromByteCount: max))"
        case .timeOfDay(let start, let end):
            return "\(start):00 - \(end):00"
        case .dayOfWeek(let days):
            let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let names = days.compactMap { day in
                (1...7).contains(day) ? dayNames[day - 1] : nil
            }
            return names.joined(separator: ", ")
        }
    }
}

// MARK: - Equatable Conformance

extension PatternCondition: Equatable {
    /// Explicit nonisolated equality implementation to avoid actor isolation issues
    /// when used within @Model classes like LearnedPattern
    nonisolated static func == (lhs: PatternCondition, rhs: PatternCondition) -> Bool {
        switch (lhs, rhs) {
        case let (.fileExtension(l), .fileExtension(r)):
            return l == r
        case let (.nameContains(l), .nameContains(r)):
            return l == r
        case let (.nameStartsWith(l), .nameStartsWith(r)):
            return l == r
        case let (.nameEndsWith(l), .nameEndsWith(r)):
            return l == r
        case let (.sizeRange(lMin, lMax), .sizeRange(rMin, rMax)):
            return lMin == rMin && lMax == rMax
        case let (.timeOfDay(lStart, lEnd), .timeOfDay(rStart, rEnd)):
            return lStart == rStart && lEnd == rEnd
        case let (.dayOfWeek(lDays), .dayOfWeek(rDays)):
            return lDays == rDays
        default:
            return false
        }
    }
}

// MARK: - Temporal Context

/// Represents the temporal context when a pattern was observed.
/// Used to detect time-based patterns like "work hours" vs "personal time".
struct TemporalContext: Codable, Equatable, Sendable {
    /// Hour of the day (0-23)
    var hourOfDay: Int
    /// Day of the week (1 = Sunday, 7 = Saturday)
    var dayOfWeek: Int
    /// Whether this was during typical work hours (9am-5pm weekdays)
    var isWorkHours: Bool

    init(from date: Date) {
        let calendar = Calendar.current
        self.hourOfDay = calendar.component(.hour, from: date)
        self.dayOfWeek = calendar.component(.weekday, from: date)

        // Work hours: 9am-5pm on weekdays (Mon-Fri = 2-6)
        let isWeekday = (2...6).contains(dayOfWeek)
        let isBusinessHours = (9...17).contains(hourOfDay)
        self.isWorkHours = isWeekday && isBusinessHours
    }
}
