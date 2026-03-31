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
    var surfaceActivity: FileSurfaceStyle.ActivityState = .none

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

    private var surfaceStyle: FileSurfaceStyle {
        .resolved(
            kind: .listRow,
            isHovered: isHovered,
            isSelected: isSelected,
            isFocused: isFocused,
            activity: surfaceActivity
        )
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
        FileRowAccessibilityState.value(
            view: "list",
            isSelected: isSelected,
            isFocused: isFocused,
            status: file.status,
            activity: surfaceActivity
        )
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
        .background(FileSurfaceBackground(style: surfaceStyle))
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous))
        .overlay(rowSheen)
        .overlay(
            FileSurfaceBorder(
                style: surfaceStyle,
                cornerRadius: FormaRadius.small,
                primaryLineWidth: rowBorderWidth,
                accentLineWidth: 1,
                accentInset: 2.5,
                innerBorderColor: rowInnerBorderColor,
                innerBorderInset: 1
            )
        )
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
                        Color.formaBoneWhite.opacity(
                            surfaceStyle.interactionState == .focused || surfaceStyle.interactionState == .selected ? 0.24 : 0.14
                        ),
                        Color.formaBoneWhite.opacity(surfaceStyle.interactionState == .hover ? 0.08 : 0.04),
                        Color.formaBoneWhite.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    private var rowBorderWidth: CGFloat {
        if surfaceStyle.interactionState == .focused {
            return 1.5
        }
        if surfaceStyle.interactionState == .selected {
            return 1.0
        }
        return colorScheme == .dark ? 0.75 : 0.6
    }

    private var rowInnerBorderColor: Color {
        switch surfaceStyle.interactionState {
        case .focused, .selected:
            return Color.formaBoneWhite.opacity(0.30)
        case .hover:
            return Color.formaBoneWhite.opacity(0.18)
        case .rest:
            if surfaceStyle.activityState != .none {
                return Color.formaBoneWhite.opacity(0.16)
            }
            return Color.formaBoneWhite.opacity(0.10)
        }
    }

    private var rowAmbientShadowColor: Color {
        switch surfaceStyle.interactionState {
        case .focused:
            return Color.formaSteelBlue.opacity(0.10)
        case .selected:
            return Color.formaObsidian.opacity(0.05)
        case .hover:
            return Color.formaObsidian.opacity(0.06)
        case .rest:
            return .clear
        }
    }

    private var rowAmbientShadowRadius: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused: return 8
        case .selected: return 5
        case .hover: return 4
        case .rest: return 0
        }
    }

    private var rowAmbientShadowY: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused: return 3
        case .selected, .hover: return 2
        case .rest: return 0
        }
    }

    private var rowContactShadowColor: Color {
        switch surfaceStyle.interactionState {
        case .focused, .hover:
            return Color.formaObsidian.opacity(0.08)
        case .selected, .rest:
            return .clear
        }
    }

    private var rowContactShadowRadius: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused, .hover: return 1
        case .selected, .rest: return 0
        }
    }

    private var rowContactShadowY: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused, .hover: return 1
        case .selected, .rest: return 0
        }
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
