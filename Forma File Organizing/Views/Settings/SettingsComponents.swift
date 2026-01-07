import SwiftUI

// MARK: - Simple Settings Helpers (Forma-styled, Settings-safe)
// These avoid the layout issues with FormaSection in Settings windows

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

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
                .foregroundColor(Color.formaSecondaryLabel)
                .padding(.leading, FormaSpacing.micro)

            // Content card - white background with subtle border
            content
                .background(Color.formaControlBackground)
                .formaCornerRadius(FormaRadius.card)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                        .stroke(Color.formaObsidian.opacity(Color.FormaOpacity.light), lineWidth: 1)
                )
                .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle), radius: 2, x: 0, y: 1)
        }
    }
}

struct SettingsRow<Accessory: View>: View {
    let title: String
    let subtitle: String?
    let accessory: Accessory

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
                        .foregroundColor(Color.formaSecondaryLabel)
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
