import SwiftUI

struct ContentTagQuickFilters: View {
    let availableTags: [MetadataContentTag]
    let selectedTags: Set<MetadataContentTag>
    let onToggle: (MetadataContentTag) -> Void

    var body: some View {
        if !availableTags.isEmpty {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                Text("Quick Filters")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FormaSpacing.tight) {
                        ForEach(availableTags, id: \.self) { tag in
                            let isSelected = selectedTags.contains(tag)

                            Button(action: { onToggle(tag) }) {
                                HStack(spacing: FormaSpacing.tight - (FormaSpacing.micro / 2)) {
                                    Image(systemName: isSelected ? "tag.fill" : "tag")
                                        .font(.formaCaption)

                                    Text(tag.displayName)
                                        .font(.formaSmall)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, FormaSpacing.tight + (FormaSpacing.micro / 2))
                                .padding(.vertical, FormaSpacing.tight - (FormaSpacing.micro / 2))
                                .background(
                                    isSelected
                                    ? Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
                                    : Color.formaControlBackground
                                )
                                .formaCornerRadius(FormaRadius.control)
                                .overlay(
                                    RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                                        .stroke(
                                            isSelected ? Color.formaSteelBlue : Color.formaSeparator,
                                            lineWidth: 1
                                        )
                                )
                                .foregroundColor(isSelected ? .white : .formaLabel)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, FormaLayout.Gutters.center)
            .padding(.bottom, FormaSpacing.tight)
        }
    }
}
