import SwiftUI

/// Premium grid tile with Apple-quality polish and progressive disclosure
struct FileGridItem: View {
    let file: FileItem
    let isFocused: Bool
    let isSelected: Bool
    let isSelectionMode: Bool

    // Search match type for content search badge
    let searchMatchType: ContentSearchService.MatchType?

    // Callbacks
    let onToggleSelection: () -> Void
    let onOrganize: () -> Void
    let onEdit: () -> Void
    let onSkip: () -> Void
    let onQuickLook: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Constants

    // Card dimensions per Enhanced Card Catalog spec
    private let cardWidth: CGFloat = 200
    private let cardHeight: CGFloat = 260
    private let cornerRadius: CGFloat = FormaRadius.large
    private let categoryBorderWidth: CGFloat = 3

    // MARK: - Dynamic Thumbnail Properties

    /// Image file extensions that get enhanced visual treatment
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff", "tif"
    ]

    /// Whether this file is an image that should get enhanced visual treatment
    private var isImageFile: Bool {
        let ext = (file.name as NSString).pathExtension.lowercased()
        return Self.imageExtensions.contains(ext)
    }

    /// Images get larger thumbnails (130px vs 120px)
    private var thumbnailSize: CGFloat {
        isImageFile ? 130 : 120
    }

    /// Images get tighter padding for more visual presence
    private var thumbnailPadding: CGFloat {
        isImageFile ? FormaSpacing.standard - FormaSpacing.micro : FormaSpacing.standard  // 12px vs 16px
    }

    // MARK: - Computed Properties

    private var hasDestination: Bool {
        file.destination != nil
    }

    private var destinationName: String {
        file.destination?.displayName ?? ""
    }

    private var categoryColors: (primary: Color, secondary: Color) {
        (file.category.color, file.category.color)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Main tile content with category color left border
            HStack(spacing: 0) {
                // Category color accent bar (left border)
                RoundedRectangle(cornerRadius: categoryBorderWidth / 2)
                    .fill(file.category.color.opacity(Color.FormaOpacity.prominent))
                    .frame(width: categoryBorderWidth)
                    .padding(.vertical, FormaSpacing.tight)

                VStack(spacing: FormaSpacing.standard) {
                    // Premium thumbnail with enhanced treatment for images
                    FormaThumbnail.grid(
                        file: file,
                        size: thumbnailSize,
                        categoryColors: categoryColors,
                        isCardHovered: isHovered,
                        onQuickLook: onQuickLook
                    )

                    // File info - fixed height container for consistent card sizing
                    VStack(spacing: FormaSpacing.tight) {
                        // Primary: Filename - fixed 2-line height for consistency
                        Text(file.name)
                            .font(.formaCompactSemibold)
                            .foregroundColor(.formaLabel)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36, alignment: .top) // Fixed height for 2 lines of text

                        // Tertiary: Size + Modified date
                        Text("\(file.size) • \(file.creationDate.formatted(.relative(presentation: .named)))")
                            .font(.formaCaption)
                            .foregroundColor(Color.formaSecondaryLabel.opacity(Color.FormaOpacity.strong))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, FormaSpacing.standard)

                    // Destination badge - only show when has destination, "Uncategorized" on hover only
                    GridDestinationBadge(
                        hasDestination: hasDestination,
                        destinationName: destinationName,
                        isHovered: isHovered
                    )
                    .opacity(isHovered ? 0 : 1)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.leading, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.standard)
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(tileBorder)
            .shadow(
                color: tileShadowColor,
                radius: tileShadowRadius,
                x: 0,
                y: tileShadowY
            )

            // Hover overlay with quick actions
            if isHovered && !isSelectionMode {
                HoverActionOverlay(
                    hasDestination: hasDestination,
                    cornerRadius: cornerRadius,
                    onOrganize: onOrganize,
                    onEdit: onEdit,
                    onSkip: onSkip,
                    onQuickLook: onQuickLook
                )
            }

            // Selection checkbox (top-left)
            if isSelected || isSelectionMode || isHovered {
                VStack {
                    HStack {
                        FormaCheckbox.grid(
                            isSelected: isSelected,
                            action: onToggleSelection
                        )
                        .padding(FormaSpacing.tight)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                    removal: .opacity
                ))
            }

            // Search match badge (top-right)
            if let matchType = searchMatchType {
                VStack {
                    HStack {
                        Spacer()
                        SearchMatchBadge(matchType: matchType)
                            .padding(FormaSpacing.tight)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight) // Enhanced Card Catalog: 260px for visual richness
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection()
            }
        }
        .scaleEffect(tileScale)
        .animation(reduceMotion ? .none : .spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isHovered)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Background

    @ViewBuilder
    private var tileBackground: some View {
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
            Color.formaControlBackground.opacity(Color.FormaOpacity.prominent)
        } else {
            Color.formaControlBackground.opacity(Color.FormaOpacity.high)
        }
    }

    // MARK: - Border

    @ViewBuilder
    private var tileBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                isFocused ? Color.formaSteelBlue :
                    (isSelected ? Color.formaSteelBlue.opacity(Color.FormaOpacity.strong) :
                        Color.formaObsidian.opacity(Color.FormaOpacity.subtle)),
                lineWidth: isFocused ? 2 : (isSelected ? 1.5 : 1)
            )
    }

    // MARK: - Shadow

    private var tileShadowColor: Color {
        if isFocused {
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay)
        } else if isSelected {
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.medium)
        } else if isHovered {
            return Color.formaObsidian.opacity(Color.FormaOpacity.light)
        } else {
            return Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
        }
    }

    private var tileShadowRadius: CGFloat {
        if isFocused { return 12 }
        else if isSelected { return 10 }
        else if isHovered { return 8 }
        else { return 4 }
    }

    private var tileShadowY: CGFloat {
        if isFocused { return 6 }
        else if isSelected { return 5 }
        else if isHovered { return 4 }
        else { return 2 }
    }

    private var tileScale: CGFloat {
        if isFocused { return 1.03 }
        else if isHovered && !isSelected { return 1.01 }
        else { return 1.0 }
    }
}


// MARK: - Grid Destination Badge

private struct GridDestinationBadge: View {
    let hasDestination: Bool
    let destinationName: String
    let isHovered: Bool

    var body: some View {
        if hasDestination {
            HStack(spacing: FormaSpacing.micro) {
                Image(systemName: "arrow.right")
                    .font(.formaMicro)
                Text(destinationName)
                    .font(.formaCaptionSemibold)
                    .lineLimit(1)
            }
            .foregroundColor(Color.formaSteelBlue)
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro)
            .background(
                Capsule()
                    .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
            )
        } else {
            // Only show "Uncategorized" on hover - reduces visual noise
            Text("Uncategorized")
                .font(.formaCaptionSemibold)
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

// MARK: - Hover Action Overlay

private struct HoverActionOverlay: View {
    let hasDestination: Bool
    let cornerRadius: CGFloat
    let onOrganize: () -> Void
    let onEdit: () -> Void
    let onSkip: () -> Void
    let onQuickLook: () -> Void

    var body: some View {
        VStack {
            Spacer()

            // Frosted action bar
            HStack(spacing: FormaSpacing.tight) {
                // Primary: Organize
                if hasDestination {
                    FormaActionButton.grid(
                        icon: "checkmark",
                        color: Color.formaSage,
                        isPrimary: true,
                        tooltip: "Organize",
                        action: onOrganize
                    )
                }

                // Secondary: Skip
                FormaActionButton.grid(
                    icon: "forward.fill",
                    color: Color.formaObsidian,
                    isPrimary: false,
                    tooltip: "Skip",
                    action: onSkip
                )

                // Overflow menu
                Menu {
                    Button(action: onOrganize) {
                        Label("Organize", systemImage: "checkmark.circle")
                    }
                    .disabled(!hasDestination)

                    Button(action: onEdit) {
                        Label("Edit Destination", systemImage: "pencil")
                    }

                    Button(action: onSkip) {
                        Label("Skip", systemImage: "forward")
                    }

                    Divider()

                    Button(action: onQuickLook) {
                        Label("Quick Look", systemImage: "eye")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.formaCompactSemibold)
                        .foregroundColor(Color.formaSecondaryLabel.opacity(Color.FormaOpacity.high))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.regularMaterial)
                                .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.light), radius: 2, x: 0, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FormaSpacing.standard - FormaSpacing.micro)
            .padding(.vertical, FormaSpacing.tight)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.medium), radius: 8, x: 0, y: -2)
            )
            .padding(FormaSpacing.tight)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

