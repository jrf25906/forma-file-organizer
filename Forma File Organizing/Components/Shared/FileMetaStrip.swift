import SwiftUI

enum FileMetaStripDensity: Equatable {
    case compact
    case regular

    var textFont: Font {
        switch self {
        case .compact: return .formaCaption
        case .regular: return .formaSmall
        }
    }

    var statusSize: FormaBadge.BadgeSize {
        switch self {
        case .compact: return .small
        case .regular: return .regular
        }
    }

    var itemSpacing: CGFloat {
        switch self {
        case .compact: return 6
        case .regular: return 8
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .compact: return 8
        case .regular: return 9
        }
    }

    var confidenceSize: CGFloat {
        switch self {
        case .compact: return 5
        case .regular: return 6
        }
    }

    var verticalSpacing: CGFloat {
        switch self {
        case .compact: return 3
        case .regular: return 4
        }
    }
}

enum FileMetaDestinationPlacement: Equatable {
    case inline
    case block
}

struct FileMetaStrip: View {
    let file: FileItem
    var density: FileMetaStripDensity = .regular
    var destinationPlacement: FileMetaDestinationPlacement = .block
    var showsDestinationPromptWhenMissing: Bool = true
    var onSetDestination: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var statusPresentation: FileStatusPresentation {
        FileStatusPresentation.resolve(for: file)
    }

    private var provenancePresentation: FileProvenancePresentation? {
        guard shouldShowProvenance else { return nil }
        return FileProvenancePresentation.resolve(for: file)
    }

    private var shouldShowProvenance: Bool {
        if let matchReason = file.matchReason, !matchReason.isEmpty {
            return true
        }
        if file.confidenceScore != nil || file.matchedRuleID != nil {
            return true
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: density.verticalSpacing) {
            HStack(alignment: .center, spacing: density.itemSpacing) {
                metaItem(icon: "doc", text: file.fileExtension.uppercased())
                metaItem(icon: "clock", text: compactAgeText)

                FormaBadge(
                    text: statusPresentation.label,
                    color: statusPresentation.color,
                    size: density.statusSize,
                    style: .subtle
                )
                .help(statusPresentation.accessibilityLabel)

                if let provenancePresentation {
                    provenanceBadge(provenancePresentation)
                }

                if let relativePath = file.relativePathContextLabel {
                    relativePathBadge(relativePath)
                        .help("Current folder: \(relativePath)")
                }

                if destinationPlacement == .inline {
                    destinationView(inline: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if destinationPlacement == .block {
                destinationView(inline: false)
            }
        }
    }

    private var compactAgeText: String {
        let days = Calendar.current.dateComponents([.day], from: file.creationDate, to: Date()).day ?? 0
        if days > 1 { return "\(days)d" }
        if days == 1 { return "1d" }
        return "today"
    }

    private var destinationFont: Font {
        switch (density, destinationPlacement) {
        case (.compact, .inline):
            return .formaCaptionSemibold
        case (.compact, .block):
            return .formaSmallMedium
        case (.regular, .inline):
            return .formaSmallMedium
        case (.regular, .block):
            return .formaSmallSemibold
        }
    }

    private var destinationForegroundColor: Color {
        switch destinationPlacement {
        case .inline:
            return .formaSecondaryLabelHigh
        case .block:
            return Color.formaLabel.opacity(Color.FormaOpacity.strong)
        }
    }

    private var destinationContainerPadding: CGFloat {
        density == .compact ? 5 : 6
    }

    @ViewBuilder
    private func destinationView(inline: Bool) -> some View {
        if let destination = file.destination {
            let destinationContent = HStack(spacing: 4) {
                if inline {
                    Spacer(minLength: density.itemSpacing)
                }

                Image(systemName: destination.isTrash ? "trash" : "folder")
                    .font(.system(size: density.iconSize, weight: inline ? .medium : .semibold))
                Text(truncatePath(destination.displayName))
                    .font(destinationFont)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if inline {
                destinationContent
                    .foregroundStyle(destination.isTrash ? Color.formaWarning : destinationForegroundColor)
                    .help("Destination: \(destination.displayName)")
            } else {
                destinationContent
                    .foregroundStyle(destination.isTrash ? Color.formaWarning : destinationForegroundColor)
                    .padding(.horizontal, destinationContainerPadding + 1)
                    .padding(.vertical, density == .compact ? 3 : 4)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                            .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                            .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.medium), lineWidth: 0.5)
                    )
                    .help("Destination: \(destination.displayName)")
            }
        } else if showsDestinationPromptWhenMissing, let onSetDestination {
            Button(action: onSetDestination) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: density.iconSize, weight: .semibold))
                    Text("Set destination")
                        .font(density.textFont)
                }
                .foregroundStyle(Color.formaSteelBlue)
                .padding(.horizontal, density == .compact ? 6 : 8)
                .padding(.vertical, density == .compact ? 2 : 3)
                .background(
                    Capsule()
                        .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                )
            }
            .buttonStyle(.plain)
            .help("Choose a destination folder")
        }
    }

    private func metaItem(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: density.iconSize, weight: .medium))
            Text(text)
                .font(density.textFont)
        }
        .foregroundStyle(colorScheme == .dark ? Color.formaTertiaryLabelHigh : Color.formaTertiaryLabel)
    }

    private func relativePathBadge(_ value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "folder")
                .font(.system(size: density.iconSize, weight: .semibold))
            Text(value)
                .font(density.textFont)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(Color.formaSecondaryLabelHigh)
        .padding(.horizontal, density == .compact ? 5 : 6)
        .padding(.vertical, density == .compact ? 1 : 2)
        .background(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
        .clipShape(Capsule())
    }

    private func provenanceBadge(_ presentation: FileProvenancePresentation) -> some View {
        HStack(spacing: 3) {
            Image(systemName: presentation.icon)
                .font(.system(size: density.iconSize, weight: .semibold))
            Text(presentation.label)
                .font(density.textFont)
                .lineLimit(1)
        }
        .foregroundStyle(Color.formaSecondaryLabelHigh)
        .padding(.horizontal, density == .compact ? 5 : 6)
        .padding(.vertical, density == .compact ? 1 : 2)
        .background(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
        .clipShape(Capsule())
        .help(presentation.helpText)
    }

    private func truncatePath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count <= 2 { return path }
        guard let last = components.last else { return path }
        let previous = components.dropLast().last.map(String.init)
        if let previous {
            return "\u{2026}/\(previous)/\(last)"
        }
        return "\u{2026}/\(last)"
    }
}

struct FileStatusPresentation {
    let label: String
    let accessibilityLabel: String
    let color: Color

    static func resolve(for file: FileItem) -> FileStatusPresentation {
        switch file.status {
        case .pending:
            if file.destination == nil {
                return FileStatusPresentation(
                    label: "Needs destination",
                    accessibilityLabel: "Needs destination",
                    color: .formaWarning
                )
            }
            return FileStatusPresentation(
                label: "Review",
                accessibilityLabel: "Needs review before organizing",
                color: .formaSteelBlue
            )
        case .ready:
            return FileStatusPresentation(
                label: "Ready",
                accessibilityLabel: "Ready to organize",
                color: .formaSteelBlue
            )
        case .completed:
            return FileStatusPresentation(
                label: "Organized",
                accessibilityLabel: "Already organized",
                color: .formaSage
            )
        case .skipped:
            return FileStatusPresentation(
                label: "Skipped",
                accessibilityLabel: "Skipped",
                color: .formaSecondaryLabelHigh
            )
        }
    }
}

struct FileProvenancePresentation {
    let label: String
    let icon: String
    let helpText: String

    static func resolve(for file: FileItem) -> FileProvenancePresentation {
        let helpText = file.matchReason?.isEmpty == false
            ? file.matchReason!
            : "Suggestion source: \(label(for: file.suggestionSource))"

        return FileProvenancePresentation(
            label: label(for: file.suggestionSource),
            icon: icon(for: file.suggestionSource),
            helpText: helpText
        )
    }

    private static func label(for source: SuggestionSource) -> String {
        switch source {
        case .rule:
            return "Rule"
        case .personalMemory:
            return "Memory"
        case .pattern:
            return "Learned"
        case .mlPrediction:
            return "Predicted"
        }
    }

    private static func icon(for source: SuggestionSource) -> String {
        switch source {
        case .rule:
            return "arrow.triangle.branch"
        case .personalMemory:
            return "brain.head.profile"
        case .pattern:
            return "sparkles"
        case .mlPrediction:
            return "wand.and.stars"
        }
    }
}
