import SwiftUI

// MARK: - Template Selection Step View

/// Fourth step: Per-folder template assignment
struct TemplateSelectionStepView: View {
    @Binding var folderSelection: OnboardingFolderSelection
    @Binding var templateSelection: FolderTemplateSelection
    let personality: OrganizationPersonality?
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var useGlobalTemplate = false

    private var selectedFolders: [OnboardingFolder] {
        var folders: [OnboardingFolder] = []
        if folderSelection.desktop { folders.append(.desktop) }
        if folderSelection.downloads { folders.append(.downloads) }
        if folderSelection.documents { folders.append(.documents) }
        if folderSelection.pictures { folders.append(.pictures) }
        if folderSelection.music { folders.append(.music) }
        return folders
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: FormaSpacing.generous) {
                    // Header
                    VStack(spacing: FormaSpacing.standard) {
                        OnboardingGeometricIcon(style: .system)
                            .frame(width: 64, height: 64)

                        Text("Customize Each Space")
                            .font(.formaH1)
                            .foregroundColor(.formaLabel)

                        Text("Different folders deserve different organization.\nTell us how you'd like each one organized.")
                            .font(.formaBodyLarge)
                            .foregroundColor(.formaSecondaryLabel)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, FormaSpacing.huge)

                    // Per-folder cards
                    VStack(spacing: FormaSpacing.standard) {
                        ForEach(selectedFolders, id: \.self) { folder in
                            FolderTemplateCard(
                                folder: folder,
                                selectedTemplate: binding(for: folder),
                                personality: personality
                            )
                        }
                    }
                    .padding(.horizontal, FormaSpacing.large)

                    // Use same template toggle
                    HStack(spacing: FormaSpacing.tight) {
                        Button(action: applyGlobalTemplate) {
                            HStack(spacing: FormaSpacing.tight) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.formaCompact)
                                Text("Use same template for all folders")
                                    .font(.formaBody)
                            }
                            .foregroundColor(.formaSteelBlue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, FormaSpacing.tight)

                    // Tip box
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "lightbulb.fill")
                            .font(.formaBodySemibold)
                            .foregroundColor(.formaWarmOrange)

                        Text("Tip: You can change these anytime in Settings")
                            .font(.formaBody)
                            .foregroundColor(.formaSecondaryLabel)
                    }
                    .padding(FormaSpacing.standard)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(Color.formaWarmOrange.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
                    )
                    .padding(.horizontal, FormaSpacing.large)
                }
                .padding(.bottom, FormaSpacing.extraLarge)
            }

            // Footer
            OnboardingFooter(
                primaryTitle: "Preview Your System",
                primaryEnabled: true,
                primaryAction: onContinue,
                secondaryTitle: "Back",
                secondaryAction: onBack
            )
        }
    }

    private func binding(for folder: OnboardingFolder) -> Binding<OrganizationTemplate> {
        Binding(
            get: { templateSelection.template(for: folder, personality: personality) },
            set: { newValue in
                var updated = templateSelection
                updated.setTemplate(newValue, for: folder)
                templateSelection = updated
            }
        )
    }

    private func applyGlobalTemplate() {
        let defaultTemplate = personality?.suggestedTemplate ?? .minimal
        var updated = templateSelection
        for folder in selectedFolders {
            updated.setTemplate(defaultTemplate, for: folder)
        }
        templateSelection = updated
    }
}

// MARK: - Preview

#Preview("Template Selection Step") {
    TemplateSelectionStepView(
        folderSelection: .constant(OnboardingFolderSelection(
            desktop: true,
            downloads: true,
            documents: false,
            pictures: true,
            music: false
        )),
        templateSelection: .constant(FolderTemplateSelection()),
        personality: nil,
        onContinue: {},
        onBack: {}
    )
    .frame(width: 650, height: 720)
    .background(Color.formaBackground)
}
