//
//  FormaBadges.swift
//  Forma - Reusable UI Components
//
//  Implementation of Forma brand UI components
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI

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
                .lineLimit(1)
                .truncationMode(.tail)
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
            Capsule().fill(color.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle))
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch style {
        case .outlined:
            Capsule().stroke(color, lineWidth: 1)
        case .subtle:
            Capsule()
                .stroke(
                    color.opacity(Color.FormaOpacity.medium + Color.FormaOpacity.ultraSubtle),
                    lineWidth: 0.75
                )
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
