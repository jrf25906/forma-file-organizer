import SwiftUI

struct MenuBarSurface<Content: View>: View {
    let tier: FormaMaterialTier
    let tint: Color?
    let cornerRadius: CGFloat
    let padding: CGFloat?
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        tier: FormaMaterialTier = .raised,
        tint: Color? = nil,
        cornerRadius: CGFloat = FormaRadius.card,
        padding: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tier = tier
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if let padding {
                content.padding(padding)
            } else {
                content
            }
        }
        .background {
            FormaChromeSurface(
                cornerRadius: cornerRadius,
                fill: fillOverlay,
                tint: tint,
                elevation: elevation,
                showsShadow: false
            )
        }
        .clipShape(shape)
        .shadow(color: ambientShadowColor, radius: ambientShadowRadius, x: 0, y: ambientShadowY)
        .shadow(color: contactShadowColor, radius: contactShadowRadius, x: 0, y: contactShadowY)
    }

    private var fillOverlay: Color {
        colorScheme == .dark
            ? Color.formaControlBackground.opacity(0.80)
            : Color.formaBoneWhite.opacity(0.86)
    }

    private var elevation: FormaChromeElevation {
        switch tier {
        case .base:
            return .resting
        case .raised:
            return .raised
        case .overlay:
            return .floating
        }
    }

    private var ambientShadowColor: Color {
        switch tier {
        case .base:
            return Color.formaObsidian.opacity(colorScheme == .dark ? 0.10 : 0.05)
        case .raised:
            return Color.formaObsidian.opacity(colorScheme == .dark ? 0.11 : 0.05)
        case .overlay:
            return Color.formaObsidian.opacity(colorScheme == .dark ? 0.14 : 0.08)
        }
    }

    private var ambientShadowRadius: CGFloat {
        switch tier {
        case .base:
            return 4
        case .raised:
            return 6
        case .overlay:
            return 10
        }
    }

    private var ambientShadowY: CGFloat {
        switch tier {
        case .base:
            return 1
        case .raised:
            return 2
        case .overlay:
            return 3
        }
    }

    private var contactShadowColor: Color {
        Color.formaObsidian.opacity(colorScheme == .dark ? 0.14 : 0.07)
    }

    private var contactShadowRadius: CGFloat {
        switch tier {
        case .base:
            return 1
        case .raised:
            return 2
        case .overlay:
            return 2
        }
    }

    private var contactShadowY: CGFloat {
        switch tier {
        case .base:
            return 1
        case .raised:
            return 1
        case .overlay:
            return 1
        }
    }
}

struct MenuBarFlatRow<Content: View>: View {
    let tint: Color?
    let cornerRadius: CGFloat
    let padding: CGFloat?
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        tint: Color? = nil,
        cornerRadius: CGFloat = FormaRadius.control,
        padding: CGFloat? = FormaSpacing.tight,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if let padding {
                content.padding(padding)
            } else {
                content
            }
        }
        .background {
            shape
                .fill(baseFill)
                .overlay {
                    if let tint {
                        shape.fill(tint.opacity(colorScheme == .dark ? 0.11 : 0.07))
                    }
                }
                .overlay(
                    shape.strokeBorder(borderColor, lineWidth: 1)
                )
        }
        .clipShape(shape)
    }

    private var baseFill: Color {
        colorScheme == .dark
            ? Color.formaControlBackground.opacity(0.38)
            : Color.formaBoneWhite.opacity(0.46)
    }

    private var borderColor: Color {
        if let tint {
            return tint.opacity(colorScheme == .dark ? 0.22 : 0.14)
        }

        return Color.formaSeparator.opacity(colorScheme == .dark ? 0.28 : 0.12)
    }
}

struct MenuBarDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(Color.formaSeparator.opacity(colorScheme == .dark ? 0.28 : 0.10))
            .frame(height: 1)
    }
}

struct MenuBarSectionHeading: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(spacing: FormaSpacing.tight) {
            Text(title)
                .font(.formaCaptionSemibold)
                .tracking(0.5)
                .foregroundColor(.formaTertiaryLabel)
                .textCase(.uppercase)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.formaMenuMetadata)
                    .foregroundColor(.formaTertiaryLabel)
                    .monospacedDigit()
            }
        }
    }
}

struct MenuBarButtonStyle: ButtonStyle {
    enum Kind {
        case primary(Color)
        case secondary(Color?)
        case utility
    }

    let kind: Kind

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor(isPressed: configuration.isPressed))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background(isPressed: configuration.isPressed))
            .opacity(isEnabled ? 1 : Color.FormaOpacity.high)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var cornerRadius: CGFloat {
        switch kind {
        case .utility:
            return FormaRadius.pill
        case .primary, .secondary:
            return FormaRadius.control
        }
    }

    private var horizontalPadding: CGFloat {
        switch kind {
        case .utility:
            return FormaSpacing.tight
        case .primary, .secondary:
            return FormaSpacing.standard
        }
    }

    private var verticalPadding: CGFloat {
        switch kind {
        case .utility:
            return 6
        case .primary, .secondary:
            return 8
        }
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        switch kind {
        case .primary:
            return .formaBoneWhite.opacity(isPressed ? Color.FormaOpacity.prominent : 1.0)
        case let .secondary(tint):
            return (tint ?? .formaLabel).opacity(isPressed ? Color.FormaOpacity.prominent : 1.0)
        case .utility:
            return .formaSecondaryLabel.opacity(isPressed ? Color.FormaOpacity.prominent : 1.0)
        }
    }

    private func background(isPressed: Bool) -> some View {
        FormaChromeSurface(
            cornerRadius: cornerRadius,
            fill: backgroundFill(isPressed: isPressed),
            tint: backgroundTint(isPressed: isPressed),
            elevation: backgroundElevation(isPressed: isPressed)
        )
    }

    private func backgroundElevation(isPressed: Bool) -> FormaChromeElevation {
        if isPressed {
            return .inset
        }

        switch kind {
        case .primary:
            return .emphasized
        case .secondary:
            return .resting
        case .utility:
            return .resting
        }
    }

    private func backgroundFill(isPressed: Bool) -> Color {
        switch kind {
        case let .primary(tint):
            return tint.opacity(isPressed ? 0.80 : 0.88)
        case let .secondary(tint):
            if tint == nil {
                return colorScheme == .dark
                    ? Color.formaControlBackground.opacity(isPressed ? 0.54 : 0.42)
                    : Color.formaBoneWhite.opacity(isPressed ? 0.68 : 0.54)
            }
            return colorScheme == .dark
                ? Color.formaControlBackground.opacity(isPressed ? 0.60 : 0.48)
                : Color.formaBoneWhite.opacity(isPressed ? 0.72 : 0.60)
        case .utility:
            return colorScheme == .dark
                ? Color.formaControlBackground.opacity(isPressed ? 0.42 : 0.28)
                : Color.formaBoneWhite.opacity(isPressed ? 0.58 : 0.42)
        }
    }

    private func backgroundTint(isPressed: Bool) -> Color? {
        switch kind {
        case let .primary(tint):
            return tint
        case let .secondary(tint):
            return tint?.opacity(isPressed ? 0.36 : 0.22)
        case .utility:
            return nil
        }
    }

}
