import SwiftUI

// MARK: - Simple Settings Helpers (Forma-styled, Settings-safe)
// These avoid the layout issues with FormaSection in Settings windows

struct SettingsTabShell<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var backdropFill: Color {
        colorScheme == .dark ? .formaSurfaceAnchor : .formaSurfaceChrome
    }

    var body: some View {
        ZStack {
            backdropFill

            GradientBackdropView(
                intensity: colorScheme == .dark ? Color.FormaOpacity.light : Color.FormaOpacity.subtle,
                blurRadius: FormaSpacing.huge + FormaSpacing.tight
            )

            content
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
                .font(.formaSmallSemibold)
                .tracking(0.3)
                .foregroundColor(.formaLabel)
                .padding(.leading, FormaSpacing.micro)

            // Content card - work surface with a restrained edge
            content
                .background(Color.formaSurfaceWork)
                .formaCornerRadius(FormaRadius.card)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                        .stroke(
                            colorScheme == .dark
                                ? Color.formaBoneWhite.opacity(0.16)
                                : Color.formaObsidian.opacity(Color.FormaOpacity.light),
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

    init(_ title: String, subtitle: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: FormaSpacing.standard) {
            VStack(alignment: .leading, spacing: 2) {
                // Title
                Text(title)
                    .font(.formaBody)
                    .foregroundColor(.formaLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Subtitle
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabelHigh)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: FormaSpacing.standard)
            accessory
        }
        .padding(FormaSpacing.large)
        .frame(minHeight: 56)
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
