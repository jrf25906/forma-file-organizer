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

    var onOrganize: (FileItem) -> Void = { _ in }
    var onSkip: ((FileItem) -> Void)? = nil
    var onEditDestination: ((FileItem) -> Void)? = nil
    var onCreateRule: ((FileItem) -> Void)? = nil
    var onViewRule: ((FileItem) -> Void)? = nil
    var onQuickLook: ((FileItem) -> Void)? = nil
    var onToggleSelection: ((FileItem) -> Void)? = nil
    var onThumbnailHover: ((FileItem?, NSEvent?) -> Void)? = nil

    @State private var isHovered = false
    @State private var showQuickLookHint = false
    @State private var showReasoning = false
    @State private var isDestinationHovered = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Constants
    private let categoryBorderWidth: CGFloat = 4

    private var thumbnailSize: CGFloat {
        switch density {
        case .tight: return 54
        case .balanced: return 62
        case .spacious: return 72
        }
    }

    private var rowMinHeight: CGFloat {
        switch density {
        case .tight: return 98
        case .balanced: return 112
        case .spacious: return 128
        }
    }

    private var rowVerticalPadding: CGFloat {
        switch density {
        case .tight: return FormaSpacing.tight - 2
        case .balanced: return FormaSpacing.standard - 2
        case .spacious: return FormaSpacing.standard + 2
        }
    }

    private var contentSpacing: CGFloat {
        switch density {
        case .tight: return FormaSpacing.tight + (FormaSpacing.micro / 2)
        case .balanced: return FormaSpacing.standard
        case .spacious: return FormaSpacing.standard + (FormaSpacing.micro / 2)
        }
    }

    private var infoStackSpacing: CGFloat {
        switch density {
        case .tight: return FormaSpacing.micro + 2
        case .balanced: return FormaSpacing.tight
        case .spacious: return FormaSpacing.tight + 2
        }
    }

    private var chipHorizontalPadding: CGFloat {
        density == .tight ? (FormaSpacing.tight - 2) : FormaSpacing.tight
    }

    private var chipVerticalPadding: CGFloat {
        density == .spacious ? (FormaSpacing.micro + 1) : FormaSpacing.micro
    }

    private var selectionControlEmphasisOpacity: Double {
        (isHovered || isSelectionMode || isSelected) ? 1.0 : 0.72
    }

    // MARK: - Primary Action Configuration
    // Unified terminology: "Organize" when destination exists, "Set Destination" when it doesn't
    // The status pill shows file state, so button label stays consistent
    private var primaryActionConfig: FileRowActionConfig {
        FileRowActionConfig.resolve(
            file: file,
            onOrganize: onOrganize,
            onEditDestination: onEditDestination,
            onCreateRule: onCreateRule
        )
    }

    // Helper function for intelligent path truncation
    private func truncatePath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count <= 2 { return path }
        guard let last = components.last else { return path }
        return "…/\(last)"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Single accent rail communicates priority/category without adding noise
            RoundedRectangle(cornerRadius: categoryBorderWidth / 2)
                .fill(file.category.color.opacity(Color.FormaOpacity.prominent))
                .frame(width: categoryBorderWidth)
                .padding(.vertical, rowVerticalPadding)
                .help("Category: \(file.category.displayName)")

            HStack(alignment: .top, spacing: contentSpacing) {
                // Selection checkbox appears only when relevant.
                if let onToggleSelection = onToggleSelection {
                    FormaCheckbox.premium(
                        isSelected: isSelected,
                        isVisible: true,
                        action: { onToggleSelection(file) }
                    )
                    .opacity(selectionControlEmphasisOpacity)
                    .frame(width: 32, height: 32, alignment: .top)
                    .contentShape(Rectangle())
                    .help(isSelected ? "Deselect file" : "Select file")
                }

                // Keep thumbnail compact so text hierarchy stays dominant.
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

                // File info uses a deliberate 3-level hierarchy:
                // 1) filename + primary state, 2) readable summary line, 3) compact metadata chips.
                VStack(alignment: .leading, spacing: infoStackSpacing) {
                    HStack(spacing: FormaSpacing.tight - 2) {
                        Text(file.name)
                            .font(.formaH3)
                            .foregroundStyle(Color.formaLabel)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        statusChip

                        if let matchType = searchMatchType {
                            SearchMatchBadge(matchType: matchType)
                        }
                    }

                    Text(summaryLineText)
                        .font(.formaBody)
                        .foregroundStyle(Color.formaSecondaryLabelHigh)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: FormaSpacing.micro + 2) {
                        metadataChip(
                            icon: "doc",
                            label: file.fileExtension.uppercased(),
                            foreground: Color.formaSecondaryLabelHigh
                        )

                        metadataChip(
                            icon: "calendar",
                            label: "Age: \(compactAgeText)",
                            foreground: file.ageColor
                        )

                        if let destination = file.destination {
                            metadataChip(
                                icon: destination.isTrash ? "trash" : "folder",
                                label: isDestinationHovered ? destination.displayName : truncatePath(destination.displayName),
                                foreground: Color.formaSteelBlue,
                                background: Color.formaSteelBlue.opacity(isDestinationHovered ? Color.FormaOpacity.medium : Color.FormaOpacity.light)
                            )
                            .onHover { hovering in
                                isDestinationHovered = hovering
                            }
                            .help("Destination: \(destination.displayName)")
                        } else {
                            metadataChip(
                                icon: "questionmark.folder",
                                label: "No destination",
                                foreground: Color.formaSecondaryLabelHigh
                            )
                        }

                        if let confidence = file.confidenceScore {
                            Button(action: { showReasoning.toggle() }) {
                                ConfidenceBadge(
                                    score: confidence,
                                    matchReason: file.matchReason,
                                    showsChevron: true,
                                    isExpanded: showReasoning
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if showReasoning, let reasoning = file.matchReason {
                        ReasoningView(reasoning: reasoning, isExpanded: showReasoning)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if let snippet = contentSnippet {
                        ContentSnippetView(snippet: snippet)
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isHovered)

                Spacer(minLength: contentSpacing)

                HStack(spacing: FormaSpacing.tight - 2) {
                    if isHovered || isFocused {
                        HStack(spacing: 4) {
                            if onSkip != nil {
                                FormaActionButton.icon(
                                    icon: "forward.fill",
                                    color: Color.formaSecondaryLabel,
                                    tooltip: "Skip",
                                    action: { onSkip?(file) }
                                )
                            }

                            FormaActionButton.icon(
                                icon: "eye.fill",
                                color: Color.formaSecondaryLabel,
                                tooltip: "Quick Look",
                                action: { onQuickLook?(file) }
                            )
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }

                    // Primary action ownership is controlled by MainContentView action map.
                    if showsPrimaryActionButton {
                        PrimaryActionButton(
                            label: primaryActionConfig.label,
                            icon: primaryActionConfig.icon,
                            color: primaryActionConfig.color,
                            action: primaryActionConfig.action
                        )
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isHovered)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isFocused)
            }
            .padding(.leading, FormaSpacing.standard)
            .padding(.trailing, FormaSpacing.large)
            .padding(.vertical, rowVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, FormaSpacing.tight)
        .frame(minHeight: rowMinHeight)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous))
        .overlay(cardBorder)
        .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: cardShadowY)
        .scaleEffect(hoverScale)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: isHovered)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: isSelected)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: isFocused)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .if(isSelectionMode && onToggleSelection != nil) { row in
            row.onTapGesture {
                onToggleSelection?(file)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fileRow_\(file.name)")
    }

    // MARK: - Computed Styles

    private var statusChip: some View {
        HStack(spacing: FormaSpacing.micro) {
            Image(systemName: statusChipConfig.icon)
                .font(.formaCaptionSemibold)
            Text(statusChipConfig.label)
                .font(.formaSmallSemibold)
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
                .font(.formaSmall)
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, chipHorizontalPadding)
        .padding(.vertical, chipVerticalPadding)
        .background(
            Capsule(style: .continuous)
                .fill(background)
        )
    }

    private var statusChipConfig: (label: String, icon: String, color: Color) {
        switch file.status {
        case .pending:
            if file.destination == nil {
                return ("Needs Destination", "questionmark.circle.fill", .formaWarning)
            }
            return ("Needs Review", "exclamationmark.circle.fill", .formaWarning)
        case .ready:
            return ("Ready", "checkmark.circle.fill", .formaSage)
        case .completed:
            return ("Organized", "checkmark.seal.fill", .formaSage)
        case .skipped:
            return ("Skipped", "forward.fill", .formaSecondaryLabelHigh)
        }
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

    /// Compact age display: "32d", "7d", "1d", "today"
    private var compactAgeText: String {
        let days = Calendar.current.dateComponents([.day], from: file.creationDate, to: Date()).day ?? 0
        if days > 1 { return "\(days)d" }
        if days == 1 { return "1d" }
        return "today"
    }

    private var ageSummaryText: String {
        compactAgeText == "today" ? "today" : "\(compactAgeText) old"
    }

    private var cardBackground: some View {
        Group {
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
                        Color.formaCardBackground.opacity(Color.FormaOpacity.prominent + Color.FormaOpacity.subtle),
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
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous)
            .strokeBorder(
                isFocused ? Color.formaSteelBlue.opacity(Color.FormaOpacity.prominent) :
                isSelected ? Color.formaSteelBlue.opacity(Color.FormaOpacity.strong) :
                Color.formaBoneWhite.opacity(isHovered ? Color.FormaOpacity.medium : Color.FormaOpacity.light),
                lineWidth: isFocused ? 1.5 : 1
            )
    }

    private var cardShadowColor: Color {
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

    private var cardShadowRadius: CGFloat {
        if isFocused || isSelected { return 10 }
        if isHovered { return 8 }
        return 5
    }

    private var cardShadowY: CGFloat {
        if isFocused || isSelected { return 4 }
        if isHovered { return 3 }
        return 1
    }

    private var hoverScale: CGFloat {
        if isHovered && !isSelected && !isFocused {
            return 1.003
        }
        return 1.0
    }
}

// MARK: - Primary Action Resolver (Testable)

struct FileRowActionConfig {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    static func resolve(
        file: FileItem,
        onOrganize: @escaping (FileItem) -> Void,
        onEditDestination: ((FileItem) -> Void)?,
        onCreateRule: ((FileItem) -> Void)?
    ) -> FileRowActionConfig {
        if file.destination != nil {
            return FileRowActionConfig(
                label: "Organize",
                icon: "checkmark.circle.fill",
                color: file.status == .ready ? .formaSage : .formaSteelBlue,
                action: {
                    if file.status == .ready {
                        onOrganize(file)
                    } else {
                        onEditDestination?(file)
                    }
                }
            )
        }

        return FileRowActionConfig(
            label: "Set Destination",
            icon: "folder.badge.plus",
            color: .formaSteelBlue,
            action: { onCreateRule?(file) }
        )
    }
}


// MARK: - Primary Action Button (Pill Style)

struct PrimaryActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var borderColor: Color {
        Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.16 : 0.24)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.formaSmallSemibold)
                Text(label)
                    .font(.formaSmallSemibold)
            }
            .foregroundStyle(Color.formaBoneWhite)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(isPressed ? 0.9 : (isHovered ? 0.8 : 1.0)))
            )
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .shadow(color: color.opacity(0.3), radius: isHovered ? 4 : 2, x: 0, y: isHovered ? 2 : 1)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isPressed)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Search Match Badge

/// Displays a small badge indicating how a file matched the search query
struct SearchMatchBadge: View {
    let matchType: ContentSearchService.MatchType

    private var config: (icon: String, label: String, color: Color) {
        switch matchType {
        case .filename:
            return ("textformat", "Name", .formaSteelBlue)
        case .content:
            return ("doc.text.magnifyingglass", "Content", .formaWarmOrange)
        case .both:
            return ("checkmark.circle.fill", "Name + Content", .formaSage)
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: config.icon)
                .font(.formaMicro)
            Text(config.label)
                .font(.formaCaptionSemibold)
        }
        .foregroundStyle(config.color)
        .padding(.horizontal, FormaSpacing.tight - (FormaSpacing.micro / 2))
        .padding(.vertical, FormaSpacing.micro / 2)
        .background(config.color.opacity(Color.FormaOpacity.medium))
        .overlay(
            Capsule()
                .strokeBorder(config.color.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

// MARK: - Content Snippet View

/// Displays a snippet of file content showing where the search term was found
struct ContentSnippetView: View {
    let snippet: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "text.quote")
                .font(.formaCaptionSemibold)
                .foregroundStyle(Color.formaSecondaryLabelHigh)

            Text(snippet)
                .font(.formaSmall)
                .foregroundStyle(Color.formaSecondaryLabelHigh)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
        .background(Color.formaObsidian.opacity(Color.FormaOpacity.light))
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous))
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
