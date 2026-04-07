import Foundation
import SwiftUI

struct ProjectSpaceDetailView: View {
    struct Snapshot: Hashable {
        struct FileSnapshot: Identifiable, Hashable {
            let fileRow: ProjectSpaceFileRow
            let displayName: String
            let directoryText: String
            let recencyText: String
            let statusText: String?
            let tagsText: String?
            let iconName: String

            var id: String { fileRow.id }
        }

        let eyebrow: String
        let title: String
        let backButtonTitle: String
        let closeButtonTitle: String
        let fileCountText: String
        let recencyText: String
        let sourceFoldersTitle: String
        let sourceFolderSummary: String
        let filesTitle: String
        let emptyFilesText: String
        let files: [FileSnapshot]

        init(
            detail: ProjectSpaceDetail,
            now: Date = Date(),
            recencyTextProvider: ((Date, Date) -> String)? = nil,
            fileRecencyTextProvider: ((Date, Date) -> String)? = nil
        ) {
            let detailRecencyText = recencyTextProvider ?? Self.defaultRecencyText(activityAt:relativeTo:)
            let fileRecencyText = fileRecencyTextProvider ?? Self.defaultRecencyText(activityAt:relativeTo:)

            self.eyebrow = "Project Space"
            self.title = detail.projectLabel
            self.backButtonTitle = "Back"
            self.closeButtonTitle = "Close"
            self.fileCountText = Self.fileCountText(for: detail.fileCount)
            self.recencyText = detailRecencyText(detail.lastActivityAt, now)
            self.sourceFoldersTitle = "Source Folders"
            self.sourceFolderSummary = Self.sourceFolderSummary(for: detail.sourceFolderHints)
            self.filesTitle = "Current Files"
            self.emptyFilesText = "No current files are available in this project space."
            self.files = detail.files
                .sorted(by: Self.fileSortOrder(_:_:))
                .map { fileRow in
                    FileSnapshot(
                        fileRow: fileRow,
                        displayName: fileRow.displayName,
                        directoryText: Self.directoryText(for: fileRow.path),
                        recencyText: fileRecencyText(fileRow.lastActivityAt, now),
                        statusText: fileRow.workflowStatus.map(Self.statusText(for:)),
                        tagsText: Self.tagsText(for: fileRow.tags),
                        iconName: Self.iconName(for: fileRow)
                    )
                }
        }

        private static func fileCountText(for count: Int) -> String {
            count == 1 ? "1 file" : "\(count) files"
        }

        private static func defaultRecencyText(activityAt: Date, relativeTo now: Date) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: activityAt, relativeTo: now)
        }

        private static func fileSortOrder(_ lhs: ProjectSpaceFileRow, _ rhs: ProjectSpaceFileRow) -> Bool {
            if lhs.lastActivityAt != rhs.lastActivityAt {
                return lhs.lastActivityAt > rhs.lastActivityAt
            }

            let displayNameComparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            if displayNameComparison != .orderedSame {
                return displayNameComparison == .orderedAscending
            }

            return lhs.canonicalIdentity < rhs.canonicalIdentity
        }

        private static func sourceFolderSummary(for hints: [String]) -> String {
            guard !hints.isEmpty else {
                return "No source folders available"
            }

            return hints.joined(separator: ", ")
        }

        private static func directoryText(for path: String) -> String {
            let url = URL(fileURLWithPath: path)
            let directoryPath = url.deletingLastPathComponent().path
            return directoryPath.isEmpty ? path : directoryPath
        }

        private static func statusText(for status: MetadataWorkflowStatus) -> String {
            status.rawValue.capitalized
        }

        private static func tagsText(for tags: [String]) -> String? {
            guard !tags.isEmpty else { return nil }
            return tags.joined(separator: ", ")
        }

        private static func iconName(for fileRow: ProjectSpaceFileRow) -> String {
            switch fileRow.fileExtension.lowercased() {
            case "pdf":
                return "doc.richtext"
            case "png", "jpg", "jpeg", "gif", "heic":
                return "photo"
            case "zip":
                return "archivebox"
            case "md", "txt", "rtf":
                return "doc.text"
            default:
                return "doc"
            }
        }
    }

    let snapshot: Snapshot
    let onBack: () -> Void
    let onOpenFile: (ProjectSpaceFileRow) -> Void

    init(
        detail: ProjectSpaceDetail,
        onBack: @escaping () -> Void,
        onOpenFile: @escaping (ProjectSpaceFileRow) -> Void
    ) {
        self.snapshot = Snapshot(detail: detail)
        self.onBack = onBack
        self.onOpenFile = onOpenFile
    }

    init(
        snapshot: Snapshot,
        onBack: @escaping () -> Void,
        onOpenFile: @escaping (ProjectSpaceFileRow) -> Void
    ) {
        self.snapshot = snapshot
        self.onBack = onBack
        self.onOpenFile = onOpenFile
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            topBar
            headerBlock
            sourceFoldersBlock
            fileListBlock
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("projectSpaceDetailView")
    }

    private var topBar: some View {
        HStack(spacing: FormaSpacing.tight) {
            Button(action: onBack) {
                Label(snapshot.backButtonTitle, systemImage: "chevron.left")
                    .font(.formaCompactSemibold)
                    .foregroundStyle(Color.formaSteelBlue)
            }
            .buttonStyle(.plain)
            .help("Return to project spaces")

            Spacer(minLength: 0)

            Button(action: onBack) {
                Image(systemName: "xmark")
                    .font(.formaCaptionSemibold)
                    .foregroundStyle(Color.formaSecondaryLabel)
                    .padding(FormaSpacing.tight)
                    .background(
                        Circle()
                            .fill(Color.formaControlBackground.opacity(Color.FormaOpacity.light))
                    )
            }
            .buttonStyle(.plain)
            .help(snapshot.closeButtonTitle)
            .accessibilityLabel(snapshot.closeButtonTitle)
            .accessibilityIdentifier("projectSpaceDetailCloseButton")
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            Text(snapshot.eyebrow.uppercased())
                .font(.formaCaptionSemibold)
                .tracking(0.5)
                .foregroundStyle(Color.formaSecondaryLabel)

            Text(snapshot.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.formaLabel)

            HStack(spacing: FormaSpacing.tight) {
                statPill(text: snapshot.fileCountText, tint: .formaSteelBlue)
                statPill(text: snapshot.recencyText, tint: .formaSage)
            }
        }
    }

    private var sourceFoldersBlock: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(snapshot.sourceFoldersTitle)
                .font(.formaCaptionSemibold)
                .foregroundStyle(Color.formaSecondaryLabel)

            Label(snapshot.sourceFolderSummary, systemImage: "folder")
                .font(.formaBody)
                .foregroundStyle(Color.formaLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FormaSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaControlBackground.opacity(Color.FormaOpacity.light))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }

    private var fileListBlock: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(snapshot.filesTitle)
                .font(.formaCaptionSemibold)
                .foregroundStyle(Color.formaSecondaryLabel)

            if snapshot.files.isEmpty {
                Text(snapshot.emptyFilesText)
                    .font(.formaBody)
                    .foregroundStyle(Color.formaSecondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(FormaSpacing.standard)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(Color.formaControlBackground.opacity(Color.FormaOpacity.light))
                    )
            } else {
                LazyVStack(spacing: FormaSpacing.tight) {
                    ForEach(snapshot.files) { file in
                        fileButton(file)
                    }
                }
            }
        }
    }

    private func fileButton(_ file: Snapshot.FileSnapshot) -> some View {
        Button {
            onOpenFile(file.fileRow)
        } label: {
            HStack(alignment: .top, spacing: FormaSpacing.standard) {
                fileIcon(name: file.iconName)

                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    Text(file.displayName)
                        .font(.formaBodySemibold)
                        .foregroundStyle(Color.formaLabel)
                        .lineLimit(1)

                    Text(file.directoryText)
                        .font(.formaCaption)
                        .foregroundStyle(Color.formaSecondaryLabel)
                        .lineLimit(1)

                    HStack(spacing: FormaSpacing.tight) {
                        if let statusText = file.statusText {
                            metadataPill(text: statusText, tint: .formaSage)
                        }

                        if let tagsText = file.tagsText {
                            metadataPill(text: tagsText, tint: .formaSteelBlue)
                        }
                    }
                }

                Spacer(minLength: 0)

                Text(file.recencyText)
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaSecondaryLabel)
                    .multilineTextAlignment(.trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FormaSpacing.standard)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(Color.formaControlBackground.opacity(Color.FormaOpacity.light))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.formaCaptionSemibold)
            .foregroundStyle(tint)
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro / 2)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(Color.FormaOpacity.light))
            )
    }

    private func metadataPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.formaCaption)
            .foregroundStyle(tint)
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro / 2)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(Color.FormaOpacity.light))
            )
            .lineLimit(1)
    }

    private func fileIcon(name: String) -> some View {
        RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
            .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
            .frame(width: 34, height: 34)
            .overlay(
                Image(systemName: name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.formaSteelBlue)
            )
    }
}
