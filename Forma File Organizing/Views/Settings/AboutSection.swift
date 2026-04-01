import SwiftUI

struct AboutSection: View {
    @Environment(\.colorScheme) private var colorScheme

    private var logoContainerFill: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.1)
            : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle + 0.01)
    }

    private var logoContainerStroke: Color {
        colorScheme == .dark
            ? Color.formaBoneWhite.opacity(0.24)
            : Color.formaSeparator.opacity(Color.FormaOpacity.light)
    }

    @ViewBuilder
    private var aboutLogo: some View {
        if colorScheme == .dark {
            Image("logo-mark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 90)
                .colorInvert()
                .brightness(0.08)
                .contrast(1.08)
                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 2)
        } else {
            FormaLogo(style: .mark, height: 90)
        }
    }

    var body: some View {
        let privacyURL = URL(string: "https://formafiles.com/privacy")
        let termsURL = URL(string: "https://formafiles.com/terms")

        VStack(spacing: FormaSpacing.generous) {
            Spacer()

            // Brand logo
            aboutLogo
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

            Text("File organization you can actually trust.")
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
        .background(Color.clear)
    }
}
