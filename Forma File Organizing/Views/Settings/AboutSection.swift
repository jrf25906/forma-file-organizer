import SwiftUI

struct AboutSection: View {
    var body: some View {
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

            Text("Version 1.0.0")
                .font(.formaSmall)
                .foregroundColor(.formaTertiaryLabel)
                .padding(.bottom)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.formaBoneWhite)
    }
}
