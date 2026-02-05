import SwiftUI

struct AboutSection: View {
    @Environment(\.colorScheme) private var colorScheme

    private var logoContainerFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.05)
            : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle + 0.01)
    }

    private var logoContainerStroke: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.12)
            : Color.formaSeparator.opacity(Color.FormaOpacity.light)
    }

    var body: some View {
        let privacyURL = URL(string: "https://formafiles.com/privacy")
        let termsURL = URL(string: "https://formafiles.com/terms")

        VStack(spacing: FormaSpacing.generous) {
            Spacer()

            // Brand logo
            FormaLogo(style: .mark, height: 90)
                .padding(FormaSpacing.standard)
                .background(
                    RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous)
                        .fill(logoContainerFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous)
                        .stroke(logoContainerStroke, lineWidth: 1)
                )
                .padding(.bottom, FormaSpacing.standard)

            Text("Forma")
                .font(.formaH1)
                .foregroundColor(.formaLabel)

            Text("Give your files form.")
                .font(.formaBody)
                .foregroundColor(colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel)

            Spacer()

            VStack(spacing: FormaSpacing.tight) {
                Text("Version 1.0.0")
                    .font(.formaSmall)
                    .foregroundColor(colorScheme == .dark ? .formaTertiaryLabelHigh : .formaTertiaryLabel)

                HStack(spacing: FormaSpacing.tight) {
                    if let privacyURL {
                        Link("Privacy Policy", destination: privacyURL)
                    }
                    Text("·")
                        .foregroundColor(colorScheme == .dark ? .formaTertiaryLabelHigh : .formaTertiaryLabel)
                    if let termsURL {
                        Link("Terms", destination: termsURL)
                    }
                }
                .font(.formaSmall)
                .foregroundColor(colorScheme == .dark ? .formaTertiaryLabelHigh : .formaTertiaryLabel)
                .tint(.formaSteelBlue)
            }
            .padding(.bottom)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.formaBackground)
    }
}
