import SwiftUI

/// Settings section for managing folder access permissions.
///
/// This replaces the previous SwiftData-based CustomFolder management with
/// a simpler Keychain-based approach using BookmarkFolderService.
struct CustomFoldersSection: View {
    @StateObject private var folderService = BookmarkFolderService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showRevokeConfirmation = false
    @State private var folderToRevoke: BookmarkFolder?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            SettingsPageHeader(
                "Folder Access",
                subtitle: "Forma can organize files in the folders you've granted access to. Toggle folders on or off to control which are scanned."
            )
            .padding(.vertical, FormaSpacing.standard)

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
                    .padding(.bottom, FormaSpacing.generous)
                }
            }

            // Info text
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "info.circle")
                    .font(.formaCaption)
                    .foregroundColor(colorScheme == .dark ? .formaTertiaryLabelHigh : .formaTertiaryLabel)
                Text("To add more folders, use the + button in the sidebar.")
                    .font(.formaCaption)
                    .foregroundColor(colorScheme == .dark ? .formaTertiaryLabelHigh : .formaTertiaryLabel)
            }
            .padding(.bottom, FormaSpacing.standard)
        }
        .background(Color.clear)
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
    @Environment(\.colorScheme) private var colorScheme

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
                .foregroundColor(
                    isEnabled
                        ? .formaSteelBlue
                        : (colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel)
                )
                .frame(width: 32)

            // Folder info
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.formaBodyBold)
                    .foregroundColor(isEnabled ? .formaLabel : (colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel))

                if let path = folder.path {
                    Text(path)
                        .font(.formaSmall)
                        .foregroundColor(colorScheme == .dark ? .formaTertiaryLabelHigh : .formaTertiaryLabel)
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
                        .foregroundColor(colorScheme == .dark ? .formaSecondaryLabelHigh : .formaSecondaryLabel)
                }
                .buttonStyle(.plain)
                .help("Revoke access to this folder")
                .transition(.opacity)
            }
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaSurfaceWork)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? Color.formaBoneWhite.opacity(0.14)
                        : Color.formaObsidian.opacity(0.08),
                    lineWidth: FormaBorderWidth.thin
                )
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
