import SwiftUI
import SwiftData

// MARK: - Onboarding Flow Coordinator

/// Unified onboarding flow that guides users through setup in 5 steps:
/// 1. Welcome - Value proposition and excitement
/// 2. Folders - User selects which folders to organize
/// 3. Quiz - Personality assessment for template recommendation
/// 4. Per-Folder Templates - Assign templates to each selected folder
/// 5. Preview - Review complete folder structure before starting
struct OnboardingFlowView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var state = OnboardingState()

    var body: some View {
        ZStack {
            // Background
            Color.formaBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator (hidden on welcome)
                if state.currentStep != .welcome {
                    OnboardingProgressBar(currentStep: state.currentStep)
                        .padding(.top, FormaSpacing.standard)
                        .padding(.horizontal, FormaSpacing.huge)
                }

                // Step content
                Group {
                    switch state.currentStep {
                    case .welcome:
                        WelcomeStepView(onContinue: advanceToFolders)

                    case .folders:
                        FolderSelectionStepView(
                            selection: $state.folderSelection,
                            isRequestingPermissions: state.isRequestingPermissions,
                            onContinue: advanceToQuiz,
                            onBack: { state.advance(to: .welcome) }
                        )
                        .environmentObject(dashboardViewModel)

                    case .quiz:
                        PersonalityQuizStepView(
                            onComplete: { result in
                                state.personality = result
                                // Initialize template selection with defaults based on personality
                                state.templateSelection.applyDefaults(
                                    personality: result,
                                    selectedFolders: state.folderSelection
                                )
                                advanceToFolderTemplates()
                            },
                            onBack: { state.advance(to: .folders) }
                        )

                    case .folderTemplates:
                        TemplateSelectionStepView(
                            folderSelection: $state.folderSelection,
                            templateSelection: $state.templateSelection,
                            personality: state.personality,
                            onContinue: advanceToPreview,
                            onBack: { state.advance(to: .quiz) }
                        )

                    case .preview:
                        OnboardingPreviewStepView(
                            folderSelection: state.folderSelection,
                            templateSelection: state.templateSelection,
                            personality: state.personality,
                            onComplete: completeOnboarding,
                            onBack: { state.advance(to: .folderTemplates) }
                        )
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .frame(width: 650, height: 720)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: state.currentStep)
    }

    // MARK: - Navigation

    private func advanceToFolders() {
        state.advance(to: .folders)
    }

    private func advanceToQuiz() {
        // Save folder selection
        state.folderSelection.save()

        // Request permissions BEFORE advancing - user must grant access
        state.isRequestingPermissions = true
        Task {
            await requestPermissionsForSelectedFolders()

            // Only advance after permissions are granted
            await MainActor.run {
                state.isRequestingPermissions = false
                state.advance(to: .quiz)
            }
        }
    }

    private func advanceToFolderTemplates() {
        state.advance(to: .folderTemplates)
    }

    private func advanceToPreview() {
        // Save template selection before preview
        state.templateSelection.save()
        state.advance(to: .preview)
    }

    private func completeOnboarding() {
        // Save all state
        state.folderSelection.save()
        state.templateSelection.save()
        state.personality?.save()

        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Note: Bookmarks are already saved to Keychain during permission requests.
        // BookmarkFolderService reads directly from Keychain, so no CustomFolder creation needed.

        // Apply per-folder template rules (creates scoped categories)
        dashboardViewModel.applyPerFolderTemplates(
            folderSelection: state.folderSelection,
            templateSelection: state.templateSelection,
            personality: state.personality,
            context: modelContext
        )

        // Log onboarding completion with summary of templates applied
        let activityService = ActivityLoggingService(modelContext: modelContext)
        let templatesUsed = Set(state.selectedFolders.map {
            state.templateSelection.template(for: $0, personality: state.personality).displayName
        })
        let templateSummary = templatesUsed.joined(separator: ", ")
        activityService.logOnboardingCompleted(templateName: templateSummary)

        // Refresh folder service so sidebar updates with newly granted permissions
        BookmarkFolderService.shared.refresh()

        // Complete and dismiss
        dashboardViewModel.completeOnboarding()
    }

    // MARK: - Permissions & Setup

    private func requestPermissionsForSelectedFolders() async {
        if state.folderSelection.desktop {
            _ = await dashboardViewModel.requestDesktopAccess()
        }
        if state.folderSelection.downloads {
            _ = await dashboardViewModel.requestDownloadsAccess()
        }
        if state.folderSelection.documents {
            _ = await dashboardViewModel.requestDocumentsAccess()
        }
        if state.folderSelection.pictures {
            _ = await dashboardViewModel.requestPicturesAccess()
        }
        if state.folderSelection.music {
            _ = await dashboardViewModel.requestMusicAccess()
        }
    }
}

// MARK: - Preview

#Preview("Full Onboarding") {
    OnboardingFlowView()
        .environmentObject(DashboardViewModel())
}
