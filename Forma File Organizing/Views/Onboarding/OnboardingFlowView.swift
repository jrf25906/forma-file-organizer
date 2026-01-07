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

        // Create CustomFolder entries for each selected folder so they appear in sidebar
        createCustomFoldersFromSelection()

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

        // Reload custom folders so sidebar updates
        dashboardViewModel.loadCustomFolders(from: modelContext)

        // Complete and dismiss
        dashboardViewModel.completeOnboarding()
    }

    // MARK: - Permissions & Setup

    /// Creates CustomFolder SwiftData entries from the onboarding folder selections.
    /// This bridges the gap between permissions granted during onboarding and the sidebar's dynamic locations.
    private func createCustomFoldersFromSelection() {
        var createdCount = 0

        for folder in state.selectedFolders {
            // Load the bookmark data that was saved during permission request
            guard let bookmarkData = SecureBookmarkStore.loadBookmark(forKey: folder.bookmarkKey) else {
                Log.warning("OnboardingFlowView: No bookmark found for \(folder.title), skipping CustomFolder creation", category: .bookmark)
                continue
            }

            // Check if a CustomFolder with this path already exists
            let existingPath = folder.folderPath
            let descriptor = FetchDescriptor<CustomFolder>(
                predicate: #Predicate { $0.path == existingPath }
            )

            do {
                let existing = try modelContext.fetch(descriptor)
                if !existing.isEmpty {
                    Log.info("OnboardingFlowView: CustomFolder for \(folder.title) already exists, skipping", category: .filesystem)
                    continue
                }

                // Create the CustomFolder entry
                let customFolder = try CustomFolder(
                    name: folder.title,
                    path: folder.folderPath,
                    bookmarkData: bookmarkData
                )

                modelContext.insert(customFolder)
                createdCount += 1
                Log.info("OnboardingFlowView: Created CustomFolder for \(folder.title)", category: .filesystem)
            } catch {
                Log.error("OnboardingFlowView: Failed to create CustomFolder for \(folder.title) - \(error.localizedDescription)", category: .filesystem)
            }
        }

        // Save all at once
        if createdCount > 0 {
            do {
                try modelContext.save()
                Log.info("OnboardingFlowView: Saved \(createdCount) CustomFolder entries from onboarding", category: .filesystem)
            } catch {
                Log.error("OnboardingFlowView: Failed to save CustomFolder entries - \(error.localizedDescription)", category: .filesystem)
            }
        }
    }

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
