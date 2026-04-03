import SwiftUI

struct TrustedAutomationScopeRecommendationSheet: View {
    let recommendation: TrustedAutomationScopeRecommendation
    let onConfirm: (TrustedAutomationScopeType) -> Void
    let onCancel: () -> Void

    @State private var selectedScopeType: TrustedAutomationScopeType

    init(
        recommendation: TrustedAutomationScopeRecommendation,
        onConfirm: @escaping (TrustedAutomationScopeType) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.recommendation = recommendation
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _selectedScopeType = State(initialValue: recommendation.recommendedScope.scopeType)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.large) {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                Text("Trust this automatically")
                    .font(.formaH2)
                    .foregroundColor(.formaLabel)

                Text("Forma recommends the narrowest safe scope based on what you just approved.")
                    .font(.formaBody)
                    .foregroundColor(.formaSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: FormaSpacing.standard) {
                ForEach(recommendation.allScopeChoices) { option in
                    scopeOptionRow(option)
                }
            }

            if let selectedOption = recommendation.option(for: selectedScopeType) {
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    Text("Why this is safe")
                        .font(.formaBodySemibold)
                        .foregroundColor(.formaLabel)

                    Text(selectedOption.rationaleSummary)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Files in this scope can be moved automatically.")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }
                .padding(FormaSpacing.large)
                .background(Color.formaControlBackground.opacity(Color.FormaOpacity.overlay))
                .formaCornerRadius(FormaRadius.card)
            }

            HStack {
                Button("Not now", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundColor(.formaSecondaryLabel)

                Spacer()

                Button("Trust This Scope") {
                    onConfirm(selectedScopeType)
                }
                .buttonStyle(.borderedProminent)
                .tint(.formaSteelBlue)
            }
        }
        .padding(FormaSpacing.extraLarge)
        .frame(width: 460)
        .background(Color.formaBackground)
    }

    private func scopeOptionRow(_ option: TrustedAutomationScopeRecommendationOption) -> some View {
        Button(action: {
            selectedScopeType = option.scopeType
        }) {
            HStack(spacing: FormaSpacing.standard) {
                Image(systemName: option.scopeType == selectedScopeType ? "largecircle.fill.circle" : "circle")
                    .font(.formaBody)
                    .foregroundColor(option.scopeType == selectedScopeType ? .formaSteelBlue : .formaSecondaryLabel)

                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    HStack(spacing: FormaSpacing.tight) {
                        Text(option.scopeType.displayName)
                            .font(.formaBodySemibold)
                            .foregroundColor(.formaLabel)

                        if option.scopeType == recommendation.recommendedScope.scopeType {
                            Text("Recommended")
                                .font(.formaCaptionBold)
                                .foregroundColor(.formaSteelBlue)
                                .padding(.horizontal, FormaSpacing.tight)
                                .padding(.vertical, FormaSpacing.micro)
                                .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                                .clipShape(Capsule())
                        }
                    }

                    Text(option.displayName)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }

                Spacer()
            }
            .padding(FormaSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(option.scopeType == selectedScopeType ? Color.formaSteelBlue.opacity(Color.FormaOpacity.light) : Color.formaCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .stroke(
                        option.scopeType == selectedScopeType
                        ? Color.formaSteelBlue.opacity(Color.FormaOpacity.prominent)
                        : Color.formaSeparator.opacity(Color.FormaOpacity.strong),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
