import SwiftUI

struct ProjectSpaceAutomationComposerSheet: View {
    @Binding var draft: ProjectSpaceAutomationComposerDraft
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Form {
                Section("Workflow Template") {
                    WorkflowTemplatePicker(
                        selectedTemplateID: Binding(
                            get: { draft.workflowTemplateID },
                            set: { draft.workflowTemplateID = $0 }
                        ),
                        preview: nil
                    )
                }

                Section("Triggers") {
                    toggleRow("Manual run", kind: .manual)
                    toggleRow("Realtime ingress", kind: .folderWatch)
                    toggleRow("Scheduled sweep", kind: .scheduledSweep)
                }

                Section("Admission") {
                    Picker("Admission Mode", selection: $draft.admissionMode) {
                        Text("Manual review").tag(ProjectSpaceAutomationAdmissionMode.manualReview)
                        Text("Automatic admission").tag(ProjectSpaceAutomationAdmissionMode.automatic)
                    }
                    .pickerStyle(.radioGroup)
                }

                Section("Lifecycle") {
                    Text("New policies are saved as drafts so you can inspect them before relying on them.")
                        .font(.formaBody)
                        .foregroundStyle(Color.formaSecondaryLabel)
                }
            }

            footer
        }
        .frame(minWidth: 540, minHeight: 460)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.micro) {
            Text("New Project Policy")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.formaLabel)

            Text("Create a constrained policy for this project space.")
                .font(.formaBody)
                .foregroundStyle(Color.formaSecondaryLabel)
        }
        .padding(FormaSpacing.large)
    }

    private var footer: some View {
        HStack(spacing: FormaSpacing.tight) {
            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)

            Spacer(minLength: 0)

            Button("Save Draft", action: onSave)
                .buttonStyle(.borderedProminent)
                .disabled(WorkflowTemplateCatalog.template(for: draft.workflowTemplateID) == nil)
        }
        .padding(FormaSpacing.large)
        .background(Color.formaBackground)
    }

    private func toggleRow(_ title: String, kind: ProjectSpaceAutomationTriggerKind) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { draft.triggerKinds.contains(kind) },
                set: { isEnabled in
                    if isEnabled {
                        if !draft.triggerKinds.contains(kind) {
                            draft.triggerKinds.append(kind)
                        }
                    } else {
                        draft.triggerKinds.removeAll { $0 == kind }
                    }

                    if draft.triggerKinds.isEmpty {
                        draft.triggerKinds = [.manual]
                    } else {
                        draft.triggerKinds = ProjectSpaceAutomationPolicy.normalizedTriggerKindRaws(draft.triggerKinds)
                            .compactMap(ProjectSpaceAutomationTriggerKind.init(rawValue:))
                    }
                }
            )
        )
    }
}
