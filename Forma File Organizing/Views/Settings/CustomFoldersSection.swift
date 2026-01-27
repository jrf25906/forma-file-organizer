import SwiftUI

/// Settings section for managing folder access permissions.
///
/// This replaces the previous SwiftData-based CustomFolder management with
/// a simpler Keychain-based approach using BookmarkFolderService.
struct CustomFoldersSection: View {
    @StateObject private var folderService = BookmarkFolderService.shared
    @State private var showRevokeConfirmation = false
    @State private var folderToRevoke: BookmarkFolder?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Folder Access")
                    .font(.formaH2)
                    .foregroundColor(.formaObsidian)
                Spacer()
            }
            .padding(FormaSpacing.generous)

            // Description
            Text("Forma can organize files in the folders you've granted access to. Toggle folders on or off to control which are scanned.")
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)
                .padding(.horizontal, FormaSpacing.generous)
                .padding(.bottom, FormaSpacing.standard)

            if folderService.availableFolders.isEmpty {
                // Empty state
                FormaEmptyState(
                    title: "No Folders Configured",
                    message: "Grant access to folders during onboarding or by clicking the + button in the sidebar.",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                // Folder list
                ScrollView {
                    LazyVStack(spacing: FormaSpacing.standard) {
                        ForEach(folderService.availableFolders) { folder in
                            FolderAccessRow(
                                folder: folder,
                                onToggle: { enabled in
                                    folderService.setEnabled(enabled, for: folder)
                                },
                                onRevoke: {
                                    folderToRevoke = folder
                                    showRevokeConfirmation = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, FormaSpacing.generous)
                    .padding(.bottom, FormaSpacing.generous)
                }
            }

            // Info text
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "info.circle")
                    .font(.formaCaption)
                    .foregroundColor(.formaTertiaryLabel)
                Text("To add more folders, use the + button in the sidebar.")
                    .font(.formaCaption)
                    .foregroundColor(.formaTertiaryLabel)
            }
            .padding(.horizontal, FormaSpacing.generous)
            .padding(.bottom, FormaSpacing.standard)
        }
        .background(Color.formaBoneWhite)
        .alert("Revoke Access?", isPresented: $showRevokeConfirmation) {
            Button("Cancel", role: .cancel) {
                folderToRevoke = nil
            }
            Button("Revoke", role: .destructive) {
                if let folder = folderToRevoke {
                    folderService.removeBookmark(for: folder.folderType)
                }
                folderToRevoke = nil
            }
        } message: {
            if let folder = folderToRevoke {
                Text("Forma will no longer have access to your \(folder.displayName) folder. You can re-grant access later from the sidebar.")
            }
        }
    }
}

// MARK: - Folder Access Row

private struct FolderAccessRow: View {
    let folder: BookmarkFolder
    let onToggle: (Bool) -> Void
    let onRevoke: () -> Void

    @State private var isHovered = false
    @State private var isEnabled: Bool

    init(folder: BookmarkFolder, onToggle: @escaping (Bool) -> Void, onRevoke: @escaping () -> Void) {
        self.folder = folder
        self.onToggle = onToggle
        self.onRevoke = onRevoke
        self._isEnabled = State(initialValue: folder.isEnabled)
    }

    var body: some View {
        HStack(spacing: FormaSpacing.standard) {
            // Folder icon
            Image(systemName: folder.iconName)
                .font(.formaH3)
                .foregroundColor(isEnabled ? .formaSteelBlue : .formaSecondaryLabel)
                .frame(width: 32)

            // Folder info
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.formaBodyBold)
                    .foregroundColor(isEnabled ? .formaObsidian : .formaSecondaryLabel)

                if let path = folder.path {
                    Text(path)
                        .font(.formaSmall)
                        .foregroundColor(.formaTertiaryLabel)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            // Toggle
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Color.formaSteelBlue)
                .scaleEffect(0.9)
                .onChange(of: isEnabled) { _, newValue in
                    onToggle(newValue)
                }

            // Revoke button (shown on hover)
            if isHovered {
                Button(action: onRevoke) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.formaBody)
                        .foregroundColor(.formaSecondaryLabel)
                }
                .buttonStyle(.plain)
                .help("Revoke access to this folder")
                .transition(.opacity)
            }
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaObsidian.opacity(Color.FormaOpacity.light), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CustomFoldersSection()
        .frame(width: 500, height: 400)
}
