import SwiftUI

struct RuleDestinationPicker: View {
    @Binding var formState: RuleFormState
    @Binding var showFolderPicker: Bool
    let onPreviewDeleteMatches: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Then")
                    .font(.formaBodyLarge)
                    .foregroundColor(.formaSecondaryLabel)

                Menu {
                    ForEach(Rule.ActionType.allCases, id: \.self) { type in
                        Button(type.rawValue.capitalized) { formState.actionType = type }
                    }
                } label: {
                    Text(formState.actionType.rawValue)
                        .font(.formaBodyLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(.formaSteelBlue)
                        .underline(true, color: .formaSteelBlue.opacity(0.3))
                }
                .menuStyle(.borderlessButton)

                Text("to")
                    .font(.formaBodyLarge)
                    .foregroundColor(.formaSecondaryLabel)
                    .opacity(formState.actionType == .delete ? 0.3 : 1.0)
            }

            if formState.actionType == .delete {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.formaError)
                    Text("Trash")
                        .fontWeight(.medium)
                        .foregroundColor(.formaError)
                }
                .padding(.vertical, 4)

                RulePreviewSection(onPreview: onPreviewDeleteMatches)
            } else {
                Button(action: { showFolderPicker = true }) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.formaSteelBlue)
                        Text(formState.destinationDisplayPath.isEmpty ? "Select folder..." : formState.destinationDisplayPath)
                            .fontWeight(.medium)
                            .foregroundColor(formState.destinationDisplayPath.isEmpty ? .formaSecondaryLabel : .formaObsidian)

                        if formState.destinationBookmarkData != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.formaSoftGreen)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.formaControlBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(formState.destinationDisplayPath.isEmpty ? Color.formaSteelBlue : Color.formaSeparator, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
