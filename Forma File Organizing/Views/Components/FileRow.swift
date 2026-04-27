import SwiftUI

// MARK: - Premium File Card Component
// Redesigned for Apple Design Award quality
// Features: Progressive disclosure, premium thumbnail treatment, refined visual hierarchy

enum FileRowAccessibilityState {
    static func value(
        view: String,
        isSelected: Bool,
        isFocused: Bool,
        status: FileItem.OrganizationStatus,
        activity: FileSurfaceStyle.ActivityState,
        widthClass: FileSurfaceWidthClass? = nil
    ) -> String {
        var parts = [
            "view=\(view)",
            "selected=\(isSelected ? 1 : 0)",
            "focused=\(isFocused ? 1 : 0)",
            "status=\(status.rawValue)",
            "activity=\(activity.rawValue)"
        ]

        if let widthClass {
            parts.append("widthClass=\(widthClass == .compact ? "compact" : "regular")")
        }

        return parts.joined(separator: ";")
    }
}

enum FileRowAccessibilityIdentifier {
    static func rowIdentifier(fileName: String, filePath: String) -> String {
        identifier(prefix: "fileRow", fileName: fileName, filePath: filePath)
    }

    static func cardStateIdentifier(fileName: String, filePath: String) -> String {
        identifier(prefix: "fileRowState", fileName: fileName, filePath: filePath)
    }

    static func listStateIdentifier(fileName: String, filePath: String) -> String {
        identifier(prefix: "fileListRowState", fileName: fileName, filePath: filePath)
    }

    static func gridStateIdentifier(fileName: String, filePath: String) -> String {
        identifier(prefix: "fileGridItemState", fileName: fileName, filePath: filePath)
    }

    static func selectionCheckboxIdentifier(fileName: String, filePath: String) -> String {
        identifier(prefix: "fileSelectionCheckbox", fileName: fileName, filePath: filePath)
    }

    static func primaryActionIdentifier(
        fileName: String,
        filePath: String,
        actionKindSuffix: String
    ) -> String {
        identifier(
            prefix: "filePrimaryAction_\(actionKindSuffix)",
            fileName: fileName,
            filePath: filePath
        )
    }

    private static func identifier(prefix: String, fileName: String, filePath: String) -> String {
        "\(prefix)_\(fileName)__\(encodedPath(filePath))"
    }

    private static func encodedPath(_ filePath: String) -> String {
        Data(filePath.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

struct FileRow: View {
    let file: FileItem
    var density: FileDisplayDensity = .balanced

    // State & Callbacks
    var isFocused: Bool = false
    var isSelected: Bool = false
    var isSelectionMode: Bool = false
    var showsPrimaryActionButton: Bool = true
    var showKeyboardHints: Bool = false
    var surfaceActivity: FileSurfaceStyle.ActivityState = .none

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
    @Environment(\.fileSurfaceLayout) private var fileSurfaceLayout

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

    private var surfaceStyle: FileSurfaceStyle {
        .resolved(
            kind: .card,
            isHovered: isHovered,
            isSelected: isSelected,
            isFocused: isFocused,
            activity: surfaceActivity
        )
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
        FileRowAccessibilityState.value(
            view: "card",
            isSelected: isSelected,
            isFocused: isFocused,
            status: file.status,
            activity: surfaceActivity,
            widthClass: fileSurfaceLayout.widthClass
        )
    }

    // MARK: - Primary Action Configuration
    // Unified terminology keeps the action outcome-focused:
    // organize ready files, review pending suggestions, or choose a destination.
    private var primaryActionConfig: FileRowActionConfig {
        FileRowActionConfig.resolve(
            file: file,
            onOrganize: onOrganize,
            onEditDestination: onEditDestination,
            onCreateRule: onCreateRule
        )
    }

    private var showsAccessoryRow: Bool {
        shouldRevealPrimaryAction || shouldRevealOverflowMenu
    }

    var body: some View {
        Group {
            if fileSurfaceLayout.isCompact {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    HStack(alignment: .top, spacing: contentSpacing) {
                        selectionControl
                        thumbnailView
                        identityBlock
                    }

                    if showsAccessoryRow {
                        HStack(spacing: contentSpacing) {
                            Spacer(minLength: 0)
                            accessoryActions
                        }
                    }
                }
            } else {
                HStack(alignment: .center, spacing: contentSpacing) {
                    selectionControl
                    thumbnailView
                    identityBlock
                    Spacer(minLength: contentSpacing)
                    accessoryActions
                }
            }
        }
        .padding(.leading, contentLeadingPadding)
        .padding(.trailing, contentTrailingPadding)
        .padding(.vertical, rowVerticalPadding)
        .frame(minHeight: rowMinHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FileSurfaceBackground(style: surfaceStyle))
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
        .overlay(cardSheen)
        .overlay(
            FileSurfaceBorder(
                style: surfaceStyle,
                cornerRadius: FormaRadius.control,
                primaryLineWidth: cardOuterBorderWidth,
                accentLineWidth: 1,
                accentInset: 3,
                innerBorderColor: cardInnerBorderColor
            )
        )
        .shadow(color: cardAmbientShadowColor, radius: cardAmbientShadowRadius, x: 0, y: cardAmbientShadowY)
        .shadow(color: cardContactShadowColor, radius: cardContactShadowRadius, x: 0, y: cardContactShadowY)
        .animation(reduceMotion ? nil : FormaEasing.microFeedback, value: isHovered)
        .animation(reduceMotion ? nil : FormaEasing.microFeedback, value: isSelected)
        .animation(reduceMotion ? nil : FormaEasing.microFeedback, value: isFocused)
        .onHover { hovering in
            isHovered = hovering
        }
        .if(isSelectionMode && onToggleSelection != nil) { row in
            row.onTapGesture {
                onToggleSelection?(file)
            }
        }
        .contextMenu {
            if !isSelectionMode {
                FileActionMenuContent(
                    file: file,
                    primaryActionKind: primaryActionKind,
                    matchingRules: matchingRules,
                    availableDestinations: availableDestinations,
                    onPrimaryAction: primaryActionConfig.action,
                    onEditDestination: { onEditDestination?(file) },
                    onSkip: { onSkip?(file) },
                    onQuickLook: { onQuickLook?(file) },
                    onCreateRule: onCreateRule.map { action in { action(file) } },
                    onApplyRule: onApplyRule,
                    onChangeDestination: onChangeDestination.map { action in { destination in action(file, destination) } },
                    disablesEdit: onEditDestination == nil,
                    disablesSkip: onSkip == nil
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            FileRowAccessibilityIdentifier.rowIdentifier(
                fileName: file.name,
                filePath: file.path
            )
        )
        .accessibilityValue(rowStateAccessibilityValue)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityIdentifier(
                    FileRowAccessibilityIdentifier.cardStateIdentifier(
                        fileName: file.name,
                        filePath: file.path
                    )
                )
                .accessibilityLabel("File row state \(rowStateAccessibilityValue)")
                .accessibilityValue(rowStateAccessibilityValue)
        }
    }

    @ViewBuilder
    private var selectionControl: some View {
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
            .accessibilityIdentifier(
                FileRowAccessibilityIdentifier.selectionCheckboxIdentifier(
                    fileName: file.name,
                    filePath: file.path
                )
            )
        }
    }

    private var thumbnailView: some View {
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
    }

    private var identityBlock: some View {
        FileIdentityBlock(
            file: file,
            layout: .card,
            searchMatchType: searchMatchType,
            contentSnippet: contentSnippet
        )
        .animation(reduceMotion ? nil : FormaEasing.microFeedback, value: isHovered)
    }

    private var accessoryActions: some View {
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

    private var cardSheen: some View {
        RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(
                            surfaceStyle.interactionState == .focused || surfaceStyle.interactionState == .selected ? 0.16 : 0.06
                        ),
                        Color.formaBoneWhite.opacity(surfaceStyle.interactionState == .hover ? 0.04 : 0.015),
                        Color.formaBoneWhite.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    private var cardInnerBorderColor: Color {
        switch surfaceStyle.interactionState {
        case .focused, .selected:
            return Color.formaBoneWhite.opacity(0.24)
        case .hover:
            return Color.formaBoneWhite.opacity(0.14)
        case .rest:
            if surfaceStyle.activityState != .none {
                return Color.formaBoneWhite.opacity(0.10)
            }
            return Color.formaBoneWhite.opacity(0.035)
        }
    }

    private var cardOuterBorderWidth: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused:
            return FormaBorderWidth.medium
        case .selected:
            return FormaBorderWidth.thin
        case .hover:
            return 0.6
        case .rest:
            return surfaceStyle.activityState == .none ? 0.5 : 0.6
        }
    }

    private var cardAmbientShadowColor: Color {
        switch surfaceStyle.interactionState {
        case .focused:
            return Color.formaSteelBlue.opacity(0.08)
        case .selected:
            return Color.formaObsidian.opacity(0.03)
        case .hover:
            return Color.formaObsidian.opacity(0.04)
        case .rest:
            return surfaceStyle.activityState == .none ? .clear : Color.formaObsidian.opacity(0.01)
        }
    }

    private var cardAmbientShadowRadius: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused: return 7
        case .selected: return 4
        case .hover: return 3
        case .rest: return surfaceStyle.activityState == .none ? 0 : 1.5
        }
    }

    private var cardAmbientShadowY: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused: return 3
        case .selected, .hover: return 1
        case .rest: return surfaceStyle.activityState == .none ? 0 : 1
        }
    }

    private var cardContactShadowColor: Color {
        switch surfaceStyle.interactionState {
        case .focused, .hover:
            return Color.formaObsidian.opacity(0.06)
        case .selected, .rest:
            return surfaceStyle.interactionState == .selected
                ? Color.formaObsidian.opacity(0.02)
                : .clear
        }
    }

    private var cardContactShadowRadius: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused: return 1.5
        case .selected, .hover: return 1
        case .rest: return 0
        }
    }

    private var cardContactShadowY: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused:
            return 2
        case .selected, .hover:
            return 1
        case .rest:
            return 0
        }
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
