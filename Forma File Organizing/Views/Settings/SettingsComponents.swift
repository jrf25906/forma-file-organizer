import SwiftUI

// MARK: - Simple Settings Helpers (Forma-styled, Settings-safe)
// These avoid the layout issues with FormaSection in Settings windows

struct SettingsTabShell<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var shellFill: Color {
        colorScheme == .dark
            ? Color.formaObsidian.opacity(0.46)
            : Color.formaBoneWhite.opacity(0.72)
    }

    private var shellStroke: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.16)
            : Color.formaObsidian.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle)
    }

    var body: some View {
        ZStack {
            GradientBackdropView(
                intensity: colorScheme == .dark ? Color.FormaOpacity.medium : Color.FormaOpacity.overlay,
                blurRadius: FormaSpacing.huge + FormaSpacing.tight
            )

            content
                .padding(FormaSpacing.tight)
                .background(
                    RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous)
                        .fill(shellFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous)
                                .stroke(shellStroke, lineWidth: 1)
                        )
                        .shadow(
                            color: colorScheme == .dark
                                ? Color.black.opacity(0.26)
                                : Color.formaObsidian.opacity(Color.FormaOpacity.medium),
                            radius: 14,
                            x: 0,
                            y: 6
                        )
                )
                .padding(FormaSpacing.standard)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            // Section header - matches FormaSection styling
            Text(title)
                .font(.formaBodySemibold)
                .tracking(0.5)
                .foregroundColor(colorScheme == .dark ? Color.formaSecondaryLabelHigh : Color.formaSecondaryLabel)
                .padding(.leading, FormaSpacing.micro)

            // Content card - white background with subtle border
            content
                .background(Color.formaControlBackground)
                .formaCornerRadius(FormaRadius.card)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                        .stroke(
                            colorScheme == .dark
                                ? Color.formaSeparator.opacity(0.35)
                                : Color.formaSeparator.opacity(Color.FormaOpacity.light),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.14)
                        : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        }
    }
}

struct SettingsRow<Accessory: View>: View {
    let title: String
    let subtitle: String?
    let accessory: Accessory
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, subtitle: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Title
                Text(title)
                    .font(.formaBody)
                    .foregroundColor(.formaLabel)

                // Subtitle
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.formaSmall)
                        .foregroundColor(colorScheme == .dark ? Color.formaSecondaryLabelHigh : Color.formaSecondaryLabel)
                }
            }
            Spacer()
            accessory
        }
        .padding(FormaSpacing.large)
    }
}

/// User's preferred appearance mode for the app
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    /// Converts to SwiftUI ColorScheme (nil = follow system)
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
