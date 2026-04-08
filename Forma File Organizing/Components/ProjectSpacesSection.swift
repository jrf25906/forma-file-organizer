import Foundation
import SwiftUI

struct ProjectSpacesSection: View {
    struct Snapshot: Hashable {
        struct RowSnapshot: Identifiable, Hashable {
            let summary: ProjectSpaceSummary
            let title: String
            let fileCountText: String
            let recencyText: String
            let sourceFolderSummary: String?
            let accessibilityIdentifier: String

            var id: String { summary.id }
        }

        let title: String
        let subtitle: String
        let accessibilityIdentifier: String
        let rows: [RowSnapshot]

        init?(
            summaries: [ProjectSpaceSummary],
            now: Date = Date(),
            recencyTextProvider: ((Date, Date) -> String)? = nil
        ) {
            let orderedSummaries = summaries.sorted(by: Self.summarySortOrder(_:_:))
            guard !orderedSummaries.isEmpty else { return nil }

            let relativeText = recencyTextProvider ?? Self.defaultRecencyText(activityAt:relativeTo:)

            self.title = "Project Spaces"
            self.subtitle = "Open a space to review destinations and correct labels."
            self.accessibilityIdentifier = "projectSpacesSection"
            self.rows = orderedSummaries.map { summary in
                RowSnapshot(
                    summary: summary,
                    title: summary.displayName,
                    fileCountText: Self.fileCountText(for: summary.fileCount),
                    recencyText: relativeText(summary.lastActivityAt, now),
                    sourceFolderSummary: Self.sourceFolderSummary(for: summary.sourceFolderHints),
                    accessibilityIdentifier: Self.rowAccessibilityIdentifier(for: summary)
                )
            }
        }

        private static func summarySortOrder(_ lhs: ProjectSpaceSummary, _ rhs: ProjectSpaceSummary) -> Bool {
            if lhs.lastActivityAt != rhs.lastActivityAt {
                return lhs.lastActivityAt > rhs.lastActivityAt
            }

            if lhs.fileCount != rhs.fileCount {
                return lhs.fileCount > rhs.fileCount
            }

            let normalizedLabelComparison = lhs.normalizedLabel.localizedCaseInsensitiveCompare(rhs.normalizedLabel)
            if normalizedLabelComparison != .orderedSame {
                return normalizedLabelComparison == .orderedAscending
            }

            if lhs.projectLabel != rhs.projectLabel {
                return lhs.projectLabel < rhs.projectLabel
            }

            return false
        }

        private static func fileCountText(for count: Int) -> String {
            count == 1 ? "1 file" : "\(count) files"
        }

        private static func defaultRecencyText(activityAt: Date, relativeTo now: Date) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: activityAt, relativeTo: now)
        }

        private static func sourceFolderSummary(for hints: [String]) -> String? {
            guard !hints.isEmpty else { return nil }
            let visibleHints = Array(hints.prefix(2))
            let remainingCount = hints.count - visibleHints.count
            let base = visibleHints.joined(separator: ", ")

            guard remainingCount > 0 else {
                return base
            }

            return "\(base) +\(remainingCount)"
        }

        private static func rowAccessibilityIdentifier(for summary: ProjectSpaceSummary) -> String {
            "projectSpacesRow_\(sanitizedIdentifierComponent(summary.normalizedLabel))"
        }

        private static func sanitizedIdentifierComponent(_ text: String) -> String {
            let pieces = text.unicodeScalars.map { scalar -> String in
                CharacterSet.alphanumerics.contains(scalar) ? String(Character(scalar)) : "_"
            }

            return pieces.joined()
        }
    }

    let snapshot: Snapshot?
    let onSelect: (ProjectSpaceSummary) -> Void

    init(
        summaries: [ProjectSpaceSummary],
        now: Date = Date(),
        onSelect: @escaping (ProjectSpaceSummary) -> Void
    ) {
        self.snapshot = Snapshot(summaries: summaries, now: now)
        self.onSelect = onSelect
    }

    init(
        snapshot: Snapshot?,
        onSelect: @escaping (ProjectSpaceSummary) -> Void
    ) {
        self.snapshot = snapshot
        self.onSelect = onSelect
    }

    var body: some View {
        Group {
            if let snapshot {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    header(snapshot: snapshot)

                    VStack(spacing: FormaSpacing.tight) {
                        ForEach(snapshot.rows) { row in
                            rowButton(row)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(snapshot.accessibilityIdentifier)
            }
        }
    }

    private func header(snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            HStack(alignment: .center, spacing: FormaSpacing.tight) {
                Image(systemName: "square.grid.2x2")
                    .font(.formaBodySemibold)
                    .foregroundStyle(Color.formaSteelBlue)

                Text(snapshot.title)
                    .font(.formaBodySemibold)
                    .foregroundStyle(Color.formaLabel)

                Spacer(minLength: 0)
            }

            Text(snapshot.subtitle)
                .font(.formaCaption)
                .foregroundStyle(Color.formaSecondaryLabel)
        }
    }

    private func rowButton(_ row: Snapshot.RowSnapshot) -> some View {
        Button {
            onSelect(row.summary)
        } label: {
            HStack(alignment: .top, spacing: FormaSpacing.standard) {
                iconPlate

                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    HStack(alignment: .firstTextBaseline, spacing: FormaSpacing.tight) {
                        Text(row.title)
                            .font(.formaBodySemibold)
                            .foregroundStyle(Color.formaLabel)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Text(row.fileCountText)
                            .font(.formaCaptionSemibold)
                            .foregroundStyle(Color.formaSteelBlue)
                            .padding(.horizontal, FormaSpacing.tight)
                            .padding(.vertical, FormaSpacing.micro / 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                            )
                    }

                    Text(row.recencyText)
                        .font(.formaCaption)
                        .foregroundStyle(Color.formaSecondaryLabel)

                    if let sourceFolderSummary = row.sourceFolderSummary {
                        Label(sourceFolderSummary, systemImage: "folder")
                            .font(.formaCaption)
                            .foregroundStyle(Color.formaSecondaryLabel)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FormaSpacing.standard)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(Color.formaControlBackground.opacity(Color.FormaOpacity.light))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(row.accessibilityIdentifier)
    }

    private var iconPlate: some View {
        RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
            .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
            .frame(width: 34, height: 34)
            .overlay(
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.formaSteelBlue)
            )
    }
}
