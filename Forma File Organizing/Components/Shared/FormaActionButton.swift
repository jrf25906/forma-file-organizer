import SwiftUI

/// Unified action button component with style variants
/// Consolidates: IconActionButton, CompactActionButton, GridActionButton
struct FormaActionButton: View {
    enum Style {
        case icon      // Icon-only with circle background (FileRow)
        case compact   // Minimal icon button (FileListRow)
        case grid      // Grid-style with material background (FileGridItem)

        var buttonSize: CGFloat {
            switch self {
            case .icon: return 32
            case .compact: return 24
            case .grid: return 32
            }
        }

        var iconFont: Font {
            switch self {
            case .icon: return .formaCompact
            case .compact: return .formaCaptionSemibold
            case .grid: return .formaSmallSemibold
            }
        }
    }

    let icon: String
    let color: Color
    var style: Style = .icon
    var isPrimary: Bool = false
    var tooltip: String = ""
    let action: () -> Void

    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(isPrimary && style == .icon ? .formaBodyLarge : style.iconFont)
                .fontWeight(.semibold)
                .foregroundStyle(foregroundColor)
                .frame(width: buttonSize, height: buttonSize)
                .background(backgroundView)
                .overlay(overlayBorder)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : (isHovered && style == .grid ? 1.08 : 1.0))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isPressed)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
            if hovering && style != .grid {
                NSCursor.pointingHand.push()
            } else if !hovering && style != .grid {
                NSCursor.pop()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    // MARK: - Computed Properties

    private var buttonSize: CGFloat {
        if isPrimary && style == .icon {
            return 36
        }
        if isPrimary && style == .grid {
            return 36
        }
        return style.buttonSize
    }

    private var foregroundColor: Color {
        switch style {
        case .icon:
            if isPrimary {
                return color
            } else {
                return isHovered ? Color.formaLabel : color
            }
        case .compact:
            return color.opacity(isHovered ? Color.FormaOpacity.prominent : Color.FormaOpacity.strong)
        case .grid:
            if isPrimary {
                return .formaBoneWhite
            } else {
                return color.opacity(isHovered ? Color.FormaOpacity.prominent : Color.FormaOpacity.high)
            }
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .icon:
            Circle()
                .fill(iconBackgroundFill)
        case .compact:
            Circle()
                .fill(compactBackgroundFill)
        case .grid:
            Circle()
                .fill(gridBackgroundFill)
                .shadow(
                    color: shadowColor,
                    radius: shadowRadius,
                    x: 0,
                    y: shadowY
                )
        }
    }

    private var iconBackgroundFill: Color {
        if isPrimary {
            return color.opacity(
                isPressed ? Color.FormaOpacity.medium :
                (isHovered ? Color.FormaOpacity.medium : Color.FormaOpacity.light)
            )
        } else {
            return Color.formaObsidian.opacity(
                isPressed ? Color.FormaOpacity.light :
                (isHovered ? Color.FormaOpacity.light : Color.FormaOpacity.subtle)
            )
        }
    }

    private var compactBackgroundFill: Color {
        Color.formaObsidian.opacity(
            isHovered ? Color.FormaOpacity.light : Color.FormaOpacity.subtle
        )
    }

    private var gridBackgroundFill: some ShapeStyle {
        if isPrimary {
            return AnyShapeStyle(color)
        } else {
            return AnyShapeStyle(.regularMaterial)
        }
    }

    @ViewBuilder
    private var overlayBorder: some View {
        if style == .icon {
            Circle()
                .strokeBorder(borderColor, lineWidth: 1)
        }
    }

    private var borderColor: Color {
        if isPrimary {
            return color.opacity(isHovered ? Color.FormaOpacity.overlay : Color.FormaOpacity.medium)
        } else {
            return Color.formaObsidian.opacity(isHovered ? Color.FormaOpacity.medium : Color.FormaOpacity.light)
        }
    }

    private var shadowColor: Color {
        if isPrimary {
            return color.opacity(Color.FormaOpacity.overlay)
        } else {
            return Color.formaObsidian.opacity(Color.FormaOpacity.light)
        }
    }

    private var shadowRadius: CGFloat {
        isPrimary ? 6 : 2
    }

    private var shadowY: CGFloat {
        isPrimary ? 3 : 1
    }
}

// MARK: - Convenience Initializers

extension FormaActionButton {
    /// Icon-style action button (FileRow)
    static func icon(
        icon: String,
        color: Color,
        tooltip: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> FormaActionButton {
        FormaActionButton(
            icon: icon,
            color: color,
            style: .icon,
            isPrimary: isPrimary,
            tooltip: tooltip,
            action: action
        )
    }

    /// Compact action button (FileListRow)
    static func compact(
        icon: String,
        color: Color = Color.formaObsidian,
        tooltip: String,
        action: @escaping () -> Void
    ) -> FormaActionButton {
        FormaActionButton(
            icon: icon,
            color: color,
            style: .compact,
            tooltip: tooltip,
            action: action
        )
    }

    /// Grid-style action button (FileGridItem)
    static func grid(
        icon: String,
        color: Color,
        isPrimary: Bool = false,
        tooltip: String,
        action: @escaping () -> Void
    ) -> FormaActionButton {
        FormaActionButton(
            icon: icon,
            color: color,
            style: .grid,
            isPrimary: isPrimary,
            tooltip: tooltip,
            action: action
        )
    }
}

// MARK: - Preview

#Preview("FormaActionButton Variants") {
    VStack(spacing: FormaSpacing.large) {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Icon Style (FileRow)")
                .font(.formaBodySemibold)
            HStack(spacing: FormaSpacing.standard) {
                FormaActionButton.icon(
                    icon: "eye.fill",
                    color: .formaSecondaryLabel,
                    tooltip: "Quick Look",
                    action: {}
                )
                FormaActionButton.icon(
                    icon: "forward.fill",
                    color: .formaSecondaryLabel,
                    tooltip: "Skip",
                    action: {}
                )
                FormaActionButton.icon(
                    icon: "checkmark.circle.fill",
                    color: .formaSage,
                    tooltip: "Organize",
                    isPrimary: true,
                    action: {}
                )
            }
        }

        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Compact Style (FileListRow)")
                .font(.formaBodySemibold)
            HStack(spacing: FormaSpacing.standard) {
                FormaActionButton.compact(
                    icon: "forward.fill",
                    tooltip: "Skip",
                    action: {}
                )
                FormaActionButton.compact(
                    icon: "eye.fill",
                    tooltip: "Quick Look",
                    action: {}
                )
            }
        }

        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Grid Style (FileGridItem)")
                .font(.formaBodySemibold)
            HStack(spacing: FormaSpacing.standard) {
                FormaActionButton.grid(
                    icon: "forward.fill",
                    color: .formaObsidian,
                    tooltip: "Skip",
                    action: {}
                )
                FormaActionButton.grid(
                    icon: "checkmark",
                    color: .formaSage,
                    isPrimary: true,
                    tooltip: "Organize",
                    action: {}
                )
            }
        }
    }
    .padding(FormaSpacing.generous)
    .background(Color.formaBackground)
}
