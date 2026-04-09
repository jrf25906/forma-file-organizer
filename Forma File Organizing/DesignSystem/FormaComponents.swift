//
//  FormaComponents.swift
//  Forma - Reusable UI Components
//
//  Implementation of Forma brand UI components
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI

// MARK: - Card Container

struct FormaCard<Content: View>: View {
    let content: Content
    var isSelected: Bool = false

    init(isSelected: Bool = false, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.content = content()
    }

    var body: some View {
        content
            .formaCardPadding()
            .background(Color.formaControlBackground)
            .formaCornerRadius(FormaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .stroke(
                        isSelected ? Color.formaSteelBlue : Color.formaSeparator,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .formaShadow(isSelected ? .cardSelected : .card)
    }
}

// MARK: - List Card Modifier

/// A lighter-weight card style for list views that maintains visual consistency
/// with the main card view but is more compact and suitable for dense lists
struct FormaListCard: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if isSelected {
                        // Slightly more subtle gradient for list view
                        LinearGradient(
                            colors: [
                                Color.formaSteelBlue.opacity(Color.FormaOpacity.light),
                                Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle + (Color.FormaOpacity.ultraSubtle / 2))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else if isHovered {
                        Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
                    } else {
                        Color.formaBoneWhite
                    }
                }
            )
            .formaCornerRadius(FormaRadius.card) // Large card radius for consistency
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.formaSteelBlue.opacity(Color.FormaOpacity.strong)
                            : Color.formaObsidian.opacity(Color.FormaOpacity.subtle + (Color.FormaOpacity.ultraSubtle / 2)),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .formaShadow(isSelected ? .cardSelected : .card)
    }
}

extension View {
    func formaListCard(isSelected: Bool, isHovered: Bool) -> some View {
        modifier(FormaListCard(isSelected: isSelected, isHovered: isHovered))
    }
}

// MARK: - Progress Bar

struct FormaProgressBar: View {
    var progress: Double // 0.0 to 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.formaObsidian.opacity(Color.FormaOpacity.light))
                    .frame(height: 2)
                
                // Fill
                Rectangle()
                    .fill(Color.formaSteelBlue)
                    .frame(width: geometry.size.width * CGFloat(progress), height: 2)
                    .animation(.easeInOut(duration: 0.2), value: progress)
            }
        }
        .frame(height: 2)
    }
}

// MARK: - Success Indicator

struct FormaSuccessIndicator: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.formaIcon)
            .foregroundColor(.formaSage)
    }
}

// MARK: - File Count Badge

struct FormaFileBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.formaSmall)
            .fontWeight(.semibold)
            .foregroundColor(.formaBoneWhite)
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro)
            .background(
                Capsule()
                    .fill(Color.formaSteelBlue)
            )
    }
}

// MARK: - Status Pill

/// A compact pill-shaped indicator showing file organization status.
/// Used in FileRow to communicate the current state of a file to users.
///
/// Usage:
/// ```swift
/// FormaStatusPill(status: file.status)
/// ```
struct FormaStatusPill: View {
    let status: FileItem.OrganizationStatus

    private var config: (text: String, icon: String, color: Color) {
        switch status {
        case .pending:
            // Using muted blue instead of warm orange - calmer "needs attention" state
            // that doesn't feel alarming or compete with media category color
            return ("Needs Destination", "questionmark.circle", .formaTertiaryLabel)
        case .ready:
            return ("Ready", "checkmark.circle", .formaSage)
        case .completed:
            return ("Organized", "checkmark.seal.fill", .formaSage.opacity(Color.FormaOpacity.high))
        case .skipped:
            return ("Skipped", "forward.fill", .formaSecondaryLabel)
        }
    }

    var body: some View {
        HStack(spacing: FormaSpacing.micro) {
            Image(systemName: config.icon)
                .font(.formaMicro)
                .fontWeight(.semibold)
            Text(config.text)
                .font(.formaCaption)
                .fontWeight(.medium)
        }
        .foregroundStyle(config.color)
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
        .background(config.color.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle))
        .clipShape(Capsule())
    }
}

#Preview("Status Pills") {
    VStack(spacing: 12) {
        FormaStatusPill(status: .pending)
        FormaStatusPill(status: .ready)
        FormaStatusPill(status: .completed)
        FormaStatusPill(status: .skipped)
    }
    .padding()
    .background(Color.formaBackground)
}

// MARK: - Logo Mark

struct FormaLogo: View {
    enum Style {
        case mark      // Just the geometric icon
        case lockup    // Icon + "Forma" wordmark
    }

    let style: Style
    let height: CGFloat

    init(style: Style = .mark, height: CGFloat = 32) {
        self.style = style
        self.height = height
    }

    var body: some View {
        Image("logo-mark")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: height)
    }
}

// MARK: - Category Icon

struct FormaCategoryIcon: View {
    let category: FileTypeCategory
    let font: Font
    
    init(category: FileTypeCategory, font: Font = .formaH1) {
        self.category = category
        self.font = font
    }
    
    var body: some View {
        Image(systemName: category.iconName)
            .font(font)
            .foregroundColor(category.color)
    }
}

// MARK: - File List Item

struct FormaFileListItem: View {
    let fileName: String
    let fileCategory: FileTypeCategory
    let destination: String
    var isSelected: Bool = false
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: FormaSpacing.standard) {
                // Category icon
                FormaCategoryIcon(category: fileCategory, font: .formaIconMedium)
                
                VStack(alignment: .leading, spacing: 4) {
                    // File name
                    Text(fileName)
                        .formaBodyStyle()
                    
                    // Destination
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.formaSmall)
                        Text(destination)
                            .formaMetadataStyle()
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.formaSteelBlue)
                }
            }
            .padding(FormaSpacing.standard)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(isSelected ? Color.formaSteelBlue.opacity(Color.FormaOpacity.light) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty State View

struct FormaEmptyState: View {
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    
    init(title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: FormaSpacing.generous) {
            Spacer()
            
            // Icon or illustration would go here
            Image(systemName: "folder.badge.questionmark")
                .font(.formaIconLarge)
                .foregroundColor(.formaSecondaryLabelHigh)
            
            VStack(spacing: FormaSpacing.tight) {
                Text(title)
                    .formaH2Style()
                
                Text(message)
                    .font(.formaBody)
                    .foregroundColor(messageColor)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                FormaPrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 200)
            }
            
            Spacer()
        }
        .frame(maxWidth: 400)
        .padding(FormaSpacing.extraLarge)
    }

    private var messageColor: Color {
        colorScheme == .dark
            ? .formaSecondaryLabelHigh
            : Color.formaLabel.opacity(0.7)
    }
}

// MARK: - Actionable Empty State View

/// An empty state variant that presents a curated list of next actions
/// rather than a single primary button.
struct FormaActionableEmptyState<ActionContent: View>: View {
    let title: String
    let message: String
    let iconName: String
    let iconColor: Color
    @ViewBuilder let actions: () -> ActionContent

    @Environment(\.colorScheme) private var colorScheme
    @State private var showCelebration = false
    @State private var checkmarkScale: CGFloat = 0.5
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: FormaSpacing.generous) {
            Spacer()

            // Success checkmark with spring animation
            ZStack {
                Circle()
                    .fill(iconColor.opacity(Color.FormaOpacity.light + Color.FormaOpacity.subtle))
                    .frame(width: 100, height: 100)
                
                Image(systemName: iconName)
                    .font(.formaIconLarge)
                    .foregroundColor(iconColor)
                    .scaleEffect(checkmarkScale)
            }
            .scaleEffect(showCelebration ? 1.0 : 0.5)
            .opacity(showCelebration ? 1.0 : 0.0)
            
            VStack(spacing: FormaSpacing.tight) {
                Text(title)
                    .formaH2Style()
                
                Text(message)
                    .font(.formaBody)
                    .foregroundColor(messageColor)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Next actions section
            VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                Text("What's next?")
                    .font(.formaBodyBold)
                    .foregroundColor(.formaLabel)
                
                VStack(spacing: FormaSpacing.tight) {
                    actions()
                }
            }
            .padding(FormaSpacing.generous)
            .background(Color.formaControlBackground.opacity(Color.FormaOpacity.overlay))
            .formaCornerRadius(FormaRadius.card)
            
            Spacer()
        }
        .padding(.horizontal, FormaSpacing.extraLarge + (FormaSpacing.standard - FormaSpacing.micro))
        .padding(.vertical, FormaSpacing.large + FormaSpacing.tight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                    showCelebration = true
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                    checkmarkScale = 1.0
                }
            } else {
                showCelebration = true
                checkmarkScale = 1.0
            }
        }
    }

    private var messageColor: Color {
        colorScheme == .dark
            ? .formaSecondaryLabelHigh
            : Color.formaLabel.opacity(0.7)
    }
}

// MARK: - Loading Spinner

// MARK: - Preview Helpers

#Preview("Card") {
    VStack(spacing: 20) {
        FormaCard {
            Text("Unselected Card Content")
                .formaBodyStyle()
        }
        
        FormaCard(isSelected: true) {
            Text("Selected Card Content")
                .formaBodyStyle()
        }
    }
    .padding()
    .frame(width: 300)
}

#Preview("Progress Bar") {
    VStack(spacing: 20) {
        FormaProgressBar(progress: 0.0)
        FormaProgressBar(progress: 0.5)
        FormaProgressBar(progress: 1.0)
    }
    .padding()
    .frame(width: 300)
}

#Preview("File List Item") {
    FormaFileListItem(
        fileName: "invoice-2024.pdf",
        fileCategory: .documents,
        destination: "Documents/Finance/Invoices",
        isSelected: true,
        onSelect: {}
    )
    .frame(width: 400)
}

#Preview("Empty State") {
    FormaEmptyState(
        title: "No Files to Organize",
        message: "Your Desktop is clean! When files need organizing, they'll appear here.",
        actionTitle: "Scan Now",
        action: {}
    )
}

#Preview("Logo") {
    VStack(spacing: 30) {
        FormaLogo(style: .mark, height: 64)
        FormaLogo(style: .mark, height: 32)
        FormaLogo(style: .mark, height: 24)
    }
    .padding()
}

// MARK: - Form Controls

/// A standard text field matching the Forma design system
struct FormaTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var hasError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(title)
                .font(.formaBodySemibold)
                .foregroundStyle(Color.formaSecondaryLabel)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(FormaSpacing.standard - FormaSpacing.micro)
                .background(Color.formaCardBackground)
                .formaCornerRadius(FormaRadius.control)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .strokeBorder(
                            hasError ? Color.formaWarmOrange : Color.formaSeparator.opacity(Color.FormaOpacity.strong),
                            lineWidth: 1
                        )
                )
        }
    }
}

/// A standard folder picker control matching the Forma design system
struct FormaFolderPicker: View {
    let title: String
    let displayPath: String
    let hasSelection: Bool
    var hasError: Bool = false
    let onSelect: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(title)
                .font(.formaBodySemibold)
                .foregroundStyle(Color.formaSecondaryLabel)

            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Image(systemName: hasSelection ? "folder.fill" : "folder.badge.plus")
                        .font(.formaBodyLarge)
                        .foregroundStyle(hasSelection ? Color.formaSteelBlue : Color.formaSecondaryLabel)

                    Text(displayPath.isEmpty ? "Select a folder…" : displayPath)
                        .font(.formaBodySemibold)
                        .foregroundStyle(hasSelection ? Color.formaLabel : Color.formaSecondaryLabel)

                    Spacer()

                    if hasSelection {
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.formaSecondaryLabel)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(FormaSpacing.standard - FormaSpacing.micro)
                .background(Color.formaCardBackground)
                .formaCornerRadius(FormaRadius.control)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                        .strokeBorder(
                            hasError ? Color.formaWarmOrange : (hasSelection ? Color.formaSteelBlue.opacity(Color.FormaOpacity.strong) : Color.formaSeparator.opacity(Color.FormaOpacity.strong)),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Generic Badge Component

/// A versatile badge for status indicators, counts, and labels.
/// Supports various sizes and color schemes for consistent badge rendering across the app.
///
/// Usage:
/// ```swift
/// FormaBadge("New", color: .formaSteelBlue)
/// FormaBadge("3", color: .formaSage, size: .small)
/// FormaBadge("Warning", color: .orange, style: .outlined)
/// ```
struct FormaBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil
    var size: BadgeSize = .regular
    var style: BadgeStyle = .filled

    enum BadgeSize {
        case small   // Compact badges for counts
        case regular // Standard badges
        case large   // Prominent badges

        var font: Font {
            switch self {
            case .small: return .formaCaptionSemibold
            case .regular: return .formaSmallSemibold
            case .large: return .formaCompactSemibold
            }
        }

        var iconFont: Font {
            switch self {
            case .small: return .formaCaptionSemibold
            case .regular: return .formaSmallMedium
            case .large: return .formaCompactMedium
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 6
            case .regular: return 8
            case .large: return 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 2
            case .regular: return 4
            case .large: return 6
            }
        }
    }

    enum BadgeStyle {
        case filled   // Solid background
        case outlined // Border only
        case subtle   // Light background tint
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(size.iconFont)
            }
            Text(text)
                .font(size.font)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(background)
        .clipShape(Capsule())
        .overlay(borderOverlay)
    }

    private var foregroundColor: Color {
        switch style {
        case .filled: return .white
        case .outlined, .subtle: return color
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .filled:
            Capsule().fill(color)
        case .outlined:
            Color.clear
        case .subtle:
            Capsule().fill(color.opacity(Color.FormaOpacity.light))
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch style {
        case .outlined:
            Capsule().stroke(color, lineWidth: 1)
        default:
            EmptyView()
        }
    }
}

#Preview("FormaBadge") {
    VStack(spacing: 16) {
        // Filled style
        HStack(spacing: 8) {
            FormaBadge(text: "New", color: .formaSteelBlue)
            FormaBadge(text: "3", color: .formaSage, size: .small)
            FormaBadge(text: "Important", color: .formaWarmOrange, size: .large)
        }

        // Subtle style
        HStack(spacing: 8) {
            FormaBadge(text: "Draft", color: .formaSecondaryLabel, style: .subtle)
            FormaBadge(text: "Pending", color: .orange, style: .subtle)
            FormaBadge(text: "Complete", color: .formaSage, icon: "checkmark", style: .subtle)
        }

        // Outlined style
        HStack(spacing: 8) {
            FormaBadge(text: "Optional", color: .formaSecondaryLabel, style: .outlined)
            FormaBadge(text: "Beta", color: .formaSteelBlue, style: .outlined)
        }
    }
    .padding()
    .background(Color.formaBackground)
}

// MARK: - List Action Button

/// A list-style action button with icon, title, optional subtitle, and chevron.
/// Used for navigation items, settings rows, and action lists.
///
/// Usage:
/// ```swift
/// FormaListButton(
///     icon: "folder",
///     title: "Choose Folder",
///     action: { showFolderPicker() }
/// )
///
/// FormaListButton(
///     icon: "gear",
///     title: "Settings",
///     subtitle: "Configure app preferences",
///     action: { openSettings() }
/// )
/// ```
struct FormaListButton: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var iconColor: Color = .formaSteelBlue
    var showChevron: Bool = true
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.standard) {
                // Icon
                Image(systemName: icon)
                    .font(.formaBody)
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.formaBodyMedium)
                        .foregroundColor(.formaLabel)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.formaSmall)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                }

                Spacer()

                // Chevron
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.formaSmall)
                        .foregroundColor(.formaTertiaryLabel)
                }
            }
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.tight + FormaSpacing.micro)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(isHovered ? Color.formaObsidian.opacity(Color.FormaOpacity.subtle) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview("FormaListButton") {
    VStack(spacing: 0) {
        FormaListButton(
            icon: "folder",
            title: "Choose Folder",
            action: {}
        )

        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

        FormaListButton(
            icon: "gear",
            title: "Settings",
            subtitle: "Configure app preferences",
            action: {}
        )

        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

        FormaListButton(
            icon: "arrow.triangle.2.circlepath",
            title: "Sync Status",
            subtitle: "Last synced 5 minutes ago",
            iconColor: .formaSage,
            action: {}
        )

        Divider().padding(.leading, FormaSpacing.extraLarge + FormaSpacing.tight)

        FormaListButton(
            icon: "questionmark.circle",
            title: "Help & Support",
            showChevron: false,
            action: {}
        )
    }
    .padding()
    .background(Color.formaBackground)
    .frame(width: 320)
}

// MARK: - Stat Badge

/// A badge for displaying metrics and statistics with value and label.
/// Used in analytics views, dashboards, and summaries.
///
/// Usage:
/// ```swift
/// FormaStatBadge(value: "42", label: "Files Organized")
/// FormaStatBadge(value: "1.2GB", label: "Space Saved", color: .formaSage)
/// ```
struct FormaStatBadge: View {
    let value: String
    let label: String
    var color: Color = .formaSteelBlue
    var icon: String? = nil

    var body: some View {
        VStack(spacing: FormaSpacing.micro) {
            HStack(spacing: FormaSpacing.micro) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.formaSmall)
                        .foregroundColor(color)
                }
                Text(value)
                    .font(.formaH2)
                    .foregroundColor(color)
            }

            Text(label)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
        }
        .padding(.horizontal, FormaSpacing.standard)
        .padding(.vertical, FormaSpacing.tight)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .fill(color.opacity(Color.FormaOpacity.subtle))
        )
    }
}

#Preview("FormaStatBadge") {
    HStack(spacing: 16) {
        FormaStatBadge(value: "42", label: "Files")
        FormaStatBadge(value: "1.2GB", label: "Saved", color: .formaSage, icon: "arrow.down.circle")
        FormaStatBadge(value: "98%", label: "Match Rate", color: .formaWarmOrange)
    }
    .padding()
    .background(Color.formaBackground)
}

// MARK: - Hero Icon Container

/// A large decorative icon container for empty states and celebration screens.
/// Provides consistent styling for prominent icons throughout the app.
///
/// Usage:
/// ```swift
/// FormaHeroIcon(systemName: "checkmark.circle.fill", color: .formaSage)
/// FormaHeroIcon(systemName: "folder.badge.plus", style: .subtle)
/// ```
struct FormaHeroIcon: View {
    let systemName: String
    var color: Color = .formaSteelBlue
    var size: HeroSize = .regular
    var style: HeroStyle = .prominent

    enum HeroSize {
        case regular  // 48pt icon
        case large    // 64pt icon

        var font: Font {
            switch self {
            case .regular: return .formaIcon
            case .large: return .formaIconLarge
            }
        }

        var containerSize: CGFloat {
            switch self {
            case .regular: return 80
            case .large: return 100
            }
        }
    }

    enum HeroStyle {
        case prominent  // Colored icon with tinted background
        case subtle     // Muted icon for secondary empty states
    }

    var body: some View {
        ZStack {
            if style == .prominent {
                Circle()
                    .fill(color.opacity(Color.FormaOpacity.light))
                    .frame(width: size.containerSize, height: size.containerSize)
            }

            Image(systemName: systemName)
                .font(size.font)
                .foregroundColor(style == .prominent ? color : .formaSecondaryLabel)
        }
    }
}

#Preview("FormaHeroIcon") {
    VStack(spacing: 24) {
        FormaHeroIcon(systemName: "checkmark.circle.fill", color: .formaSage)
        FormaHeroIcon(systemName: "folder.badge.plus", size: .large)
        FormaHeroIcon(systemName: "questionmark.folder", style: .subtle)
    }
    .padding()
    .background(Color.formaBackground)
}

// MARK: - Shadow Standardization System
// Apple Design Award refinement: Consistent shadow treatment for proper depth and elevation

/// Shadow levels for consistent elevation hierarchy
enum FormaShadowLevel {
    /// Resting card state - subtle depth
    case card
    /// Selected/active card - enhanced elevation
    case cardSelected
    /// Floating elements (action bars, popovers) - prominent elevation
    case floating
    /// Primary button depth
    case button
    /// No shadow
    case none
}

extension View {
    /// Apply standardized shadow based on elevation level
    /// - Parameter level: The shadow level to apply (defaults to .card)
    /// - Returns: View with appropriate shadow for its elevation
    func formaShadow(_ level: FormaShadowLevel = .card) -> some View {
        switch level {
        case .card:
            return AnyView(self.shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.light), radius: 4, x: 0, y: 2))
        case .cardSelected:
            return AnyView(self.shadow(color: Color.formaSteelBlue.opacity(Color.FormaOpacity.medium), radius: 8, x: 0, y: 3))
        case .floating:
            return AnyView(self.shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.medium), radius: 16, x: 0, y: 4))
        case .button:
            return AnyView(self.shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.light), radius: 4, x: 0, y: 2))
        case .none:
            return AnyView(self)
        }
    }
}

// MARK: - Corner Radius Standardization
// Apple Design Award refinement: Enforce .continuous style for premium, smooth curves

extension View {
    /// Apply corner radius with .continuous style for premium appearance
    /// - Parameter radius: The corner radius value
    /// - Returns: View with smooth, continuous corner radius
    ///
    /// Standard values:
    /// - 12px: Large surfaces (cards, panels, modals)
    /// - 8px: Interactive elements (buttons, inputs)
    /// - 6px: Nested elements (icon backgrounds, badges)
    func formaCornerRadius(_ radius: CGFloat) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Segmented Control

/// A premium, segmented control with a sliding highlight, often used for tab bars or mode switches.
struct FormaSegmentedControl<SelectionValue: Hashable, Content: View>: View {
    @Binding var selection: SelectionValue
    let options: [SelectionValue]
    @ViewBuilder let content: (SelectionValue) -> Content

    @Namespace private var namespace
    @Environment(\.colorScheme) private var colorScheme

    private let containerCornerRadius: CGFloat = FormaControlChromeMetrics.containerCornerRadius
    private let selectedCornerRadius: CGFloat = FormaControlChromeMetrics.selectedCornerRadius
    private let segmentHeight: CGFloat = FormaControlChromeMetrics.segmentHeight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                FormaSegmentButton(
                    isSelected: selection == option,
                    namespace: namespace,
                    tint: .formaSteelBlue,
                    selectedCornerRadius: selectedCornerRadius,
                    segmentHeight: segmentHeight,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = option
                        }
                    },
                    content: { content(option) }
                )

                if index < options.count - 1 {
                    Rectangle()
                        .fill(FormaControlChromePalette.separator(colorScheme))
                        .frame(width: 1, height: FormaControlChromeMetrics.dividerHeight)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(2)
        .background {
            FormaSegmentedBackground(
                cornerRadius: containerCornerRadius,
                tint: containerTint
            )
            .overlay(
                RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                    .stroke(FormaControlChromePalette.containerBorder(colorScheme), lineWidth: 0.5)
            )
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: selection)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var containerTint: Color {
        colorScheme == .dark
            ? Color.formaMutedBlue.opacity(0.16)
            : Color.formaSteelBlue.opacity(0.10)
    }
}

struct FormaSegmentButton<Content: View>: View {
    let isSelected: Bool
    let namespace: Namespace.ID
    let tint: Color
    let selectedCornerRadius: CGFloat
    let segmentHeight: CGFloat
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(FormaControlChromePalette.activeFill(colorScheme, tint: tint))
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(FormaControlChromePalette.activeBorder(colorScheme), lineWidth: 0.5)
                        )
                        .shadow(color: FormaControlChromePalette.activeShadow(colorScheme), radius: 1.5, x: 0, y: 0.5)
                        .matchedGeometryEffect(id: "segmentIndicator", in: namespace)
                        .padding(.vertical, FormaControlChromeMetrics.shellInset)
                        .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(FormaControlChromePalette.hoverFill(colorScheme, tint: tint))
                        .padding(.vertical, FormaControlChromeMetrics.shellInset)
                        .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                }

                content()
                    .padding(.horizontal, 10)
                    .frame(height: segmentHeight)
                    .foregroundColor(
                        isSelected
                            ? FormaControlChromePalette.selectedForeground(colorScheme)
                            : (
                                isHovered
                                    ? FormaControlChromePalette.highlightedForeground(colorScheme)
                                    : FormaControlChromePalette.normalForeground(colorScheme)
                            )
                    )
            }
            .frame(height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(FormaControlPressButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isSelected)
        .animation(.easeOut(duration: 0.16), value: isHovered)
    }
}

/// Standalone icon button that perfectly matches the segmented control styling.
struct FormaSegmentedIconButton: View {
    let icon: String
    let isSelected: Bool
    let help: String?
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private let containerCornerRadius: CGFloat = FormaControlChromeMetrics.containerCornerRadius
    private let selectedCornerRadius: CGFloat = FormaControlChromeMetrics.selectedCornerRadius
    private let segmentWidth: CGFloat = FormaControlChromeMetrics.iconSegmentWidth
    private let segmentHeight: CGFloat = FormaControlChromeMetrics.segmentHeight

    init(icon: String, isSelected: Bool = false, help: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.isSelected = isSelected
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(FormaControlChromePalette.activeFill(colorScheme, tint: .formaSteelBlue))
                        .overlay(
                            RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                                .stroke(FormaControlChromePalette.activeBorder(colorScheme), lineWidth: 0.5)
                        )
                        .shadow(color: FormaControlChromePalette.activeShadow(colorScheme), radius: 1.5, x: 0, y: 0.5)
                        .padding(.vertical, FormaControlChromeMetrics.shellInset)
                        .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: selectedCornerRadius, style: .continuous)
                        .fill(FormaControlChromePalette.hoverFill(colorScheme, tint: .formaSteelBlue))
                        .padding(.vertical, FormaControlChromeMetrics.shellInset)
                        .padding(.horizontal, FormaControlChromeMetrics.shellInset)
                }

                Image(systemName: icon)
                    .font(.system(size: FormaControlChromeMetrics.segmentIconFontSize, weight: .medium))
                    .foregroundColor(
                        isSelected
                            ? FormaControlChromePalette.selectedForeground(colorScheme)
                            : (
                                isHovered
                                    ? FormaControlChromePalette.highlightedForeground(colorScheme)
                                    : FormaControlChromePalette.normalForeground(colorScheme)
                            )
                    )
                    .frame(width: segmentWidth, height: segmentHeight)
            }
            .frame(width: segmentWidth, height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(FormaControlPressButtonStyle())
        .padding(2)
        .background {
            FormaSegmentedBackground(
                cornerRadius: containerCornerRadius,
                tint: containerTint
            )
            .overlay(
                RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous)
                    .stroke(FormaControlChromePalette.containerBorder(colorScheme), lineWidth: 0.5)
            )
        }
        .help(help ?? "")
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isSelected)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var containerTint: Color {
        colorScheme == .dark
            ? Color.formaMutedBlue.opacity(0.16)
            : Color.formaSteelBlue.opacity(0.10)
    }
}

/// Shared capsule background used for FormaSegmentedControl and standalone FormaSegmentedIconButton
struct FormaSegmentedBackground: View {
    let cornerRadius: CGFloat
    var tint: Color? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            FormaMaterialSurface(tier: .raised, cornerRadius: cornerRadius, tint: tint)

            LinearGradient(
                colors: [
                    Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.10 : 0.16),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(shape)
        }
    }
}
