import SwiftUI

struct AnalyticsStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.formaH2)
                .foregroundColor(.formaObsidian)
            Text(label)
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
        }
        .padding(FormaSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.formaControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.subtle), radius: 8, x: 0, y: 4)
    }
}
