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
        case .tight: return 246
        case .balanced: return 278
        case .spacious: return 320
        }
    }
    private let cornerRadius: CGFloat = FormaRadius.large
    private let categoryBorderWidth: CGFloat = 3

    private var tileVerticalPadding: CGFloat {
        switch density {
        case .tight: return FormaSpacing.tight + (FormaSpacing.micro / 2)
        case .balanced: return FormaSpacing.standard
        case .spacious: return FormaSpacing.standard + (FormaSpacing.micro / 2)
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
        case .tight: return FormaSpacing.micro + 1
        case .balanced: return FormaSpacing.micro + 2
        case .spacious: return FormaSpacing.tight
        }
    }

    private var contentHorizontalPadding: CGFloat {
        switch density {
        case .tight: return FormaSpacing.tight + (FormaSpacing.micro / 2)
        case .balanced: return FormaSpacing.standard
        case .spacious: return FormaSpacing.standard + (FormaSpacing.micro / 2)
        }
    }

    private var nameBlockHeight: CGFloat {
        switch density {
        case .tight: return 30
        case .balanced: return 34
        case .spacious: return 40
        }
    }

    private var summaryLineLimit: Int {
        density == .tight ? 1 : 2
    }

    private var chipHorizontalPadding: CGFloat {
        density == .tight ? (FormaSpacing.tight - 2) : FormaSpacing.tight
    }

    private var chipVerticalPadding: CGFloat {
        density == .spacious ? (FormaSpacing.micro + 1) : FormaSpacing.micro
    }

    private var selectionControlEmphasisOpacity: Double {
        (isSelected || isSelectionMode || isHovered) ? 1.0 : 0.72
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
            return isImageFile ? 108 : 98
        case .balanced:
            return isImageFile ? 128 : 116
        case .spacious:
            return isImageFile ? 146 : 132
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

    private var ageSummaryText: String {
        compactAgeText == "today" ? "today" : "\(compactAgeText) old"
    }

    private var summaryLineText: String {
        var segments = [file.category.displayName, ageSummaryText]

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

    private var statusChipConfig: (label: String, icon: String, color: Color) {
        switch file.status {
        case .pending:
            if file.destination == nil {
                return ("Needs Dest", "questionmark.circle.fill", .formaWarning)
            }
            return ("Review", "exclamationmark.circle.fill", .formaWarning)
        case .ready:
            return ("Ready", "checkmark.circle.fill", .formaSage)
        case .completed:
            return ("Organized", "checkmark.seal.fill", .formaSage)
        case .skipped:
            return ("Skipped", "forward.fill", .formaSecondaryLabelHigh)
        }
    }

    private var categoryColors: (primary: Color, secondary: Color) {
        (file.category.color, file.category.color)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: categoryBorderWidth / 2)
                    .fill(file.category.color.opacity(Color.FormaOpacity.prominent))
                    .frame(width: categoryBorderWidth)
                    .padding(.vertical, tileVerticalPadding)
                    .help("Category: \(file.category.displayName)")

                VStack(alignment: .leading, spacing: contentSpacing) {
                    HStack {
                        Spacer(minLength: 0)
                        FormaThumbnail.grid(
                            file: file,
                            size: thumbnailSize,
                            categoryColors: categoryColors,
                            isCardHovered: isHovered,
                            onQuickLook: onQuickLook
                        )
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: textStackSpacing) {
                        Text(file.name)
                            .font(.formaCompactSemibold)
                            .foregroundStyle(Color.formaLabel)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: nameBlockHeight, alignment: .topLeading)

                        HStack(spacing: FormaSpacing.micro + 2) {
                            statusChip
                            if let confidence = file.confidenceScore {
                                ConfidenceDot(score: confidence, matchReason: file.matchReason, size: 9)
                            }
                            Spacer(minLength: 0)
                        }

                        Text(summaryLineText)
                            .font(.formaCaption)
                            .foregroundStyle(Color.formaSecondaryLabelHigh)
                            .lineLimit(summaryLineLimit)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: FormaSpacing.micro + 2) {
                            metadataChip(
                                icon: "doc",
                                label: file.fileExtension.uppercased(),
                                foreground: Color.formaSecondaryLabelHigh
                            )

                            metadataChip(
                                icon: "calendar",
                                label: compactAgeText,
                                foreground: file.ageColor
                            )
                        }

                        if let destination = file.destination {
                            metadataChip(
                                icon: destination.isTrash ? "trash" : "folder",
                                label: truncatePath(destination.displayName),
                                foreground: Color.formaSteelBlue,
                                background: Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
                            )
                            .help("Destination: \(destination.displayName)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            metadataChip(
                                icon: "questionmark.folder",
                                label: "No destination",
                                foreground: Color.formaSecondaryLabelHigh
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, contentHorizontalPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.leading, FormaSpacing.tight)
            .padding(.vertical, tileVerticalPadding)
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(tileBorder)
            .shadow(color: tileShadowColor, radius: tileShadowRadius, x: 0, y: tileShadowY)

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

            VStack {
                HStack {
                    FormaCheckbox.premium(
                        isSelected: isSelected,
                        isVisible: true,
                        action: onToggleSelection
                    )
                    .opacity(selectionControlEmphasisOpacity)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .help(isSelected ? "Deselect file" : "Select file")
                    .padding(FormaSpacing.tight)
                    Spacer()
                }
                Spacer()
            }

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
        .frame(height: cardHeight)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .if(isSelectionMode) { tile in
            tile.onTapGesture {
                onToggleSelection()
            }
        }
        .scaleEffect(tileScale)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isFocused)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isHovered)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isSelected)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fileRow_\(file.name)")
    }

    // MARK: - Component Helpers

    private var statusChip: some View {
        HStack(spacing: FormaSpacing.micro) {
            Image(systemName: statusChipConfig.icon)
                .font(.formaMicro)
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

    private func metadataChip(
        icon: String,
        label: String,
        foreground: Color,
        background: Color = Color.formaObsidian.opacity(Color.FormaOpacity.subtle + Color.FormaOpacity.ultraSubtle)
    ) -> some View {
        HStack(spacing: FormaSpacing.micro) {
            Image(systemName: icon)
                .font(.formaCaption)
            Text(label)
                .font(.formaCaptionSemibold)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, chipHorizontalPadding)
        .padding(.vertical, chipVerticalPadding)
        .background(
            Capsule(style: .continuous)
                .fill(background)
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
    private var tileBackground: some View {
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

    @ViewBuilder
    private var tileBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                isFocused ? Color.formaSteelBlue.opacity(Color.FormaOpacity.prominent) :
                isSelected ? Color.formaSteelBlue.opacity(Color.FormaOpacity.strong) :
                Color.formaBoneWhite.opacity(isHovered ? Color.FormaOpacity.medium : Color.FormaOpacity.light),
                lineWidth: isFocused ? 1.5 : 1
            )
    }

    private var tileShadowColor: Color {
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

    private var tileShadowRadius: CGFloat {
        if isFocused || isSelected { return 10 }
        if isHovered { return 8 }
        return 5
    }

    private var tileShadowY: CGFloat {
        if isFocused || isSelected { return 4 }
        if isHovered { return 3 }
        return 2
    }

    private var tileScale: CGFloat {
        if isFocused {
            return 1.01
        }
        if isHovered && !isSelected {
            return 1.006
        }
        return 1.0
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

            HStack(spacing: FormaSpacing.tight) {
                if hasDestination && showsPrimaryActionButton {
                    FormaActionButton.grid(
                        icon: "checkmark",
                        color: Color.formaSage,
                        isPrimary: true,
                        tooltip: "Organize",
                        action: onOrganize
                    )
                }

                FormaActionButton.grid(
                    icon: "forward.fill",
                    color: Color.formaObsidian,
                    isPrimary: false,
                    tooltip: "Skip",
                    action: onSkip
                )

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
                        .foregroundStyle(Color.formaSecondaryLabel.opacity(Color.FormaOpacity.high))
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
