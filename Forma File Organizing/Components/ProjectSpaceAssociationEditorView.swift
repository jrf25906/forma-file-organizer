import SwiftUI

struct ProjectSpaceAssociationEditorView: View {
    let fileName: String
    let sourceFolderHint: String?
    @Binding var proposedLabel: String
    let suggestedLabels: [String]
    let onSave: () -> Void
    let onCancel: () -> Void

    private var trimmedProposedLabel: String {
        proposedLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                Text("Correct Project Label")
                    .font(.formaBodySemibold)
                    .foregroundStyle(Color.formaLabel)

                Text(fileName)
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaSecondaryLabel)

                if let sourceFolderHint, !sourceFolderHint.isEmpty {
                    Label(sourceFolderHint, systemImage: "folder")
                        .font(.formaCaption)
                        .foregroundStyle(Color.formaSecondaryLabel)
                }
            }

            TextField("Project label", text: $proposedLabel)
                .textFieldStyle(.roundedBorder)

            if !suggestedLabels.isEmpty {
                VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                    Text("Suggested Labels")
                        .font(.formaCaptionSemibold)
                        .foregroundStyle(Color.formaSecondaryLabel)

                    HStack(spacing: FormaSpacing.tight) {
                        ForEach(suggestedLabels, id: \.self) { label in
                            Button(label) {
                                proposedLabel = label
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            HStack(spacing: FormaSpacing.tight) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer(minLength: 0)

                Button("Save Correction", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedProposedLabel.isEmpty)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("projectSpaceAssociationEditor")
    }
}
