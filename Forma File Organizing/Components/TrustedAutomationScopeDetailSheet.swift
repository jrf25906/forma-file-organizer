import SwiftUI

struct TrustedAutomationScopeDetailSheet: View {
    struct Snapshot: Hashable {
        struct RunSnapshot: Identifiable, Hashable {
            let id: UUID
            let statusText: String
            let triggerText: String
            let timestampText: String
            let summaryText: String
            let exampleFilesText: String?
        }

        let title: String
        let scopeTypeText: String
        let statusText: String
        let healthBadgeText: String
        let healthMessages: [String]
        let boundarySummary: String
        let sourceBoundarySummary: String
        let destinationSummary: String
        let lifecycleSummary: String
        let latestPreflightSummary: String
        let earnedTrustSummary: String
        let rationaleSummary: String
        let workflowTemplateTitle: String
        let workflowTemplateSummary: String
        let workflowStepShapeText: String
        let latestWorkflowStatusText: String
        let rollbackAvailabilityText: String
        let recentRuns: [RunSnapshot]
        let canPause: Bool
        let canResume: Bool
        let canRevoke: Bool

        init(
            detail: TrustedAutomationScopeDetail,
            now: Date = Date(),
            relativeDateProvider: (Date, Date) -> String = Self.defaultRelativeDateText
        ) {
            let parsedBoundary = Self.parseBoundary(detail)
            let preflightRun = detail.recentRuns.first { $0.status == .simulated }

            self.title = detail.summary.displayName
            self.scopeTypeText = detail.summary.scopeType.displayName
            self.statusText = detail.lifecycle.status.rawValue.capitalized
            self.healthBadgeText = Self.healthBadgeText(for: detail.health.state)
            self.healthMessages = detail.health.messages.isEmpty
                ? [Self.fallbackHealthMessage(for: detail.health.state)]
                : detail.health.messages
            self.boundarySummary = detail.summary.boundarySummary
            self.sourceBoundarySummary = parsedBoundary.source
            self.destinationSummary = parsedBoundary.destination
            self.lifecycleSummary = Self.makeLifecycleSummary(
                detail: detail,
                now: now,
                relativeDateProvider: relativeDateProvider
            )
            self.latestPreflightSummary = Self.makePreflightSummary(for: preflightRun)
            self.earnedTrustSummary = "\(detail.acceptedEvidenceCount) approvals • \(detail.overrideEvidenceCount) overrides • \(detail.undoEvidenceCount) undo corrections"
            self.rationaleSummary = detail.rationaleSummary
            self.workflowTemplateTitle = detail.selectedWorkflowTemplate?.displayName ?? "Template required"
            self.workflowTemplateSummary = detail.selectedWorkflowTemplate?.summaryText
                ?? "Assign a built-in workflow template to let this trusted scope execute automatically."
            self.workflowStepShapeText = Self.workflowStepShapeText(
                for: detail.selectedWorkflowTemplate?.allowedActions ?? detail.summary.allowedActions
            )
            self.latestWorkflowStatusText = Self.latestWorkflowStatusText(detail.latestWorkflowRun)
            self.rollbackAvailabilityText = Self.rollbackAvailabilityText(detail.latestWorkflowRun)
            self.recentRuns = detail.recentRuns.map {
                RunSnapshot(
                    id: $0.id,
                    statusText: Self.runStatusText($0.status),
                    triggerText: Self.triggerText($0.triggerSource),
                    timestampText: relativeDateProvider($0.endedAt ?? $0.startedAt, now),
                    summaryText: Self.runSummaryText($0),
                    exampleFilesText: $0.exampleFileNames.isEmpty ? nil : $0.exampleFileNames.prefix(3).joined(separator: ", ")
                )
            }
            self.canPause = detail.lifecycle.status == .active
            self.canResume = detail.lifecycle.status == .paused
            self.canRevoke = detail.lifecycle.status != .revoked
        }

        private static func parseBoundary(_ detail: TrustedAutomationScopeDetail) -> (source: String, destination: String) {
            if let boundaryDescriptor = detail.boundaryDescriptor {
                let source = makeSourceBoundarySummary(boundaryDescriptor.sourceBoundary)
                return (source, boundaryDescriptor.destinationSnapshot.displayName)
            }

            let parts = detail.summary.boundarySummary
                .components(separatedBy: "->")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if parts.count >= 2 {
                return (parts[0], parts[1])
            }

            return (detail.summary.boundarySummary, "Automatic destination")
        }

        private static func makeSourceBoundarySummary(
            _ sourceBoundary: TrustedAutomationScopeBoundaryDescriptor.SourceBoundary
        ) -> String {
            let base = sourceBoundary.scanRootPath.map {
                URL(fileURLWithPath: $0).lastPathComponent
            } ?? sourceBoundary.sourceLocation.displayName

            guard let relativeParentPath = sourceBoundary.relativeParentPath else {
                return base
            }

            return "\(base) > \(relativeParentPath.replacingOccurrences(of: "/", with: " > "))"
        }

        private static func makeLifecycleSummary(
            detail: TrustedAutomationScopeDetail,
            now: Date,
            relativeDateProvider: (Date, Date) -> String
        ) -> String {
            let trustedAt = relativeDateProvider(detail.lifecycle.createdAt, now)
            let evidenceAt = relativeDateProvider(detail.lifecycle.lastEvidenceAt, now)
            return "Trusted \(trustedAt) • Last evidence \(evidenceAt)"
        }

        private static func makePreflightSummary(for run: TrustedAutomationScopeRecentRunSummary?) -> String {
            guard let run else {
                return "No scope-specific preflight has run yet."
            }

            if let summaryText = run.summaryText, !summaryText.isEmpty {
                return summaryText
            }

            if run.organizedCount > 0 {
                return "\(run.organizedCount) file(s) would move automatically on the next trusted pass."
            }

            if run.heldCount > 0 {
                return "\(run.heldCount) file(s) would still be held for review."
            }

            if run.failedCount > 0 {
                return "\(run.failedCount) file(s) failed in the latest trusted pass."
            }

            return "Recent scope checks matched \(run.matchedCount) file(s)."
        }

        private static func runSummaryText(_ run: TrustedAutomationScopeRecentRunSummary) -> String {
            if let summaryText = run.summaryText, !summaryText.isEmpty {
                return summaryText
            }

            if run.organizedCount > 0 {
                return "\(run.organizedCount) organized • \(run.heldCount) held • \(run.failedCount) failed"
            }

            return "\(run.matchedCount) matched • \(run.eligibleCount) eligible"
        }

        private static func runStatusText(_ status: TrustedAutomationScopeRunStatus) -> String {
            switch status {
            case .simulated:
                return "Simulated"
            case .executed:
                return "Executed"
            case .held:
                return "Held"
            case .failed:
                return "Failed"
            }
        }

        private static func triggerText(_ triggerSource: TrustedAutomationScopeRunTriggerSource) -> String {
            switch triggerSource {
            case .promotionPreview:
                return "Promotion preview"
            case .scheduledAutomationPass:
                return "Scheduled pass"
            case .realtimeAutomationPass:
                return "Live watch pass"
            case .manualRefreshInspection:
                return "Manual inspection"
            }
        }

        private static func healthBadgeText(for state: TrustedAutomationScopeHealthState) -> String {
            switch state {
            case .healthy:
                return "Healthy"
            case .quiet:
                return "Quiet"
            case .needsAttention:
                return "Needs Attention"
            }
        }

        private static func fallbackHealthMessage(for state: TrustedAutomationScopeHealthState) -> String {
            switch state {
            case .healthy:
                return "This trusted scope is ready for automatic organization."
            case .quiet:
                return "No recent automation activity has been recorded."
            case .needsAttention:
                return "This trusted scope needs attention before it runs cleanly."
            }
        }

        private static func defaultRelativeDateText(_ date: Date, _ now: Date) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: now)
        }

        private static func workflowStepShapeText(
            for actions: [TrustedAutomationAllowedAction]
        ) -> String {
            TrustedAutomationAllowedAction.workflowStepShapeText(for: actions)
        }

        private static func latestWorkflowStatusText(
            _ latestWorkflowRun: TrustedAutomationScopeWorkflowRunSummary?
        ) -> String {
            guard let latestWorkflowRun else {
                return "Latest workflow run: Not run yet"
            }

            let statusText: String
            switch latestWorkflowRun.primaryStatus {
            case .queued:
                statusText = "Queued"
            case .running:
                statusText = "Running"
            case .succeeded:
                statusText = "Succeeded"
            case .completedWithIssues:
                statusText = "Completed with issues"
            case .failed:
                statusText = "Failed"
            case .canceled:
                statusText = "Canceled"
            }

            return "Latest workflow run: \(statusText)"
        }

        private static func rollbackAvailabilityText(
            _ latestWorkflowRun: TrustedAutomationScopeWorkflowRunSummary?
        ) -> String {
            guard let latestWorkflowRun else {
                return "Rollback unavailable until a workflow run succeeds"
            }

            if latestWorkflowRun.isRollbackAvailable {
                return "Rollback available"
            }

            switch latestWorkflowRun.rollbackStatus {
            case .requested:
                return "Rollback requested"
            case .inProgress:
                return "Rollback in progress"
            case .succeeded:
                return "Rollback completed"
            case .failed:
                return "Rollback failed"
            case .notRequested:
                return "Rollback unavailable"
            }
        }
    }

    let detail: TrustedAutomationScopeDetail
    let onPause: () -> Void
    let onResume: () -> Void
    let onRevoke: () -> Void
    let onClose: () -> Void

    private var snapshot: Snapshot {
        Snapshot(detail: detail)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: FormaSpacing.large) {
                    header

                    card(title: "Boundary", systemImage: "scope") {
                        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                            detailMetric(title: "Scope", value: snapshot.scopeTypeText)
                            detailMetric(title: "Source", value: snapshot.sourceBoundarySummary)
                            detailMetric(title: "Destination", value: snapshot.destinationSummary)
                            detailMetric(title: "Boundary summary", value: snapshot.boundarySummary)
                        }
                    }

                    card(title: "Status", systemImage: "checkmark.shield") {
                        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                            HStack(spacing: FormaSpacing.tight) {
                                statusBadge(snapshot.statusText, tint: statusTint(snapshot.statusText))
                                statusBadge(snapshot.healthBadgeText, tint: statusTint(snapshot.healthBadgeText))
                            }

                            Text(snapshot.lifecycleSummary)
                                .font(.formaSmall)
                                .foregroundStyle(Color.formaSecondaryLabel)

                            ForEach(snapshot.healthMessages, id: \.self) { message in
                                Text(message)
                                    .font(.formaSmall)
                                    .foregroundStyle(Color.formaSecondaryLabel)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    card(title: "Workflow", systemImage: "square.stack.3d.down.forward") {
                        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                            detailMetric(title: "Template", value: snapshot.workflowTemplateTitle)
                            detailMetric(title: "Summary", value: snapshot.workflowTemplateSummary)
                            detailMetric(title: "Step shape", value: snapshot.workflowStepShapeText)
                            detailMetric(title: "Status", value: snapshot.latestWorkflowStatusText)
                            detailMetric(title: "Rollback", value: snapshot.rollbackAvailabilityText)
                        }
                    }

                    card(title: "Latest Preflight", systemImage: "checklist") {
                        Text(snapshot.latestPreflightSummary)
                            .font(.formaBody)
                            .foregroundStyle(Color.formaLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    card(title: "Earned Trust", systemImage: "person.badge.shield.checkmark") {
                        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                            Text(snapshot.earnedTrustSummary)
                                .font(.formaSmallSemibold)
                                .foregroundStyle(Color.formaSteelBlue)
                            Text(snapshot.rationaleSummary)
                                .font(.formaBody)
                                .foregroundStyle(Color.formaLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    card(title: "Recent Runs", systemImage: "clock.arrow.circlepath") {
                        if snapshot.recentRuns.isEmpty {
                            Text("No recent runs recorded yet.")
                                .font(.formaBody)
                                .foregroundStyle(Color.formaSecondaryLabel)
                        } else {
                            VStack(spacing: FormaSpacing.standard) {
                                ForEach(snapshot.recentRuns) { run in
                                    VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                                        HStack {
                                            statusBadge(run.statusText, tint: statusTint(run.statusText))
                                            Text(run.triggerText)
                                                .font(.formaSmallSemibold)
                                                .foregroundStyle(Color.formaLabel)
                                            Spacer()
                                            Text(run.timestampText)
                                                .font(.formaCaption)
                                                .foregroundStyle(Color.formaSecondaryLabelHigh)
                                        }

                                        Text(run.summaryText)
                                            .font(.formaSmall)
                                            .foregroundStyle(Color.formaLabel)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if let exampleFilesText = run.exampleFilesText {
                                            Text(exampleFilesText)
                                                .font(.formaCaption)
                                                .foregroundStyle(Color.formaSecondaryLabelHigh)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(FormaSpacing.standard)
                                    .background(
                                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                                            .fill(Color.formaControlBackground.opacity(Color.FormaOpacity.overlay))
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(FormaSpacing.extraLarge)
            }

            Divider()

            HStack {
                Button("Close", action: onClose)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.formaSecondaryLabel)

                Spacer()

                if snapshot.canPause {
                    Button("Pause Scope", action: onPause)
                        .buttonStyle(.bordered)
                }

                if snapshot.canResume {
                    Button("Resume Scope", action: onResume)
                        .buttonStyle(.borderedProminent)
                        .tint(.formaSteelBlue)
                }

                if snapshot.canRevoke {
                    Button("Revoke Scope", role: .destructive, action: onRevoke)
                        .buttonStyle(.bordered)
                }
            }
            .padding(FormaSpacing.large)
        }
        .frame(minWidth: 560, minHeight: 640)
        .background(Color.formaBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text(detail.summary.displayName)
                .font(.formaH2)
                .foregroundStyle(Color.formaLabel)

            Text("Manage this review-earned autopilot boundary, inspect its latest health, and control its lifecycle.")
                .font(.formaBody)
                .foregroundStyle(Color.formaSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func card<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: systemImage)
                    .font(.formaBodySemibold)
                    .foregroundStyle(Color.formaSteelBlue)
                Text(title)
                    .font(.formaBodySemibold)
                    .foregroundStyle(Color.formaLabel)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FormaSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
    }

    private func detailMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            Text(title)
                .font(.formaCaptionBold)
                .foregroundStyle(Color.formaSecondaryLabelHigh)
            Text(value)
                .font(.formaBody)
                .foregroundStyle(Color.formaLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusBadge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.formaCaptionBold)
            .foregroundStyle(tint)
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro)
            .background(
                Capsule()
                    .fill(tint.opacity(Color.FormaOpacity.light))
            )
    }

    private func statusTint(_ text: String) -> Color {
        switch text {
        case "Active", "Healthy", "Executed":
            return Color.formaSage
        case "Paused", "Quiet", "Held", "Simulated":
            return Color.formaWarmOrange
        case "Needs Attention", "Failed":
            return Color.formaWarmOrange
        case "Revoked":
            return Color.formaSecondaryLabelHigh
        default:
            return Color.formaSteelBlue
        }
    }
}
