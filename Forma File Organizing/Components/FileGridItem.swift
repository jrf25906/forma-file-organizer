import SwiftUI

/// Readability-first grid tile aligned with the card/list hierarchy.
struct FileGridItem: View {
    let file: FileItem
    var density: FileDisplayDensity = .balanced
    let isFocused: Bool
    let isSelected: Bool
    let isSelectionMode: Bool
    let showsPrimaryActionButton: Bool
    var surfaceActivity: FileSurfaceStyle.ActivityState = .none

    // Search match type for content search badge
    let searchMatchType: ContentSearchService.MatchType?

    // Callbacks
    let onToggleSelection: () -> Void
    let onOrganize: () -> Void
    let onEdit: () -> Void
    let onSkip: () -> Void
    let onQuickLook: () -> Void
    var availableDestinations: [Destination] = []
    var onChangeDestination: ((Destination) -> Void)? = nil
    var matchingRules: [Rule] = []
    var onCreateRule: (() -> Void)? = nil
    var onApplyRule: ((Rule) -> Void)? = nil

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Constants

    private var cardHeight: CGFloat {
        switch density {
        case .tight: return 204
        case .balanced: return 236
        case .spacious: return 256
        }
    }
    private let cornerRadius: CGFloat = FormaRadius.card

    private var contentHorizontalPadding: CGFloat {
        switch density {
        case .tight: return 10
        case .balanced: return 12
        case .spacious: return 12
        }
    }

    private var selectionControlEmphasisOpacity: Double {
        (isSelected || isSelectionMode || isHovered) ? 1.0 : 0.72
    }

    private var rowStateAccessibilityValue: String {
        FileRowAccessibilityState.value(
            view: "grid",
            isSelected: isSelected,
            isFocused: isFocused,
            status: file.status,
            activity: surfaceActivity
        )
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

    // MARK: - Dynamic Thumbnail Properties

    /// Image file extensions that get enhanced visual treatment.
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff", "tif"
    ]

    /// Whether this file is an image that should get enhanced visual treatment.
    private var isImageFile: Bool {
        let ext = (file.name as NSString).pathExtension.lowercased()
        return Self.imageExtensions.contains(ext)
    }

    private var thumbnailSize: CGFloat {
        switch density {
        case .tight:
            return isImageFile ? 78 : 64
        case .balanced:
            return isImageFile ? 90 : 74
        case .spacious:
            return isImageFile ? 102 : 86
        }
    }

    private var categoryColors: (primary: Color, secondary: Color) {
        (file.category.color, file.category.color)
    }

    // MARK: - Body

    /// Footer height for the 3-line text area below the thumbnail.
    private var footerHeight: CGFloat {
        switch density {
        case .tight: return 86
        case .balanced: return 106
        case .spacious: return 116
        }
    }

    private var mediaSectionHeight: CGFloat {
        cardHeight - footerHeight
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack {
                    FormaThumbnail.grid(
                        file: file,
                        size: thumbnailSize,
                        categoryColors: categoryColors,
                        isCardHovered: isHovered,
                        onQuickLook: onQuickLook
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: mediaSectionHeight)
                .frame(maxWidth: .infinity)
                .clipped()

                VStack(alignment: .leading, spacing: FormaSpacing.micro + 1) {
                    FileIdentityBlock(
                        file: file,
                        layout: .grid,
                        searchMatchType: searchMatchType
                    )
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.top, FormaSpacing.tight + 1)
                .padding(.bottom, FormaSpacing.tight - 1)
                .frame(height: footerHeight, alignment: .topLeading)
                .background(footerBackground)
            }
            .background(FileSurfaceBackground(style: surfaceStyle))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(tileSheen)
            .overlay(
                FileSurfaceBorder(
                    style: surfaceStyle,
                    cornerRadius: cornerRadius,
                    primaryLineWidth: tileOuterBorderWidth,
                    accentLineWidth: 1,
                    accentInset: 3,
                    innerBorderColor: tileInnerBorderColor
                )
            )
            .shadow(color: tileAmbientShadowColor, radius: tileAmbientShadowRadius, x: 0, y: tileAmbientShadowY)
            .shadow(color: tileContactShadowColor, radius: tileContactShadowRadius, x: 0, y: tileContactShadowY)

            if (isHovered || isFocused) && !isSelectionMode {
                VStack {
                    Spacer()

                    ZStack(alignment: .bottom) {
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.formaObsidian.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(maxWidth: .infinity)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: cornerRadius,
                                bottomTrailingRadius: cornerRadius,
                                topTrailingRadius: 0,
                                style: .continuous
                            )
                        )

                        HStack {
                            Spacer()

                            FileAccessoryActions(
                                file: file,
                                layout: .overlay,
                                primaryActionKind: primaryActionKind,
                                showsPrimaryAction: showsPrimaryActionButton,
                                showsOverflowMenu: true,
                                matchingRules: matchingRules,
                                availableDestinations: availableDestinations,
                                onPrimaryAction: primaryActionHandler,
                                onEditDestination: onEdit,
                                onSkip: onSkip,
                                onQuickLook: onQuickLook,
                                onCreateRule: onCreateRule,
                                onApplyRule: onApplyRule,
                                onChangeDestination: onChangeDestination
                            )
                        }
                        .padding(.horizontal, FormaSpacing.standard - FormaSpacing.micro)
                        .padding(.bottom, FormaSpacing.tight)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .frame(maxWidth: .infinity)
                }
                .transition(.opacity)
            }

            VStack {
                HStack {
                    FormaCheckbox.premium(
                        isSelected: isSelected,
                        isVisible: true,
                        action: onToggleSelection
                    )
                    .opacity(selectionControlEmphasisOpacity)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
                    .help(isSelected ? "Deselect file" : "Select file")
                    .padding(.leading, FormaSpacing.tight)
                    .padding(.top, FormaSpacing.tight)
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .if(isSelectionMode) { tile in
            tile.onTapGesture {
                onToggleSelection()
            }
        }
        .animation(reduceMotion ? .none : FormaEasing.microFeedback, value: isFocused)
        .animation(reduceMotion ? .none : FormaEasing.microFeedback, value: isHovered)
        .animation(reduceMotion ? .none : FormaEasing.microFeedback, value: isSelected)
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
                    FileRowAccessibilityIdentifier.gridStateIdentifier(
                        fileName: file.name,
                        filePath: file.path
                    )
                )
                .accessibilityLabel("File grid item state \(rowStateAccessibilityValue)")
                .accessibilityValue(rowStateAccessibilityValue)
        }
    }

    // MARK: - Helpers

    // MARK: - Surface Styling

    private var tileSheen: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(
                            surfaceStyle.interactionState == .focused || surfaceStyle.interactionState == .selected ? 0.24 : 0.16
                        ),
                        Color.formaBoneWhite.opacity(surfaceStyle.interactionState == .hover ? 0.08 : 0.05),
                        Color.formaBoneWhite.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    private var footerBackground: some View {
        ZStack(alignment: .top) {
            surfaceStyle.fillColor.opacity(Color.FormaOpacity.strong)

            Color.formaSeparator.opacity(0.3)
                .frame(height: 0.5)
        }
    }

    private var tileInnerBorderColor: Color {
        switch surfaceStyle.interactionState {
        case .focused, .selected:
            return Color.formaBoneWhite.opacity(0.32)
        case .hover:
            return Color.formaBoneWhite.opacity(0.18)
        case .rest:
            if surfaceStyle.activityState != .none {
                return Color.formaBoneWhite.opacity(0.16)
            }
            return Color.formaBoneWhite.opacity(0.12)
        }
    }

    private var tileOuterBorderWidth: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused:
            return FormaBorderWidth.medium
        case .selected:
            return FormaBorderWidth.thin
        case .hover, .rest:
            return 0.75
        }
    }

    private var tileAmbientShadowColor: Color {
        switch surfaceStyle.interactionState {
        case .focused:
            return Color.formaSteelBlue.opacity(0.12)
        case .selected:
            return Color.formaObsidian.opacity(0.06)
        case .hover:
            return Color.formaObsidian.opacity(0.08)
        case .rest:
            return Color.formaObsidian.opacity(0.03)
        }
    }

    private var tileAmbientShadowRadius: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused: return 12
        case .selected: return 8
        case .hover: return 6
        case .rest: return 4
        }
    }

    private var tileAmbientShadowY: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused: return 4
        case .selected, .hover: return 3
        case .rest: return 1
        }
    }

    private var tileContactShadowColor: Color {
        switch surfaceStyle.interactionState {
        case .focused, .hover:
            return Color.formaObsidian.opacity(0.10)
        case .selected, .rest:
            return Color.formaObsidian.opacity(0.05)
        }
    }

    private var tileContactShadowRadius: CGFloat {
        switch surfaceStyle.interactionState {
        case .focused: return 2
        case .selected, .hover: return 1.5
        case .rest: return 1
        }
    }

    private var tileContactShadowY: CGFloat {
        surfaceStyle.interactionState == .focused ? 2 : 1
    }
}

extension FileGridItem {
    private func primaryActionHandler() {
        switch primaryActionKind {
        case .organize:
            onOrganize()
        case .review, .setDestination:
            onEdit()
        }
    }
}
