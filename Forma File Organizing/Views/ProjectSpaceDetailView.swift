import Foundation
import SwiftUI

struct ProjectSpaceDetailView: View {
    struct Snapshot: Hashable {
        struct WorkflowSectionSnapshot: Hashable {
            let sectionTitle: String
            let selectedTemplateText: String
            let helperText: String
            let previewText: String?
            let organizeButtonTitle: String
            let isOrganizeButtonEnabled: Bool
            let disabledReasonText: String?
            let latestRunSummaryText: String?
        }

        struct PreferredDestinationSnapshot: Hashable {
            let destinationDisplayName: String
            let eventCountText: String
            let lastUsedText: String
        }

        struct RecentActivitySnapshot: Hashable {
            let fileDisplayName: String
            let eventSummaryText: String
            let destinationText: String
            let timestampText: String
            let iconName: String
        }

        struct FileSnapshot: Identifiable, Hashable {
            let fileRow: ProjectSpaceFileRow
            let displayName: String
            let directoryText: String
            let recencyText: String
            let statusText: String?
            let tagsText: String?
            let projectAssociationText: String?
            let sourceFolderText: String?
            let correctionButtonTitle: String
            let iconName: String

            var id: String { fileRow.id }
        }

        let eyebrow: String
        let title: String
        let backButtonTitle: String
        let closeButtonTitle: String
        let fileCountText: String
        let recencyText: String
        let workflowSection: WorkflowSectionSnapshot?
        let overviewTitle: String
        let overviewFileCountText: String
        let overviewActiveFoldersText: String
        let overviewPreferredDestinationsText: String
        let overviewRecentActivityText: String
        let overviewSourceFoldersText: String
        let sourceFoldersTitle: String
        let sourceFolderSummary: String
        let preferredDestinationsTitle: String
        let emptyPreferredDestinationsText: String
        let preferredDestinations: [PreferredDestinationSnapshot]
        let recentActivityTitle: String
        let emptyRecentActivityText: String
        let recentActivity: [RecentActivitySnapshot]
        let filesTitle: String
        let emptyFilesText: String
        let files: [FileSnapshot]

        init(
            detail: ProjectSpaceDetail,
            workflowSection: WorkflowSectionSnapshot? = nil,
            now: Date = Date(),
            recencyTextProvider: ((Date, Date) -> String)? = nil,
            fileRecencyTextProvider: ((Date, Date) -> String)? = nil,
            destinationRecencyTextProvider: ((Date, Date) -> String)? = nil,
            activityRecencyTextProvider: ((Date, Date) -> String)? = nil
        ) {
            let detailRecencyText = recencyTextProvider ?? Self.defaultRecencyText(activityAt:relativeTo:)
            let fileRecencyText = fileRecencyTextProvider ?? Self.defaultRecencyText(activityAt:relativeTo:)
            let destinationRecencyText = destinationRecencyTextProvider ?? Self.defaultRecencyText(activityAt:relativeTo:)
            let activityRecencyText = activityRecencyTextProvider ?? Self.defaultRecencyText(activityAt:relativeTo:)

            self.eyebrow = "Project Space"
            self.title = detail.projectLabel
            self.backButtonTitle = "Back"
            self.closeButtonTitle = "Close"
            self.fileCountText = Self.fileCountText(for: detail.fileCount)
            self.recencyText = detailRecencyText(detail.lastActivityAt, now)
            self.workflowSection = workflowSection
            self.overviewTitle = "Overview"
            self.overviewFileCountText = Self.countText(
                count: detail.overview.currentFileCount,
                singular: "current file",
                plural: "current files"
            )
            self.overviewActiveFoldersText = Self.countText(
                count: detail.overview.activeFolderCount,
                singular: "active folder",
                plural: "active folders"
            )
            self.overviewPreferredDestinationsText = Self.countText(
                count: detail.overview.preferredDestinationCount,
                singular: "preferred destination",
                plural: "preferred destinations"
            )
            self.overviewRecentActivityText = Self.countText(
                count: detail.overview.recentActivityCount,
                singular: "recent event",
                plural: "recent events"
            )
            self.overviewSourceFoldersText = Self.sourceFolderSummary(
                for: detail.overview.activeFolderHints.isEmpty
                    ? detail.sourceFolderHints
                    : detail.overview.activeFolderHints
            )
            self.sourceFoldersTitle = "Source Folders"
            self.sourceFolderSummary = Self.sourceFolderSummary(for: detail.sourceFolderHints)
            self.preferredDestinationsTitle = "Preferred Destinations"
            self.emptyPreferredDestinationsText = "No preferred destinations have been learned yet."
            self.preferredDestinations = detail.preferredDestinations.map { destination in
                PreferredDestinationSnapshot(
                    destinationDisplayName: destination.destinationDisplayName,
                    eventCountText: Self.countText(
                        count: destination.eventCount,
                        singular: "move",
                        plural: "moves"
                    ),
                    lastUsedText: destinationRecencyText(destination.lastUsedAt, now)
                )
            }
            self.recentActivityTitle = "Recent Activity"
            self.emptyRecentActivityText = "No recent activity is available for this project space."
            self.recentActivity = detail.recentActivity.map { activity in
                RecentActivitySnapshot(
                    fileDisplayName: activity.fileDisplayName,
                    eventSummaryText: activity.detailsSummary ?? Self.eventTitle(for: activity.eventKind),
                    destinationText: activity.destinationDisplayName ?? "No destination recorded",
                    timestampText: activityRecencyText(activity.timestamp, now),
                    iconName: Self.activityIconName(for: activity.eventKind)
                )
            }
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
                        projectAssociationText: fileRow.projectAssociation,
                        sourceFolderText: fileRow.sourceFolderHint,
                        correctionButtonTitle: "Correct Label",
                        iconName: Self.iconName(for: fileRow)
                    )
                }
        }

        private static func fileCountText(for count: Int) -> String {
            count == 1 ? "1 file" : "\(count) files"
        }

        private static func countText(count: Int, singular: String, plural: String) -> String {
            count == 1 ? "1 \(singular)" : "\(count) \(plural)"
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

        private static func eventTitle(for eventKind: FileOrganizationHistoryEntry.EventKind) -> String {
            switch eventKind {
            case .organized:
                return "Organized"
            case .rekeyed:
                return "Rekeyed"
            case .ignored:
                return "Ignored"
            case .noted:
                return "Noted"
            case .undone:
                return "Undone"
            case .scanned:
                return "Scanned"
            }
        }

        private static func activityIconName(for eventKind: FileOrganizationHistoryEntry.EventKind) -> String {
            switch eventKind {
            case .organized:
                return "arrow.triangle.branch"
            case .rekeyed:
                return "tag"
            case .ignored:
                return "eye.slash"
            case .noted:
                return "pencil"
            case .undone:
                return "arrow.uturn.backward"
            case .scanned:
                return "magnifyingglass"
            }
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
    let workflowTemplateID: Binding<String?>?
    let workflowSimulationPreview: WorkflowTemplateSimulationPreview?
    let isWorkflowTemplatePickerEnabled: Bool
    let isOrganizingProjectSpaceWorkflow: Bool
    let onOrganizeProjectSpace: (() -> Void)?
    let onBack: () -> Void
    let onOpenFile: (ProjectSpaceFileRow) -> Void
    let onCorrectAssociation: (ProjectSpaceFileRow) -> Void

    init(
        detail: ProjectSpaceDetail,
        workflowSection: Snapshot.WorkflowSectionSnapshot? = nil,
        workflowTemplateID: Binding<String?>? = nil,
        workflowSimulationPreview: WorkflowTemplateSimulationPreview? = nil,
        isWorkflowTemplatePickerEnabled: Bool = true,
        isOrganizingProjectSpaceWorkflow: Bool = false,
        onOrganizeProjectSpace: (() -> Void)? = nil,
        onBack: @escaping () -> Void,
        onOpenFile: @escaping (ProjectSpaceFileRow) -> Void,
        onCorrectAssociation: @escaping (ProjectSpaceFileRow) -> Void = { _ in }
    ) {
        self.snapshot = Snapshot(detail: detail, workflowSection: workflowSection)
        self.workflowTemplateID = workflowTemplateID
        self.workflowSimulationPreview = workflowSimulationPreview
        self.isWorkflowTemplatePickerEnabled = isWorkflowTemplatePickerEnabled
        self.isOrganizingProjectSpaceWorkflow = isOrganizingProjectSpaceWorkflow
        self.onOrganizeProjectSpace = onOrganizeProjectSpace
        self.onBack = onBack
        self.onOpenFile = onOpenFile
        self.onCorrectAssociation = onCorrectAssociation
    }

    init(
        snapshot: Snapshot,
        workflowTemplateID: Binding<String?>? = nil,
        workflowSimulationPreview: WorkflowTemplateSimulationPreview? = nil,
        isWorkflowTemplatePickerEnabled: Bool = true,
        isOrganizingProjectSpaceWorkflow: Bool = false,
        onOrganizeProjectSpace: (() -> Void)? = nil,
        onBack: @escaping () -> Void,
        onOpenFile: @escaping (ProjectSpaceFileRow) -> Void,
        onCorrectAssociation: @escaping (ProjectSpaceFileRow) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.workflowTemplateID = workflowTemplateID
        self.workflowSimulationPreview = workflowSimulationPreview
        self.isWorkflowTemplatePickerEnabled = isWorkflowTemplatePickerEnabled
        self.isOrganizingProjectSpaceWorkflow = isOrganizingProjectSpaceWorkflow
        self.onOrganizeProjectSpace = onOrganizeProjectSpace
        self.onBack = onBack
        self.onOpenFile = onOpenFile
        self.onCorrectAssociation = onCorrectAssociation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            topBar
            headerBlock
            if let workflowSection = snapshot.workflowSection {
                workflowBlock(workflowSection)
            }
            overviewBlock
            sourceFoldersBlock
            preferredDestinationsBlock
            recentActivityBlock
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

    private var overviewBlock: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(snapshot.overviewTitle)
                .font(.formaCaptionSemibold)
                .foregroundStyle(Color.formaSecondaryLabel)

            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                overviewRow(text: snapshot.overviewFileCountText, iconName: "doc.text")
                overviewRow(text: snapshot.overviewActiveFoldersText, iconName: "folder")
                overviewRow(text: snapshot.overviewPreferredDestinationsText, iconName: "tray.and.arrow.down")
                overviewRow(text: snapshot.overviewRecentActivityText, iconName: "clock.arrow.circlepath")
                overviewRow(text: snapshot.overviewSourceFoldersText, iconName: "square.stack.3d.down.right")
            }
        }
        .padding(FormaSpacing.standard)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private func workflowBlock(_ workflow: Snapshot.WorkflowSectionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(workflow.sectionTitle)
                .font(.formaCaptionSemibold)
                .foregroundStyle(Color.formaSecondaryLabel)

            Text(workflow.helperText)
                .font(.formaBody)
                .foregroundStyle(Color.formaLabel)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                Text("Selected Template")
                    .font(.formaCaptionSemibold)
                    .foregroundStyle(Color.formaSecondaryLabel)

                Text(workflow.selectedTemplateText)
                    .font(.formaBodySemibold)
                    .foregroundStyle(Color.formaLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let workflowTemplateID {
                WorkflowTemplatePicker(
                    selectedTemplateID: workflowTemplateID,
                    preview: workflowSimulationPreview
                )
                .disabled(!isWorkflowTemplatePickerEnabled)
            } else if let previewText = workflow.previewText {
                metadataPill(
                    text: previewText,
                    tint: workflow.isOrganizeButtonEnabled ? .formaSage : .formaWarmOrange
                )
            }

            if let latestRunSummaryText = workflow.latestRunSummaryText {
                Label(latestRunSummaryText, systemImage: "clock.arrow.circlepath")
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                onOrganizeProjectSpace?()
            } label: {
                HStack(spacing: FormaSpacing.tight) {
                    if isOrganizingProjectSpaceWorkflow {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(workflow.organizeButtonTitle)
                        .font(.formaBodySemibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                !workflow.isOrganizeButtonEnabled ||
                    isOrganizingProjectSpaceWorkflow ||
                    onOrganizeProjectSpace == nil
            )

            if let disabledReasonText = workflow.disabledReasonText {
                Text(disabledReasonText)
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FormaSpacing.standard)
        .background(cardBackground)
        .overlay(cardBorder)
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

    private var preferredDestinationsBlock: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(snapshot.preferredDestinationsTitle)
                .font(.formaCaptionSemibold)
                .foregroundStyle(Color.formaSecondaryLabel)

            if snapshot.preferredDestinations.isEmpty {
                emptyCard(text: snapshot.emptyPreferredDestinationsText)
            } else {
                VStack(spacing: FormaSpacing.tight) {
                    ForEach(Array(snapshot.preferredDestinations.enumerated()), id: \.offset) { _, destination in
                        HStack(alignment: .center, spacing: FormaSpacing.standard) {
                            fileIcon(name: "tray.and.arrow.down")

                            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                                Text(destination.destinationDisplayName)
                                    .font(.formaBodySemibold)
                                    .foregroundStyle(Color.formaLabel)

                                Text(destination.lastUsedText)
                                    .font(.formaCaption)
                                    .foregroundStyle(Color.formaSecondaryLabel)
                            }

                            Spacer(minLength: 0)

                            metadataPill(text: destination.eventCountText, tint: .formaSteelBlue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(FormaSpacing.standard)
                        .background(cardBackground)
                        .overlay(cardBorder)
                    }
                }
            }
        }
    }

    private var recentActivityBlock: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(snapshot.recentActivityTitle)
                .font(.formaCaptionSemibold)
                .foregroundStyle(Color.formaSecondaryLabel)

            if snapshot.recentActivity.isEmpty {
                emptyCard(text: snapshot.emptyRecentActivityText)
            } else {
                VStack(spacing: FormaSpacing.tight) {
                    ForEach(Array(snapshot.recentActivity.enumerated()), id: \.offset) { _, activity in
                        HStack(alignment: .top, spacing: FormaSpacing.standard) {
                            fileIcon(name: activity.iconName)

                            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                                Text(activity.fileDisplayName)
                                    .font(.formaBodySemibold)
                                    .foregroundStyle(Color.formaLabel)

                                Text(activity.eventSummaryText)
                                    .font(.formaCaption)
                                    .foregroundStyle(Color.formaLabel)

                                Label(activity.destinationText, systemImage: "arrow.triangle.branch")
                                    .font(.formaCaption)
                                    .foregroundStyle(Color.formaSecondaryLabel)
                            }

                            Spacer(minLength: 0)

                            Text(activity.timestampText)
                                .font(.formaCaption)
                                .foregroundStyle(Color.formaSecondaryLabel)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(FormaSpacing.standard)
                        .background(cardBackground)
                        .overlay(cardBorder)
                    }
                }
            }
        }
    }

    private func fileButton(_ file: Snapshot.FileSnapshot) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
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
                .contentShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(alignment: .center, spacing: FormaSpacing.tight) {
                if let projectAssociationText = file.projectAssociationText {
                    metadataPill(text: projectAssociationText, tint: .formaSteelBlue)
                }

                if let sourceFolderText = file.sourceFolderText {
                    metadataPill(text: sourceFolderText, tint: .formaSage)
                }

                Spacer(minLength: 0)

                Button(file.correctionButtonTitle) {
                    onCorrectAssociation(file.fileRow)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FormaSpacing.standard)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private func overviewRow(text: String, iconName: String) -> some View {
        Label(text, systemImage: iconName)
            .font(.formaBody)
            .foregroundStyle(Color.formaLabel)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.formaBody)
            .foregroundStyle(Color.formaSecondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FormaSpacing.standard)
            .background(cardBackground)
            .overlay(cardBorder)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
            .fill(Color.formaControlBackground.opacity(Color.FormaOpacity.light))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
            .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
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
