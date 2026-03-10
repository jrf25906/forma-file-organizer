import Foundation

/// Classifies the operational health of saved rules for Smart Rules UI.
///
/// This keeps duplicate detection and destination accessibility checks out of views,
/// so the rules list can present clear, stable states.
final class RuleHealthService {

    struct RuleHealth {
        enum Kind {
            case duplicateOrOverlap
            case needsPermission
            case willCreate
            case ready
            case disabled
        }

        let kind: Kind
        let badgeLabel: String?
        let message: String?

        var isReadyLike: Bool {
            kind == .ready
        }
    }

    private let overlapDetector = RuleOverlapDetector()
    private let destinationResolver = DestinationResolver()

    func classify(rules: [Rule]) -> [UUID: RuleHealth] {
        Dictionary(uniqueKeysWithValues: rules.map { rule in
            (rule.id, classify(rule: rule, against: rules))
        })
    }

    private func classify(rule: Rule, against rules: [Rule]) -> RuleHealth {
        if !rule.isEnabled {
            return RuleHealth(kind: .disabled, badgeLabel: "Disabled", message: "This rule is turned off.")
        }

        if let category = rule.category, !category.isEnabled {
            return RuleHealth(kind: .disabled, badgeLabel: "Category Off", message: "The '\(category.name)' category is disabled.")
        }

        let overlaps = overlapDetector.detectOverlaps(for: rule, against: rules, excludeRuleID: rule.id)
        if let overlap = overlaps.first {
            let badgeLabel = overlap.overlapType == .exactDuplicate ? "Duplicate" : "Overlap"
            return RuleHealth(
                kind: .duplicateOrOverlap,
                badgeLabel: badgeLabel,
                message: overlap.explanation
            )
        }

        guard rule.actionType != .delete,
              let destination = rule.destination else {
            return RuleHealth(kind: .ready, badgeLabel: nil, message: nil)
        }

        if destination.bookmarkData != nil {
            switch destination.validate() {
            case .valid, .stale:
                return RuleHealth(kind: .ready, badgeLabel: nil, message: nil)
            case .invalid(let reason):
                return RuleHealth(kind: .needsPermission, badgeLabel: "Needs Permission", message: reason)
            }
        }

        switch destinationResolver.checkResolvability(destination) {
        case .valid:
            return RuleHealth(kind: .ready, badgeLabel: nil, message: nil)
        case .resolvable(let parentFolder):
            return RuleHealth(
                kind: .willCreate,
                badgeLabel: "Will Create",
                message: "Forma can create this folder inside \(parentFolder) when you save or run the bulk create action."
            )
        case .unresolvable(let reason):
            return RuleHealth(kind: .needsPermission, badgeLabel: "Needs Permission", message: reason)
        }
    }
}
