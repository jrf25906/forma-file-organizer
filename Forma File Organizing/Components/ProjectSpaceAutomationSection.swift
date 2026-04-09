import SwiftUI

struct ProjectSpaceAutomationSection: View {
    struct Snapshot: Hashable {
        struct PolicySnapshot: Identifiable, Hashable {
            let id: UUID
            let workflowTemplateID: String
            let workflowTemplateDisplayName: String
            let state: ProjectSpaceAutomationPolicyState
            let stateText: String
            let triggerSummaryText: String
            let admissionSummaryText: String
            let healthBadgeText: String
            let healthMessageText: String
            let latestRunSummaryText: String?
            let accessibilityIdentifier: String

            init(
                id: UUID,
                workflowTemplateID: String,
                workflowTemplateDisplayName: String,
                state: ProjectSpaceAutomationPolicyState,
                stateText: String,
                triggerSummaryText: String,
                admissionSummaryText: String,
                healthBadgeText: String,
                healthMessageText: String,
                latestRunSummaryText: String?,
                accessibilityIdentifier: String? = nil
            ) {
                self.id = id
                self.workflowTemplateID = workflowTemplateID
                self.workflowTemplateDisplayName = workflowTemplateDisplayName
                self.state = state
                self.stateText = stateText
                self.triggerSummaryText = triggerSummaryText
                self.admissionSummaryText = admissionSummaryText
                self.healthBadgeText = healthBadgeText
                self.healthMessageText = healthMessageText
                self.latestRunSummaryText = latestRunSummaryText
                self.accessibilityIdentifier = accessibilityIdentifier ?? "projectSpaceAutomationPolicy_\(id.uuidString)"
            }

            init(policy: ProjectSpaceAutomationPolicyDetail) {
                self.id = policy.id
                self.workflowTemplateID = policy.workflowTemplateID
                self.workflowTemplateDisplayName = policy.workflowTemplateDisplayName
                self.state = policy.state
                self.stateText = policy.stateText
                self.triggerSummaryText = policy.triggerSummaryText
                self.admissionSummaryText = policy.admissionSummaryText
                self.healthBadgeText = policy.healthBadgeText
                self.healthMessageText = policy.healthMessageText
                self.latestRunSummaryText = policy.latestRunSummaryText
                self.accessibilityIdentifier = "projectSpaceAutomationPolicy_\(policy.id.uuidString)"
            }
        }

        struct GroupSnapshot: Identifiable, Hashable {
            let kind: ProjectSpaceAutomationBoardGroupKind
            let title: String
            let policies: [PolicySnapshot]

            var id: String { kind.rawValue }

            init(group: ProjectSpaceAutomationBoardGroup) {
                self.kind = group.kind
                self.title = group.title
                self.policies = group.policies.map(PolicySnapshot.init(policy:))
            }

            init(
                kind: ProjectSpaceAutomationBoardGroupKind,
                title: String,
                policies: [PolicySnapshot]
            ) {
                self.kind = kind
                self.title = title
                self.policies = policies
            }
        }

        let title: String
        let subtitle: String
        let composerButtonTitle: String
        let groups: [GroupSnapshot]

        init(board: ProjectSpaceAutomationBoard) {
            self.title = board.title
            self.subtitle = board.subtitle
            self.composerButtonTitle = board.composerButtonTitle
            self.groups = board.groups.map(GroupSnapshot.init(group:))
        }

        init(
            title: String,
            subtitle: String,
            composerButtonTitle: String,
            groups: [GroupSnapshot]
        ) {
            self.title = title
            self.subtitle = subtitle
            self.composerButtonTitle = composerButtonTitle
            self.groups = groups
        }
    }

    let snapshot: Snapshot
    let onCreatePolicy: (() -> Void)?
    let onInspectPolicy: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            header

            if snapshot.groups.isEmpty {
                Text("No project policies yet. Create one to keep this space consistent.")
                    .font(.formaBody)
                    .foregroundStyle(Color.formaSecondaryLabel)
                    .padding(FormaSpacing.standard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBackground)
                    .overlay(cardBorder)
            } else {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    ForEach(snapshot.groups) { group in
                        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                            Text(group.title)
                                .font(.formaCaptionBold)
                                .foregroundStyle(Color.formaSecondaryLabelHigh)

                            VStack(spacing: FormaSpacing.tight) {
                                ForEach(group.policies) { policy in
                                    policyButton(policy)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: FormaSpacing.standard) {
            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                Text(snapshot.title)
                    .font(.formaBodySemibold)
                    .foregroundStyle(Color.formaLabel)

                Text(snapshot.subtitle)
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let onCreatePolicy {
                Button(snapshot.composerButtonTitle, action: onCreatePolicy)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func policyButton(_ policy: Snapshot.PolicySnapshot) -> some View {
        Button {
            onInspectPolicy(policy.id)
        } label: {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                HStack(alignment: .firstTextBaseline, spacing: FormaSpacing.tight) {
                    VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                        Text(policy.workflowTemplateDisplayName)
                            .font(.formaBodySemibold)
                            .foregroundStyle(Color.formaLabel)

                        Text(policy.stateText)
                            .font(.formaCaption)
                            .foregroundStyle(Color.formaSecondaryLabel)
                    }

                    Spacer(minLength: 0)

                    statusBadge(policy.healthBadgeText)
                }

                Text(policy.triggerSummaryText)
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaSecondaryLabel)

                Text(policy.admissionSummaryText)
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaSecondaryLabel)

                Text(policy.healthMessageText)
                    .font(.formaCaption)
                    .foregroundStyle(Color.formaLabel)
                    .fixedSize(horizontal: false, vertical: true)

                if let latestRunSummaryText = policy.latestRunSummaryText {
                    Label(latestRunSummaryText, systemImage: "clock.arrow.circlepath")
                        .font(.formaCaption)
                        .foregroundStyle(Color.formaSecondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FormaSpacing.standard)
            .background(cardBackground)
            .overlay(cardBorder)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(policy.accessibilityIdentifier)
    }

    private func statusBadge(_ text: String) -> some View {
        Text(text)
            .font(.formaCaptionSemibold)
            .foregroundStyle(Color.formaSteelBlue)
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
            )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
            .fill(Color.formaControlBackground.opacity(Color.FormaOpacity.light))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
            .strokeBorder(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
    }
}
