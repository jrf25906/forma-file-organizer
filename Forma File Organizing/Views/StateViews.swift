import SwiftUI

struct EmptyStateView: View {
    var title: String = "All Clean!"
    var message: String = "Your Desktop is organized."
    var icon: String = "checkmark"
    var iconColor: Color = .formaSage

    var body: some View {
        VStack(spacing: FormaSpacing.standard) {
            Spacer()

            ZStack {
                Circle()
                    .fill(iconColor.opacity(Color.FormaOpacity.light))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.formaHero)
                    .foregroundColor(iconColor)
            }
            .padding(.bottom, FormaSpacing.standard)

            Text(title)
                .formaH2Style()
                .foregroundColor(Color.formaObsidian)

            Text(message)
                .formaBodyStyle()
                .foregroundColor(Color.formaObsidian.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
                .multilineTextAlignment(.center)
                .padding(.horizontal, FormaSpacing.extraLarge)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.formaBoneWhite)
    }
}
