import SwiftUI

struct RecentFilesGrid: View {
    let files: [FileItem]
    let onSeeAll: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: FormaSpacing.standard),
        GridItem(.flexible(), spacing: FormaSpacing.standard),
        GridItem(.flexible(), spacing: FormaSpacing.standard),
        GridItem(.flexible(), spacing: FormaSpacing.standard)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Header
            HStack {
                Text("Recent Files")
                    .formaH2Style()
                    .foregroundColor(Color.formaObsidian)

                Spacer()

                Button(action: onSeeAll) {
                    HStack(spacing: FormaSpacing.micro) {
                        Text("See All")
                            .formaMetadataStyle()
                        Image(systemName: "arrow.right")
                            .font(.formaCaption)
                    }
                    .foregroundColor(Color.formaSteelBlue)
                }
                .buttonStyle(.plain)
            }

            // Grid
            if files.isEmpty {
                EmptyRecentFiles()
            } else {
                LazyVGrid(columns: columns, spacing: FormaSpacing.standard) {
                    ForEach(Array(files.prefix(8)), id: \.path) { file in
                        RecentFileCard(file: file)
                    }
                }
            }
        }
        .padding(FormaSpacing.generous)
    }
}

struct RecentFileCard: View {
    let file: FileItem

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            // File icon/thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(file.category.color.opacity(Color.FormaOpacity.light))
                    .frame(height: 100)

                Image(systemName: file.iconName)
                    .font(.formaIconMedium)
                    .foregroundColor(file.category.color)
            }

            // File info
            VStack(alignment: .leading, spacing: FormaSpacing.micro / 2) {
                Text(file.name)
                    .formaMetadataStyle()
                    .foregroundColor(Color.formaObsidian)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack {
                    Text(file.fileExtension.uppercased())
                        .font(.formaMicro)
                        .foregroundColor(.formaBoneWhite)
                        .padding(.horizontal, FormaSpacing.micro)
                        .padding(.vertical, FormaSpacing.micro / 2)
                        .background(
                            Capsule()
                                .fill(file.category.color)
                        )

                    Text(file.size)
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                }
            }
        }
        .padding(FormaSpacing.tight)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .fill(Color.formaControlBackground)
                .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.subtle), radius: 4, x: 0, y: 2)
        )
    }
}

struct EmptyRecentFiles: View {
    var body: some View {
        VStack(spacing: FormaSpacing.standard) {
            Image(systemName: "folder.badge.questionmark")
                .font(.formaIcon)
                .foregroundColor(.formaSecondaryLabel)

            Text("No Recent Files")
                .formaH2Style()
                .foregroundColor(.formaSecondaryLabel)

            Text("Scan your Desktop or Downloads to see files here")
                .formaMetadataStyle()
                .foregroundColor(.formaSecondaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(FormaSpacing.extraLarge)
    }
}

// MARK: - Preview
#Preview {
    RecentFilesGrid(
        files: FileItem.mocks,
        onSeeAll: {
            Log.debug("Preview see all recent files tapped", category: .ui)
        }
    )
    .frame(width: 800)
}
