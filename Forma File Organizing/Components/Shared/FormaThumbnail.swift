import SwiftUI

/// Unified thumbnail component with display mode variants
/// Consolidates: PremiumThumbnail, CompactThumbnail, GridThumbnail
struct FormaThumbnail: View {
    enum DisplayMode {
        case premium    // Large (84px) with category gradient and shadows
        case compact    // Small (44px) for list rows
        case grid       // Medium (120-130px) for grid tiles with enhanced image treatment

        var defaultSize: CGFloat {
            switch self {
            case .premium: return 84
            case .compact: return 44
            case .grid: return 120
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .premium: return FormaRadius.card - (FormaSpacing.micro / 2)
            case .compact: return FormaRadius.control
            case .grid: return FormaRadius.card
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .premium: return 0.6
            case .compact: return 1.0
            case .grid: return 48
            }
        }
    }

    let file: FileItem
    var mode: DisplayMode = .premium
    var size: CGFloat? = nil
    var categoryColors: (primary: Color, secondary: Color)? = nil
    var isSelected: Bool = false
    var showQuickLook: Bool = false
    var isCardHovered: Bool = false
    var onQuickLook: () -> Void = {}
    var onHoverChange: (Bool) -> Void = { _ in }

    @State private var thumbnail: NSImage?
    @State private var isLoading = false
    @State private var isThumbnailHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed Properties

    private var actualSize: CGFloat {
        size ?? mode.defaultSize
    }

    private var colors: (primary: Color, secondary: Color) {
        categoryColors ?? (file.category.color, file.category.color)
    }

    /// Image file extensions that get enhanced visual treatment in grid mode
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff", "tif"
    ]

    private var isImageFile: Bool {
        let ext = (file.name as NSString).pathExtension.lowercased()
        return Self.imageExtensions.contains(ext)
    }

    /// Only show actual thumbnails for visual media types
    private var shouldShowThumbnail: Bool {
        let ext = file.fileExtension.lowercased()
        let visualExtensions = ["jpg", "jpeg", "png", "heic", "gif", "webp", "pdf", "mov", "mp4", "m4v"]
        return visualExtensions.contains(ext)
    }

    /// Grid mode images get zoom effect
    private var zoomScale: CGFloat {
        if mode == .grid && isImageFile && isThumbnailHovered {
            return 1.05
        }
        return 1.0
    }

    var body: some View {
        Button(action: onQuickLook) {
            ZStack {
                // Base thumbnail container
                thumbnailContainer
                    .frame(width: actualSize, height: actualSize)
                    .clipShape(RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous))
                    .overlay(thumbnailBorder)
                    .shadow(color: primaryShadowColor, radius: primaryShadowRadius, x: 0, y: primaryShadowY)
                    .shadow(color: secondaryShadowColor, radius: secondaryShadowRadius, x: 0, y: secondaryShadowY)

                // Selection overlay (premium mode only)
                if mode == .premium && isSelected {
                    RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                        .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                        .frame(width: actualSize, height: actualSize)
                }

                // Quick Look overlay
                if shouldShowQuickLookOverlay {
                    quickLookOverlay
                        .transition(.opacity)
                }
            }
        }
        .buttonStyle(.plain)
        .help(mode == .compact ? "Quick Look • Space" : "")
        .onHover { hovering in
            isThumbnailHovered = hovering
            onHoverChange(hovering)
            if hovering && mode != .grid {
                NSCursor.pointingHand.push()
            } else if !hovering && mode != .grid {
                NSCursor.pop()
            }
        }
        .task(id: file.path) {
            await loadThumbnail()
        }
    }

    // MARK: - Thumbnail Container

    @ViewBuilder
    private var thumbnailContainer: some View {
        ZStack {
            // Category gradient background (always shown as base)
            categoryGradient

            // Content layer
            if shouldShowThumbnail, let thumb = thumbnail {
                // Show actual thumbnail
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: thumbnailAspectMode)
                    .scaleEffect(mode == .grid && isImageFile ? zoomScale : 1.0)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                        value: isThumbnailHovered
                    )
            } else if isLoading && shouldShowThumbnail {
                // Loading indicator
                ProgressView()
                    .scaleEffect(mode == .compact ? 0.5 : 0.6)
            } else {
                // Fallback to system icon
                fallbackIcon
            }
        }
    }

    private var thumbnailAspectMode: ContentMode {
        mode == .grid && isImageFile ? .fill : .fill
    }

    private var categoryGradient: some View {
        LinearGradient(
            colors: [
                colors.primary.opacity(Color.FormaOpacity.light),
                colors.secondary.opacity(Color.FormaOpacity.subtle)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var fallbackIcon: some View {
        if mode == .compact {
            // Use SF Symbol for compact mode
            Image(systemName: file.iconName)
                .font(.formaH3)
                .fontWeight(.medium)
                .foregroundColor(Color.formaSteelBlue.opacity(Color.FormaOpacity.prominent))
        } else if mode == .grid {
            // Grid mode with border highlight
            ZStack {
                RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                    .stroke(Color.formaBoneWhite.opacity(Color.FormaOpacity.strong), lineWidth: 1)
                    .frame(width: actualSize - 2, height: actualSize - 2)
                    .blur(radius: 0.5)

                Image(systemName: file.iconName)
                    .font(.system(size: mode.iconSize, weight: .light))
                    .foregroundColor(colors.primary.opacity(Color.FormaOpacity.high))
            }
        } else {
            // Premium mode uses native macOS icon
            let icon = NSWorkspace.shared.icon(forFile: file.path)
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: actualSize * mode.iconSize, height: actualSize * mode.iconSize)
        }
    }

    // MARK: - Borders

    @ViewBuilder
    private var thumbnailBorder: some View {
        if mode == .premium {
            RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.formaBoneWhite.opacity(Color.FormaOpacity.overlay),
                            Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Shadows

    private var primaryShadowColor: Color {
        switch mode {
        case .premium:
            return Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
        case .compact:
            return Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
        case .grid:
            return Color.formaObsidian.opacity(Color.FormaOpacity.light)
        }
    }

    private var primaryShadowRadius: CGFloat {
        mode == .premium ? 2 : (mode == .grid ? 4 : 3)
    }

    private var primaryShadowY: CGFloat {
        mode == .premium ? 1 : (mode == .grid ? 2 : 1)
    }

    private var secondaryShadowColor: Color {
        if mode == .premium {
            return Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
        } else if mode == .grid && isImageFile {
            return colors.primary.opacity(Color.FormaOpacity.medium)
        }
        return .clear
    }

    private var secondaryShadowRadius: CGFloat {
        mode == .premium ? 4 : (isThumbnailHovered ? 16 : 12)
    }

    private var secondaryShadowY: CGFloat {
        mode == .premium ? 2 : (isThumbnailHovered ? 8 : 6)
    }

    // MARK: - Quick Look Overlay

    private var shouldShowQuickLookOverlay: Bool {
        switch mode {
        case .premium:
            return showQuickLook
        case .compact:
            return isCardHovered
        case .grid:
            return isImageFile && isThumbnailHovered
        }
    }

    @ViewBuilder
    private var quickLookOverlay: some View {
        switch mode {
        case .premium:
            ZStack {
                RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)

                Image(systemName: "eye.fill")
                    .font(.formaH2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.formaBoneWhite)
                    .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.overlay), radius: 2, x: 0, y: 1)
            }
            .frame(width: actualSize, height: actualSize)

        case .compact:
            RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: actualSize, height: actualSize)
                .overlay(
                    Image(systemName: "eye.fill")
                        .font(.formaBodyLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.formaSteelBlue)
                )

        case .grid:
            RoundedRectangle(cornerRadius: mode.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    VStack(spacing: FormaSpacing.micro) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 24, weight: .semibold))
                        Text("Quick Look")
                            .font(.formaCaptionSemibold)
                    }
                    .foregroundColor(colors.primary)
                )
        }
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnail() async {
        // Only load thumbnails for visual media
        guard shouldShowThumbnail else { return }
        guard thumbnail == nil else { return }

        isLoading = true
        defer { isLoading = false }

        thumbnail = await ThumbnailService.shared.thumbnail(
            for: file.path,
            size: CGSize(width: actualSize * 2, height: actualSize * 2) // Request 2x for Retina
        )
    }
}

// MARK: - Convenience Initializers

extension FormaThumbnail {
    /// Premium thumbnail variant (84px, with selection overlay)
    static func premium(
        file: FileItem,
        size: CGFloat = 84,
        isSelected: Bool = false,
        showQuickLook: Bool = false,
        onQuickLook: @escaping () -> Void = {},
        onHoverChange: @escaping (Bool) -> Void = { _ in }
    ) -> FormaThumbnail {
        FormaThumbnail(
            file: file,
            mode: .premium,
            size: size,
            isSelected: isSelected,
            showQuickLook: showQuickLook,
            onQuickLook: onQuickLook,
            onHoverChange: onHoverChange
        )
    }

    /// Compact thumbnail variant (44px, for list rows)
    static func compact(
        file: FileItem,
        categoryColors: (primary: Color, secondary: Color),
        isCardHovered: Bool = false,
        onQuickLook: @escaping () -> Void = {}
    ) -> FormaThumbnail {
        FormaThumbnail(
            file: file,
            mode: .compact,
            categoryColors: categoryColors,
            isCardHovered: isCardHovered,
            onQuickLook: onQuickLook
        )
    }

    /// Grid thumbnail variant (120-130px, enhanced for images)
    static func grid(
        file: FileItem,
        size: CGFloat,
        categoryColors: (primary: Color, secondary: Color),
        isCardHovered: Bool = false,
        onQuickLook: @escaping () -> Void = {}
    ) -> FormaThumbnail {
        FormaThumbnail(
            file: file,
            mode: .grid,
            size: size,
            categoryColors: categoryColors,
            isCardHovered: isCardHovered,
            onQuickLook: onQuickLook
        )
    }
}

// MARK: - Preview

#Preview("FormaThumbnail Variants") {
    VStack(spacing: FormaSpacing.large) {
        if let mockFile = FileItem.mocks.first {
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Text("Premium (84px)")
                    .font(.formaBodySemibold)
                HStack(spacing: FormaSpacing.standard) {
                    FormaThumbnail.premium(file: mockFile)
                    FormaThumbnail.premium(file: mockFile, isSelected: true)
                    FormaThumbnail.premium(file: mockFile, showQuickLook: true)
                }
            }

            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Text("Compact (44px)")
                    .font(.formaBodySemibold)
                HStack(spacing: FormaSpacing.standard) {
                    FormaThumbnail.compact(
                        file: mockFile,
                        categoryColors: (mockFile.category.color, mockFile.category.color)
                    )
                    FormaThumbnail.compact(
                        file: mockFile,
                        categoryColors: (mockFile.category.color, mockFile.category.color),
                        isCardHovered: true
                    )
                }
            }

            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Text("Grid (120px)")
                    .font(.formaBodySemibold)
                HStack(spacing: FormaSpacing.standard) {
                    FormaThumbnail.grid(
                        file: mockFile,
                        size: 120,
                        categoryColors: (mockFile.category.color, mockFile.category.color)
                    )
                }
            }
        }
    }
    .padding(FormaSpacing.generous)
    .background(Color.formaBackground)
}
