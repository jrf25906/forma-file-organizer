import SwiftUI

struct WorkflowTemplateSimulationPreview: Equatable, Sendable {
    let templateID: String
    let templateDisplayName: String
    let selectedFileCount: Int
    let readyToRunCount: Int
    let blockedCount: Int
    let exampleFileNames: [String]

    var summaryText: String {
        var components = ["\(selectedFileCount) selected"]

        if readyToRunCount > 0 {
            components.append("\(readyToRunCount) ready to run")
        }

        if blockedCount > 0 {
            components.append("\(blockedCount) blocked in simulation")
        }

        return components.joined(separator: ", ")
    }

    static func make(
        templateID: String?,
        files: [FileItem],
        invocationContext: WorkflowInvocationContext = .dashboardReview,
        planner: WorkflowPlanner = WorkflowPlanner()
    ) -> WorkflowTemplateSimulationPreview? {
        guard let template = WorkflowTemplateCatalog.template(for: templateID),
              !files.isEmpty else {
            return nil
        }

        let plan = planner.plan(
            templateID: template.id,
            files: files,
            invocationContext: invocationContext
        )
        let readyToRunCount = plan.files.filter { !$0.isBlocked }.count
        let blockedCount = plan.files.count - readyToRunCount

        return WorkflowTemplateSimulationPreview(
            templateID: template.id,
            templateDisplayName: template.displayName,
            selectedFileCount: files.count,
            readyToRunCount: readyToRunCount,
            blockedCount: blockedCount,
            exampleFileNames: Array(files.prefix(3).map(\.name))
        )
    }
}

struct WorkflowTemplatePicker: View {
    @Binding var selectedTemplateID: String?
    var preview: WorkflowTemplateSimulationPreview?

    private var selection: Binding<String> {
        Binding(
            get: { selectedTemplateID ?? "" },
            set: { selectedTemplateID = $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            Text("Workflow Template")
                .font(.formaCaption)
                .foregroundColor(.formaSecondaryLabel)

            Picker("Workflow Template", selection: selection) {
                Text("Choose a template")
                    .tag("")

                ForEach(WorkflowTemplateCatalog.shippedTemplates) { template in
                    Text(template.displayName)
                        .tag(template.id)
                }
            }
            .pickerStyle(.menu)

            if let template = WorkflowTemplateCatalog.template(for: selectedTemplateID) {
                Text(template.summaryText)
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let preview {
                Text(preview.summaryText)
                    .font(.formaCaptionSemibold)
                    .foregroundColor(preview.blockedCount == 0 ? .formaSage : .formaWarmOrange)
            }
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaControlBackground.opacity(Color.FormaOpacity.strong))
        .formaCornerRadius(FormaRadius.control)
    }
}
