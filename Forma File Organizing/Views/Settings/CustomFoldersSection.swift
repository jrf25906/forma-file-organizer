import SwiftUI
import SwiftData

struct CustomFoldersSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var customFolders: [CustomFolder]

    private var sortedCustomFolders: [CustomFolder] {
        customFolders.sorted { $0.creationDate < $1.creationDate }
    }

    @StateObject private var folderManager = CustomFolderManager()
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var editingFolder: CustomFolder?
    @State private var editingName = ""
    @State private var hoveredFolderId: PersistentIdentifier?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Custom Folders")
                    .font(.formaH2)
                    .foregroundColor(.formaObsidian)
                Spacer()

                FormaPrimaryButton(title: "Add Folders", action: addFolder)
                    .frame(width: 140)
                    .disabled(isAdding)
                    .hoverLift(scale: 1.03, shadowRadius: 8)
            }
            .padding(FormaSpacing.generous)

            if sortedCustomFolders.isEmpty {
                FormaEmptyState(
                    title: "No Custom Folders",
                    message: "Add folders to scan for files to organize. You can select multiple folders at once.",
                    actionTitle: "Add Folders",
                    action: addFolder
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: FormaSpacing.standard) {
                        ForEach(sortedCustomFolders) { folder in
                            FolderRow(
                                folder: folder,
                                isHovered: hoveredFolderId == folder.id,
                                isEditing: editingFolder?.id == folder.id,
                                editingName: $editingName,
                                onEditStart: {
                                    startEditing(folder)
                                },
                                onEditSave: {
                                    saveEditedName(for: folder)
                                },
                                onDelete: {
                                    deleteFolder(folder)
                                },
                                onToggle: {
                                    folder.isEnabled.toggle()
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        Log.error("CustomFoldersSection: Failed to toggle folder '\(folder.name)' - \(error.localizedDescription)", category: .analytics)
                                        folder.isEnabled.toggle() // Revert on failure
                                        errorMessage = "Failed to save folder change"
                                        showError = true
                                    }
                                }
                            )
                            .onHover { hovering in
                                hoveredFolderId = hovering ? folder.id : nil
                            }
                        }
                    }
                    .padding(.horizontal, FormaSpacing.generous)
                    .padding(.bottom, FormaSpacing.generous)
                }
            }
        }
        .background(Color.formaBoneWhite)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    private func addFolder() {
        isAdding = true
        Task {
            do {
                // Use multi-select to allow adding several folders at once
                let folders = try await folderManager.createCustomFolders()
                for folder in folders {
                    modelContext.insert(folder)
                }
                try modelContext.save()
            } catch CustomFolderManager.CustomFolderError.userCancelled {
                // User cancelled, do nothing
            } catch {
                Log.error("CustomFoldersSection: Failed to add folders - \(error.localizedDescription)", category: .analytics)
                errorMessage = error.localizedDescription
                showError = true
            }
            isAdding = false
        }
    }

    private func startEditing(_ folder: CustomFolder) {
        editingFolder = folder
        editingName = folder.name
    }

    private func saveEditedName(for folder: CustomFolder) {
        if !editingName.isEmpty {
            let previousName = folder.name
            do {
                try folder.updateName(editingName)
                try modelContext.save()
            } catch {
                Log.error("CustomFoldersSection: Failed to rename folder '\(previousName)' - \(error.localizedDescription)", category: .analytics)
                errorMessage = "Failed to rename folder: \(error.localizedDescription)"
                showError = true
            }
        }
        editingFolder = nil
    }

    private func deleteFolder(_ folder: CustomFolder) {
        let folderName = folder.name
        modelContext.delete(folder)
        do {
            try modelContext.save()
        } catch {
            Log.error("CustomFoldersSection: Failed to delete folder '\(folderName)' - \(error.localizedDescription)", category: .analytics)
            modelContext.insert(folder) // Re-insert on failure
            errorMessage = "Failed to delete folder"
            showError = true
        }
    }
}

// MARK: - Folder Row Component

struct FolderRow: View {
    let folder: CustomFolder
    let isHovered: Bool
    let isEditing: Bool
    @Binding var editingName: String
    let onEditStart: () -> Void
    let onEditSave: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        let isEnabledBinding = Binding(
            get: { folder.isEnabled },
            set: { folder.isEnabled = $0 }
        )

        HStack(spacing: FormaSpacing.standard) {
            Toggle("", isOn: isEnabledBinding)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Color.formaSteelBlue)
                .scaleEffect(0.9)
                .onChange(of: folder.isEnabled) { _, _ in
                    onToggle()
                }

            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    TextField("Folder Name", text: $editingName, onCommit: onEditSave)
                        .textFieldStyle(.roundedBorder)
                        .font(.formaBodyBold)
                } else {
                    Text(folder.name)
                        .font(.formaBodyBold)
                        .foregroundColor(folder.isEnabled ? .formaObsidian : .formaSecondaryLabel)
                }

                Text(folder.path)
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onEditStart) {
                        Image(systemName: "pencil")
                            .font(.formaBodySemibold)
                            .foregroundColor(.formaSecondaryLabel)
                            .frame(width: 32, height: 32)
                            .background(Color.formaControlBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Edit folder name")
                    .hoverLift(scale: 1.05, shadowRadius: 3)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.formaBodySemibold)
                            .foregroundColor(.formaError)
                            .frame(width: 32, height: 32)
                            .background(Color.formaError.opacity(Color.FormaOpacity.light))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete folder")
                    .hoverLift(scale: 1.05, shadowRadius: 3)
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaObsidian.opacity(Color.FormaOpacity.light), lineWidth: 1)
        )
        .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle), radius: 2, x: 0, y: 1)
        .toggleRipple(trigger: folder.isEnabled)
        .hoverLift(scale: 1.005, shadowRadius: 6)
    }
}
