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

    /// Category accent rail width: 2pt for all densities.
    private let categoryRailWidth: CGFloat = 2

    private var thumbnailSize: CGFloat {
        switch density {
        case .tight: return 20
        case .balanced: return 24
        case .spacious: return 28
        }
    }

    private var rowMinHeight: CGFloat {
        switch density {
        case .tight: return 36
        case .balanced: return 44
        case .spacious: return 48
        }
    }

    private var rowVerticalPadding: CGFloat {
        switch density {
        case .tight: return 4
        case .balanced: return 6
        case .spacious: return 8
        }
    }

    private var contentSpacing: CGFloat {
        switch density {
        case .tight: return 6
        case .balanced: return 8
        case .spacious: return 10
        }
    }

    private var selectionControlEmphasisOpacity: Double {
        (isSelectionMode || isHovered || isSelected) ? 1.0 : 0.72
    }

    private var rowStateAccessibilityValue: String {
        "view=list;selected=\(isSelected ? 1 : 0);focused=\(isFocused ? 1 : 0);status=\(file.status.rawValue)"
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

    /// Status label + color for inline dot-and-label indicator.
    private var statusLabelConfig: (label: String, color: Color) {
        switch file.status {
        case .pending:
            if file.destination == nil {
                return ("Needs Dest", .formaWarning)
            }
            return ("Review", .formaWarning)
        case .ready:
            return ("Ready", .formaSage)
        case .completed:
            return ("Organized", .formaSage)
        case .skipped:
            return ("Skipped", .formaSecondaryLabelHigh)
        }
    }

    /// Right-aligned metadata string: "PDF · 32d · Review"
    private var metadataText: String {
        let segments: [String] = [
            file.fileExtension.uppercased(),
            compactAgeText,
            statusLabelConfig.label
        ]
        return segments.joined(separator: " \u{00B7} ")
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Category accent rail (2pt).
            RoundedRectangle(cornerRadius: categoryRailWidth / 2)
                .fill(file.category.color.opacity(Color.FormaOpacity.prominent))
                .frame(width: categoryRailWidth)
                .padding(.vertical, rowVerticalPadding)
                .help("Category: \(file.category.displayName)")

            // Main single-line content.
            HStack(spacing: contentSpacing) {
                FormaCheckbox.premium(
                    isSelected: isSelected,
                    isVisible: true,
                    action: onToggleSelection
                )
                .opacity(selectionControlEmphasisOpacity)
                .frame(width: 24, height: 24, alignment: .center)
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

                // Text area: (1) filename, (2) metadata, (3) destination
                VStack(alignment: .leading, spacing: 2) {
                    // Line 1 — Filename [search badge]
                    HStack(spacing: FormaSpacing.tight - 2) {
                        Text(file.name)
                            .font(.formaBodySemibold)
                            .foregroundStyle(Color.formaLabel)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if let matchType = searchMatchType {
                            SearchMatchBadge(matchType: matchType)
                        }
                    }

                    // Line 2 — Static metadata + Active status + destination
                    HStack(spacing: FormaSpacing.tight - 2) {
                        // Static: type + age with icons
                        HStack(spacing: 3) {
                            Image(systemName: "doc")
                                .font(.system(size: 9))
                            Text(file.fileExtension.uppercased())
                                .font(.formaCaption)
                        }
                        .foregroundStyle(Color.formaTertiaryLabelHigh)

                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(compactAgeText)
                                .font(.formaCaption)
                        }
                        .foregroundStyle(Color.formaTertiaryLabelHigh)

                        // Active: status dot
                        Circle()
                            .fill(statusLabelConfig.color)
                            .frame(width: 5, height: 5)
                            .help(statusLabelConfig.label)

                        if let confidence = file.confidenceScore {
                            ConfidenceDot(score: confidence, matchReason: file.matchReason, size: 5)
                        }

                        if let destination = file.destination {
                            Text("→ \(truncatePath(destination.displayName))")
                                .font(.formaCaption)
                                .foregroundStyle(Color.formaSteelBlue)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help("Destination: \(destination.displayName)")
                        } else {
                            Button(action: onEdit) {
                                HStack(spacing: 3) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 9, weight: .semibold))
                                    Text("Set destination")
                                        .font(.formaCaption)
                                }
                                .foregroundStyle(Color.formaSteelBlue)
                                .padding(.horizontal, FormaSpacing.tight - 2)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Set file destination")
                        }
                    }
                }

                Spacer(minLength: FormaSpacing.tight)

                // Action buttons area
                HStack(spacing: FormaSpacing.micro) {
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

                    if !isSelectionMode && showsPrimaryActionButton {
                        if hasDestination {
                            Button(action: onOrganize) {
                                Image(systemName: "checkmark")
                                    .font(.formaSmallSemibold)
                                    .foregroundStyle(Color.formaBoneWhite)
                                    .frame(width: 26, height: 26)
                                    .background(
                                        Circle()
                                            .fill(Color.formaSage)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Organize \u{2022} \u{23CE}")
                        } else {
                            Button(action: onEdit) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.formaSmallSemibold)
                                    .foregroundStyle(Color.formaSteelBlue)
                                    .frame(width: 26, height: 26)
                                    .background(
                                        Circle()
                                            .fill(Color.formaSteelBlue.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Set Destination")
                        }
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
                                .frame(width: 26, height: 26)
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
                .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isHovered)
            }
            .padding(.leading, FormaSpacing.tight)
            .padding(.trailing, FormaSpacing.tight)
            .padding(.vertical, rowVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, FormaSpacing.tight)
        .frame(minHeight: rowMinHeight)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous))
        .overlay(rowBorder)
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
        .accessibilityValue(rowStateAccessibilityValue)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityIdentifier("fileListRowState_\(file.name)")
                .accessibilityLabel("File list row state \(rowStateAccessibilityValue)")
                .accessibilityValue(rowStateAccessibilityValue)
        }
    }

    // MARK: - Component Helpers

    private func truncatePath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count <= 2 { return path }
        guard let last = components.last else { return path }
        return "\u{2026}/\(last)"
    }

    // MARK: - Surface Styling

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected || isFocused {
            Color.formaSteelBlue.opacity(0.12)
        } else if isHovered {
            Color.formaCardBackground
        } else if rowIndex % 2 == 1 {
            Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var rowBorder: some View {
        if isFocused {
            RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                .strokeBorder(
                    Color.formaSteelBlue.opacity(0.80),
                    lineWidth: 1.5
                )
        } else if isSelected {
            RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                .strokeBorder(
                    Color.formaSteelBlue.opacity(0.50),
                    lineWidth: 1
                )
        } else if isHovered {
            RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                .strokeBorder(
                    Color.formaSeparator.opacity(0.5),
                    lineWidth: 0.5
                )
        } else {
            EmptyView()
        }
    }
}
