import Foundation

/// Classifies the operational health of saved rules for Smart Rules UI.
///
/// This keeps duplicate detection and destination accessibility checks out of views,
/// so the rules list can present clear, stable states.
final class RuleHealthService {

    struct RuleHealth {
        enum Kind {
            case duplicate
            case overlap
            case needsPermission
            case willCreate
            case stale
            case ready
            case disabled
        }

        let kind: Kind
        let badgeLabel: String?
        let message: String?

        var isReadyLike: Bool {
            kind == .ready || kind == .stale
        }
    }

    struct ExactDuplicateCleanupPlan: Identifiable {
        struct Group {
            let keeperRuleID: UUID
            let duplicateRuleIDs: [UUID]
        }

        let id = UUID()
        let groups: [Group]

        var duplicateRuleIDs: [UUID] {
            groups.flatMap(\.duplicateRuleIDs)
        }

        var duplicateCount: Int {
            duplicateRuleIDs.count
        }

        var preservedRuleCount: Int {
            groups.count
        }
    }

    private let overlapDetector = RuleOverlapDetector()
    private let destinationResolver = DestinationResolver()
    private let jsonEncoder = JSONEncoder()

    func classify(
        rules: [Rule],
        staleRuleThresholdDays: Int? = nil,
        evaluationDate: Date = Date()
    ) -> [UUID: RuleHealth] {
        Dictionary(uniqueKeysWithValues: rules.map { rule in
            (
                rule.id,
                classify(
                    rule: rule,
                    against: rules,
                    staleRuleThresholdDays: staleRuleThresholdDays,
                    evaluationDate: evaluationDate
                )
            )
        })
    }

    func exactDuplicateCleanupPlan(duplicateRules: [Rule]) -> ExactDuplicateCleanupPlan? {
        let groupedRules = Dictionary(grouping: duplicateRules) { duplicateSignature(for: $0) }

        let groups = groupedRules.values.compactMap { groupedRuleSet -> ExactDuplicateCleanupPlan.Group? in
            let sortedRules = groupedRuleSet.sorted(by: duplicateCleanupOrder)
            guard sortedRules.count > 1 else { return nil }

            return ExactDuplicateCleanupPlan.Group(
                keeperRuleID: sortedRules[0].id,
                duplicateRuleIDs: Array(sortedRules.dropFirst()).map(\.id)
            )
        }
        .sorted { lhs, rhs in
            lhs.duplicateRuleIDs.count > rhs.duplicateRuleIDs.count
        }

        guard !groups.isEmpty else { return nil }
        return ExactDuplicateCleanupPlan(groups: groups)
    }

    private func classify(
        rule: Rule,
        against rules: [Rule],
        staleRuleThresholdDays: Int?,
        evaluationDate: Date
    ) -> RuleHealth {
        if !rule.isEnabled {
            return RuleHealth(kind: .disabled, badgeLabel: "Disabled", message: "This rule is turned off.")
        }

        if let category = rule.category, !category.isEnabled {
            return RuleHealth(kind: .disabled, badgeLabel: "Category Off", message: "The '\(category.name)' category is disabled.")
        }

        let overlaps = overlapDetector.detectOverlaps(for: rule, against: rules, excludeRuleID: rule.id)
        if let overlap = overlaps.first {
            switch overlap.overlapType {
            case .exactDuplicate:
                return RuleHealth(
                    kind: .duplicate,
                    badgeLabel: "Duplicate",
                    message: overlap.explanation
                )
            case .conflictingDestination:
                return RuleHealth(
                    kind: .overlap,
                    badgeLabel: "Conflict",
                    message: overlap.explanation
                )
            case .subset, .superset, .partialOverlap:
                return RuleHealth(
                    kind: .overlap,
                    badgeLabel: "Overlap",
                    message: overlap.explanation
                )
            }
        }

        guard rule.actionType != .delete,
              let destination = rule.destination else {
            return staleAdjustedHealth(
                for: rule,
                baseHealth: RuleHealth(kind: .ready, badgeLabel: nil, message: nil),
                staleRuleThresholdDays: staleRuleThresholdDays,
                evaluationDate: evaluationDate
            )
        }

        if destination.bookmarkData != nil {
            switch destination.validate() {
            case .valid, .stale:
                return staleAdjustedHealth(
                    for: rule,
                    baseHealth: RuleHealth(kind: .ready, badgeLabel: nil, message: nil),
                    staleRuleThresholdDays: staleRuleThresholdDays,
                    evaluationDate: evaluationDate
                )
            case .invalid(let reason):
                return RuleHealth(kind: .needsPermission, badgeLabel: "Needs Permission", message: reason)
            }
        }

        switch destinationResolver.checkResolvability(destination) {
        case .valid:
            return staleAdjustedHealth(
                for: rule,
                baseHealth: RuleHealth(kind: .ready, badgeLabel: nil, message: nil),
                staleRuleThresholdDays: staleRuleThresholdDays,
                evaluationDate: evaluationDate
            )
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

    private func staleAdjustedHealth(
        for rule: Rule,
        baseHealth: RuleHealth,
        staleRuleThresholdDays: Int?,
        evaluationDate: Date
    ) -> RuleHealth {
        guard baseHealth.kind == .ready,
              let staleRuleThresholdDays,
              staleRuleThresholdDays > 0,
              let staleDays = staleDays(for: rule, evaluationDate: evaluationDate),
              staleDays >= staleRuleThresholdDays else {
            return baseHealth
        }

        let message: String
        if rule.lastTriggeredDate != nil {
            message = "This rule hasn't matched any files in \(staleDays) days."
        } else {
            message = "This rule hasn't matched any files since it was created \(staleDays) days ago."
        }

        return RuleHealth(kind: .stale, badgeLabel: "Stale", message: message)
    }

    private func staleDays(for rule: Rule, evaluationDate: Date) -> Int? {
        let referenceDate = rule.lastTriggeredDate ?? rule.creationDate
        let interval = evaluationDate.timeIntervalSince(referenceDate)
        guard interval >= 0 else { return nil }
        return Int(interval / 86_400)
    }

    private struct DuplicateSignature: Hashable {
        let logicalOperator: String
        let primaryConditions: [String]
        let exclusionConditions: [String]
        let actionType: String
        let destination: String
        let scope: String
    }

    private func duplicateSignature(for rule: Rule) -> DuplicateSignature {
        DuplicateSignature(
            logicalOperator: rule.logicalOperator.rawValue,
            primaryConditions: rule.conditions.map(canonicalConditionString(for:)).sorted(),
            exclusionConditions: rule.exclusionConditions.map(canonicalConditionString(for:)).sorted(),
            actionType: rule.actionType.rawValue,
            destination: canonicalDestinationString(for: rule.destination),
            scope: canonicalScopeString(for: rule.category?.scope ?? .global)
        )
    }

    private func duplicateCleanupOrder(lhs: Rule, rhs: Rule) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        if lhs.creationDate != rhs.creationDate {
            return lhs.creationDate < rhs.creationDate
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func canonicalConditionString(for condition: RuleCondition) -> String {
        if let data = try? jsonEncoder.encode(condition) {
            return data.base64EncodedString()
        }
        return String(describing: condition)
    }

    private func canonicalDestinationString(for destination: Destination?) -> String {
        switch destination {
        case .trash?:
            return "trash"
        case .folder(_, let displayName)?:
            return "folder:\(displayName)"
        case nil:
            return "none"
        }
    }

    private func canonicalScopeString(for scope: CategoryScope) -> String {
        switch scope {
        case .global:
            return "global"
        case .folders(let scopedFolders):
            let semanticFolders = scopedFolders.map { scopedFolder in
                scopedFolder.resolve()?.standardizedFileURL.path ?? scopedFolder.displayName
            }
            .sorted()
            return "folders:\(semanticFolders.joined(separator: "|"))"
        }
    }
}

final class FolderHealthAlertService {
    private let storageService: StorageService
    private let ruleHealthService: RuleHealthService

    init(
        storageService: StorageService = .shared,
        ruleHealthService: RuleHealthService = RuleHealthService()
    ) {
        self.storageService = storageService
        self.ruleHealthService = ruleHealthService
    }

    func evaluate(
        files: [FileItem],
        rules: [Rule],
        settings: FolderHealthAlertSettings,
        monitoredRootPathsByFolder: [BookmarkFolder.FolderType: String] = BookmarkFolder.alertEligibleRootPaths(),
        now: Date = Date()
    ) -> FolderHealthEvaluation {
        let folderBreakdown = storageService.calculateFolderBreakdown(
            from: files,
            monitoredRootPathsByFolder: monitoredRootPathsByFolder
        )
        let accessibleFolderTypes = Set(monitoredRootPathsByFolder.keys)

        let folderSizeAlerts = BookmarkFolder.FolderType.allCases.compactMap { folderType -> FolderSizeAlert? in
            guard accessibleFolderTypes.contains(folderType),
                  let thresholdBytes = settings.folderSizeThresholdBytesByFolder[folderType],
                  thresholdBytes > 0 else {
                return nil
            }

            let currentBytes = folderBreakdown[folderType] ?? 0
            guard currentBytes >= thresholdBytes else { return nil }

            return FolderSizeAlert(
                folderType: folderType,
                currentBytes: currentBytes,
                thresholdBytes: thresholdBytes
            )
        }

        let staleRuleAlert = makeStaleRuleAlert(
            rules: rules,
            settings: settings,
            now: now
        )

        return FolderHealthEvaluation(
            folderSizeAlerts: folderSizeAlerts,
            staleRuleAlert: staleRuleAlert
        )
    }

    private func makeStaleRuleAlert(
        rules: [Rule],
        settings: FolderHealthAlertSettings,
        now: Date
    ) -> StaleRuleAlert? {
        guard let staleRuleThresholdDays = settings.staleRuleThresholdDays,
              staleRuleThresholdDays > 0 else {
            return nil
        }

        let healthByID = ruleHealthService.classify(
            rules: rules,
            staleRuleThresholdDays: staleRuleThresholdDays,
            evaluationDate: now
        )

        let summaries = rules.compactMap { rule -> StaleRuleAlert.RuleSummary? in
            guard healthByID[rule.id]?.kind == .stale else { return nil }

            let referenceDate = rule.lastTriggeredDate ?? rule.creationDate
            let staleDays = max(staleRuleThresholdDays, Int(max(0, now.timeIntervalSince(referenceDate)) / 86_400))

            return StaleRuleAlert.RuleSummary(
                id: rule.id,
                ruleName: rule.name,
                referenceDate: referenceDate,
                staleDays: staleDays,
                hasMatchedBefore: rule.lastTriggeredDate != nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.staleDays != rhs.staleDays {
                return lhs.staleDays > rhs.staleDays
            }
            return lhs.ruleName.localizedCaseInsensitiveCompare(rhs.ruleName) == .orderedAscending
        }

        guard !summaries.isEmpty else { return nil }
        return StaleRuleAlert(thresholdDays: staleRuleThresholdDays, rules: summaries)
    }
}
