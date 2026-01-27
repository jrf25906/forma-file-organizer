import SwiftUI

// MARK: - Premium File Card Component
// Redesigned for Apple Design Award quality
// Features: Progressive disclosure, premium thumbnail treatment, refined visual hierarchy

struct FileRow: View {
    let file: FileItem

    // State & Callbacks
    var isFocused: Bool = false
    var isSelected: Bool = false
    var isSelectionMode: Bool = false
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
    @State private var showActions = false
    @State private var showReasoning = false
    @State private var isDestinationHovered = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Constants
    private let categoryBorderWidth: CGFloat = 4

    // MARK: - Primary Action Configuration
    // Unified terminology: "Organize" when destination exists, "Set Destination" when it doesn't
    // The status pill shows file state, so button label stays consistent
    private var primaryActionConfig: (label: String, icon: String, color: Color, action: () -> Void) {
        if file.destination != nil {
            // Has destination - always show "Organize" (status pill explains if confirmation needed)
            return (
                "Organize",
                "checkmark.circle.fill",
                file.status == .ready ? .formaSage : .formaSteelBlue,
                {
                    if file.status == .ready {
                        onOrganize(file)
                    } else {
                        // Opens destination editor for confirmation
                        onEditDestination?(file)
                    }
                }
            )
        } else {
            // No destination - clear action label
            return (
                "Set Destination",
                "folder.badge.plus",
                .formaSteelBlue,
                { onCreateRule?(file) }
            )
        }
    }

    // Helper function for intelligent path truncation
    private func truncatePath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count <= 2 { return path }
        let last = components.last!
        return "…/\(last)"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Category color accent bar (left border)
            RoundedRectangle(cornerRadius: categoryBorderWidth / 2)
                .fill(file.category.color.opacity(Color.FormaOpacity.prominent))
                .frame(width: categoryBorderWidth)
                .padding(.vertical, FormaSpacing.standard)
                .help("Category: \(file.category.displayName)")

            HStack(spacing: FormaSpacing.standard) {
                // Selection Checkbox - appears on hover/selection
                if let onToggleSelection = onToggleSelection {
                    FormaCheckbox.premium(
                        isSelected: isSelected,
                        isVisible: isHovered || isSelectionMode || isSelected,
                        action: { onToggleSelection(file) }
                    )
                    .frame(width: 24)
                }

                // Premium Thumbnail (compact)
                FormaThumbnail.premium(
                    file: file,
                    size: 68,
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

            // File Info - Clear hierarchy
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                // Primary: Filename (most prominent) with search match indicator
                HStack(spacing: 6) {
                    Text(file.name)
                        .font(.title3) // Specific request for larger filename
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.formaLabel)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    // Search match type badge
                    if let matchType = searchMatchType {
                        SearchMatchBadge(matchType: matchType)
                    }
                }

                // Secondary: Destination badge (if exists)
                if let destination = file.destination {
                    let displayName = destination.displayName
                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                        HStack(spacing: 6) {
                            // Destination info with hover-to-expand full path
                            HStack(spacing: 5) {
                                Image(systemName: "folder.fill")
                                    .font(.formaSmallMedium)
                                Text(isDestinationHovered ? displayName : truncatePath(displayName))
                                    .lineLimit(1)
                                    .animation(.easeInOut(duration: 0.15), value: isDestinationHovered)
                            }
                            .font(.formaCompactMedium)
                            .foregroundStyle(Color.formaSteelBlue)
                            .padding(.horizontal, FormaSpacing.tight + (FormaSpacing.micro / 2))
                            .padding(.vertical, FormaSpacing.micro)
                            .background(Color.formaSteelBlue.opacity(isDestinationHovered ? Color.FormaOpacity.light : Color.FormaOpacity.light))
                            .clipShape(Capsule())
                            .onHover { hovering in
                                isDestinationHovered = hovering
                            }
                            .help("Destination: \(displayName)")
                            
                            // Confidence indicator (if available)
                            if let confidence = file.confidenceScore {
                                Button(action: { showReasoning.toggle() }) {
                                    ConfidenceBadge(score: confidence, matchReason: file.matchReason, showsChevron: true, isExpanded: showReasoning)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Expandable reasoning section
                        if showReasoning, let reasoning = file.matchReason {
                            ReasoningView(reasoning: reasoning, isExpanded: showReasoning)
                        }
                    }
                }

                // Tertiary: Compact metadata line
                HStack(spacing: FormaSpacing.tight) {
                    // Status pill (only show if not pending, since context already implies pending)
                    if file.status != .pending {
                        FormaStatusPill(status: file.status)
                    }

                    // Consolidated metadata: .ext · age · reason
                    HStack(spacing: 0) {
                        Text(".\(file.fileExtension.lowercased())")
                            .foregroundStyle(Color.formaSecondaryLabel)

                        Text(" · ")
                            .foregroundStyle(Color.formaTertiaryLabel)

                        Text(compactAgeText)
                            .foregroundStyle(file.ageColor)

                        // Show match reason if available
                        if let reason = file.matchReason {
                            Text(" · ")
                                .foregroundStyle(Color.formaTertiaryLabel)
                            Text(reason)
                                .foregroundStyle(Color.formaSteelBlue)
                        }
                    }
                    .font(.formaCompact)
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)

                // Content Search Snippet (shows when file matched by content)
                if let snippet = contentSnippet {
                    ContentSnippetView(snippet: snippet)
                }
            }

            Spacer(minLength: FormaSpacing.standard)

            // Action Buttons
            HStack(spacing: 12) {
                // Secondary actions (fade in on hover)
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

                // Primary action - Pill style for prominence
                PrimaryActionButton(
                    label: primaryActionConfig.label,
                    icon: primaryActionConfig.icon,
                    color: primaryActionConfig.color,
                    action: primaryActionConfig.action
                )
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isHovered)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isFocused)
            }
            .padding(.leading, FormaSpacing.standard)
            .padding(.trailing, FormaSpacing.large)
        }
        .padding(.leading, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.standard)
        .frame(height: 100)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .overlay(cardBorder)
        .shadow(color: cardShadowColor, radius: cardShadowRadius, x: 0, y: cardShadowY)
        .scaleEffect(hoverScale)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            if isSelectionMode, let onToggleSelection = onToggleSelection {
                onToggleSelection(file)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fileRow_\(file.name)")
    }

    // MARK: - Computed Styles

    private var ageContextText: String {
        let age = Date().timeIntervalSince(file.creationDate)
        if age > 2592000 { return "Over 30 days old" } // 30 days
        if age > 604800 { return "Over 7 days old" }   // 7 days
        if age > 86400 { return "Yesterday" }
        return "New today"
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
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
            .strokeBorder(
                isFocused ? Color.formaSteelBlue :
                isSelected ? Color.formaSteelBlue.opacity(Color.FormaOpacity.strong) :
                isHovered ? Color.formaObsidian.opacity(Color.FormaOpacity.light) :
                Color.formaObsidian.opacity(Color.FormaOpacity.subtle),
                lineWidth: isFocused ? 2 : (isSelected ? 1.5 : 1)
            )
    }

    private var cardShadowColor: Color {
        if isFocused {
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
        } else if isSelected {
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle)
        } else if isHovered {
            return Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
        } else {
            return Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle)
        }
    }

    private var cardShadowRadius: CGFloat {
        if isFocused || isSelected { return 6 }
        if isHovered { return 4 }
        return 2
    }

    private var cardShadowY: CGFloat {
        if isFocused || isSelected { return 2 }
        if isHovered { return 1 }
        return 1
    }

    private var hoverScale: CGFloat {
        if isHovered && !isSelected && !isFocused {
            return 1.005
        }
        return 1.0
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
            .foregroundStyle(Color.formaBoneWhite)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(isPressed ? 0.9 : (isHovered ? 0.8 : 1.0)))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
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

// MARK: - Confidence Badge Component

struct ConfidenceBadge: View {
    let score: Double
    let matchReason: String?
    var showsChevron: Bool = false
    var isExpanded: Bool = false
    
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    private var confidenceLevel: (label: String, icon: String, color: Color) {
        if score >= 0.9 {
            return ("High", "checkmark.shield.fill", .formaSage)
        } else if score >= 0.6 {
            return ("Medium", "checkmark.circle.fill", .formaSteelBlue)
        } else {
            return ("Low", "exclamationmark.triangle.fill", .formaWarmOrange)
        }
    }
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: confidenceLevel.icon)
                .font(.formaCaptionSemibold)
            Text(confidenceLevel.label)
                .font(.formaCaptionSemibold)

            if showsChevron {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.formaCaptionSemibold)
            }
        }
        .foregroundStyle(confidenceLevel.color)
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
        .background(
            Capsule()
                .fill(confidenceLevel.color.opacity(Color.FormaOpacity.light))
        )
        .overlay(
            Capsule()
                .strokeBorder(confidenceLevel.color.opacity(isHovered ? Color.FormaOpacity.overlay : Color.FormaOpacity.medium), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.8), value: isExpanded)
        .help(showsChevron ? "Tap to \(isExpanded ? "hide" : "show") details" : tooltipText)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var tooltipText: String {
        var text = "Confidence: \(confidenceLevel.label) (\(Int(score * 100))%)"
        if let reason = matchReason, !reason.isEmpty {
            text += "\n\n\(reason)"
        }
        return text
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
        .background(config.color.opacity(Color.FormaOpacity.light))
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
                .foregroundStyle(.secondary)

            Text(snippet)
                .font(.formaSmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
        .background(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
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
