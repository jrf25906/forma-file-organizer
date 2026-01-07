import SwiftUI

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.formaBodySemibold)
                }
                Text(title)
                    .font(.formaBodyBold)
            }
            .foregroundColor(.formaBoneWhite)
            .padding(.vertical, FormaSpacing.Button.vertical)
            .padding(.horizontal, FormaSpacing.generous)
            .frame(maxWidth: .infinity)
            .background(Color.formaSteelBlue)
            .formaCornerRadius(FormaRadius.control)
            .formaShadow(.button)
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaSpacing.tight) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.formaBodyMedium)
                }
                Text(title)
                    .formaBodyStyle()
            }
            .foregroundColor(Color.formaObsidian)
            .padding(.vertical, FormaSpacing.Button.vertical - (FormaSpacing.micro / 4)) // 7px: 32px total height with border
            .padding(.horizontal, FormaSpacing.generous)
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .stroke(Color.formaObsidian.opacity(Color.FormaOpacity.medium), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.formaBodyBold)
            .foregroundStyle(Color.formaBoneWhite)
            .padding(.vertical, FormaSpacing.standard)
            .padding(.horizontal, FormaSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(
                        Color.formaSteelBlue.opacity(
                            configuration.isPressed ? (Color.FormaOpacity.prominent + Color.FormaOpacity.subtle) : 1.0
                        )
                    )
            )
            .formaShadow(.button)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .formaBodyStyle()
            .foregroundStyle(Color.formaLabel)
            .padding(.vertical, FormaSpacing.standard)
            .padding(.horizontal, FormaSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .stroke(Color.formaSeparator, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? Color.FormaOpacity.high : 1.0)
    }
}
