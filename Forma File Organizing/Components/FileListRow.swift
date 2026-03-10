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
    var availableDestinations: [Destination] = []
    var onChangeDestination: ((Destination) -> Void)? = nil

    // Rule integration
    var matchingRules: [Rule] = []
    var onCreateRule: (() -> Void)? = nil
    var onApplyRule: ((Rule) -> Void)? = nil

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Constants

    private var thumbnailSize: CGFloat {
        switch density {
        case .tight: return 20
        case .balanced: return 24
        case .spacious: return 28
        }
    }

    private var rowMinHeight: CGFloat {
        switch density {
        case .tight: return 40
        case .balanced: return 48
        case .spacious: return 54
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

    private var primaryActionKind: FilePrimaryActionKind {
        FilePrimaryActionKind.resolve(for: file)
    }

    private var shouldRevealAccessoryActions: Bool {
        isHovered || isFocused || isSelected || isSelectionMode
    }

    private var shouldShowPrimaryAction: Bool {
        guard !isSelectionMode, showsPrimaryActionButton else { return false }
        if primaryActionKind == .setDestination {
            return true
        }
        return shouldRevealAccessoryActions
    }

    private var rowStateAccessibilityValue: String {
        "view=list;selected=\(isSelected ? 1 : 0);focused=\(isFocused ? 1 : 0);status=\(file.status.rawValue)"
    }

    // MARK: - Computed Properties

    private var hasDestination: Bool {
        file.destination != nil
    }

    // MARK: - Body

    var body: some View {
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

            FileIdentityBlock(
                file: file,
                layout: .list,
                searchMatchType: searchMatchType
            )

            Spacer(minLength: FormaSpacing.tight)

            FileAccessoryActions(
                file: file,
                layout: .compact,
                primaryActionKind: primaryActionKind,
                showsPrimaryAction: shouldShowPrimaryAction,
                showsOverflowMenu: shouldRevealAccessoryActions,
                matchingRules: matchingRules,
                availableDestinations: availableDestinations,
                onPrimaryAction: primaryActionHandler,
                onEditDestination: onEdit,
                onSkip: onSkip,
                onQuickLook: onQuickLook,
                onCreateRule: onCreateRule,
                onApplyRule: onApplyRule,
                onChangeDestination: onChangeDestination,
                disablesPrimaryAction: primaryActionKind == .organize ? (!hasDestination || isSelected) : isSelected,
                disablesEdit: isSelected,
                disablesSkip: isSelected
            )
            .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isHovered)
        }
        .padding(.leading, FormaSpacing.tight)
        .padding(.trailing, FormaSpacing.tight)
        .padding(.vertical, rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, FormaSpacing.tight)
        .frame(minHeight: rowMinHeight)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous))
        .overlay(rowSheen)
        .overlay(rowBorder)
        .shadow(color: rowAmbientShadowColor, radius: rowAmbientShadowRadius, x: 0, y: rowAmbientShadowY)
        .shadow(color: rowContactShadowColor, radius: rowContactShadowRadius, x: 0, y: rowContactShadowY)
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

    // MARK: - Surface Styling

    private var rowSheen: some View {
        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(isFocused || isSelected ? 0.24 : 0.14),
                        Color.formaBoneWhite.opacity(isHovered ? 0.08 : 0.04),
                        Color.formaBoneWhite.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var rowBackground: some View {
        ZStack {
            Color.formaListRowBackground

            if isHovered && !isSelected && !isFocused {
                Color.formaListRowHoverOverlay
            }

            if isSelected || isFocused {
                Color.formaListRowSelectionOverlay
            }
        }
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
            .strokeBorder(rowBorderColor, lineWidth: rowBorderWidth)
            .overlay(
                RoundedRectangle(cornerRadius: FormaNestedRadius.inset(FormaRadius.small, by: 1), style: .continuous)
                    .stroke(rowInnerBorderColor, lineWidth: 0.7)
            )
    }

    private var rowBorderColor: Color {
        if isFocused {
            return .formaListRowFocusedBorder
        }
        if isSelected {
            return .formaListRowSelectedBorder
        }
        if isHovered {
            return .formaListRowHoverBorder
        }
        return .formaListRowBorder
    }

    private var rowBorderWidth: CGFloat {
        if isFocused {
            return 1.5
        }
        if isSelected {
            return 1.0
        }
        return colorScheme == .dark ? 0.75 : 0.6
    }

    private var rowInnerBorderColor: Color {
        if isFocused || isSelected {
            return Color.formaBoneWhite.opacity(0.30)
        }
        if isHovered {
            return Color.formaBoneWhite.opacity(0.18)
        }
        return Color.formaBoneWhite.opacity(0.10)
    }

    private var rowAmbientShadowColor: Color {
        if isFocused {
            return Color.formaSteelBlue.opacity(0.10)
        }
        if isSelected {
            return Color.formaObsidian.opacity(0.05)
        }
        if isHovered {
            return Color.formaObsidian.opacity(0.06)
        }
        return .clear
    }

    private var rowAmbientShadowRadius: CGFloat {
        if isFocused { return 8 }
        if isSelected { return 5 }
        if isHovered { return 4 }
        return 0
    }

    private var rowAmbientShadowY: CGFloat {
        if isFocused { return 3 }
        if isSelected || isHovered { return 2 }
        return 0
    }

    private var rowContactShadowColor: Color {
        if isFocused || isHovered {
            return Color.formaObsidian.opacity(0.08)
        }
        return .clear
    }

    private var rowContactShadowRadius: CGFloat {
        if isFocused || isHovered { return 1 }
        return 0
    }

    private var rowContactShadowY: CGFloat {
        if isFocused || isHovered { return 1 }
        return 0
    }

    private func primaryActionHandler() {
        switch primaryActionKind {
        case .organize:
            onOrganize()
        case .review, .setDestination:
            onEdit()
        }
    }
}
