import SwiftUI
import SwiftData

struct WorkflowRunDetailSheet: View {
    struct Snapshot {
        struct StepRow: Identifiable {
            let id: UUID
            let title: String
            let statusText: String
            let errorText: String?
        }

        struct FileRow: Identifiable {
            let id: UUID
            let title: String
            let sourceSummary: String?
            let destinationSummary: String?
            let dispositionText: String
            let compensationText: String
            let failureText: String?
        }

        let templateDisplayName: String
        let statusText: String
        let rollbackText: String
        let startedAtText: String
        let endedAtText: String
        let stepRows: [StepRow]
        let fileRows: [FileRow]
    }

    let runID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var snapshot: Snapshot?
    @State private var hasLoadedSnapshot = false

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot {
                    ScrollView {
                        VStack(alignment: .leading, spacing: FormaSpacing.large) {
                            summaryCard(snapshot)

                            if !snapshot.stepRows.isEmpty {
                                detailCard(title: "Steps", systemImage: "list.number") {
                                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                                        ForEach(snapshot.stepRows) { row in
                                            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                                                Text(row.title)
                                                    .font(.formaBodySemibold)
                                                    .foregroundColor(.formaLabel)
                                                Text(row.statusText)
                                                    .font(.formaSmall)
                                                    .foregroundColor(.formaSecondaryLabel)

                                                if let errorText = row.errorText {
                                                    Text(errorText)
                                                        .font(.formaCaption)
                                                        .foregroundColor(.formaWarmOrange)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            if !snapshot.fileRows.isEmpty {
                                detailCard(title: "File Actions", systemImage: "doc.text") {
                                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                                        ForEach(snapshot.fileRows) { row in
                                            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                                                Text(row.title)
                                                    .font(.formaBodySemibold)
                                                    .foregroundColor(.formaLabel)

                                                if let sourceSummary = row.sourceSummary {
                                                    detailMetric(title: "From", value: sourceSummary)
                                                }
                                                if let destinationSummary = row.destinationSummary {
                                                    detailMetric(title: "To", value: destinationSummary)
                                                }
                                                detailMetric(title: "Disposition", value: row.dispositionText)
                                                detailMetric(title: "Compensation", value: row.compensationText)

                                                if let failureText = row.failureText {
                                                    Text(failureText)
                                                        .font(.formaCaption)
                                                        .foregroundColor(.formaWarmOrange)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(FormaSpacing.extraLarge)
                    }
                } else if hasLoadedSnapshot {
                    ContentUnavailableView(
                        "Workflow Run Unavailable",
                        systemImage: "exclamationmark.square",
                        description: Text("The selected workflow run could not be loaded.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(FormaSpacing.extraLarge)
                } else {
                    ProgressView("Loading workflow run…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(FormaSpacing.extraLarge)
                }
            }
            .navigationTitle("Workflow Run")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .task(id: runID) {
            snapshot = loadSnapshot()
            hasLoadedSnapshot = true
        }
    }

    private func loadSnapshot() -> Snapshot? {
        let store = WorkflowAuditStore(modelContext: modelContext)
        let run = try? store.run(id: runID)
        guard let run else {
            return nil
        }

        let stepRuns = (try? store.stepRuns(runID: run.id)) ?? []
        let stepRunsByID = Dictionary(uniqueKeysWithValues: stepRuns.map { ($0.id, $0) })
        let fileRows = ((try? store.fileActions(runID: run.id)) ?? []).map { action in
            Snapshot.FileRow(
                id: action.id,
                title: workflowActionTitle(for: action, using: stepRunsByID),
                sourceSummary: action.sourcePath.map(abbreviatePath),
                destinationSummary: action.destinationPath.map(abbreviatePath),
                dispositionText: action.disposition.rawValue.capitalized,
                compensationText: action.compensationStatus.rawValue.capitalized,
                failureText: action.failureReason
            )
        }

        return Snapshot(
            templateDisplayName: WorkflowTemplateCatalog.template(for: run.workflowTemplateID)?.displayName ?? "Workflow",
            statusText: ActivityItem.workflowStatusText(
                primaryStatus: run.primaryStatus,
                rollbackStatus: run.rollbackStatus
            ),
            rollbackText: ActivityItem.workflowRollbackText(
                primaryStatus: run.primaryStatus,
                rollbackStatus: run.rollbackStatus
            ),
            startedAtText: timestampText(for: run.startedAt),
            endedAtText: run.endedAt.map(timestampText) ?? "Still running",
            stepRows: stepRuns.map { stepRun in
                Snapshot.StepRow(
                    id: stepRun.id,
                    title: stepRunTitle(stepRun.stepID),
                    statusText: stepRun.status.rawValue.capitalized,
                    errorText: stepRun.errorMessage
                )
            },
            fileRows: fileRows
        )
    }

    private func summaryCard(_ snapshot: Snapshot) -> some View {
        detailCard(title: snapshot.templateDisplayName, systemImage: "square.stack.3d.down.forward") {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                detailMetric(title: "Status", value: snapshot.statusText)
                detailMetric(title: "Rollback", value: snapshot.rollbackText)
                detailMetric(title: "Started", value: snapshot.startedAtText)
                detailMetric(title: "Completed", value: snapshot.endedAtText)
            }
        }
    }

    private func detailCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            Label(title, systemImage: systemImage)
                .font(.formaBodySemibold)
                .foregroundColor(.formaLabel)

            content()
        }
        .padding(FormaSpacing.large)
        .background(Color.formaCardBackground)
        .formaCornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }

    private func detailMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            Text(title)
                .font(.formaCaptionSemibold)
                .foregroundColor(.formaSecondaryLabel)
            Text(value)
                .font(.formaSmall)
                .foregroundColor(.formaLabel)
        }
    }

    func workflowActionTitle(
        for action: WorkflowFileActionRecord,
        using stepRunsByID: [UUID: WorkflowStepRunRecord]
    ) -> String {
        guard let stepRunID = action.stepRunID,
              let stepRun = stepRunsByID[stepRunID] else {
            return action.destinationPath.flatMap(displayFileName(forPath:))
                ?? action.sourcePath.flatMap(displayFileName(forPath:))
                ?? action.fileIdentity
        }

        let kindTitle = stepKindTitle(stepRun.stepID)
        let fileName = action.destinationPath.flatMap(displayFileName(forPath:))
            ?? action.sourcePath.flatMap(displayFileName(forPath:))
            ?? stepRunFileName(stepRun.stepID)

        guard let fileName else {
            return kindTitle
        }

        return "\(kindTitle) • \(fileName)"
    }

    func stepRunTitle(_ stepID: String) -> String {
        let kindTitle = stepKindTitle(stepID)
        guard let fileName = stepRunFileName(stepID) else {
            return kindTitle
        }

        return "\(kindTitle) • \(fileName)"
    }

    private func timestampText(for date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func stepKindTitle(_ stepID: String) -> String {
        let parts = stepID.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 2 else {
            return stepID
        }

        return String(parts[1]).capitalized
    }

    private func stepRunFileName(_ stepID: String) -> String? {
        let parts = stepID.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            return nil
        }

        return displayFileName(forPath: String(parts[2]))
    }

    private func displayFileName(forPath path: String) -> String? {
        guard path.contains("/") else {
            return nil
        }

        let fileName = URL(fileURLWithPath: path).lastPathComponent
        return fileName.isEmpty ? nil : fileName
    }

    private func abbreviatePath(_ path: String) -> String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homePath) {
            return "~" + path.dropFirst(homePath.count)
        }
        return path
    }
}
