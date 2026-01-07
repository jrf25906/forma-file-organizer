import SwiftUI

// MARK: - Preview Step View

/// Fifth step: Final preview showing complete folder structure before completion
struct OnboardingPreviewStepView: View {
    let folderSelection: OnboardingFolderSelection
    let templateSelection: FolderTemplateSelection
    let personality: OrganizationPersonality?
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var animateIn = false

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
                    // Header with celebration
                    VStack(spacing: FormaSpacing.standard) {
                        Text("✨")
                            .font(.formaIcon)
                            .scaleEffect(animateIn ? 1.0 : 0.5)
                            .opacity(animateIn ? 1.0 : 0)

                        Text("Your Organization System")
                            .font(.formaH1)
                            .foregroundColor(.formaLabel)
                            .opacity(animateIn ? 1.0 : 0)
                            .offset(y: animateIn ? 0 : 10)

                        Text("Here's how Forma will organize your files.\nFolders are created automatically when files need them.")
                            .font(.formaBodyLarge)
                            .foregroundColor(.formaSecondaryLabel)
                            .multilineTextAlignment(.center)
                            .opacity(animateIn ? 1.0 : 0)
                            .offset(y: animateIn ? 0 : 10)
                    }
                    .padding(.top, FormaSpacing.huge)

                    // Complete folder structure preview
                    VStack(alignment: .leading, spacing: FormaSpacing.generous) {
                        ForEach(Array(selectedFolders.enumerated()), id: \.element) { index, folder in
                            let template = templateSelection.template(for: folder, personality: personality)
                            FolderStructurePreview(
                                rootFolderName: folder.title,
                                template: template,
                                showAnnotations: true,
                                accentColor: folder.color
                            )
                            .padding(FormaSpacing.standard)
                            .background(
                                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                                    .fill(Color.formaBoneWhite.opacity(Color.FormaOpacity.strong + Color.FormaOpacity.light))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                                    .stroke(folder.color.opacity(Color.FormaOpacity.medium), lineWidth: 1)
                            )
                            .opacity(animateIn ? 1.0 : 0)
                            .offset(y: animateIn ? 0 : 20)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.1),
                                value: animateIn
                            )
                        }
                    }
                    .padding(.horizontal, FormaSpacing.large)

                    // Note about lazy folder creation
                    HStack(spacing: FormaSpacing.tight) {
                        Image(systemName: "sparkles")
                            .font(.formaBodySemibold)
                            .foregroundColor(.formaSage)

                        Text("These folders will be created as files are sorted.\nNo empty folders—just what you need, when needed.")
                            .font(.formaBody)
                            .foregroundColor(.formaSecondaryLabel)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(FormaSpacing.standard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(Color.formaSage.opacity(Color.FormaOpacity.light - Color.FormaOpacity.ultraSubtle))
                    )
                    .padding(.horizontal, FormaSpacing.large)
                    .opacity(animateIn ? 1.0 : 0)
                }
                .padding(.bottom, FormaSpacing.extraLarge)
            }

            // Footer with celebration button
            OnboardingFooter(
                primaryTitle: "🎉 Start Organizing",
                primaryEnabled: true,
                primaryAction: onComplete,
                secondaryTitle: "Back",
                secondaryAction: onBack
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateIn = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Preview Step") {
    OnboardingPreviewStepView(
        folderSelection: OnboardingFolderSelection(
            desktop: true,
            downloads: true,
            documents: false,
            pictures: true,
            music: false
        ),
        templateSelection: FolderTemplateSelection(
            desktop: .minimal,
            downloads: .para,
            pictures: .chronological
        ),
        personality: nil,
        onComplete: {},
        onBack: {}
    )
    .frame(width: 650, height: 720)
    .background(Color.formaBackground)
}
