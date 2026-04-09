import SwiftUI

struct TrustedAutomationScopeRecommendationSheet: View {
    struct Snapshot: Hashable {
        let recommendedBadgeText: String
        let selectedScopeTitle: String
        let selectedScopeDisplayName: String
        let sourceBoundaryTitle: String
        let sourceBoundarySummary: String
        let destinationTitle: String
        let destinationSummary: String
        let automaticBehaviorSummary: String
        let preflightSummary: String
        let rationaleSummary: String
        let alternativeScopeTitles: [String]

        init(
            recommendation: TrustedAutomationScopeRecommendation,
            selectedScopeType: TrustedAutomationScopeType,
            previewSummary: TrustedAutomationScopeRecommendationPreviewSummary?
        ) {
            let selectedOption = recommendation.option(for: selectedScopeType) ?? recommendation.recommendedScope
            let destinationSummary = recommendation.snapshot.chosenDestination?.displayName ?? "No destination"
            let sourceBoundarySummary = Self.makeSourceBoundarySummary(from: recommendation.snapshot)

            self.recommendedBadgeText = "Recommended"
            self.selectedScopeTitle = selectedOption.scopeType.displayName
            self.selectedScopeDisplayName = selectedOption.displayName
            self.sourceBoundaryTitle = "Source boundary"
            self.sourceBoundarySummary = sourceBoundarySummary
            self.destinationTitle = "Trusted destination"
            self.destinationSummary = destinationSummary
            self.automaticBehaviorSummary = Self.makeAutomaticBehaviorSummary(
                for: selectedOption.scopeType,
                snapshot: recommendation.snapshot,
                destinationSummary: destinationSummary
            )
            self.preflightSummary = previewSummary?.summaryText ?? "No pending or ready files currently match this scope."
            self.rationaleSummary = selectedOption.rationaleSummary
            self.alternativeScopeTitles = recommendation.allScopeChoices
                .filter { $0.scopeType != selectedOption.scopeType }
                .map { $0.scopeType.displayName }
        }

        private static func makeSourceBoundarySummary(from snapshot: OrganizationMemorySnapshot) -> String {
            let base = snapshot.scanRootPath.map {
                URL(fileURLWithPath: $0).lastPathComponent
            } ?? snapshot.sourceLocation.displayName

            guard let relativeParentPath = snapshot.relativeParentPath, !relativeParentPath.isEmpty else {
                return base
            }

            return "\(base) > \(relativeParentPath.replacingOccurrences(of: "/", with: " > "))"
        }

        private static func makeAutomaticBehaviorSummary(
            for scopeType: TrustedAutomationScopeType,
            snapshot: OrganizationMemorySnapshot,
            destinationSummary: String
        ) -> String {
            switch scopeType {
            case .rule:
                return "Files that match this rule can move automatically to \(destinationSummary)."
            case .folder:
                return "Files from this folder can move automatically to \(destinationSummary)."
            case .category:
                return "\(snapshot.fileTypeCategory.displayName) files from this source can move automatically to \(destinationSummary)."
            }
        }

    }

    let recommendation: TrustedAutomationScopeRecommendation
    let previewSummariesByType: [TrustedAutomationScopeType: TrustedAutomationScopeRecommendationPreviewSummary]?
    let onConfirm: (TrustedAutomationScopeType, String) -> Void
    let onCancel: () -> Void

    @State private var selectedScopeType: TrustedAutomationScopeType
    @State private var selectedWorkflowTemplateID: String?

    private var selectedWorkflowTemplate: BuiltInWorkflowTemplate? {
        WorkflowTemplateCatalog.template(for: selectedWorkflowTemplateID)
    }

    init(
        recommendation: TrustedAutomationScopeRecommendation,
        previewSummariesByType: [TrustedAutomationScopeType: TrustedAutomationScopeRecommendationPreviewSummary]? = nil,
        onConfirm: @escaping (TrustedAutomationScopeType, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.recommendation = recommendation
        self.previewSummariesByType = previewSummariesByType
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _selectedScopeType = State(initialValue: recommendation.recommendedScope.scopeType)
        _selectedWorkflowTemplateID = State(initialValue: nil)
    }

    var body: some View {
        let snapshot = Snapshot(
            recommendation: recommendation,
            selectedScopeType: selectedScopeType,
            previewSummary: previewSummary(for: selectedScopeType)
        )

        VStack(alignment: .leading, spacing: FormaSpacing.large) {
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                Text("Trust this automatically")
                    .font(.formaH2)
                    .foregroundColor(.formaLabel)

                Text("Forma recommends the narrowest safe scope based on what you just approved. Review the boundary before anything becomes automatic.")
                    .font(.formaBody)
                    .foregroundColor(.formaSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: FormaSpacing.standard) {
                ForEach(recommendation.allScopeChoices) { option in
                    scopeOptionRow(option)
                }
            }

            HStack(alignment: .top, spacing: FormaSpacing.standard) {
                detailCard(title: snapshot.sourceBoundaryTitle, systemImage: "scope") {
                    Text(snapshot.sourceBoundarySummary)
                }

                detailCard(title: snapshot.destinationTitle, systemImage: "folder") {
                    Text(snapshot.destinationSummary)
                }
            }

            detailCard(title: "Automatic behavior", systemImage: "bolt.badge.checkmark") {
                Text(snapshot.automaticBehaviorSummary)
            }

            detailCard(title: "Workflow template", systemImage: "square.stack.3d.down.forward") {
                VStack(alignment: .leading, spacing: FormaSpacing.standard) {
                    WorkflowTemplatePicker(selectedTemplateID: $selectedWorkflowTemplateID)

                    if let selectedWorkflowTemplate {
                        Text("Trusted automation will run: \(workflowStepShapeText(for: selectedWorkflowTemplate.allowedActions)).")
                            .font(.formaCaption)
                            .foregroundColor(.formaSecondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Choose a built-in template before enabling trust.")
                        .font(.formaCaptionSemibold)
                        .foregroundColor(.formaWarmOrange)
                    }
                }
            }

            detailCard(title: "First preflight", systemImage: "checklist") {
                Text(snapshot.preflightSummary)
            }

            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                Text("Why this is safe")
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaLabel)

                Text(snapshot.rationaleSummary)
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                if !snapshot.alternativeScopeTitles.isEmpty {
                    Text("Alternatives: \(snapshot.alternativeScopeTitles.joined(separator: ", "))")
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabelHigh)
                }
            }
            .padding(FormaSpacing.large)
            .background(Color.formaControlBackground.opacity(Color.FormaOpacity.overlay))
            .formaCornerRadius(FormaRadius.card)

            HStack {
                Button("Not now", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundColor(.formaSecondaryLabel)

                Spacer()

                Button("Trust \(snapshot.selectedScopeTitle) Scope") {
                    guard let selectedWorkflowTemplateID else { return }
                    onConfirm(selectedScopeType, selectedWorkflowTemplateID)
                }
                .buttonStyle(.borderedProminent)
                .tint(.formaSteelBlue)
                .disabled(selectedWorkflowTemplateID == nil)
            }
        }
        .padding(FormaSpacing.extraLarge)
        .frame(width: 460)
        .background(Color.formaBackground)
    }

    private func scopeOptionRow(_ option: TrustedAutomationScopeRecommendationOption) -> some View {
        Button(action: {
            selectedScopeType = option.scopeType
        }) {
            HStack(spacing: FormaSpacing.standard) {
                Image(systemName: option.scopeType == selectedScopeType ? "largecircle.fill.circle" : "circle")
                    .font(.formaBody)
                    .foregroundColor(option.scopeType == selectedScopeType ? .formaSteelBlue : .formaSecondaryLabel)

                VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                    HStack(spacing: FormaSpacing.tight) {
                        Text(option.scopeType.displayName)
                            .font(.formaBodySemibold)
                            .foregroundColor(.formaLabel)

                        if option.scopeType == recommendation.recommendedScope.scopeType {
                            Text(
                                Snapshot(
                                    recommendation: recommendation,
                                    selectedScopeType: option.scopeType,
                                    previewSummary: previewSummary(for: option.scopeType)
                                ).recommendedBadgeText
                            )
                                .font(.formaCaptionBold)
                                .foregroundColor(.formaSteelBlue)
                                .padding(.horizontal, FormaSpacing.tight)
                                .padding(.vertical, FormaSpacing.micro)
                                .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
                                .clipShape(Capsule())
                        }
                    }

                    Text(option.displayName)
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }

                Spacer()
            }
            .padding(FormaSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(option.scopeType == selectedScopeType ? Color.formaSteelBlue.opacity(Color.FormaOpacity.light) : Color.formaCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .stroke(
                        option.scopeType == selectedScopeType
                        ? Color.formaSteelBlue.opacity(Color.FormaOpacity.prominent)
                        : Color.formaSeparator.opacity(Color.FormaOpacity.strong),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func detailCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: systemImage)
                    .font(.formaCaptionBold)
                    .foregroundColor(.formaSteelBlue)
                Text(title)
                    .font(.formaCaptionBold)
                    .foregroundColor(.formaSecondaryLabelHigh)
            }

            content()
                .font(.formaBody)
                .foregroundColor(.formaLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FormaSpacing.large)
        .background(Color.formaCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
        .formaCornerRadius(FormaRadius.card)
    }

    private func previewSummary(
        for scopeType: TrustedAutomationScopeType
    ) -> TrustedAutomationScopeRecommendationPreviewSummary? {
        let selectedOption = recommendation.option(for: scopeType) ?? recommendation.recommendedScope
        return previewSummariesByType?[selectedOption.scopeType]
    }

    private func workflowStepShapeText(
        for actions: [TrustedAutomationAllowedAction]
    ) -> String {
        TrustedAutomationAllowedAction.workflowStepShapeText(for: actions)
    }
}
