import SwiftUI
import UniformTypeIdentifiers

/// Sheet for editing a file's destination using secure folder picker.
/// Replaces legacy string-based destination entry with bookmark-backed system.
struct EditDestinationSheet: View {
    let file: FileItem
    let onSave: (Destination) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var destinationDisplayPath: String
    @State private var destinationBookmarkData: Data?
    @State private var showFolderPicker: Bool = false
    @State private var errorMessage: String?

    init(file: FileItem, onSave: @escaping (Destination) -> Void) {
        self.file = file
        self.onSave = onSave

        // Initialize from file's existing destination
        if let destination = file.destination {
            _destinationDisplayPath = State(initialValue: destination.displayName)
            _destinationBookmarkData = State(initialValue: destination.bookmarkData)
        } else {
            _destinationDisplayPath = State(initialValue: "")
            _destinationBookmarkData = State(initialValue: nil)
        }
    }

    private var hasValidDestination: Bool {
        destinationBookmarkData != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.generous) {
            Text("Edit Destination")
                .formaH2Style()
                .foregroundColor(Color.formaLabel)

            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                Text(file.name)
                    .font(.formaBodyBold)
                    .foregroundColor(Color.formaLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("Current: \(file.destination?.displayName ?? "None")")
                    .formaMetadataStyle()
                    .foregroundColor(Color.formaSecondaryLabel)
            }

            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                Text("Move to")
                    .font(Font.formaBodyBold)
                    .foregroundColor(Color.formaLabel)

                HStack(spacing: FormaSpacing.tight) {
                    // Destination display
                    HStack(spacing: FormaSpacing.tight) {
                        if hasValidDestination {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.formaSteelBlue)
                                .font(.formaBody)
                            Text(destinationDisplayPath)
                                .font(.formaBody)
                                .foregroundColor(.formaLabel)
                        } else {
                            Image(systemName: "folder.badge.plus")
                                .foregroundColor(.formaSecondaryLabel)
                                .font(.formaBody)
                            Text("Select a folder…")
                                .font(.formaBody)
                                .foregroundColor(.formaSecondaryLabel)
                        }
                        Spacer()
                    }
                    .padding(FormaSpacing.standard)
                    .background(
                        hasValidDestination
                            ? Color.formaSteelBlue.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle)
                            : Color.formaControlBackground
                    )
                    .formaCornerRadius(FormaRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                            .stroke(hasValidDestination ? Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay) : Color.formaSeparator, lineWidth: 1)
                    )
                    .onTapGesture {
                        showFolderPicker = true
                    }

                    Button(action: { showFolderPicker = true }) {
                        Image(systemName: "folder")
                            .font(.formaBodyMedium)
                            .foregroundColor(.formaSteelBlue)
                            .padding(FormaSpacing.standard)
                            .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                            .formaCornerRadius(FormaRadius.small)
                    }
                    .buttonStyle(.plain)
                    .help("Choose folder")
                }

                Text(hasValidDestination ? "Folder access saved securely" : "Select a folder to set the destination")
                    .formaMetadataStyle()
                    .foregroundColor(hasValidDestination ? .formaSage : .formaSecondaryLabel)

                if let error = errorMessage {
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.formaWarmOrange)
                        Text(error)
                            .font(.formaSmall)
                            .foregroundColor(.formaWarmOrange)
                    }
                }
            }

            Spacer()

            HStack(spacing: FormaSpacing.standard) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Save") {
                    guard let bookmarkData = destinationBookmarkData else {
                        errorMessage = "Please select a destination folder"
                        return
                    }
                    let destination = Destination.folder(bookmark: bookmarkData, displayName: destinationDisplayPath)
                    onSave(destination)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!hasValidDestination)
            }
            .padding(.top, FormaSpacing.standard)
        }
        .padding(FormaSpacing.extraLarge)
        .frame(width: 420)
        .accessibilityIdentifier("editDestinationSheet")
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                destinationBookmarkData = bookmarkData
                destinationDisplayPath = url.lastPathComponent
                errorMessage = nil

            } catch {
                errorMessage = "Failed to save folder access: \(error.localizedDescription)"
            }

        case .failure(let error):
            errorMessage = "Failed to select folder: \(error.localizedDescription)"
        }
    }
}
