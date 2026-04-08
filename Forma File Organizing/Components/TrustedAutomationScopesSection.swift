import SwiftUI

struct TrustedAutomationScopesSection: View {
    enum Style: Hashable {
        case compact
        case management
    }

    struct Snapshot: Hashable {
        struct SectionSnapshot: Identifiable, Hashable {
            let id: String
            let title: String
            let rows: [RowSnapshot]
        }

        struct RowSnapshot: Identifiable, Hashable {
            let id: UUID
            let title: String
            let scopeTypeText: String
            let boundarySummary: String
            let destinationSummary: String
            let statusText: String
            let healthBadgeText: String
            let healthMessage: String
            let lastRunText: String
            let recentActivityText: String
            let accessibilityIdentifier: String
        }

        let title: String
        let style: Style
        let sections: [SectionSnapshot]

        var rows: [RowSnapshot] {
            sections.flatMap(\.rows)
        }

        init?(
            title: String,
            sections: [TrustedAutomationScopeSummarySection],
            style: Style,
            now: Date = Date(),
            relativeDateProvider: (Date, Date) -> String = Self.defaultRelativeDateText
        ) {
            let displaySections: [TrustedAutomationScopeSummarySection]
            switch style {
            case .compact:
                let compactSummaries = sections
                    .filter { $0.status != .revoked }
                    .flatMap(\.summaries)
                    .sorted(by: Self.isPreferredCompactSummary)
                    .prefix(3)

                guard !compactSummaries.isEmpty else {
                    return nil
                }

                displaySections = [
                    TrustedAutomationScopeSummarySection(
                        status: .active,
                        title: sections.first(where: { $0.status != .revoked && !$0.summaries.isEmpty })?.title ?? "Active",
                        summaries: Array(compactSummaries)
                    )
                ]
            case .management:
                displaySections = sections.filter { !$0.summaries.isEmpty }
                guard !displaySections.isEmpty else {
                    return nil
                }
            }

            self.title = title
            self.style = style
            self.sections = displaySections.map { section in
                SectionSnapshot(
                    id: "\(section.status.rawValue)-\(section.title)",
                    title: section.title,
                    rows: section.summaries.map {
                        Self.makeRowSnapshot(
                            summary: $0,
                            now: now,
                            relativeDateProvider: relativeDateProvider
                        )
                    }
                )
            }
        }

        private static func makeRowSnapshot(
            summary: TrustedAutomationScopeSummary,
            now: Date,
            relativeDateProvider: (Date, Date) -> String
        ) -> RowSnapshot {
            let parsedBoundary = parseBoundarySummary(summary.boundarySummary)
            let referenceDate = summary.lastRun?.endedAt
                ?? summary.lastRun?.startedAt
                ?? summary.lifecycle.lastRunAt
                ?? summary.lifecycle.revokedAt
                ?? summary.lifecycle.pausedAt
                ?? summary.lifecycle.updatedAt

            let recentActivityText = summary.lastRun?.summaryText
                ?? summary.health.messages.first
                ?? fallbackActivityText(for: summary)

            return RowSnapshot(
                id: summary.id,
                title: summary.displayName,
                scopeTypeText: summary.scopeType.displayName,
                boundarySummary: parsedBoundary.source,
                destinationSummary: parsedBoundary.destination,
                statusText: summary.lifecycle.status.rawValue.capitalized,
                healthBadgeText: healthBadgeText(for: summary.health.state),
                healthMessage: summary.health.messages.first ?? fallbackHealthMessage(for: summary.health.state),
                lastRunText: makeLastRunText(
                    summary: summary,
                    referenceDate: referenceDate,
                    now: now,
                    relativeDateProvider: relativeDateProvider
                ),
                recentActivityText: recentActivityText,
                accessibilityIdentifier: "trustedAutomationScopeRow_\(summary.id.uuidString)"
            )
        }

        private static func parseBoundarySummary(_ value: String) -> (source: String, destination: String) {
            let parts = value
                .components(separatedBy: "->")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if parts.count >= 2 {
                return (parts[0], parts[1])
            }

            return (value, "Automatic destination")
        }

        private static func healthBadgeText(for state: TrustedAutomationScopeHealthState) -> String {
            switch state {
            case .healthy:
                return "Healthy"
            case .quiet:
                return "Quiet"
            case .needsAttention:
                return "Needs Attention"
            }
        }

        private static func fallbackHealthMessage(for state: TrustedAutomationScopeHealthState) -> String {
            switch state {
            case .healthy:
                return "Ready for automatic organization."
            case .quiet:
                return "No recent automation activity."
            case .needsAttention:
                return "This trusted scope needs review."
            }
        }

        private static func fallbackActivityText(for summary: TrustedAutomationScopeSummary) -> String {
            switch summary.lifecycle.status {
            case .active:
                return "Trusted automation is ready."
            case .paused:
                return "Automatic moves are paused for this scope."
            case .revoked:
                return "This scope no longer runs automatically."
            }
        }

        private static func makeLastRunText(
            summary: TrustedAutomationScopeSummary,
            referenceDate: Date,
            now: Date,
            relativeDateProvider: (Date, Date) -> String
        ) -> String {
            let relative = relativeDateProvider(referenceDate, now)

            if summary.lastRun != nil || summary.lifecycle.lastRunAt != nil {
                return "Last run \(relative)"
            }

            switch summary.lifecycle.status {
            case .active:
                return "Updated \(relative)"
            case .paused:
                return "Paused \(relative)"
            case .revoked:
                return "Revoked \(relative)"
            }
        }

        private static func isPreferredCompactSummary(
            _ lhs: TrustedAutomationScopeSummary,
            _ rhs: TrustedAutomationScopeSummary
        ) -> Bool {
            let lhsRank = compactPriority(for: lhs)
            let rhsRank = compactPriority(for: rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            let lhsDate = lhs.lastRun?.endedAt
                ?? lhs.lastRun?.startedAt
                ?? lhs.lifecycle.lastRunAt
                ?? lhs.lifecycle.updatedAt
            let rhsDate = rhs.lastRun?.endedAt
                ?? rhs.lastRun?.startedAt
                ?? rhs.lifecycle.lastRunAt
                ?? rhs.lifecycle.updatedAt
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }

            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }

        private static func compactPriority(for summary: TrustedAutomationScopeSummary) -> Int {
            switch summary.health.state {
            case .needsAttention:
                return 0
            case .healthy:
                return 1
            case .quiet:
                return 2
            }
        }

        private static func defaultRelativeDateText(_ date: Date, _ now: Date) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: now)
        }
    }

    let snapshot: Snapshot
    let onSelect: (UUID) -> Void

    init(snapshot: Snapshot, onSelect: @escaping (UUID) -> Void) {
        self.snapshot = snapshot
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.title)
                    .font(.formaBodySemibold)
                    .foregroundStyle(Color.formaLabel)

                Spacer()

                Text("\(snapshot.rows.count)")
                    .font(.formaCaptionBold)
                    .foregroundStyle(Color.formaSecondaryLabelHigh)
                    .padding(.horizontal, FormaSpacing.tight)
                    .padding(.vertical, FormaSpacing.micro)
                    .background(
                        Capsule()
                            .fill(Color.formaControlBackground.opacity(Color.FormaOpacity.overlay))
                    )
            }

            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                ForEach(snapshot.sections) { section in
                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                        if snapshot.style == .management {
                            Text(section.title)
                                .font(.formaCaptionBold)
                                .tracking(0.4)
                                .foregroundStyle(Color.formaSecondaryLabelHigh)
                        }

                        VStack(spacing: FormaSpacing.tight) {
                            ForEach(section.rows) { row in
                                Button {
                                    onSelect(row.id)
                                } label: {
                                    rowView(row)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(row.accessibilityIdentifier)
                            }
                        }
                    }
                }
            }
        }
    }

    private func rowView(_ row: Snapshot.RowSnapshot) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            HStack(alignment: .firstTextBaseline, spacing: FormaSpacing.tight) {
                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    Text(row.title)
                        .font(.formaBodySemibold)
                        .foregroundStyle(Color.formaLabel)

                    Text(row.scopeTypeText)
                        .font(.formaCaption)
                        .foregroundStyle(Color.formaSecondaryLabelHigh)
                }

                Spacer()

                badge(row.statusText, tint: badgeTint(for: row.statusText))
                badge(row.healthBadgeText, tint: badgeTint(for: row.healthBadgeText))

                Image(systemName: "chevron.right")
                    .font(.formaCaptionBold)
                    .foregroundStyle(Color.formaTertiaryLabel)
            }

            HStack(spacing: FormaSpacing.standard) {
                metadataStack(title: "Boundary", value: row.boundarySummary)
                metadataStack(title: "Destination", value: row.destinationSummary)
            }

            Text(row.healthMessage)
                .font(.formaSmall)
                .foregroundStyle(Color.formaSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(row.lastRunText) • \(row.recentActivityText)")
                .font(.formaCaption)
                .foregroundStyle(Color.formaSecondaryLabelHigh)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FormaSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }

    private func metadataStack(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            Text(title)
                .font(.formaCaptionBold)
                .foregroundStyle(Color.formaSecondaryLabelHigh)
            Text(value)
                .font(.formaSmall)
                .foregroundStyle(Color.formaLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.formaCaptionBold)
            .foregroundStyle(tint)
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro)
            .background(
                Capsule()
                    .fill(tint.opacity(Color.FormaOpacity.light))
            )
    }

    private func badgeTint(for text: String) -> Color {
        switch text {
        case "Active", "Healthy":
            return Color.formaSage
        case "Paused", "Quiet":
            return Color.formaWarmOrange
        case "Needs Attention":
            return Color.formaWarmOrange
        case "Revoked":
            return Color.formaSecondaryLabelHigh
        default:
            return Color.formaSteelBlue
        }
    }
}
