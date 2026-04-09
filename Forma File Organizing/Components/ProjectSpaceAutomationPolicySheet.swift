import SwiftUI

struct ProjectSpaceAutomationPolicySheet: View {
    let policy: ProjectSpaceAutomationPolicyDetail
    let preview: WorkflowTemplateSimulationPreview?
    let manualRunDisabledReason: String?
    let isManualRunInProgress: Bool
    let onRunNow: () -> Void
    let onActivate: (() -> Void)?
    let onPause: (() -> Void)?
    let onResume: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Form {
                Section("Policy") {
                    labeledValue("Workflow", policy.workflowTemplateDisplayName)
                    labeledValue("Status", policy.stateText)
                    labeledValue("Triggers", policy.triggerSummaryText)
                }

                Section("Admission") {
                    labeledValue("Mode", policy.admissionSummaryText)
                    Text(policy.admissionExplanationText)
                        .font(.formaBody)
                        .foregroundStyle(Color.formaLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Health") {
                    labeledValue("Badge", policy.healthBadgeText)
                    Text(policy.healthMessageText)
                        .font(.formaBody)
                        .foregroundStyle(Color.formaLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Latest Run") {
                    if let latestRunSummaryText = policy.latestRunSummaryText {
                        Text(latestRunSummaryText)
                            .font(.formaBody)
                            .foregroundStyle(Color.formaLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("No policy-owned run has completed yet.")
                            .font(.formaBody)
                            .foregroundStyle(Color.formaSecondaryLabel)
                    }
                }

                Section("Manual Run") {
                    if let preview {
                        Text(preview.summaryText)
                            .font(.formaBody)
                            .foregroundStyle(Color.formaLabel)
                    }

                    Button {
                        onRunNow()
                    } label: {
                        HStack(spacing: FormaSpacing.tight) {
                            if isManualRunInProgress {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Text("Run Now")
                                .font(.formaBodySemibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isManualRunInProgress || manualRunDisabledReason != nil)

                    if let manualRunDisabledReason {
                        Text(manualRunDisabledReason)
                            .font(.formaCaption)
                            .foregroundStyle(Color.formaSecondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            footer
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: FormaSpacing.standard) {
            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                Text(policy.workflowTemplateDisplayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.formaLabel)

                Text("Project Policy")
                    .font(.formaCaptionSemibold)
                    .foregroundStyle(Color.formaSecondaryLabel)
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.formaCaptionSemibold)
                    .foregroundStyle(Color.formaSecondaryLabel)
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.large)
    }

    private var footer: some View {
        HStack(spacing: FormaSpacing.tight) {
            if let onActivate {
                Button("Activate", action: onActivate)
                    .buttonStyle(.bordered)
            }

            if let onPause {
                Button("Pause", action: onPause)
                    .buttonStyle(.bordered)
            }

            if let onResume {
                Button("Resume", action: onResume)
                    .buttonStyle(.bordered)
            }

            Spacer(minLength: 0)

            Button("Done", action: onClose)
                .buttonStyle(.borderedProminent)
        }
        .padding(FormaSpacing.large)
        .background(Color.formaBackground)
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            Text(label)
                .font(.formaCaptionSemibold)
                .foregroundStyle(Color.formaSecondaryLabel)

            Text(value)
                .font(.formaBody)
                .foregroundStyle(Color.formaLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, FormaSpacing.micro)
    }
}
