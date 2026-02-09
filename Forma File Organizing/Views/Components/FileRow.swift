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
    var onQuickLook: ((FileItem) -> Void)? = nil
    var onToggleSelection: ((FileItem) -> Void)? = nil
    var onThumbnailHover: ((FileItem?, NSEvent?) -> Void)? = nil

    @State private var isHovered = false
    @State private var showQuickLookHint = false
    @State private var isDestinationHovered = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Constants
    private let categoryRailWidth: CGFloat = 2

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

    // Helper function for intelligent path truncation
    private func truncatePath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count <= 2 { return path }
        guard let last = components.last else { return path }
        return "\u{2026}/\(last)"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Single accent rail communicates priority/category without adding noise
            RoundedRectangle(cornerRadius: categoryRailWidth / 2)
                .fill(file.category.color.opacity(Color.FormaOpacity.prominent))
                .frame(width: categoryRailWidth)
                .padding(.vertical, rowVerticalPadding)
                .help("Category: \(file.category.displayName)")

            HStack(alignment: .center, spacing: contentSpacing) {
                // Selection checkbox appears only when relevant.
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

                // 2-line layout: (1) filename + destination pill, (2) metadata
                VStack(alignment: .leading, spacing: infoStackSpacing) {
                    // Line 1 — Filename [search badge] ... [destination pill]
                    HStack(spacing: FormaSpacing.tight - 2) {
                        Text(file.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.formaLabel)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if let matchType = searchMatchType {
                            SearchMatchBadge(matchType: matchType)
                        }

                        Spacer(minLength: FormaSpacing.tight)

                        // Destination badge (right-justified)
                        if let onChangeDestination, !availableDestinations.isEmpty {
                            destinationPicker(onChangeDestination: onChangeDestination)
                        } else if let destination = file.destination {
                            destinationBadge(
                                text: truncatePath(destination.displayName),
                                icon: destination.isTrash ? "trash" : "folder",
                                color: Color.formaSteelBlue
                            )
                            .help("Destination: \(destination.displayName)")
                        } else {
                            Button(action: { onEditDestination?(file) }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.formaCaptionSemibold)
                                    Text("Set destination")
                                        .font(.formaCaptionSemibold)
                                        .lineLimit(1)
                                }
                                .foregroundStyle(Color.formaSteelBlue)
                                .padding(.horizontal, FormaSpacing.tight)
                                .padding(.vertical, FormaSpacing.micro)
                                .background(
                                    Capsule()
                                        .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.formaSteelBlue.opacity(Color.FormaOpacity.medium), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Set file destination")
                        }
                    }

                    // Line 2 — Static metadata + Active status
                    HStack(spacing: FormaSpacing.tight) {
                        // Static metadata: type + age with icons
                        HStack(spacing: FormaSpacing.tight - 2) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc")
                                    .font(.system(size: 9))
                                Text(file.fileExtension.uppercased())
                                    .font(.formaSmall)
                            }
                            .foregroundStyle(Color.formaTertiaryLabel)

                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text(compactAgeText)
                                    .font(.formaSmall)
                            }
                            .foregroundStyle(Color.formaTertiaryLabel)
                        }

                        // Active metadata: status dot
                        Circle()
                            .fill(statusIndicatorConfig.color)
                            .frame(width: 6, height: 6)
                            .help(statusIndicatorConfig.label)

                    }

                    if let snippet = contentSnippet {
                        ContentSnippetView(snippet: snippet)
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isHovered)

                Spacer(minLength: contentSpacing)

                HStack(spacing: FormaSpacing.tight - 2) {
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
            .padding(.leading, contentLeadingPadding)
            .padding(.trailing, contentTrailingPadding)
            .padding(.vertical, rowVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, FormaSpacing.tight)
        .frame(minHeight: rowMinHeight)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous))
        .overlay(cardBorder)
        .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: cardShadowY)
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
    }

    // MARK: - Destination Badge

    /// Static destination badge (non-interactive fallback), styled like ConfidenceBadge.
    private func destinationBadge(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.formaCaptionSemibold)
            Text(text)
                .font(.formaCaptionSemibold)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(color)
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
        .background(
            Capsule()
                .fill(color.opacity(Color.FormaOpacity.light))
        )
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(Color.FormaOpacity.medium), lineWidth: 1)
        )
    }

    // MARK: - Inline Destination Picker

    /// Menu styled like ConfidenceBadge that lets users change destination without leaving the card.
    private func destinationPicker(onChangeDestination: @escaping (FileItem, Destination) -> Void) -> some View {
        Menu {
            // Current destination (checked)
            if let current = file.destination {
                Button(action: {}) {
                    Label(current.displayName, systemImage: current.isTrash ? "trash" : "folder")
                }
                .disabled(true)

                Divider()
            }

            // Available destinations (excluding current)
            let otherDestinations = availableDestinations.filter { $0 != file.destination }
            ForEach(Array(otherDestinations.prefix(8).enumerated()), id: \.offset) { _, dest in
                Button(action: { onChangeDestination(file, dest) }) {
                    Label(dest.displayName, systemImage: dest.isTrash ? "trash" : "folder")
                }
            }

            if !otherDestinations.isEmpty {
                Divider()
            }

            // Trash option (if not already trash)
            if file.destination?.isTrash != true {
                Button(action: { onChangeDestination(file, .trash) }) {
                    Label("Trash", systemImage: "trash")
                }
            }

            Divider()

            // Browse for folder
            Button(action: { onEditDestination?(file) }) {
                Label("Browse\u{2026}", systemImage: "folder.badge.plus")
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: file.destination != nil ? "folder" : "questionmark.folder")
                    .font(.formaCaptionSemibold)

                if let destination = file.destination {
                    Text(truncatePath(destination.displayName))
                        .font(.formaCaptionSemibold)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Set destination")
                        .font(.formaCaptionSemibold)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.formaCaptionSemibold)
            }
            .foregroundStyle(destinationPickerColor)
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro)
            .background(
                Capsule()
                    .fill(destinationPickerColor.opacity(Color.FormaOpacity.light))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        destinationPickerColor.opacity(isDestinationHovered ? Color.FormaOpacity.overlay : Color.FormaOpacity.medium),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isDestinationHovered ? 1.05 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: isDestinationHovered)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .onHover { hovering in
            isDestinationHovered = hovering
        }
        .help(file.destination != nil ? "Change destination" : "Set destination")
    }

    private var destinationPickerColor: Color {
        file.destination != nil ? Color.formaSteelBlue : Color.formaSecondaryLabelHigh
    }

    // MARK: - Computed Styles

    /// Single-line metadata string: "PDF · 32d · Review"
    private var metadataString: String {
        let segments: [String] = [
            file.fileExtension.uppercased(),
            compactAgeText,
            statusIndicatorConfig.label
        ]
        return segments.joined(separator: " \u{00B7} ")
    }

    private var statusIndicatorConfig: (label: String, color: Color) {
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

    /// Compact age display: "32d", "7d", "1d", "today"
    private var compactAgeText: String {
        let days = Calendar.current.dateComponents([.day], from: file.creationDate, to: Date()).day ?? 0
        if days > 1 { return "\(days)d" }
        if days == 1 { return "1d" }
        return "today"
    }

    private var cardBackground: some View {
        Group {
            if isSelected || isFocused {
                Color.formaSteelBlue.opacity(0.12)
            } else {
                Color.formaCardBackground
            }
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
            .strokeBorder(
                isFocused ? Color.formaSteelBlue.opacity(0.80) :
                isSelected ? Color.formaSteelBlue.opacity(0.50) :
                isHovered ? Color.formaSeparator.opacity(0.8) :
                Color.formaSeparator.opacity(0.5),
                lineWidth: isFocused ? 1.5 : (isSelected ? 1 : 0.5)
            )
    }

    private var cardShadowColor: Color {
        if isFocused {
            return Color.formaSteelBlue.opacity(0.10)
        } else if isSelected {
            return Color.clear
        } else if isHovered {
            return Color.formaObsidian.opacity(0.05)
        } else {
            return Color.clear
        }
    }

    private var cardShadowRadius: CGFloat {
        if isFocused { return 4 }
        if isHovered { return 2 }
        return 0
    }

    private var cardShadowY: CGFloat {
        if isFocused { return 0 }
        if isHovered { return 1 }
        return 0
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.formaSmallSemibold)
                Text(label)
                    .font(.formaSmallSemibold)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(isPressed ? 0.20 : (isHovered ? 0.18 : 0.12)))
            )
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(isHovered ? 0.35 : 0.20), lineWidth: 1)
            )
            .shadow(color: Color.clear, radius: 0, x: 0, y: 0)
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
