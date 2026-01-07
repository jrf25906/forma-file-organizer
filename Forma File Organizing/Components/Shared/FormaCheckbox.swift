import SwiftUI

/// Unified checkbox component with size variants
/// Consolidates: PremiumCheckbox, CompactCheckbox, GridCheckbox, SelectionCheckbox
struct FormaCheckbox: View {
    enum Size {
        case compact   // 18x18 - for list rows
        case standard  // 20x20 - for premium cards
        case large     // 22x22 - for grid items

        var dimension: CGFloat {
            switch self {
            case .compact: return 18
            case .standard: return 20
            case .large: return 22
            }
        }

        var checkmarkFont: Font {
            switch self {
            case .compact: return .formaCaptionBold
            case .standard: return .formaSmallSemibold
            case .large: return .formaSmallSemibold
            }
        }
    }

    enum Shape {
        case rounded      // RoundedRectangle with FormaRadius.small
        case roundedSmall // RoundedRectangle with FormaRadius.micro
        case circle       // Circle (for grid items)

        var cornerRadius: CGFloat {
            switch self {
            case .rounded: return FormaRadius.small
            case .roundedSmall: return FormaRadius.micro
            case .circle: return 0 // Not used for circles
            }
        }
    }

    let isSelected: Bool
    let isVisible: Bool
    var size: Size = .standard
    var shape: Shape = .rounded
    var showShadow: Bool = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background and Border
                Group {
                    if shape == .circle {
                        Circle()
                            .fill(isSelected ? Color.formaSteelBlue : backgroundColor)
                            .frame(width: size.dimension, height: size.dimension)
                        Circle()
                            .strokeBorder(
                                isSelected ? Color.formaSteelBlue : borderColor,
                                lineWidth: 1.5
                            )
                            .frame(width: size.dimension, height: size.dimension)
                    } else {
                        RoundedRectangle(cornerRadius: shape.cornerRadius, style: .continuous)
                            .fill(isSelected ? Color.formaSteelBlue : backgroundColor)
                            .frame(width: size.dimension, height: size.dimension)
                        RoundedRectangle(cornerRadius: shape.cornerRadius, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.formaSteelBlue : borderColor,
                                lineWidth: 1.5
                            )
                            .frame(width: size.dimension, height: size.dimension)
                    }
                }

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(size.checkmarkFont)
                        .foregroundStyle(Color.formaBoneWhite)
                }
            }
            .shadow(
                color: showShadow ? Color.formaObsidian.opacity(Color.FormaOpacity.medium) : .clear,
                radius: showShadow ? 3 : 0,
                x: 0,
                y: showShadow ? 1 : 0
            )
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.8)
        .animation(
            reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8),
            value: isVisible
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8),
            value: isSelected
        )
    }

    private var backgroundColor: Color {
        switch shape {
        case .circle:
            return Color.formaControlBackground.opacity(Color.FormaOpacity.prominent)
        default:
            return size == .compact ? Color.clear : Color.formaControlBackground
        }
    }

    private var borderColor: Color {
        switch size {
        case .compact:
            return Color.formaObsidian.opacity(Color.FormaOpacity.overlay)
        case .standard:
            return Color.formaObsidian.opacity(Color.FormaOpacity.medium)
        case .large:
            return Color.formaObsidian.opacity(Color.FormaOpacity.medium)
        }
    }
}

// MARK: - Convenience Initializers

extension FormaCheckbox {
    /// Premium checkbox variant (20x20, rounded rectangle)
    static func premium(
        isSelected: Bool,
        isVisible: Bool,
        action: @escaping () -> Void
    ) -> FormaCheckbox {
        FormaCheckbox(
            isSelected: isSelected,
            isVisible: isVisible,
            size: .standard,
            shape: .rounded,
            showShadow: true,
            action: action
        )
    }

    /// Compact checkbox variant (18x18, rounded rectangle)
    static func compact(
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> FormaCheckbox {
        FormaCheckbox(
            isSelected: isSelected,
            isVisible: true,
            size: .compact,
            shape: .rounded,
            showShadow: false,
            action: action
        )
    }

    /// Grid checkbox variant (22x22, circle with shadow)
    static func grid(
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> FormaCheckbox {
        FormaCheckbox(
            isSelected: isSelected,
            isVisible: true,
            size: .large,
            shape: .circle,
            showShadow: true,
            action: action
        )
    }

    /// Selection checkbox variant (custom size, rounded small)
    static func selection(
        isSelected: Bool,
        isVisible: Bool,
        action: @escaping () -> Void
    ) -> FormaCheckbox {
        FormaCheckbox(
            isSelected: isSelected,
            isVisible: isVisible,
            size: .standard,
            shape: .roundedSmall,
            showShadow: false,
            action: action
        )
    }
}

// MARK: - Preview

#Preview("FormaCheckbox Variants") {
    VStack(spacing: FormaSpacing.large) {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Premium (Standard)")
                .font(.formaBodySemibold)
            HStack(spacing: FormaSpacing.standard) {
                FormaCheckbox.premium(isSelected: false, isVisible: true, action: {})
                FormaCheckbox.premium(isSelected: true, isVisible: true, action: {})
            }
        }

        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Compact (List)")
                .font(.formaBodySemibold)
            HStack(spacing: FormaSpacing.standard) {
                FormaCheckbox.compact(isSelected: false, action: {})
                FormaCheckbox.compact(isSelected: true, action: {})
            }
        }

        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Grid (Large Circle)")
                .font(.formaBodySemibold)
            HStack(spacing: FormaSpacing.standard) {
                FormaCheckbox.grid(isSelected: false, action: {})
                FormaCheckbox.grid(isSelected: true, action: {})
            }
        }

        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Text("Selection (Rounded Small)")
                .font(.formaBodySemibold)
            HStack(spacing: FormaSpacing.standard) {
                FormaCheckbox.selection(isSelected: false, isVisible: true, action: {})
                FormaCheckbox.selection(isSelected: true, isVisible: true, action: {})
            }
        }
    }
    .padding(FormaSpacing.generous)
    .background(Color.formaBackground)
}
