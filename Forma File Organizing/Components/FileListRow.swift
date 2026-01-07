import SwiftUI

/// Compact list row with premium styling - consistent with FileRow design language
struct FileListRow: View {
    let file: FileItem
    let rowIndex: Int
    let isFocused: Bool
    let isSelected: Bool
    let isSelectionMode: Bool

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

    // MARK: - Computed Properties

    private var hasDestination: Bool {
        file.destination != nil
    }

    private var destinationName: String {
        file.destination?.displayName ?? ""
    }

    private var categoryGradient: LinearGradient {
        file.category.gradient()
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Category color accent bar (left border)
            RoundedRectangle(cornerRadius: categoryBorderWidth / 2)
                .fill(file.category.color.opacity(Color.FormaOpacity.prominent))
                .frame(width: categoryBorderWidth)
                .padding(.vertical, FormaSpacing.tight)

            HStack(spacing: FormaSpacing.standard) {
                // Selection checkbox with smooth reveal
                if isSelectionMode || isHovered || isSelected {
                    FormaCheckbox.compact(isSelected: isSelected, action: onToggleSelection)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8)),
                            removal: .opacity
                        ))
                }

                // Compact thumbnail with Quick Look
                FormaThumbnail.compact(
                    file: file,
                    categoryColors: (file.category.color, file.category.color),
                    isCardHovered: isHovered,
                    onQuickLook: onQuickLook
                )

            // File info with refined hierarchy
            VStack(alignment: .leading, spacing: 2) {
                // Primary: Filename with search badge
                HStack(spacing: FormaSpacing.tight) {
                    Text(file.name)
                        .font(.formaBodySemibold)
                        .foregroundColor(.formaLabel)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    // Search match type badge
                    if let matchType = searchMatchType {
                        SearchMatchBadge(matchType: matchType)
                    }
                }

                // Tertiary: Metadata
                Text("\(file.fileExtension.uppercased()) • \(file.size)")
                    .font(.formaSmall)
                    .foregroundColor(Color.formaSecondaryLabel.opacity(Color.FormaOpacity.strong))
            }

            Spacer(minLength: FormaSpacing.standard)

            // Action area with progressive disclosure
            HStack(spacing: FormaSpacing.tight) {
                // Secondary actions (revealed on hover)
                if isHovered && !isSelectionMode {
                    HStack(spacing: FormaSpacing.micro) {
                        FormaActionButton.compact(icon: "forward.fill", tooltip: "Skip", action: onSkip)
                        FormaActionButton.compact(icon: "eye.fill", tooltip: "Quick Look", action: onQuickLook)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                // Destination badge or status
                DestinationBadge(
                    hasDestination: hasDestination,
                    destinationName: destinationName,
                    matchingRules: matchingRules,
                    onCreateRule: onCreateRule,
                    onApplyRule: onApplyRule,
                    file: file,
                    isHovered: isHovered
                )

                // Primary action (always visible when has destination)
                if hasDestination && !isSelectionMode {
                    Button(action: onOrganize) {
                        Image(systemName: "checkmark")
                            .font(.formaSmallSemibold)
                            .foregroundColor(.formaBoneWhite)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(Color.formaSage)
                                    .shadow(color: Color.formaSage.opacity(Color.FormaOpacity.overlay), radius: 4, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Organize • ⏎")
                }

                // Overflow menu (revealed on hover for cleaner default state)
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
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.formaCompactMedium)
                            .foregroundColor(Color.formaSecondaryLabel.opacity(Color.FormaOpacity.high))
                            .frame(width: 24, height: 24)
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
            .animation(reduceMotion ? .none : .spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
            }
            .padding(.leading, FormaSpacing.standard)
            .padding(.trailing, FormaSpacing.generous)
        }
        .padding(.leading, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.tight)
        .frame(height: 52)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .overlay(focusIndicator)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: isFocused)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isHovered)
        // PERF: Don't include isSelected in id - it forces full view recreation on selection change
        // SwiftUI handles selection state changes via @State without needing identity change
        .id(file.path)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection()
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            LinearGradient(
                colors: [
                    Color.formaSteelBlue.opacity(Color.FormaOpacity.light),
                    Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isHovered {
            Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
        } else {
            // Subtle alternating row colors
            rowIndex % 2 == 0
                ? Color.formaControlBackground.opacity(Color.FormaOpacity.strong)
                : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle)
        }
    }

    // MARK: - Focus Indicator

    @ViewBuilder
    private var focusIndicator: some View {
        if isFocused {
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSteelBlue, lineWidth: 2)
        }
    }
}


// MARK: - Destination Badge

private struct DestinationBadge: View {
    let hasDestination: Bool
    let destinationName: String
    let matchingRules: [Rule]
    let onCreateRule: (() -> Void)?
    let onApplyRule: ((Rule) -> Void)?
    let file: FileItem
    let isHovered: Bool

    var body: some View {
        if let onCreateRule = onCreateRule, let onApplyRule = onApplyRule {
            RuleButtonWithMenu(
                file: file,
                matchingRules: matchingRules,
                onCreateRule: onCreateRule,
                onApplyRule: onApplyRule
            )
        } else if hasDestination {
            HStack(spacing: FormaSpacing.tight) {
                // Destination name
                HStack(spacing: FormaSpacing.micro) {
                    Image(systemName: "arrow.right")
                        .font(.formaCaptionBold)
                    Text(destinationName)
                        .font(.formaSmallMedium)
                        .lineLimit(1)
                }
                .foregroundColor(Color.formaSteelBlue)
                .padding(.horizontal, FormaSpacing.tight)
                .padding(.vertical, FormaSpacing.micro)
                .background(
                    Capsule()
                        .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                )

                // Compact confidence indicator
                if let confidence = file.confidenceScore {
                    CompactConfidenceDot(score: confidence)
                }
            }
        } else {
            // Only show "Uncategorized" on hover - reduces visual noise
            Text("Uncategorized")
                .font(.formaSmallMedium)
                .foregroundColor(Color.formaSecondaryLabel)
                .padding(.horizontal, FormaSpacing.tight)
                .padding(.vertical, FormaSpacing.micro)
                .background(
                    Capsule()
                        .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
                )
                .opacity(isHovered ? 1 : 0)
        }
    }
}

// MARK: - Compact Confidence Dot

/// Ultra-compact confidence indicator for list view - shows color-coded dot with tooltip
private struct CompactConfidenceDot: View {
    let score: Double

    private var config: (color: Color, label: String) {
        if score >= 0.9 {
            return (.formaSage, "High Confidence (\(Int(score * 100))%)")
        } else if score >= 0.6 {
            return (.formaSteelBlue, "Medium Confidence (\(Int(score * 100))%)")
        } else {
            return (.formaWarmOrange, "Low Confidence (\(Int(score * 100))%)")
        }
    }

    var body: some View {
        Circle()
            .fill(config.color)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .strokeBorder(config.color.opacity(Color.FormaOpacity.overlay), lineWidth: 1)
            )
            .help(config.label)
    }
}
