import SwiftUI

/// A collapsible section wrapper for inspector panels
/// Persists state using AppStorage with a unique key
struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String?
    let storageKey: String
    @ViewBuilder let content: () -> Content

    @AppStorage private var isExpanded: Bool

    init(
        title: String,
        icon: String? = nil,
        storageKey: String,
        defaultExpanded: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.storageKey = storageKey
        self.content = content
        self._isExpanded = AppStorage(wrappedValue: defaultExpanded, "section.\(storageKey).expanded")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: FormaSpacing.tight) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.formaCompact)
                            .foregroundColor(.formaSecondaryLabel)
                    }

                    Text(title)
                        .font(.formaBodySemibold)
                        .tracking(0.5)
                        .foregroundColor(.formaSecondaryLabel)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.formaCaptionSemibold)
                        .foregroundColor(.formaTertiaryLabel)
                }
                .padding(.horizontal, FormaSpacing.large)
                .padding(.vertical, FormaSpacing.standard)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Content (collapsible)
            if isExpanded {
                content()
                    .padding(.horizontal, FormaSpacing.large)
                    .padding(.bottom, FormaSpacing.large)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .background(Color.formaCardBackground)
        .formaCornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: FormaSpacing.large) {
        CollapsibleSection(title: "Details", icon: "info.circle", storageKey: "preview.details") {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                Text("Name: example.pdf")
                Text("Size: 2.3 MB")
                Text("Type: Document")
            }
            .font(.formaSmall)
        }

        CollapsibleSection(title: "Organization", storageKey: "preview.organization", defaultExpanded: false) {
            Text("Suggested destination: Documents/Finance")
                .font(.formaSmall)
        }
    }
    .padding()
    .background(Color.formaBackground)
}
