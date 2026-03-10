import SwiftUI

enum FormaControlChromeMetrics {
    static let containerCornerRadius: CGFloat = 8
    static let selectedCornerRadius: CGFloat = 6
    static let segmentHeight: CGFloat = 24
    static let iconSegmentWidth: CGFloat = 32
    static let segmentIconFontSize: CGFloat = 11
    static let shellInset: CGFloat = 2
    static let dividerHeight: CGFloat = 16
}

enum FormaNestedRadius {
    static func inset(_ radius: CGFloat, by amount: CGFloat = 2) -> CGFloat {
        max(0, radius - amount)
    }
}

enum FormaChromeElevation {
    case inset
    case resting
    case raised
    case floating
    case emphasized
}

enum FormaControlChromePalette {
    static func containerFill(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.07)
            : Color.formaObsidian.opacity(0.05)
    }

    static func containerBorder(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.20)
            : Color.formaObsidian.opacity(0.10)
    }

    static func separator(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.16)
            : Color.formaObsidian.opacity(0.10)
    }

    static func hoverFill(_ colorScheme: ColorScheme, tint: Color? = nil) -> Color {
        if let tint {
            return tint.opacity(colorScheme == .dark ? 0.12 : 0.08)
        }
        return colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.08)
            : Color.formaObsidian.opacity(0.04)
    }

    static func activeFill(_ colorScheme: ColorScheme, tint: Color? = nil) -> Color {
        if let tint {
            return tint.opacity(colorScheme == .dark ? 0.20 : 0.12)
        }
        return colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.14)
            : Color.formaBoneWhite.opacity(0.88)
    }

    static func activeBorder(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.30)
            : Color.formaObsidian.opacity(0.14)
    }

    static func activeShadow(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.24)
            : Color.formaObsidian.opacity(0.08)
    }

    static func selectedForeground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .formaBoneWhite : .formaLabel
    }

    static func highlightedForeground(_ colorScheme: ColorScheme) -> Color {
        .formaLabel
    }

    static func normalForeground(_ colorScheme: ColorScheme) -> Color {
        .formaSecondaryLabel
    }
}

struct FormaControlPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                reduceMotion ? .none : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

struct FormaChromeSurface: View {
    let cornerRadius: CGFloat
    let fill: Color
    var tint: Color? = nil
    var elevation: FormaChromeElevation = .resting
    var showsShadow: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var controlActiveState

    private var isWindowActive: Bool {
        controlActiveState != .inactive
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(fill)
            .overlay {
                if let tint {
                    shape
                        .fill(tint.opacity(tintOpacity))
                }
            }
            .overlay {
                shape
                    .fill(specularGradient)
                    .opacity(specularOpacity)
                    .blendMode(.screen)
            }
            .overlay {
                shape.strokeBorder(outerBorder, lineWidth: outerBorderWidth)
            }
            .overlay {
                shape
                    .inset(by: 1)
                    .stroke(innerBorder, lineWidth: innerBorderWidth)
            }
            .shadow(color: showsShadow ? ambientShadowColor : .clear, radius: ambientShadowRadius, x: 0, y: ambientShadowY)
            .shadow(color: showsShadow ? contactShadowColor : .clear, radius: contactShadowRadius, x: 0, y: contactShadowY)
            .accessibilityHidden(true)
    }

    private var tintOpacity: Double {
        let base: Double
        switch elevation {
        case .inset:
            base = colorScheme == .dark ? 0.08 : 0.05
        case .resting:
            base = colorScheme == .dark ? 0.10 : 0.06
        case .raised:
            base = colorScheme == .dark ? 0.14 : 0.08
        case .floating:
            base = colorScheme == .dark ? 0.16 : 0.10
        case .emphasized:
            base = colorScheme == .dark ? 0.18 : 0.12
        }

        return base * (isWindowActive ? 1.0 : 0.82)
    }

    private var specularGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.28 : 0.42),
                Color.formaBoneWhite.opacity(colorScheme == .dark ? 0.08 : 0.16),
                Color.formaBoneWhite.opacity(0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var specularOpacity: Double {
        guard elevation != .inset else { return 0.18 }

        let base: Double
        switch elevation {
        case .inset:
            base = 0.18
        case .resting:
            base = colorScheme == .dark ? 0.20 : 0.30
        case .raised:
            base = colorScheme == .dark ? 0.24 : 0.34
        case .floating:
            base = colorScheme == .dark ? 0.28 : 0.38
        case .emphasized:
            base = colorScheme == .dark ? 0.32 : 0.42
        }

        return base * (isWindowActive ? 1.0 : 0.74)
    }

    private var outerBorder: Color {
        if let tint {
            return tint.opacity(colorScheme == .dark ? 0.30 : 0.18)
        }

        switch elevation {
        case .inset:
            return colorScheme == .dark
                ? Color.formaBoneWhite.opacity(0.10)
                : Color.formaObsidian.opacity(0.06)
        case .resting:
            return colorScheme == .dark
                ? Color.formaBoneWhite.opacity(0.16)
                : Color.formaObsidian.opacity(0.08)
        case .raised:
            return colorScheme == .dark
                ? Color.formaBoneWhite.opacity(0.20)
                : Color.formaObsidian.opacity(0.10)
        case .floating:
            return colorScheme == .dark
                ? Color.formaBoneWhite.opacity(0.24)
                : Color.formaObsidian.opacity(0.12)
        case .emphasized:
            return colorScheme == .dark
                ? Color.formaBoneWhite.opacity(0.28)
                : Color.formaObsidian.opacity(0.14)
        }
    }

    private var innerBorder: Color {
        if let tint {
            let baseOpacity = colorScheme == .dark ? 0.22 : 0.46
            let emphasisMultiplier = elevation == .emphasized ? 1.0 : 0.88
            let activeMultiplier = isWindowActive ? 1.0 : 0.76
            return Color.formaBoneWhite.opacity(baseOpacity * emphasisMultiplier * activeMultiplier)
        }

        let opacity: Double
        switch elevation {
        case .inset:
            opacity = colorScheme == .dark ? 0.06 : 0.20
        case .resting:
            opacity = colorScheme == .dark ? 0.10 : 0.26
        case .raised:
            opacity = colorScheme == .dark ? 0.12 : 0.30
        case .floating:
            opacity = colorScheme == .dark ? 0.14 : 0.34
        case .emphasized:
            opacity = colorScheme == .dark ? 0.18 : 0.38
        }

        return Color.formaBoneWhite.opacity(opacity * (isWindowActive ? 1.0 : 0.76))
    }

    private var outerBorderWidth: CGFloat {
        elevation == .emphasized ? 1 : 0.75
    }

    private var innerBorderWidth: CGFloat {
        elevation == .floating ? 1 : 0.75
    }

    private var ambientShadowColor: Color {
        let opacity: Double
        switch elevation {
        case .inset:
            opacity = 0
        case .resting:
            opacity = colorScheme == .dark ? 0.08 : 0.05
        case .raised:
            opacity = colorScheme == .dark ? 0.12 : 0.07
        case .floating:
            opacity = colorScheme == .dark ? 0.18 : 0.10
        case .emphasized:
            opacity = colorScheme == .dark ? 0.16 : 0.10
        }

        return Color.formaObsidian.opacity(opacity * (isWindowActive ? 1.0 : 0.68))
    }

    private var ambientShadowRadius: CGFloat {
        switch elevation {
        case .inset:
            return 0
        case .resting:
            return 3
        case .raised:
            return 8
        case .floating:
            return 14
        case .emphasized:
            return 10
        }
    }

    private var ambientShadowY: CGFloat {
        switch elevation {
        case .inset:
            return 0
        case .resting:
            return 1
        case .raised:
            return 3
        case .floating:
            return 5
        case .emphasized:
            return 4
        }
    }

    private var contactShadowColor: Color {
        guard elevation != .inset else { return .clear }
        let baseOpacity = colorScheme == .dark ? 0.18 : 0.10
        let activeMultiplier = isWindowActive ? 1.0 : 0.72
        return Color.formaObsidian.opacity(baseOpacity * activeMultiplier)
    }

    private var contactShadowRadius: CGFloat {
        switch elevation {
        case .inset:
            return 0
        case .resting:
            return 1
        case .raised:
            return 2
        case .floating:
            return 3
        case .emphasized:
            return 2
        }
    }

    private var contactShadowY: CGFloat {
        switch elevation {
        case .inset:
            return 0
        case .resting:
            return 1
        case .raised:
            return 1
        case .floating:
            return 2
        case .emphasized:
            return 1
        }
    }
}
