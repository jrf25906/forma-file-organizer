import Foundation

extension Array where Element == RuleCategory {
    /// Deterministic sort order for categories across the UI.
    var sortedByOrder: [RuleCategory] {
        sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            if lhs.creationDate != rhs.creationDate {
                return lhs.creationDate < rhs.creationDate
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
