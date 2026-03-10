import SwiftUI

// MARK: - Premium File Card Component
// Redesigned for Apple Design Award quality
// Features: Progressive disclosure, premium thumbnail treatment, refined visual hierarchy

struct FileRow: View {
    let file: FileItem
    var density: FileDisplayDensity = .balanced

    // State & Callbacks
    var isFocused: Bool = false
    var isSelected: Bool = false
    var isSelectionMode: Bool = false
    var showsPrimaryActionButton: Bool = true
    var showKeyboardHints: Bool = false

    // Search Match Display (from ContentSearchService)
    var searchMatchType: ContentSearchService.MatchType?
    var contentSnippet: String?

    // Inline destination picker
    var availableDestinations: [Destination] = []
    var onChangeDestination: ((FileItem, Destination) -> Void)? = nil

    var onOrganize: (FileItem) -> Void = { _ in }
    var onSkip: ((FileItem) -> Void)? = nil
    var onEditDestination: ((FileItem) -> Void)? = nil
    var onCreateRule: ((FileItem) -> Void)? = nil
    var onViewRule: ((FileItem) -> Void)? = nil
    var matchingRules: [Rule] = []
    var onApplyRule: ((Rule) -> Void)? = nil
    var onQuickLook: ((FileItem) -> Void)? = nil
    var onToggleSelection: ((FileItem) -> Void)? = nil
    var onThumbnailHover: ((FileItem?, NSEvent?) -> Void)? = nil

    @State private var isHovered = false
    @State private var showQuickLookHint = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private var thumbnailSize: CGFloat {
        switch density {
        case .tight: return 40
        case .balanced: return 44
        case .spacious: return 48
        }
    }

    private var rowMinHeight: CGFloat {
        switch density {
        case .tight: return 64
        case .balanced: return 72
        case .spacious: return 80
        }
    }

    private var rowVerticalPadding: CGFloat {
        switch density {
        case .tight: return 8
        case .balanced: return 8
        case .spacious: return 12
        }
    }

    private var contentSpacing: CGFloat {
        switch density {
        case .tight: return 8
        case .balanced: return 10
        case .spacious: return 12
        }
    }

    private var infoStackSpacing: CGFloat {
        switch density {
        case .tight: return 4
        case .balanced: return 5
        case .spacious: return 6
        }
    }

    private var contentLeadingPadding: CGFloat {
        switch density {
        case .tight: return 8
        case .balanced: return 12
        case .spacious: return 12
        }
    }

    private var contentTrailingPadding: CGFloat {
        switch density {
        case .tight: return 12
        case .balanced: return 16
        case .spacious: return 16
        }
    }

    private var selectionControlEmphasisOpacity: Double {
        (isHovered || isSelectionMode || isSelected) ? 1.0 : 0.72
    }

    private var primaryActionKind: FilePrimaryActionKind {
        FilePrimaryActionKind.resolve(for: file)
    }

    private var shouldRevealPrimaryAction: Bool {
        guard showsPrimaryActionButton, !isSelectionMode else { return false }
        if primaryActionKind == .setDestination {
            return true
        }
        return isHovered || isFocused || isSelected
    }

    private var shouldRevealOverflowMenu: Bool {
        guard !isSelectionMode else { return false }
        return isHovered || isFocused || isSelected
    }

    private var rowStateAccessibilityValue: String {
        "view=card;selected=\(isSelected ? 1 : 0);focused=\(isFocused ? 1 : 0);status=\(file.status.rawValue)"
    }

    // MARK: - Primary Action Configuration
    // Unified terminology: "Organize" when destination exists, "Set Destination" when it doesn't
    // The status indicator shows file state, so button label stays consistent
    private var primaryActionConfig: FileRowActionConfig {
        FileRowActionConfig.resolve(
            file: file,
            onOrganize: onOrganize,
            onEditDestination: onEditDestination,
            onCreateRule: onCreateRule
        )
    }

    var body: some View {
        HStack(alignment: .center, spacing: contentSpacing) {
            if let onToggleSelection = onToggleSelection {
                FormaCheckbox.premium(
                    isSelected: isSelected,
                    isVisible: true,
                    action: { onToggleSelection(file) }
                )
                .opacity(selectionControlEmphasisOpacity)
                .frame(width: 32, height: 32, alignment: .center)
                .contentShape(Rectangle())
                .help(isSelected ? "Deselect file" : "Select file")
            }

            FormaThumbnail.premium(
                file: file,
                size: thumbnailSize,
                isSelected: isSelected,
                showQuickLook: showQuickLookHint,
                onQuickLook: { onQuickLook?(file) },
                onHoverChange: { hovering in
                    showQuickLookHint = hovering
                    if hovering {
                        onThumbnailHover?(file, NSApp.currentEvent)
                    } else {
                        onThumbnailHover?(nil, nil)
                    }
                }
            )

            FileIdentityBlock(
                file: file,
                layout: .card,
                searchMatchType: searchMatchType,
                contentSnippet: contentSnippet
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isHovered)

            Spacer(minLength: contentSpacing)

            FileAccessoryActions(
                file: file,
                layout: .card,
                primaryActionKind: primaryActionKind,
                showsPrimaryAction: shouldRevealPrimaryAction,
                showsOverflowMenu: shouldRevealOverflowMenu,
                matchingRules: matchingRules,
                availableDestinations: availableDestinations,
                onPrimaryAction: primaryActionConfig.action,
                onEditDestination: { onEditDestination?(file) },
                onSkip: { onSkip?(file) },
                onQuickLook: { onQuickLook?(file) },
                onCreateRule: onCreateRule.map { action in { action(file) } },
                onApplyRule: onApplyRule,
                onChangeDestination: onChangeDestination.map { action in { destination in action(file, destination) } },
                disablesSkip: onSkip == nil
            )
        }
        .padding(.leading, contentLeadingPadding)
        .padding(.trailing, contentTrailingPadding)
        .padding(.vertical, rowVerticalPadding)
        .frame(minHeight: rowMinHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
        .overlay(cardSheen)
        .overlay(cardBorder)
        .shadow(color: cardAmbientShadowColor, radius: cardAmbientShadowRadius, x: 0, y: cardAmbientShadowY)
        .shadow(color: cardContactShadowColor, radius: cardContactShadowRadius, x: 0, y: cardContactShadowY)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isSelected)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isFocused)
        .onHover { hovering in
            isHovered = hovering
        }
        .if(isSelectionMode && onToggleSelection != nil) { row in
            row.onTapGesture {
                onToggleSelection?(file)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fileRow_\(file.name)")
        .accessibilityValue(rowStateAccessibilityValue)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityIdentifier("fileRowState_\(file.name)")
                .accessibilityLabel("File row state \(rowStateAccessibilityValue)")
                .accessibilityValue(rowStateAccessibilityValue)
        }
    }

    private var cardSheen: some View {
        RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(isFocused || isSelected ? 0.28 : 0.18),
                        Color.formaBoneWhite.opacity(isHovered ? 0.10 : 0.06),
                        Color.formaBoneWhite.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    private var cardBackground: some View {
        ZStack {
            Color.formaCardBackground

            if isHovered && !isSelected && !isFocused {
                Color.formaListRowHoverOverlay
            }

            if isSelected || isFocused {
                Color.formaListRowSelectionOverlay
            }
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
            .strokeBorder(cardOuterBorderColor, lineWidth: cardOuterBorderWidth)
            .overlay(
                RoundedRectangle(cornerRadius: FormaNestedRadius.inset(FormaRadius.control), style: .continuous)
                    .stroke(cardInnerBorderColor, lineWidth: 0.75)
            )
    }

    private var cardOuterBorderColor: Color {
        isFocused ? Color.formaListRowFocusedBorder :
        isSelected ? Color.formaListRowSelectedBorder :
        isHovered ? Color.formaListRowHoverBorder :
        Color.formaListRowBorder
    }

    private var cardInnerBorderColor: Color {
        if isFocused || isSelected {
            return Color.formaBoneWhite.opacity(0.34)
        }
        if isHovered {
            return Color.formaBoneWhite.opacity(0.22)
        }
        return Color.formaBoneWhite.opacity(0.14)
    }

    private var cardOuterBorderWidth: CGFloat {
        isFocused ? 1.5 : (isSelected ? 1.0 : 0.75)
    }

    private var cardAmbientShadowColor: Color {
        if isFocused {
            return Color.formaSteelBlue.opacity(0.12)
        }
        if isSelected {
            return Color.formaObsidian.opacity(0.05)
        }
        if isHovered {
            return Color.formaObsidian.opacity(0.08)
        }
        return Color.formaObsidian.opacity(0.03)
    }

    private var cardAmbientShadowRadius: CGFloat {
        if isFocused { return 10 }
        if isSelected { return 6 }
        if isHovered { return 5 }
        return 3
    }

    private var cardAmbientShadowY: CGFloat {
        if isFocused { return 4 }
        if isSelected { return 2 }
        if isHovered { return 2 }
        return 1
    }

    private var cardContactShadowColor: Color {
        if isFocused || isHovered {
            return Color.formaObsidian.opacity(0.10)
        }
        return Color.formaObsidian.opacity(0.05)
    }

    private var cardContactShadowRadius: CGFloat {
        if isFocused { return 2 }
        if isHovered || isSelected { return 1.5 }
        return 1
    }

    private var cardContactShadowY: CGFloat {
        if isFocused { return 2 }
        return 1
    }
}

// MARK: - File Item Extensions

extension FileItem {
    var ageColor: Color {
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
        if daysSinceCreation > 30 {
            return .formaWarmOrange
        } else if daysSinceCreation > 7 {
            return .formaWarmOrange.opacity(Color.FormaOpacity.high)
        }
        return .formaTertiaryLabel
    }
}

// MARK: - Preview

#Preview("File Card - Default") {
    VStack(spacing: 16) {
        FileRow(
            file: FileItem.mocks[0],
            onOrganize: { _ in }
        )

        FileRow(
            file: FileItem.mocks[0],
            isSelected: true,
            onOrganize: { _ in }
        )

        FileRow(
            file: FileItem.mocks[0],
            isFocused: true,
            showKeyboardHints: true,
            onOrganize: { _ in }
        )
    }
    .padding(FormaSpacing.generous)
    .background(Color.formaBackground)
    .frame(width: 600)
}
