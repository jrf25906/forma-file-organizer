import SwiftUI

/// Sheet for editing a file's destination using secure folder picker.
/// Replaces legacy string-based destination entry with bookmark-backed system.
struct EditDestinationSheet: View {
    let file: FileItem
    let onSave: (Destination) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var destinationDisplayPath: String
    @State private var destinationBookmarkData: Data?
    @State private var isChoosingDestination = false
    @State private var errorMessage: String?
    private let destinationResolver = DestinationResolver()

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

    private var hasSuggestedDestination: Bool {
        !destinationDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        } else if hasSuggestedDestination {
                            Image(systemName: "folder.badge.questionmark")
                                .foregroundColor(.formaWarmOrange)
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
                            : Color.formaControlBackground.opacity(colorScheme == .dark ? 0.56 : 0.86)
                    )
                    .formaCornerRadius(FormaRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                            .stroke(hasValidDestination ? Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay) : Color.formaSeparator, lineWidth: 1)
                    )
                    .onTapGesture {
                        requestDestinationAccess()
                    }

                    Button(action: requestDestinationAccess) {
                        Image(systemName: "folder")
                            .font(.formaBodyMedium)
                            .foregroundColor(.formaSteelBlue)
                            .frame(width: 40, height: 40)
                            .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                            .formaCornerRadius(FormaRadius.small)
                    }
                    .buttonStyle(.plain)
                    .help("Choose folder")
                    .disabled(isChoosingDestination)
                }

                Text(destinationHelperText)
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
                .frame(minHeight: 40)

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
                .frame(minHeight: 40)
            }
            .padding(.top, FormaSpacing.standard)
        }
        .padding(FormaSpacing.extraLarge)
        .frame(minWidth: 420, idealWidth: 460, maxWidth: 560)
        .background(Color.formaBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editDestinationSheet")
    }

    private var destinationHelperText: String {
        if hasValidDestination {
            return "Folder access saved securely"
        }

        if hasSuggestedDestination {
            return "Suggested destination: \(destinationDisplayPath). Click the folder button to grant access and Forma will finish the path for you."
        }

        return "Select a folder to set the destination"
    }

    private func requestDestinationAccess() {
        guard !isChoosingDestination else { return }

        isChoosingDestination = true
        errorMessage = nil

        Task { @MainActor in
            defer { isChoosingDestination = false }

            do {
                let destination = try await destinationResolver.requestDestinationAccess(
                    forSuggestedPath: destinationDisplayPath
                )
                destinationBookmarkData = destination.bookmarkData
                destinationDisplayPath = destination.displayName
            } catch DestinationResolver.AccessGrantError.cancelled {
                return
            } catch {
                errorMessage = "Failed to grant destination access: \(error.localizedDescription)"
            }
        }
    }
}
