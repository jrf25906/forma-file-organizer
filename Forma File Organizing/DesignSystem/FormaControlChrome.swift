import SwiftUI

enum FormaControlChromeMetrics {
    static let containerCornerRadius: CGFloat = 8
    static let selectedCornerRadius: CGFloat = 6
    static let segmentHeight: CGFloat = 24
    static let shellInset: CGFloat = 2
    static let dividerHeight: CGFloat = 16
}

enum FormaControlChromePalette {
    static func containerFill(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.08)
            : Color.formaObsidian.opacity(0.06)
    }

    static func containerBorder(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.14)
            : Color.formaObsidian.opacity(0.12)
    }

    static func separator(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.20)
            : Color.formaObsidian.opacity(0.12)
    }

    static func hoverFill(_ colorScheme: ColorScheme, tint: Color? = nil) -> Color {
        if let tint {
            return tint.opacity(colorScheme == .dark ? 0.14 : 0.08)
        }
        return colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.10)
            : Color.formaObsidian.opacity(0.05)
    }

    static func activeFill(_ colorScheme: ColorScheme, tint: Color? = nil) -> Color {
        if let tint {
            return tint.opacity(colorScheme == .dark ? 0.22 : 0.14)
        }
        return colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.16)
            : Color.formaBoneWhite.opacity(0.90)
    }

    static func activeBorder(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.22)
            : Color.formaObsidian.opacity(0.08)
    }

    static func activeShadow(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.20)
            : Color.formaObsidian.opacity(0.10)
    }

    static func selectedForeground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .formaBoneWhite : .formaLabel
    }

    static func highlightedForeground(_ colorScheme: ColorScheme) -> Color {
        .formaLabel
    }

    static func normalForeground(_ colorScheme: ColorScheme) -> Color {
        .formaSecondaryLabelHigh
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
