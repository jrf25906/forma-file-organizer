//
//  FormaMisc.swift
//  Forma - Miscellaneous Components
//
//  Utility components: logo, category icons, progress, shadows, corner radius
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI

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

// MARK: - Preview Helpers

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

#Preview("Logo") {
    VStack(spacing: 30) {
        FormaLogo(style: .mark, height: 64)
        FormaLogo(style: .mark, height: 32)
        FormaLogo(style: .mark, height: 24)
    }
    .padding()
}
