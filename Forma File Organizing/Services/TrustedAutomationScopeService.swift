import Foundation
import SwiftData

struct TrustedAutomationScopeRecommendationOption: Identifiable, Hashable, Sendable {
    let scopeType: TrustedAutomationScopeType
    let scopeKey: String
    let displayName: String
    let recommendationSource: TrustedAutomationScopeRecommendationSource
    let acceptedEvidenceCount: Int
    let overrideEvidenceCount: Int
    let undoEvidenceCount: Int
    let confidenceSnapshot: Double
    let rationaleSummary: String

    var id: String {
        "\(scopeType.rawValue)|\(scopeKey)"
    }
}

struct TrustedAutomationScopeRecommendation: Identifiable, Sendable {
    let id: UUID
    let recommendedScope: TrustedAutomationScopeRecommendationOption
    let alternativeScopes: [TrustedAutomationScopeRecommendationOption]
    let snapshot: OrganizationMemorySnapshot

    init(
        id: UUID = UUID(),
        recommendedScope: TrustedAutomationScopeRecommendationOption,
        alternativeScopes: [TrustedAutomationScopeRecommendationOption],
        snapshot: OrganizationMemorySnapshot
    ) {
        self.id = id
        self.recommendedScope = recommendedScope
        self.alternativeScopes = alternativeScopes
        self.snapshot = snapshot
    }

    var allScopeChoices: [TrustedAutomationScopeRecommendationOption] {
        var seen = Set<String>()
        return ([recommendedScope] + alternativeScopes).filter { option in
            seen.insert(option.id).inserted
        }
    }

    func option(for scopeType: TrustedAutomationScopeType) -> TrustedAutomationScopeRecommendationOption? {
        allScopeChoices.first(where: { $0.scopeType == scopeType })
    }
}

@MainActor
final class TrustedAutomationScopeService {
    enum ServiceError: LocalizedError {
        case scopeNotFound(UUID)
        case invalidTransition(id: UUID, from: TrustedAutomationScopeStatus, to: TrustedAutomationScopeStatus)
        case recommendationMissingDestination
        case recommendationOptionUnavailable(TrustedAutomationScopeType)

        var errorDescription: String? {
            switch self {
            case .scopeNotFound(let id):
                return "Trusted automation scope \(id.uuidString) was not found."
            case .invalidTransition(let id, let from, let to):
                return "Trusted automation scope \(id.uuidString) cannot transition from \(from.rawValue) to \(to.rawValue)."
            case .recommendationMissingDestination:
                return "A trusted automation recommendation requires a destination."
            case .recommendationOptionUnavailable(let scopeType):
                return "The \(scopeType.displayName.lowercased()) scope is no longer available for promotion."
            }
        }
    }

    private struct ScopeEvidence {
        let acceptedCount: Int
        let overrideCount: Int
        let correctionCount: Int
        let undoCount: Int
        let totalCount: Int

        var confidenceSnapshot: Double {
            let positive = Double(acceptedCount)
            let penalties = Double(overrideCount + correctionCount) * 0.5 + Double(undoCount) * 1.25
            let normalized = (positive - penalties + Double(totalCount)) / max(Double(totalCount) * 2.0, 1.0)
            return min(max(normalized, 0.0), 0.99)
        }

        func rationaleSummary(for scopeType: TrustedAutomationScopeType, displayName: String) -> String {
            let scopeLabel = scopeType.displayName.lowercased()
            return "You’ve approved this \(scopeLabel) pattern \(acceptedCount) time\(acceptedCount == 1 ? "" : "s") with no recent undo in \(displayName)."
        }
    }

    private struct DerivedRuleCandidate {
        let pattern: LearnedPattern
        let scopeKey: String
        let displayName: String
    }

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    func createOrReactivateScope(
        scopeType: TrustedAutomationScopeType,
        scopeKey: String,
        displayName: String,
        promotionSource: TrustedAutomationScopePromotionSource,
        recommendationSource: TrustedAutomationScopeRecommendationSource,
        acceptedEvidenceCount: Int,
        overrideEvidenceCount: Int,
        undoEvidenceCount: Int,
        confidenceSnapshot: Double,
        rationaleSummary: String,
        allowedActions: [TrustedAutomationAllowedAction],
        refreshedAt: Date = Date()
    ) throws -> TrustedAutomationScope {
        if let existing = try scope(scopeType: scopeType, scopeKey: scopeKey) {
            existing.status = .active
            existing.revokedAt = nil
            existing.refresh(
                displayName: displayName,
                promotionSource: promotionSource,
                recommendationSource: recommendationSource,
                acceptedEvidenceCount: acceptedEvidenceCount,
                overrideEvidenceCount: overrideEvidenceCount,
                undoEvidenceCount: undoEvidenceCount,
                confidenceSnapshot: confidenceSnapshot,
                rationaleSummary: rationaleSummary,
                allowedActions: allowedActions,
                refreshedAt: refreshedAt
            )
            try modelContext.save()
            return existing
        }

        let scope = TrustedAutomationScope(
            scopeType: scopeType,
            scopeKey: scopeKey,
            displayName: displayName,
            promotionSource: promotionSource,
            recommendationSource: recommendationSource,
            acceptedEvidenceCount: acceptedEvidenceCount,
            overrideEvidenceCount: overrideEvidenceCount,
            undoEvidenceCount: undoEvidenceCount,
            confidenceSnapshot: confidenceSnapshot,
            rationaleSummary: rationaleSummary,
            allowedActions: allowedActions,
            createdAt: refreshedAt
        )
        modelContext.insert(scope)
        try modelContext.save()
        return scope
    }

    func pauseScope(id: UUID, at timestamp: Date = Date()) throws {
        let scope = try requireScope(id: id)
        guard scope.status == .active else {
            throw ServiceError.invalidTransition(id: id, from: scope.status, to: .paused)
        }
        scope.status = .paused
        scope.updatedAt = timestamp
        try modelContext.save()
    }

    func resumeScope(id: UUID, at timestamp: Date = Date()) throws {
        let scope = try requireScope(id: id)
        guard scope.status == .paused else {
            throw ServiceError.invalidTransition(id: id, from: scope.status, to: .active)
        }
        scope.status = .active
        scope.revokedAt = nil
        scope.updatedAt = timestamp
        try modelContext.save()
    }

    func removeScope(id: UUID, at timestamp: Date = Date()) throws {
        let scope = try requireScope(id: id)
        scope.status = .revoked
        scope.revokedAt = timestamp
        scope.updatedAt = timestamp
        try modelContext.save()
    }

    func recommendedScope(for snapshot: OrganizationMemorySnapshot) throws -> TrustedAutomationScopeRecommendation? {
        guard let destination = snapshot.chosenDestination else {
            return nil
        }

        var candidates: [TrustedAutomationScopeRecommendationOption] = []

        if let explicitRule = try explicitRuleOption(for: snapshot, destination: destination) {
            candidates.append(explicitRule)
        } else if let derivedRule = try derivedRuleOption(for: snapshot, destination: destination) {
            candidates.append(derivedRule)
        }

        if let folder = try folderOption(for: snapshot, destination: destination) {
            candidates.append(folder)
        }

        if let category = try categoryOption(for: snapshot, destination: destination) {
            candidates.append(category)
        }

        let sorted = candidates.sorted { lhs, rhs in
            scopePriority(lhs.scopeType) < scopePriority(rhs.scopeType)
        }

        guard let recommended = sorted.first else {
            return nil
        }

        return TrustedAutomationScopeRecommendation(
            recommendedScope: recommended,
            alternativeScopes: Array(sorted.dropFirst()),
            snapshot: snapshot
        )
    }

    @discardableResult
    func promoteFromReviewDecision(
        recommendation: TrustedAutomationScopeRecommendation,
        selectedScopeType: TrustedAutomationScopeType? = nil,
        promotedAt: Date = Date()
    ) throws -> TrustedAutomationScope {
        let selectedType = selectedScopeType ?? recommendation.recommendedScope.scopeType
        guard let requestedOption = recommendation.option(for: selectedType) else {
            throw ServiceError.recommendationOptionUnavailable(selectedType)
        }

        let resolvedOption = try resolvePromotionOption(requestedOption, snapshot: recommendation.snapshot)
        return try createOrReactivateScope(
            scopeType: resolvedOption.scopeType,
            scopeKey: resolvedOption.scopeKey,
            displayName: resolvedOption.displayName,
            promotionSource: .reviewFlow,
            recommendationSource: resolvedOption.recommendationSource,
            acceptedEvidenceCount: resolvedOption.acceptedEvidenceCount,
            overrideEvidenceCount: resolvedOption.overrideEvidenceCount,
            undoEvidenceCount: resolvedOption.undoEvidenceCount,
            confidenceSnapshot: resolvedOption.confidenceSnapshot,
            rationaleSummary: resolvedOption.rationaleSummary,
            allowedActions: [.move],
            refreshedAt: promotedAt
        )
    }

    func activeScopes() throws -> [TrustedAutomationScope] {
        try allScopes().filter { $0.status == .active }
    }

    func pausedScopes() throws -> [TrustedAutomationScope] {
        try allScopes().filter { $0.status == .paused }
    }

    private func allScopes() throws -> [TrustedAutomationScope] {
        let descriptor = FetchDescriptor<TrustedAutomationScope>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func scope(
        scopeType: TrustedAutomationScopeType,
        scopeKey: String
    ) throws -> TrustedAutomationScope? {
        let lookupKey = TrustedAutomationScope.makeKey(scopeType: scopeType, scopeKey: scopeKey)
        return try allScopes().first { $0.key == lookupKey }
    }

    private func requireScope(id: UUID) throws -> TrustedAutomationScope {
        if let scope = try allScopes().first(where: { $0.id == id }) {
            return scope
        }
        throw ServiceError.scopeNotFound(id)
    }

    private func explicitRuleOption(
        for snapshot: OrganizationMemorySnapshot,
        destination: Destination
    ) throws -> TrustedAutomationScopeRecommendationOption? {
        guard let ruleID = snapshot.matchedRuleID else {
            return nil
        }

        guard let evidence = try evidence(
            matching: { event in
                event.matchedRuleID == ruleID && self.matchesDestination(event, destination: destination)
            }
        ) else {
            return nil
        }

        let rule = try RuleService(modelContext: modelContext).fetchRule(id: ruleID)
        let displayName = rule?.name ?? derivedRuleName(for: snapshot)

        return TrustedAutomationScopeRecommendationOption(
            scopeType: .rule,
            scopeKey: "rule:\(ruleID.uuidString)",
            displayName: displayName,
            recommendationSource: .explicitRule,
            acceptedEvidenceCount: evidence.acceptedCount,
            overrideEvidenceCount: evidence.overrideCount,
            undoEvidenceCount: evidence.undoCount,
            confidenceSnapshot: evidence.confidenceSnapshot,
            rationaleSummary: evidence.rationaleSummary(for: .rule, displayName: displayName)
        )
    }

    private func derivedRuleOption(
        for snapshot: OrganizationMemorySnapshot,
        destination: Destination
    ) throws -> TrustedAutomationScopeRecommendationOption? {
        guard let derivedCandidate = try derivedRuleCandidate(for: snapshot, destination: destination) else {
            return nil
        }

        guard let evidence = try evidence(
            matching: { event in
                event.fileExtension == snapshot.fileExtension.lowercased() &&
                event.sourceLocation == snapshot.sourceLocation &&
                self.normalizedRelativeParentPath(event.relativeParentPath) == nil &&
                self.matchesDestination(event, destination: destination)
            }
        ) else {
            return nil
        }

        return TrustedAutomationScopeRecommendationOption(
            scopeType: .rule,
            scopeKey: derivedCandidate.scopeKey,
            displayName: derivedCandidate.displayName,
            recommendationSource: .personalMemoryPattern,
            acceptedEvidenceCount: evidence.acceptedCount,
            overrideEvidenceCount: evidence.overrideCount,
            undoEvidenceCount: evidence.undoCount,
            confidenceSnapshot: evidence.confidenceSnapshot,
            rationaleSummary: evidence.rationaleSummary(for: .rule, displayName: derivedCandidate.displayName)
        )
    }

    private func folderOption(
        for snapshot: OrganizationMemorySnapshot,
        destination: Destination
    ) throws -> TrustedAutomationScopeRecommendationOption? {
        guard snapshot.scanRootPath != nil || snapshot.sourceLocation != .unknown else {
            return nil
        }

        let scopeKey = folderScopeKey(for: snapshot)
        let displayName = folderDisplayName(for: snapshot)

        guard let evidence = try evidence(
            matching: { event in
                self.matchesFolderContext(event, snapshot: snapshot) &&
                self.matchesDestination(event, destination: destination)
            }
        ) else {
            return nil
        }

        return TrustedAutomationScopeRecommendationOption(
            scopeType: .folder,
            scopeKey: scopeKey,
            displayName: displayName,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: evidence.acceptedCount,
            overrideEvidenceCount: evidence.overrideCount,
            undoEvidenceCount: evidence.undoCount,
            confidenceSnapshot: evidence.confidenceSnapshot,
            rationaleSummary: evidence.rationaleSummary(for: .folder, displayName: displayName)
        )
    }

    private func categoryOption(
        for snapshot: OrganizationMemorySnapshot,
        destination: Destination
    ) throws -> TrustedAutomationScopeRecommendationOption? {
        guard snapshot.fileTypeCategory != .all else {
            return nil
        }

        let displayName = snapshot.fileTypeCategory.displayName
        guard let evidence = try evidence(
            matching: { event in
                event.fileTypeCategory == snapshot.fileTypeCategory &&
                self.matchesDestination(event, destination: destination)
            }
        ) else {
            return nil
        }

        return TrustedAutomationScopeRecommendationOption(
            scopeType: .category,
            scopeKey: snapshot.fileTypeCategory.rawValue,
            displayName: displayName,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: evidence.acceptedCount,
            overrideEvidenceCount: evidence.overrideCount,
            undoEvidenceCount: evidence.undoCount,
            confidenceSnapshot: evidence.confidenceSnapshot,
            rationaleSummary: evidence.rationaleSummary(for: .category, displayName: displayName)
        )
    }

    private func evidence(
        matching predicate: (PersonalMemoryEvent) -> Bool
    ) throws -> ScopeEvidence? {
        let events = try modelContext.fetch(
            FetchDescriptor<PersonalMemoryEvent>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
        ).filter(predicate)

        guard !events.isEmpty else {
            return nil
        }

        let acceptedKinds: Set<PersonalMemoryEventKind> = [.acceptedSuggestion, .acceptedWithOverride, .manualSelection]
        let acceptedCount = events.filter { acceptedKinds.contains($0.eventKind) }.count
        let overrideCount = events.filter { $0.eventKind == .acceptedWithOverride }.count
        let correctionCount = events.filter { $0.eventKind == .manualCorrection }.count
        let undoCount = events.filter { $0.eventKind == .undoRecovery }.count
        let recentUndoCount = events.prefix(5).filter { $0.eventKind == .undoRecovery }.count
        let noisyEventCount = overrideCount + correctionCount
        let noisyRate = Double(noisyEventCount) / Double(max(events.count, 1))

        guard acceptedCount >= 3 else {
            return nil
        }
        guard recentUndoCount == 0 else {
            return nil
        }
        guard noisyRate <= 0.20 else {
            return nil
        }

        return ScopeEvidence(
            acceptedCount: acceptedCount,
            overrideCount: overrideCount,
            correctionCount: correctionCount,
            undoCount: undoCount,
            totalCount: events.count
        )
    }

    private func matchesDestination(_ event: PersonalMemoryEvent, destination: Destination) -> Bool {
        let destinationIdentity = PersonalMemoryEvent.destinationIdentity(for: destination)
        return event.chosenDestinationIdentity == destinationIdentity || event.priorDestinationIdentity == destinationIdentity
    }

    private func matchesFolderContext(_ event: PersonalMemoryEvent, snapshot: OrganizationMemorySnapshot) -> Bool {
        if let snapshotRoot = normalizedPath(snapshot.scanRootPath) {
            return normalizedPath(event.scanRootPath) == snapshotRoot
        }

        return event.scanRootPath == nil && event.sourceLocation == snapshot.sourceLocation
    }

    private func derivedRuleCandidate(
        for snapshot: OrganizationMemorySnapshot,
        destination: Destination
    ) throws -> DerivedRuleCandidate? {
        guard snapshot.matchedRuleID == nil,
              snapshot.sourceLocation != .unknown,
              normalizedRelativeParentPath(snapshot.relativeParentPath) == nil else {
            return nil
        }

        let patterns = try PersonalMemoryService(modelContext: modelContext).suggestedPatterns()
        let destinationDisplayName = destination.displayName

        guard let matchingPattern = patterns.first(where: { pattern in
            pattern.source == .personalMemory &&
            pattern.destinationPath == destinationDisplayName &&
            pattern.fileExtension == snapshot.fileExtension.lowercased() &&
            pattern.conditions.contains(.sourceLocation(snapshot.sourceLocation))
        }) else {
            return nil
        }

        return DerivedRuleCandidate(
            pattern: matchingPattern,
            scopeKey: derivedRuleScopeKey(for: snapshot, destination: destination),
            displayName: derivedRuleName(for: snapshot)
        )
    }

    private func resolvePromotionOption(
        _ option: TrustedAutomationScopeRecommendationOption,
        snapshot: OrganizationMemorySnapshot
    ) throws -> TrustedAutomationScopeRecommendationOption {
        guard snapshot.chosenDestination != nil else {
            throw ServiceError.recommendationMissingDestination
        }

        guard option.scopeType == .rule else {
            return option
        }

        let rule = try resolveRule(for: snapshot)
        return TrustedAutomationScopeRecommendationOption(
            scopeType: .rule,
            scopeKey: "rule:\(rule.id.uuidString)",
            displayName: rule.name,
            recommendationSource: option.recommendationSource,
            acceptedEvidenceCount: option.acceptedEvidenceCount,
            overrideEvidenceCount: option.overrideEvidenceCount,
            undoEvidenceCount: option.undoEvidenceCount,
            confidenceSnapshot: option.confidenceSnapshot,
            rationaleSummary: option.rationaleSummary
        )
    }

    private func resolveRule(for snapshot: OrganizationMemorySnapshot) throws -> Rule {
        let ruleService = RuleService(modelContext: modelContext)

        if let matchedRuleID = snapshot.matchedRuleID,
           let existingRule = try ruleService.fetchRule(id: matchedRuleID) {
            return try ensureRuleEnabled(existingRule, ruleService: ruleService)
        }

        let conditions = derivedRuleConditions(for: snapshot)
        let logicalOperator: Rule.LogicalOperator = conditions.count > 1 ? .and : .single
        if let existingRule = try ruleService.findMatchingMoveRule(
            conditions: conditions,
            logicalOperator: logicalOperator,
            destination: snapshot.chosenDestination
        ) {
            return try ensureRuleEnabled(existingRule, ruleService: ruleService)
        }

        if let destination = snapshot.chosenDestination,
           let derivedCandidate = try derivedRuleCandidate(for: snapshot, destination: destination) {
            let rule = LearningService().convertPatternToRule(derivedCandidate.pattern)
            rule.name = derivedCandidate.displayName
            try ruleService.createRule(rule, source: .learnedPattern)
            return rule
        }

        let newRule = Rule(
            name: derivedRuleName(for: snapshot),
            conditions: conditions,
            logicalOperator: logicalOperator,
            actionType: .move,
            destination: snapshot.chosenDestination
        )
        try ruleService.createRule(newRule, source: .learnedPattern)
        return newRule
    }

    private func ensureRuleEnabled(_ rule: Rule, ruleService: RuleService) throws -> Rule {
        guard !rule.isEnabled else {
            return rule
        }

        rule.isEnabled = true
        try ruleService.updateRule(rule)
        return rule
    }

    private func derivedRuleConditions(for snapshot: OrganizationMemorySnapshot) -> [RuleCondition] {
        var conditions: [RuleCondition] = [.fileExtension(snapshot.fileExtension.lowercased())]
        if snapshot.sourceLocation != .unknown {
            conditions.append(.sourceLocation(snapshot.sourceLocation))
        }
        return conditions
    }

    private func derivedRuleName(for snapshot: OrganizationMemorySnapshot) -> String {
        let extensionLabel = snapshot.fileExtension.uppercased()
        if snapshot.sourceLocation == .unknown {
            return "\(extensionLabel) Auto Rule"
        }
        return "\(extensionLabel) from \(snapshot.sourceLocation.displayName)"
    }

    private func folderScopeKey(for snapshot: OrganizationMemorySnapshot) -> String {
        if let scanRootPath = normalizedPath(snapshot.scanRootPath) {
            return scanRootPath
        }
        return "location:\(snapshot.sourceLocation.rawValue)"
    }

    private func folderDisplayName(for snapshot: OrganizationMemorySnapshot) -> String {
        if let scanRootPath = normalizedPath(snapshot.scanRootPath), !scanRootPath.isEmpty {
            return URL(fileURLWithPath: scanRootPath).lastPathComponent
        }
        return snapshot.sourceLocation.displayName
    }

    private func derivedRuleScopeKey(for snapshot: OrganizationMemorySnapshot, destination: Destination) -> String {
        let destinationIdentity = PersonalMemoryEvent.destinationIdentity(for: destination) ?? "unknown"
        return "derived:\(snapshot.fileExtension.lowercased())|\(snapshot.sourceLocation.rawValue)|\(destinationIdentity)"
    }

    private func normalizedPath(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return URL(fileURLWithPath: value).standardizedFileURL.path
    }

    private func normalizedRelativeParentPath(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\\\", with: "/")
    }

    private func scopePriority(_ scopeType: TrustedAutomationScopeType) -> Int {
        switch scopeType {
        case .rule:
            return 0
        case .folder:
            return 1
        case .category:
            return 2
        }
    }
}
