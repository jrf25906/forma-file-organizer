import Foundation

enum DefaultPanelEditorialSuggestionSource: Equatable {
    case promotion
    case insight
    case pattern
}

enum DefaultPanelEditorialSuggestionAccent: Equatable {
    case steelBlue
    case warm
    case sage
}

struct DefaultPanelEditorialSuggestionSnapshot: Identifiable, Equatable {
    let id: String
    let source: DefaultPanelEditorialSuggestionSource
    let title: String
    let summary: String
    let actionTitle: String
    let provenanceText: String
    let whyNowText: String?
    let metricText: String?
    let iconName: String
    let accent: DefaultPanelEditorialSuggestionAccent
}

enum DefaultPanelEditorialSuggestionFactory {
    static func build(
        promotion: ExternalReviewPromotionSuggestion?,
        insights: [FileInsight],
        patterns: [LearnedPattern]
    ) -> [DefaultPanelEditorialSuggestionSnapshot] {
        var snapshots: [DefaultPanelEditorialSuggestionSnapshot] = []

        if let promotion {
            snapshots.append(promotionSnapshot(for: promotion))
        }

        let normalizedPatternTitles = Set(patterns.map { normalizedTitle($0.patternDescription) })
        let filteredInsights = insights
            .sorted(by: compareInsights(_:_:))
            .filter { !normalizedPatternTitles.contains(normalizedTitle($0.message)) }

        snapshots.append(contentsOf: filteredInsights.map(insightSnapshot(for:)))
        snapshots.append(contentsOf: patterns.sorted(by: comparePatterns(_:_:)).map(patternSnapshot(for:)))

        return snapshots
    }

    static func promotionSnapshot(for suggestion: ExternalReviewPromotionSuggestion) -> DefaultPanelEditorialSuggestionSnapshot {
        let folderName = suggestion.folderType.displayName

        return DefaultPanelEditorialSuggestionSnapshot(
            id: "promotion-\(normalizedTitle(folderName))",
            source: .promotion,
            title: suggestion.titleText,
            summary: suggestion.detailText,
            actionTitle: suggestion.primaryActionTitle,
            provenanceText: "Monitor folder",
            whyNowText: "Why it matters: new files from \(folderName) keep landing in review until this becomes a watched folder.",
            metricText: folderName,
            iconName: suggestion.iconName,
            accent: .steelBlue
        )
    }

    static func insightSnapshot(for insight: FileInsight) -> DefaultPanelEditorialSuggestionSnapshot {
        DefaultPanelEditorialSuggestionSnapshot(
            id: insight.id,
            source: .insight,
            title: insight.message,
            summary: insightSummary(for: insight),
            actionTitle: insight.actionLabel ?? "Review",
            provenanceText: insightProvenanceText(for: insight),
            whyNowText: insightWhyNowText(for: insight),
            metricText: insightMetricText(for: insight),
            iconName: insight.iconName,
            accent: insightAccent(for: insight)
        )
    }

    static func patternSnapshot(for pattern: LearnedPattern) -> DefaultPanelEditorialSuggestionSnapshot {
        let destinationText = abbreviatedDestination(pattern.destinationPath)
        let confidence = pattern.confidenceLevel.lowercased()
        let sourceText = pattern.source == .personalMemory ? "Memory pattern" : "Pattern"

        return DefaultPanelEditorialSuggestionSnapshot(
            id: pattern.id.uuidString,
            source: .pattern,
            title: pattern.patternDescription,
            summary: "A repeated move pattern points to \(destinationText). Turn it into a reusable rule while the intent is still clear.",
            actionTitle: "Create Rule",
            provenanceText: sourceText,
            whyNowText: "Why it matters: this decision has repeated \(pattern.occurrenceCount) time\(pattern.occurrenceCount == 1 ? "" : "s") with \(confidence) confidence.",
            metricText: "\(pattern.occurrenceCount)x",
            iconName: "wand.and.stars",
            accent: .steelBlue
        )
    }

    static func normalizedTitle(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func uiTestFeaturedSnapshot() -> DefaultPanelEditorialSuggestionSnapshot {
        DefaultPanelEditorialSuggestionSnapshot(
            id: "ui-test-featured-next-move",
            source: .insight,
            title: "2 large files are still the fastest storage win",
            summary: "These are the clearest cleanup targets in the current queue. Reviewing them now frees space without changing any automation setup.",
            actionTitle: "Review Files",
            provenanceText: "Large files",
            whyNowText: "Why it matters: immediate space recovery.",
            metricText: "362 MB",
            iconName: "externaldrive.fill",
            accent: .steelBlue
        )
    }

    private static func compareInsights(_ lhs: FileInsight, _ rhs: FileInsight) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }

        if lhs.affectedCount != rhs.affectedCount {
            return (lhs.affectedCount ?? 0) > (rhs.affectedCount ?? 0)
        }

        return normalizedTitle(lhs.message) < normalizedTitle(rhs.message)
    }

    private static func comparePatterns(_ lhs: LearnedPattern, _ rhs: LearnedPattern) -> Bool {
        if lhs.confidenceScore != rhs.confidenceScore {
            return lhs.confidenceScore > rhs.confidenceScore
        }

        if lhs.occurrenceCount != rhs.occurrenceCount {
            return lhs.occurrenceCount > rhs.occurrenceCount
        }

        return normalizedTitle(lhs.patternDescription) < normalizedTitle(rhs.patternDescription)
    }

    private static func insightSummary(for insight: FileInsight) -> String {
        if let detail = insight.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
            return detail
        }

        switch insight.iconName {
        case "externaldrive.fill":
            return "The fastest storage win in view. Clearing this now frees real space without changing any automation setup."
        case "arrow.down.circle":
            return "Downloads have concentrated into one backlog, which makes this a quick cleanup pass before it spreads further."
        case "camera.viewfinder":
            return "Screenshots keep collecting in one place, so this is a clean candidate for lightweight automation."
        case "doc.on.doc":
            return "Duplicate-looking files are piling up, and reviewing them now keeps clutter from compounding."
        default:
            break
        }

        if insight.actionLabel == "Organize Together" {
            return "These files likely belong together, so one decision can clean up the whole group while context is still intact."
        }

        if insight.actionLabel == "Create Rule" {
            return "A repeated pattern is clear enough to turn one manual decision into a reusable rule."
        }

        return "This is one of the clearest next steps in the current queue."
    }

    private static func insightWhyNowText(for insight: FileInsight) -> String? {
        switch insight.iconName {
        case "externaldrive.fill":
            return "Why it matters: immediate space recovery."
        case "arrow.down.circle":
            return "Why it matters: Downloads clutter compounds quickly."
        case "camera.viewfinder":
            return "Why it matters: screenshots are easy to automate once the pattern is obvious."
        case "doc.on.doc":
            return "Why it matters: duplicate cleanup removes low-signal noise fast."
        default:
            break
        }

        if insight.actionLabel == "Organize Together" {
            return "Why it matters: grouping now can resolve the whole cluster in one move."
        }

        if insight.actionLabel == "Create Rule" {
            return "Why it matters: one rule can replace repeated cleanup."
        }

        return nil
    }

    private static func insightMetricText(for insight: FileInsight) -> String? {
        if insight.iconName == "externaldrive.fill",
           let range = insight.message.range(of: "taking up ") {
            return String(insight.message[range.upperBound...])
        }

        if let affectedCount = insight.affectedCount {
            return "\(affectedCount) file\(affectedCount == 1 ? "" : "s")"
        }

        return nil
    }

    private static func insightProvenanceText(for insight: FileInsight) -> String {
        switch insight.iconName {
        case "externaldrive.fill":
            return "Large files"
        case "arrow.down.circle":
            return "Downloads"
        case "camera.viewfinder":
            return "Screenshots"
        case "doc.on.doc":
            return "Duplicates"
        default:
            break
        }

        if insight.actionLabel == "Organize Together" {
            return "Recent cluster"
        }

        if insight.actionLabel == "Create Rule" {
            return "Pattern"
        }

        return "Suggestion"
    }

    private static func insightAccent(for insight: FileInsight) -> DefaultPanelEditorialSuggestionAccent {
        if insight.actionLabel == "Choose Destination" {
            return .warm
        }

        if insight.actionLabel == "Organize Together" {
            return .sage
        }

        return .steelBlue
    }

    private static func abbreviatedDestination(_ path: String) -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homeDir) {
            return "~" + path.dropFirst(homeDir.count)
        }

        guard path.count > 40 else { return path }

        let components = path.split(separator: "/")
        guard components.count > 2 else { return path }
        return "…/" + components.suffix(2).joined(separator: "/")
    }
}
