import SwiftUI

struct AboutSection: View {
    var body: some View {
        let privacyURL = URL(string: "https://formafiles.com/privacy")
        let termsURL = URL(string: "https://formafiles.com/terms")

        VStack(spacing: FormaSpacing.generous) {
            Spacer()

            // Brand logo
            FormaLogo(style: .mark, height: 80)
                .padding(.bottom, FormaSpacing.tight)

            Text("Forma")
                .font(.formaH1)
                .foregroundColor(.formaObsidian)

            Text("Give your files form.")
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)

            Spacer()

            VStack(spacing: FormaSpacing.tight) {
                Text("Version 1.0.0")
                    .font(.formaSmall)
                    .foregroundColor(.formaTertiaryLabel)

                HStack(spacing: FormaSpacing.tight) {
                    if let privacyURL {
                        Link("Privacy Policy", destination: privacyURL)
                    }
                    Text("·")
                        .foregroundColor(.formaTertiaryLabel)
                    if let termsURL {
                        Link("Terms", destination: termsURL)
                    }
                }
                .font(.formaSmall)
                .foregroundColor(.formaTertiaryLabel)
                .tint(.formaSteelBlue)
            }
            .padding(.bottom)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.formaBoneWhite)
    }
}
