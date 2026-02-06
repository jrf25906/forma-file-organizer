import SwiftUI

/// Readability-first list row aligned with FileRow card hierarchy.
struct FileListRow: View {
    let file: FileItem
    var density: FileDisplayDensity = .balanced
    let rowIndex: Int
    let isFocused: Bool
    let isSelected: Bool
    let isSelectionMode: Bool
    let showsPrimaryActionButton: Bool

    // Search match type for content search badge
    var searchMatchType: ContentSearchService.MatchType? = nil

    // Callbacks
    let onToggleSelection: () -> Void
    let onOrganize: () -> Void
    let onEdit: () -> Void
    let onSkip: () -> Void
    let onQuickLook: () -> Void

    // Rule integration
    var matchingRules: [Rule] = []
    var onCreateRule: (() -> Void)? = nil
    var onApplyRule: ((Rule) -> Void)? = nil

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Constants
    private let categoryBorderWidth: CGFloat = 3

    private var thumbnailSize: CGFloat {
        switch density {
        case .tight: return 38
        case .balanced: return 44
        case .spacious: return 50
        }
    }

    private var rowMinHeight: CGFloat {
        switch density {
        case .tight: return 66
        case .balanced: return 74
        case .spacious: return 88
        }
    }

    private var rowVerticalPadding: CGFloat {
        switch density {
        case .tight: return FormaSpacing.tight - 2
        case .balanced: return FormaSpacing.tight + 1
        case .spacious: return FormaSpacing.standard - 2
        }
    }

    private var contentSpacing: CGFloat {
        switch density {
        case .tight: return FormaSpacing.tight + (FormaSpacing.micro / 2)
        case .balanced: return FormaSpacing.standard
        case .spacious: return FormaSpacing.standard + (FormaSpacing.micro / 2)
        }
    }

    private var infoSpacing: CGFloat {
        switch density {
        case .tight: return FormaSpacing.micro + 1
        case .balanced: return FormaSpacing.micro + 2
        case .spacious: return FormaSpacing.tight
        }
    }

    private var chipHorizontalPadding: CGFloat {
        density == .tight ? (FormaSpacing.tight - 2) : FormaSpacing.tight
    }

    private var chipVerticalPadding: CGFloat {
        density == .spacious ? (FormaSpacing.micro + 1) : FormaSpacing.micro
    }

    private var selectionControlEmphasisOpacity: Double {
        (isSelectionMode || isHovered || isSelected) ? 1.0 : 0.72
    }

    // MARK: - Computed Properties

    private var hasDestination: Bool {
        file.destination != nil
    }

    private var hasRuleActions: Bool {
        onCreateRule != nil && onApplyRule != nil
    }

    private var compactAgeText: String {
        let days = Calendar.current.dateComponents([.day], from: file.creationDate, to: Date()).day ?? 0
        if days > 1 { return "\(days)d" }
        if days == 1 { return "1d" }
        return "today"
    }

    private var ageSummaryText: String {
        compactAgeText == "today" ? "today" : "\(compactAgeText) old"
    }

    private var statusChipConfig: (label: String, icon: String, color: Color) {
        switch file.status {
        case .pending:
            if file.destination == nil {
                return ("Needs Destination", "questionmark.circle.fill", .formaWarning)
            }
            return ("Needs Review", "exclamationmark.circle.fill", .formaWarning)
        case .ready:
            return ("Ready", "checkmark.circle.fill", .formaSage)
        case .completed:
            return ("Organized", "checkmark.seal.fill", .formaSage)
        case .skipped:
            return ("Skipped", "forward.fill", .formaSecondaryLabelHigh)
        }
    }

    private var summaryLineText: String {
        var segments = [file.fileExtension.uppercased(), file.category.displayName, ageSummaryText]

        if let reason = file.matchReason, !reason.isEmpty {
            segments.append("Rule: \(reason)")
        } else if let destination = file.destination {
            let destinationLabel = destination.isTrash ? "Trash" : truncatePath(destination.displayName)
            segments.append("Destination: \(destinationLabel)")
        } else {
            segments.append("No destination set")
        }

        return segments.joined(separator: " • ")
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Single accent rail for category/priority.
            RoundedRectangle(cornerRadius: categoryBorderWidth / 2)
                .fill(file.category.color.opacity(Color.FormaOpacity.prominent))
                .frame(width: categoryBorderWidth)
                .padding(.vertical, rowVerticalPadding)
                .help("Category: \(file.category.displayName)")

            HStack(alignment: .top, spacing: contentSpacing) {
                FormaCheckbox.premium(
                    isSelected: isSelected,
                    isVisible: true,
                    action: onToggleSelection
                )
                    .opacity(selectionControlEmphasisOpacity)
                    .frame(width: 32, height: 32, alignment: .top)
                    .contentShape(Rectangle())
                    .help(isSelected ? "Deselect file" : "Select file")

                FormaThumbnail(
                    file: file,
                    mode: .compact,
                    size: thumbnailSize,
                    categoryColors: (file.category.color, file.category.color),
                    isCardHovered: isHovered,
                    onQuickLook: onQuickLook
                )

                VStack(alignment: .leading, spacing: infoSpacing) {
                    HStack(spacing: FormaSpacing.tight - 2) {
                        Text(file.name)
                            .font(.formaBodySemibold)
                            .foregroundStyle(Color.formaLabel)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        statusChip

                        if let matchType = searchMatchType {
                            SearchMatchBadge(matchType: matchType)
                        }

                        if let confidence = file.confidenceScore {
                            ConfidenceDot(score: confidence, matchReason: file.matchReason, size: 10)
                        }
                    }

                    Text(summaryLineText)
                        .font(.formaSmall)
                        .foregroundStyle(Color.formaSecondaryLabelHigh)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: FormaSpacing.standard)

                HStack(spacing: FormaSpacing.tight - 2) {
                    if hasRuleActions && (isHovered || !matchingRules.isEmpty),
                       let onCreateRule,
                       let onApplyRule {
                        RuleButtonWithMenu(
                            file: file,
                            matchingRules: matchingRules,
                            onCreateRule: onCreateRule,
                            onApplyRule: onApplyRule
                        )
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }

                    if isHovered && !isSelectionMode {
                        HStack(spacing: FormaSpacing.micro) {
                            FormaActionButton.compact(icon: "forward.fill", tooltip: "Skip", action: onSkip)
                            FormaActionButton.compact(icon: "eye.fill", tooltip: "Quick Look", action: onQuickLook)
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }

                    if hasDestination && !isSelectionMode && showsPrimaryActionButton {
                        Button(action: onOrganize) {
                            Image(systemName: "checkmark")
                                .font(.formaSmallSemibold)
                                .foregroundStyle(Color.formaBoneWhite)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(Color.formaSage)
                                        .shadow(
                                            color: Color.formaSage.opacity(Color.FormaOpacity.overlay),
                                            radius: 4,
                                            x: 0,
                                            y: 2
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Organize • ⏎")
                    }

                    if isHovered || isSelectionMode {
                        Menu {
                            Button(action: onOrganize) {
                                Label("Organize", systemImage: "checkmark.circle")
                            }
                            .disabled(!hasDestination || isSelected)

                            Button(action: onEdit) {
                                Label("Edit Destination", systemImage: "pencil")
                            }
                            .disabled(isSelected)

                            Button(action: onSkip) {
                                Label("Skip", systemImage: "forward")
                            }
                            .disabled(isSelected)

                            Divider()

                            Button(action: onQuickLook) {
                                Label("Quick Look", systemImage: "eye")
                            }

                            if let onCreateRule {
                                Divider()
                                Button(action: onCreateRule) {
                                    Label("Create Rule", systemImage: "plus.circle")
                                }
                            }

                            if let onApplyRule, !matchingRules.isEmpty {
                                Divider()
                                ForEach(Array(matchingRules.prefix(3)), id: \.id) { rule in
                                    Button(action: { onApplyRule(rule) }) {
                                        Label(rule.name, systemImage: rule.iconName)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.formaCompactMedium)
                                .foregroundStyle(Color.formaSecondaryLabelHigh)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
                                )
                        }
                        .menuStyle(.borderlessButton)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .help("More Actions")
                    }
                }
                .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: isHovered)
            }
            .padding(.leading, FormaSpacing.standard)
            .padding(.trailing, FormaSpacing.standard)
            .padding(.vertical, rowVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, FormaSpacing.tight)
        .frame(minHeight: rowMinHeight)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .overlay(rowBorder)
        .shadow(color: rowShadowColor, radius: rowShadowRadius, x: 0, y: rowShadowY)
        .scaleEffect(rowScale)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isHovered)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isFocused)
        // PERF: Keep stable identity to avoid unnecessary full row recreation.
        .id(file.path)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .if(isSelectionMode) { row in
            row.onTapGesture {
                onToggleSelection()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fileRow_\(file.name)")
    }

    // MARK: - Component Helpers

    private var statusChip: some View {
        HStack(spacing: FormaSpacing.micro) {
            Image(systemName: statusChipConfig.icon)
                .font(.formaCaptionSemibold)
            Text(statusChipConfig.label)
                .font(.formaCaptionSemibold)
        }
        .foregroundStyle(statusChipConfig.color.opacity(Color.FormaOpacity.high))
        .padding(.horizontal, chipHorizontalPadding)
        .padding(.vertical, chipVerticalPadding)
        .background(
            Capsule(style: .continuous)
                .fill(statusChipConfig.color.opacity(Color.FormaOpacity.light))
        )
    }

    private func truncatePath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count <= 2 { return path }
        guard let last = components.last else { return path }
        return "…/\(last)"
    }

    // MARK: - Surface Styling

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            LinearGradient(
                colors: [
                    Color.formaSteelBlue.opacity(Color.FormaOpacity.medium),
                    Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isHovered || isFocused {
            LinearGradient(
                colors: [
                    Color.formaCardBackground.opacity(Color.FormaOpacity.prominent),
                    Color.formaCardBackground.opacity(Color.FormaOpacity.high + Color.FormaOpacity.light)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color.formaCardBackground.opacity(Color.FormaOpacity.high + Color.FormaOpacity.light),
                    Color.formaCardBackground.opacity(Color.FormaOpacity.high)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
            .strokeBorder(
                isFocused ? Color.formaSteelBlue.opacity(Color.FormaOpacity.prominent) :
                isSelected ? Color.formaSteelBlue.opacity(Color.FormaOpacity.strong) :
                Color.formaBoneWhite.opacity(isHovered ? Color.FormaOpacity.medium : Color.FormaOpacity.light),
                lineWidth: isFocused ? 1.5 : 1
            )
    }

    private var rowShadowColor: Color {
        if isFocused {
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.medium)
        } else if isSelected {
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
        } else if isHovered {
            return Color.formaObsidian.opacity(Color.FormaOpacity.medium)
        } else {
            return Color.formaObsidian.opacity(Color.FormaOpacity.light)
        }
    }

    private var rowShadowRadius: CGFloat {
        if isFocused || isSelected { return 8 }
        if isHovered { return 6 }
        return 3
    }

    private var rowShadowY: CGFloat {
        if isFocused || isSelected { return 3 }
        if isHovered { return 2 }
        return 1
    }

    private var rowScale: CGFloat {
        if isHovered && !isSelected && !isFocused {
            return 1.002
        }
        return 1.0
    }
}
