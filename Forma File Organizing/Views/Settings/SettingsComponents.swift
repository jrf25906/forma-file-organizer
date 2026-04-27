import SwiftUI

// MARK: - Simple Settings Helpers (Forma-styled, Settings-safe)
// These avoid the layout issues with FormaSection in Settings windows

struct SettingsTabShell<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var backdropFill: Color {
        .formaSurfaceChrome
    }

    private var ambientOverlay: LinearGradient {
        LinearGradient(
            colors: [
                Color.formaMutedBlue.opacity(colorScheme == .dark ? 0.10 : 0.07),
                Color.formaSurfaceChrome.opacity(0),
                Color.formaWarmOrange.opacity(colorScheme == .dark ? 0.04 : 0.025)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            backdropFill

            if !reduceTransparency {
                ambientOverlay
                    .allowsHitTesting(false)
            }

            content
                .padding(.horizontal, FormaSpacing.generous)
                .padding(.vertical, FormaSpacing.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .tint(.formaSteelBlue)
    }
}

struct SettingsPageHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(title)
                .font(.formaH1)
                .foregroundColor(.formaLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            if let subtitle {
                Text(subtitle)
                    .font(.formaBody)
                    .foregroundColor(.formaSecondaryLabelHigh)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .foregroundColor(.formaSecondaryLabelHigh)
                .padding(.leading, FormaSpacing.micro)

            // Content card - work surface with a restrained edge
            content
                .background(Color.formaSurfaceWork)
                .formaCornerRadius(FormaRadius.card)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                        .stroke(
                            colorScheme == .dark
                                ? Color.formaBoneWhite.opacity(0.14)
                                : Color.formaObsidian.opacity(0.08),
                            lineWidth: FormaBorderWidth.thin
                        )
                )
                .shadow(
                    color: colorScheme == .dark
                        ? Color.formaObsidian.opacity(0.24)
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
                    .font(.formaBodySemibold)
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
        .padding(.horizontal, FormaSpacing.large)
        .padding(.vertical, FormaSpacing.standard)
        .frame(minHeight: 54)
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
