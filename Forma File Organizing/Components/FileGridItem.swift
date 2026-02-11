import SwiftUI

/// Readability-first grid tile aligned with the card/list hierarchy.
struct FileGridItem: View {
    let file: FileItem
    var density: FileDisplayDensity = .balanced
    let isFocused: Bool
    let isSelected: Bool
    let isSelectionMode: Bool
    let showsPrimaryActionButton: Bool

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

    private var cardHeight: CGFloat {
        switch density {
        case .tight: return 190
        case .balanced: return 220
        case .spacious: return 240
        }
    }
    private let cornerRadius: CGFloat = FormaRadius.card
    private let categoryRailWidth: CGFloat = 2

    private var tileVerticalPadding: CGFloat {
        switch density {
        case .tight: return 8
        case .balanced: return 10
        case .spacious: return 12
        }
    }

    private var contentSpacing: CGFloat {
        switch density {
        case .tight: return FormaSpacing.tight - 2
        case .balanced: return FormaSpacing.tight
        case .spacious: return FormaSpacing.tight + 2
        }
    }

    private var textStackSpacing: CGFloat {
        switch density {
        case .tight: return 3
        case .balanced: return 4
        case .spacious: return 5
        }
    }

    private var contentHorizontalPadding: CGFloat {
        switch density {
        case .tight: return 10
        case .balanced: return 12
        case .spacious: return 12
        }
    }

    private var nameBlockHeight: CGFloat {
        switch density {
        case .tight: return 26
        case .balanced: return 30
        case .spacious: return 34
        }
    }

    private var selectionControlEmphasisOpacity: Double {
        (isSelected || isSelectionMode || isHovered) ? 1.0 : 0.72
    }

    private var rowStateAccessibilityValue: String {
        "view=grid;selected=\(isSelected ? 1 : 0);focused=\(isFocused ? 1 : 0);status=\(file.status.rawValue)"
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
            return isImageFile ? 88 : 72
        case .balanced:
            return isImageFile ? 100 : 84
        case .spacious:
            return isImageFile ? 112 : 96
        }
    }

    // MARK: - Computed Properties

    private var hasDestination: Bool {
        file.destination != nil
    }

    private var compactAgeText: String {
        let days = Calendar.current.dateComponents([.day], from: file.creationDate, to: Date()).day ?? 0
        if days > 1 { return "\(days)d" }
        if days == 1 { return "1d" }
        return "today"
    }

    private var statusChipConfig: (label: String, color: Color) {
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

    /// Single-line metadata string: "PDF · 32d · Review"
    private var metadataString: String {
        let segments: [String] = [
            file.fileExtension.uppercased(),
            compactAgeText,
            statusChipConfig.label
        ]
        return segments.joined(separator: " \u{00B7} ")
    }

    private var categoryColors: (primary: Color, secondary: Color) {
        (file.category.color, file.category.color)
    }

    // MARK: - Body

    /// Footer height for the 3-line text area below the thumbnail.
    private var footerHeight: CGFloat {
        switch density {
        case .tight: return 58
        case .balanced: return 64
        case .spacious: return 68
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Category top-edge bar
                file.category.color
                    .opacity(Color.FormaOpacity.prominent)
                    .frame(height: categoryRailWidth)
                    .help("Category: \(file.category.displayName)")

                // Full-bleed thumbnail area (fills available space)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Compact 3-line footer
                VStack(alignment: .leading, spacing: 2) {
                    // Line 1: Filename
                    Text(file.name)
                        .font(.formaSmallSemibold)
                        .foregroundStyle(Color.formaLabel)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Line 2: Static metadata + Active status
                    HStack(spacing: 4) {
                        // Static: type + age
                        HStack(spacing: 3) {
                            Image(systemName: "doc")
                                .font(.system(size: 8))
                            Text(file.fileExtension.uppercased())
                                .font(.formaCaption)
                        }
                        .foregroundStyle(Color.formaTertiaryLabel)

                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text(compactAgeText)
                                .font(.formaCaption)
                        }
                        .foregroundStyle(Color.formaTertiaryLabel)

                        // Active: status dot
                        Circle()
                            .fill(statusChipConfig.color)
                            .frame(width: 5, height: 5)
                            .help(statusChipConfig.label)

                        if let confidence = file.confidenceScore {
                            ConfidenceDot(score: confidence, matchReason: file.matchReason, size: 5)
                        }

                        Spacer(minLength: 0)
                    }

                    // Line 3: Destination
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
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.vertical, FormaSpacing.tight)
                .frame(height: footerHeight, alignment: .topLeading)
                .background(
                    // Subtle separator between thumbnail and footer
                    VStack {
                        Color.formaSeparator.opacity(0.3)
                            .frame(height: 0.5)
                        Spacer()
                    }
                )
            }
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(tileBorder)
            .shadow(color: tileShadowColor, radius: tileShadowRadius, x: 0, y: tileShadowY)

            // Hover action overlay
            if isHovered && !isSelectionMode {
                HoverActionOverlay(
                    hasDestination: hasDestination,
                    showsPrimaryActionButton: showsPrimaryActionButton,
                    cornerRadius: cornerRadius,
                    onOrganize: onOrganize,
                    onEdit: onEdit,
                    onSkip: onSkip,
                    onQuickLook: onQuickLook
                )
            }

            // Checkbox overlay (top-left)
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
                    .padding(.top, FormaSpacing.tight + categoryRailWidth)
                    Spacer()
                }
                Spacer()
            }

            // Search match badge (top-right)
            if let matchType = searchMatchType {
                VStack {
                    HStack {
                        Spacer()
                        SearchMatchBadge(matchType: matchType)
                            .padding(.trailing, FormaSpacing.tight)
                            .padding(.top, FormaSpacing.tight + categoryRailWidth)
                    }
                    Spacer()
                }
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
        .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isFocused)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isHovered)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isSelected)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fileRow_\(file.name)")
        .accessibilityValue(rowStateAccessibilityValue)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityIdentifier("fileGridItemState_\(file.name)")
                .accessibilityLabel("File grid item state \(rowStateAccessibilityValue)")
                .accessibilityValue(rowStateAccessibilityValue)
        }
    }

    // MARK: - Helpers

    private func truncatePath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count <= 2 { return path }
        guard let last = components.last else { return path }
        return "\u{2026}/\(last)"
    }

    // MARK: - Surface Styling

    @ViewBuilder
    private var tileBackground: some View {
        if isSelected || isFocused {
            Color.formaSteelBlue.opacity(0.12)
        } else {
            Color.formaCardBackground
        }
    }

    @ViewBuilder
    private var tileBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                isFocused ? Color.formaSteelBlue.opacity(0.80) :
                isSelected ? Color.formaSteelBlue.opacity(0.50) :
                isHovered ? Color.formaSeparator.opacity(0.8) :
                Color.formaSeparator.opacity(0.5),
                lineWidth: isFocused ? 1.5 : (isSelected ? 1 : 0.5)
            )
    }

    private var tileShadowColor: Color {
        if isHovered && !isSelected && !isFocused {
            return Color.formaObsidian.opacity(0.05)
        }
        return Color.clear
    }

    private var tileShadowRadius: CGFloat {
        if isHovered && !isSelected && !isFocused { return 2 }
        return 0
    }

    private var tileShadowY: CGFloat {
        if isHovered && !isSelected && !isFocused { return 1 }
        return 0
    }
}

// MARK: - Hover Action Overlay

private struct HoverActionOverlay: View {
    let hasDestination: Bool
    let showsPrimaryActionButton: Bool
    let cornerRadius: CGFloat
    let onOrganize: () -> Void
    let onEdit: () -> Void
    let onSkip: () -> Void
    let onQuickLook: () -> Void

    var body: some View {
        VStack {
            Spacer()

            ZStack(alignment: .bottom) {
                // Gradient overlay covering bottom ~45% of tile
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

                HStack(spacing: FormaSpacing.tight) {
                    if showsPrimaryActionButton {
                        if hasDestination {
                            overlayButton(icon: "checkmark", tooltip: "Organize", action: onOrganize)
                        } else {
                            overlayButton(icon: "folder.badge.plus", tooltip: "Set Destination", action: onEdit)
                        }
                    }

                    Menu {
                        Button(action: onOrganize) {
                            Label("Organize", systemImage: "checkmark.circle")
                        }
                        .disabled(!hasDestination)

                        Button(action: onEdit) {
                            Label("Edit Destination", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.formaCompactSemibold)
                            .foregroundStyle(Color.white)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, FormaSpacing.standard - FormaSpacing.micro)
                .padding(.bottom, FormaSpacing.tight)
            }
            .frame(height: nil)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .frame(maxWidth: .infinity)
            // Limit the gradient overlay to roughly the bottom 45%
            .frame(maxHeight: .infinity)
        }
        .transition(.opacity)
    }

    private func overlayButton(icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.formaCompactSemibold)
                .foregroundStyle(Color.white)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
