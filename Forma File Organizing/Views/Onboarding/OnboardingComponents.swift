import SwiftUI

// MARK: - Shared Footer

struct OnboardingFooter<PrimaryContent: View>: View {
    let primaryAction: () -> Void
    let primaryEnabled: Bool
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
    var tertiaryTitle: String? = nil
    var tertiaryAction: (() -> Void)? = nil
    var hint: String? = nil
    @ViewBuilder let primaryContent: () -> PrimaryContent

    @State private var isHovered: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Convenience initializer for the standard blue primary button
    init(
        primaryTitle: String,
        primaryEnabled: Bool,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        tertiaryTitle: String? = nil,
        tertiaryAction: (() -> Void)? = nil,
        hint: String? = nil
    ) where PrimaryContent == EmptyView {
        self.primaryAction = primaryAction
        self.primaryEnabled = primaryEnabled
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.tertiaryTitle = tertiaryTitle
        self.tertiaryAction = tertiaryAction
        self.hint = hint
        self.primaryContent = { EmptyView() }
        self._primaryTitle = primaryTitle
    }

    /// Custom primary button content initializer
    init(
        primaryEnabled: Bool = true,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        @ViewBuilder primaryContent: @escaping () -> PrimaryContent
    ) {
        self.primaryAction = primaryAction
        self.primaryEnabled = primaryEnabled
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.tertiaryTitle = nil
        self.tertiaryAction = nil
        self.hint = nil
        self.primaryContent = primaryContent
        self._primaryTitle = nil
    }

    // Internal storage for the standard title (nil when using custom content)
    private let _primaryTitle: String?

    var body: some View {
        VStack(spacing: FormaSpacing.standard) {
            // Hint text
            if let hint = hint {
                Text(hint)
                    .font(.formaCompact)
                    .foregroundColor(.formaSecondaryLabel)
            }

            HStack(spacing: FormaSpacing.standard) {
                // Back button
                if let secondaryTitle = secondaryTitle, let secondaryAction = secondaryAction {
                    Button(action: secondaryAction) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.formaCompactSemibold)
                            Text(secondaryTitle)
                                .font(.formaBodyLarge).fontWeight(.medium)
                        }
                        .foregroundColor(.formaSecondaryLabel)
                        .padding(.vertical, FormaSpacing.standard - (FormaSpacing.micro / 2))
                        .padding(.horizontal, FormaSpacing.large)
                        .background(
                            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                                .stroke(Color.formaSeparator, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Primary button — custom content or standard
                if let title = _primaryTitle {
                    Button(action: primaryAction) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.formaBodyLarge).fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                                .font(.formaBodySemibold)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .foregroundColor(.formaBoneWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FormaSpacing.standard - (FormaSpacing.micro / 2))
                        .background(
                            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                                .fill(primaryEnabled ? Color.formaSteelBlue : Color.formaSecondaryLabel.opacity(Color.FormaOpacity.overlay))
                        )
                        .shadow(color: primaryEnabled ? Color.formaSteelBlue.opacity(Color.FormaOpacity.medium) : .clear, radius: 4, x: 0, y: 2)
                        .formaShimmer(isActive: isHovered && primaryEnabled && !reduceMotion)
                        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!primaryEnabled)
                    .formaPressEffect()
                    .onHover { hovering in
                        isHovered = hovering
                    }
                } else {
                    primaryContent()
                }
            }

            // Tertiary action (skip/custom)
            if let tertiaryTitle = tertiaryTitle, let tertiaryAction = tertiaryAction {
                Button(action: tertiaryAction) {
                    Text(tertiaryTitle)
                        .font(.formaBody)
                        .foregroundColor(.formaSecondaryLabel)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FormaSpacing.large)
        .background(
            Rectangle()
                .fill(Color.formaControlBackground)
                .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.subtle), radius: 8, x: 0, y: -4)
        )
    }
}
